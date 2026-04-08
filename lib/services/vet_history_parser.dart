import 'dart:io';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as crypto;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../ai/ai_service.dart';
import '../config/emulator_config.dart';

class VetRecordParseResult {
  final VetRecordData parsedData;
  final String extractedText;
  final bool aiFailed;
  final double confidence;
  final String documentHash;

  const VetRecordParseResult({
    required this.parsedData,
    required this.extractedText,
    required this.aiFailed,
    required this.confidence,
    required this.documentHash,
  });
}

/// Service for parsing veterinary history documents with AI
/// Integrates Firebase Storage, PDF extraction, and AI parsing
class VetHistoryParser {
  final AIService _aiService;
  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;
  final String _cloudFunctionUrl;
  final String _cloudFunctionImageUrl;

  VetHistoryParser({
    required AIService aiService,
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
    String? cloudFunctionUrl,
    String? cloudFunctionImageUrl,
  }) : _aiService = aiService,
       _storage = storage ?? FirebaseStorage.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _cloudFunctionUrl =
           cloudFunctionUrl ?? EmulatorConfig.httpFunctionUrl('extractPdfText'),
       _cloudFunctionImageUrl =
           cloudFunctionImageUrl ??
           EmulatorConfig.httpFunctionUrl('extractImageText');

  /// Exposed for testing only. Use a static method to avoid needing Firebase.
  @visibleForTesting
  Map<String, dynamic> sanitizeVetJsonForTest(Map<String, dynamic> raw) =>
      _sanitizeVetJson(raw);

  String _aiDebugTag() {
    try {
      final aiService = _aiService;
      if (aiService is GPTService) {
        final provider = aiService.lastProvider;
        final modelUsed = aiService.lastModelUsed;
        final parts = <String>[];
        if (provider != null && provider.trim().isNotEmpty) {
          parts.add('provider=$provider');
        }
        if (modelUsed != null && modelUsed.trim().isNotEmpty) {
          parts.add('modelUsed=$modelUsed');
        }
        if (parts.isEmpty) return '';
        return ' (${parts.join(' ')})';
      }
    } catch (_) {
      // Best-effort only.
    }
    return '';
  }

  /// Upload PDF to Firebase Storage and parse veterinary records
  /// Returns parsed data and saves to Firestore
  Future<VetRecordData> parseUploadedPdf({
    required File pdfFile,
    required String petId,
    String? filename,
  }) async {
    try {
      // 1. Upload PDF to Firebase Storage
      final storageRef = await _uploadToStorage(pdfFile, petId, filename);
      final downloadUrl = await storageRef.getDownloadURL();
      final gsPath = _toGsPath(storageRef);

      // 2. Extract text from PDF using Cloud Function
      final extractedText = await _extractTextFromPdf(
        downloadUrl,
        gsPath: gsPath,
      );

      // 3. Parse text with AI
      final parsedData = await _parseWithAI(extractedText);

      // 4. Save to Firestore
      await _saveToFirestore(petId, parsedData, downloadUrl);

      return parsedData;
    } catch (e) {
      throw VetHistoryParseException('Failed to parse uploaded PDF: $e');
    }
  }

  /// Upload PDF bytes to Firebase Storage and parse veterinary records.
  ///
  /// This is the web-safe alternative to [parseUploadedPdf] (Flutter web cannot
  /// use `dart:io` File).
  Future<VetRecordData> parseUploadedPdfBytes({
    required Uint8List pdfBytes,
    required String petId,
    String? filename,
  }) async {
    try {
      final storageRef = await _uploadBytesToStorage(pdfBytes, petId, filename);
      final downloadUrl = await storageRef.getDownloadURL();

      final extractedText = await _extractTextFromPdf(
        downloadUrl,
        gsPath: _toGsPath(storageRef),
      );
      final parsedData = await _parseWithAI(extractedText);

      await _saveToFirestore(petId, parsedData, downloadUrl);
      return parsedData;
    } catch (e) {
      throw VetHistoryParseException('Failed to parse uploaded PDF bytes: $e');
    }
  }

  /// Upload PDF to Firebase Storage and parse veterinary records for an underwriting case.
  ///
  /// Stores artifacts under:
  /// - Storage: vet_records/cases/{caseId}/...
  /// - Firestore: underwriting_cases/{caseId}/vet_records/{docId}
  Future<VetRecordData> parseUploadedPdfForCase({
    required File pdfFile,
    required String caseId,
    String? petId,
    String? filename,
    double referralConfidenceThreshold = 60,
  }) async {
    try {
      final documentHash = crypto.sha256.convert(await pdfFile.readAsBytes()).toString();
      final storageRef = await _uploadToCaseStorage(
        pdfFile,
        caseId,
        filename,
        petId: petId,
      );
      final downloadUrl = await storageRef.getDownloadURL();

      final gsPath = _toGsPath(storageRef);

      final extractedText = await _extractTextFromPdf(
        downloadUrl,
        gsPath: gsPath,
      );

      // Store extracted text in Storage (avoid Firestore doc size limits)
      final textRef = await _uploadExtractedText(
        caseId: caseId,
        sourceFilename: filename,
        extractedText: extractedText,
      );
      final extractedTextUrl = await textRef.getDownloadURL();

      if (extractedText.trim().isEmpty) {
        final vetRecordDocId = await _saveCaseVetRecordFailure(
          caseId: caseId,
          petId: petId,
          pdfUrl: downloadUrl,
          extractedTextUrl: extractedTextUrl,
          error: 'No text extracted from document',
          documentHash: documentHash,
        );

        if (0 < referralConfidenceThreshold) {
          await _firestore.collection('underwriting_cases').doc(caseId).update({
            'status': 'referred',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          await _firestore
              .collection('underwriting_cases')
              .doc(caseId)
              .collection('events')
              .add({
                'eventType': 'referred_vet_parse_failed',
                'payload': {
                  'confidence': 0,
                  'threshold': referralConfidenceThreshold,
                  'vetRecordDocId': vetRecordDocId,
                },
                'createdAt': FieldValue.serverTimestamp(),
              });
        }

        throw VetHistoryParseException(
          'No text extracted from PDF (scanned/image-only PDF?)',
        );
      }

      VetRecordData parsedData;
      double confidence;
      String? vetRecordDocId;
      Object? parseError;

      try {
        parsedData = await _parseWithAI(extractedText);
        confidence = _estimateConfidence(
          extractedText: extractedText,
          parsedData: parsedData,
        );

        vetRecordDocId = await _saveToCaseFirestore(
          caseId: caseId,
          petId: petId,
          parsedData: parsedData,
          pdfUrl: downloadUrl,
          extractedTextUrl: extractedTextUrl,
          confidence: confidence,
          documentHash: documentHash,
        );
      } catch (e) {
        // Persist artifacts for audit/debug and mark the case as referred,
        // but throw so the UI can surface the failure.
        parsedData = _emptyVetRecordData();
        confidence = 0;
        parseError = e;
        vetRecordDocId = await _saveCaseVetRecordFailure(
          caseId: caseId,
          petId: petId,
          pdfUrl: downloadUrl,
          extractedTextUrl: extractedTextUrl,
          error: e.toString(),
          documentHash: documentHash,
        );
      }

      // Low confidence (or parse failure -> 0 confidence) => referral flag
      // (lane management, not a coverage decision).
      if (confidence < referralConfidenceThreshold) {
        await _firestore.collection('underwriting_cases').doc(caseId).update({
          'status': 'referred',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _firestore
            .collection('underwriting_cases')
            .doc(caseId)
            .collection('events')
            .add({
              'eventType': confidence == 0
                  ? 'referred_vet_parse_failed'
                  : 'referred_low_confidence_vet_parse',
              'payload': {
                'confidence': confidence,
                'threshold': referralConfidenceThreshold,
                'vetRecordDocId': vetRecordDocId,
              },
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      if (parseError != null) {
        throw VetHistoryParseException(
          'Vet record AI parse failed: ${parseError.toString()}',
        );
      }

      return parsedData;
    } catch (e) {
      throw VetHistoryParseException(
        'Failed to parse uploaded PDF for case: $e',
      );
    }
  }

  /// Upload PDF bytes to Firebase Storage and parse veterinary records for an underwriting case.
  ///
  /// Web-safe alternative to [parseUploadedPdfForCase].
  Future<VetRecordData> parseUploadedPdfBytesForCase({
    required Uint8List pdfBytes,
    required String caseId,
    String? petId,
    String? filename,
    double referralConfidenceThreshold = 60,
  }) async {
    try {
      final documentHash = crypto.sha256.convert(pdfBytes).toString();
      final storageRef = await _uploadBytesToCaseStorage(
        pdfBytes,
        caseId,
        filename,
        petId: petId,
      );
      final downloadUrl = await storageRef.getDownloadURL();

      final gsPath = _toGsPath(storageRef);

      String extractedText;
      try {
        extractedText = await _extractTextFromPdf(
          downloadUrl,
          gsPath: gsPath,
        );
      } catch (e) {
        final vetRecordDocId = await _saveCaseVetRecordFailure(
          caseId: caseId,
          petId: petId,
          pdfUrl: downloadUrl,
          extractedTextUrl: null,
          error: 'PDF text extraction failed: ${e.toString()}${_aiDebugTag()}',
          sourceType: 'pdf',
          sourceFilename: filename,
          documentHash: documentHash,
        );

        if (0 < referralConfidenceThreshold) {
          await _firestore.collection('underwriting_cases').doc(caseId).update({
            'status': 'referred',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          await _firestore
              .collection('underwriting_cases')
              .doc(caseId)
              .collection('events')
              .add({
                'eventType': 'referred_vet_parse_failed',
                'payload': {
                  'confidence': 0,
                  'threshold': referralConfidenceThreshold,
                  'vetRecordDocId': vetRecordDocId,
                  'sourceType': 'pdf',
                },
                'createdAt': FieldValue.serverTimestamp(),
              });
        }

        throw VetHistoryParseException(
          'PDF text extraction failed: ${e.toString()}${_aiDebugTag()}',
        );
      }

      final textRef = await _uploadExtractedText(
        caseId: caseId,
        sourceFilename: filename,
        extractedText: extractedText,
      );
      final extractedTextUrl = await textRef.getDownloadURL();

      if (extractedText.trim().isEmpty) {
        final vetRecordDocId = await _saveCaseVetRecordFailure(
          caseId: caseId,
          petId: petId,
          pdfUrl: downloadUrl,
          extractedTextUrl: extractedTextUrl,
          error: 'No text extracted from document${_aiDebugTag()}',
          sourceType: 'pdf',
          sourceFilename: filename,
          documentHash: documentHash,
        );

        if (0 < referralConfidenceThreshold) {
          await _firestore.collection('underwriting_cases').doc(caseId).update({
            'status': 'referred',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          await _firestore
              .collection('underwriting_cases')
              .doc(caseId)
              .collection('events')
              .add({
                'eventType': 'referred_vet_parse_failed',
                'payload': {
                  'confidence': 0,
                  'threshold': referralConfidenceThreshold,
                  'vetRecordDocId': vetRecordDocId,
                },
                'createdAt': FieldValue.serverTimestamp(),
              });
        }

        throw VetHistoryParseException(
          'No text extracted from PDF (scanned/image-only PDF?)',
        );
      }

      VetRecordData parsedData;
      double confidence;
      String? vetRecordDocId;
      Object? parseError;

      try {
        parsedData = await _parseWithAI(extractedText);
        confidence = _estimateConfidence(
          extractedText: extractedText,
          parsedData: parsedData,
        );

        vetRecordDocId = await _saveToCaseFirestore(
          caseId: caseId,
          petId: petId,
          parsedData: parsedData,
          pdfUrl: downloadUrl,
          extractedTextUrl: extractedTextUrl,
          confidence: confidence,
          documentHash: documentHash,
        );
      } catch (e) {
        parsedData = _emptyVetRecordData();
        confidence = 0;
        parseError = e;
        vetRecordDocId = await _saveCaseVetRecordFailure(
          caseId: caseId,
          petId: petId,
          pdfUrl: downloadUrl,
          extractedTextUrl: extractedTextUrl,
          error: '${e.toString()}${_aiDebugTag()}',
          sourceType: 'pdf',
          sourceFilename: filename,
          documentHash: documentHash,
        );
      }

      if (confidence < referralConfidenceThreshold) {
        await _firestore.collection('underwriting_cases').doc(caseId).update({
          'status': 'referred',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _firestore
            .collection('underwriting_cases')
            .doc(caseId)
            .collection('events')
            .add({
              'eventType': confidence == 0
                  ? 'referred_vet_parse_failed'
                  : 'referred_low_confidence_vet_parse',
              'payload': {
                'confidence': confidence,
                'threshold': referralConfidenceThreshold,
                'vetRecordDocId': vetRecordDocId,
              },
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      if (parseError != null) {
        throw VetHistoryParseException(
          'Vet record AI parse failed: ${parseError.toString()}',
        );
      }

      return parsedData;
    } catch (e) {
      throw VetHistoryParseException(
        'Failed to parse uploaded PDF bytes for case: $e',
      );
    }
  }

  /// Lenient variant of [parseUploadedPdfBytesForCase].
  ///
  /// - Always returns extractedText (when extraction succeeds).
  /// - Never throws due to AI parse failure (it returns empty parsedData + aiFailed=true).
  /// - Still throws on extraction/upload failures.
  Future<VetRecordParseResult> parseUploadedPdfBytesForCaseLenient({
    required Uint8List pdfBytes,
    required String caseId,
    String? petId,
    String? filename,
    double referralConfidenceThreshold = 60,
  }) async {
    final documentHash = crypto.sha256.convert(pdfBytes).toString();
    final storageRef = await _uploadBytesToCaseStorage(
      pdfBytes,
      caseId,
      filename,
      petId: petId,
    );
    final downloadUrl = await storageRef.getDownloadURL();

    final gsPath = _toGsPath(storageRef);

    final extractedText = await _extractTextFromPdf(
      downloadUrl,
      gsPath: gsPath,
    );

    final textRef = await _uploadExtractedText(
      caseId: caseId,
      sourceFilename: filename,
      extractedText: extractedText,
    );
    final extractedTextUrl = await textRef.getDownloadURL();

    if (extractedText.trim().isEmpty) {
      await _saveCaseVetRecordFailure(
        caseId: caseId,
        petId: petId,
        pdfUrl: downloadUrl,
        extractedTextUrl: extractedTextUrl,
        error: 'No text extracted from document${_aiDebugTag()}',
        sourceType: 'pdf',
        sourceFilename: filename,
        documentHash: documentHash,
      );
      throw VetHistoryParseException(
        'No text extracted from PDF (scanned/image-only PDF?)',
      );
    }

    try {
      final parsedData = await _parseWithAI(extractedText);
      final confidence = _estimateConfidence(
        extractedText: extractedText,
        parsedData: parsedData,
      );

      final vetRecordDocId = await _saveToCaseFirestore(
        caseId: caseId,
        petId: petId,
        parsedData: parsedData,
        pdfUrl: downloadUrl,
        extractedTextUrl: extractedTextUrl,
        confidence: confidence,
        sourceType: 'pdf',
        sourceFilename: filename,
        documentHash: documentHash,
      );

      if (confidence < referralConfidenceThreshold) {
        await _firestore.collection('underwriting_cases').doc(caseId).update({
          'status': 'referred',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _firestore
            .collection('underwriting_cases')
            .doc(caseId)
            .collection('events')
            .add({
              'eventType': 'referred_low_confidence_vet_parse',
              'payload': {
                'confidence': confidence,
                'threshold': referralConfidenceThreshold,
                'vetRecordDocId': vetRecordDocId,
                'sourceType': 'pdf',
              },
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      return VetRecordParseResult(
        parsedData: parsedData,
        extractedText: extractedText,
        aiFailed: false,
        confidence: confidence,
        documentHash: documentHash,
      );
    } catch (e) {
      await _saveCaseVetRecordFailure(
        caseId: caseId,
        petId: petId,
        pdfUrl: downloadUrl,
        extractedTextUrl: extractedTextUrl,
        error: '${e.toString()}${_aiDebugTag()}',
        sourceType: 'pdf',
        sourceFilename: filename,
        documentHash: documentHash,
      );

      if (0 < referralConfidenceThreshold) {
        await _firestore.collection('underwriting_cases').doc(caseId).update({
          'status': 'referred',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _firestore
            .collection('underwriting_cases')
            .doc(caseId)
            .collection('events')
            .add({
              'eventType': 'referred_vet_parse_failed',
              'payload': {
                'confidence': 0,
                'threshold': referralConfidenceThreshold,
                'sourceType': 'pdf',
              },
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      return VetRecordParseResult(
        parsedData: _emptyVetRecordData(),
        extractedText: extractedText,
        aiFailed: true,
        confidence: 0,
        documentHash: documentHash,
      );
    }
  }

  /// Upload image bytes (JPG/PNG) to Firebase Storage and parse veterinary
  /// records for an underwriting case.
  ///
  /// Stores artifacts under:
  /// - Storage: vet_records/cases/{caseId}/images/...
  /// - Firestore: underwriting_cases/{caseId}/vet_records/{docId}
  Future<VetRecordData> parseUploadedImageBytesForCase({
    required Uint8List imageBytes,
    required String caseId,
    String? petId,
    String? filename,
    String? contentType,
    double referralConfidenceThreshold = 60,
  }) async {
    try {
      final documentHash = crypto.sha256.convert(imageBytes).toString();
      final storageRef = await _uploadImageBytesToCaseStorage(
        imageBytes,
        caseId,
        filename,
        petId: petId,
        contentType: contentType,
      );
      final downloadUrl = await storageRef.getDownloadURL();

      String extractedText;
      try {
        extractedText = await _extractTextFromImage(
          downloadUrl,
          gsPath: _toGsPath(storageRef),
        );
      } catch (e) {
        final vetRecordDocId = await _saveCaseVetRecordFailure(
          caseId: caseId,
          petId: petId,
          pdfUrl: null,
          imageUrl: downloadUrl,
          extractedTextUrl: null,
          error: 'Image text extraction failed: ${e.toString()}${_aiDebugTag()}',
          sourceType: 'image',
          sourceFilename: filename,
          documentHash: documentHash,
        );

        if (0 < referralConfidenceThreshold) {
          await _firestore.collection('underwriting_cases').doc(caseId).update({
            'status': 'referred',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          await _firestore
              .collection('underwriting_cases')
              .doc(caseId)
              .collection('events')
              .add({
                'eventType': 'referred_vet_parse_failed',
                'payload': {
                  'confidence': 0,
                  'threshold': referralConfidenceThreshold,
                  'vetRecordDocId': vetRecordDocId,
                  'sourceType': 'image',
                },
                'createdAt': FieldValue.serverTimestamp(),
              });
        }

        throw VetHistoryParseException(
          'Image text extraction failed: ${e.toString()}${_aiDebugTag()}',
        );
      }

      final textRef = await _uploadExtractedText(
        caseId: caseId,
        sourceFilename: filename,
        extractedText: extractedText,
      );
      final extractedTextUrl = await textRef.getDownloadURL();

      if (extractedText.trim().isEmpty) {
        final vetRecordDocId = await _saveCaseVetRecordFailure(
          caseId: caseId,
          petId: petId,
          pdfUrl: null,
          imageUrl: downloadUrl,
          extractedTextUrl: extractedTextUrl,
          error: 'No text extracted from image${_aiDebugTag()}',
          sourceType: 'image',
          sourceFilename: filename,
          documentHash: documentHash,
        );

        if (0 < referralConfidenceThreshold) {
          await _firestore.collection('underwriting_cases').doc(caseId).update({
            'status': 'referred',
            'updatedAt': FieldValue.serverTimestamp(),
          });
          await _firestore
              .collection('underwriting_cases')
              .doc(caseId)
              .collection('events')
              .add({
                'eventType': 'referred_vet_parse_failed',
                'payload': {
                  'confidence': 0,
                  'threshold': referralConfidenceThreshold,
                  'vetRecordDocId': vetRecordDocId,
                  'sourceType': 'image',
                },
                'createdAt': FieldValue.serverTimestamp(),
              });
        }

        throw VetHistoryParseException('No text extracted from image');
      }

      VetRecordData parsedData;
      double confidence;
      String? vetRecordDocId;
      Object? parseError;

      try {
        parsedData = await _parseWithAI(extractedText);
        confidence = _estimateConfidence(
          extractedText: extractedText,
          parsedData: parsedData,
        );

        vetRecordDocId = await _saveToCaseFirestore(
          caseId: caseId,
          petId: petId,
          parsedData: parsedData,
          pdfUrl: null,
          imageUrl: downloadUrl,
          extractedTextUrl: extractedTextUrl,
          confidence: confidence,
          sourceType: 'image',
          sourceFilename: filename,
          documentHash: documentHash,
        );
      } catch (e) {
        parsedData = _emptyVetRecordData();
        confidence = 0;
        parseError = e;
        vetRecordDocId = await _saveCaseVetRecordFailure(
          caseId: caseId,
          petId: petId,
          pdfUrl: null,
          imageUrl: downloadUrl,
          extractedTextUrl: extractedTextUrl,
          error: '${e.toString()}${_aiDebugTag()}',
          sourceType: 'image',
          sourceFilename: filename,
          documentHash: documentHash,
        );
      }

      if (confidence < referralConfidenceThreshold) {
        await _firestore.collection('underwriting_cases').doc(caseId).update({
          'status': 'referred',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _firestore
            .collection('underwriting_cases')
            .doc(caseId)
            .collection('events')
            .add({
              'eventType': confidence == 0
                  ? 'referred_vet_parse_failed'
                  : 'referred_low_confidence_vet_parse',
              'payload': {
                'confidence': confidence,
                'threshold': referralConfidenceThreshold,
                'vetRecordDocId': vetRecordDocId,
                'sourceType': 'image',
              },
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      if (parseError != null) {
        throw VetHistoryParseException(
          'Vet record AI parse failed: ${parseError.toString()}',
        );
      }

      return parsedData;
    } catch (e) {
      throw VetHistoryParseException(
        'Failed to parse uploaded image bytes for case: $e',
      );
    }
  }

  /// Lenient variant of [parseUploadedImageBytesForCase].
  ///
  /// - Always returns extractedText (when extraction succeeds).
  /// - Never throws due to AI parse failure (it returns empty parsedData + aiFailed=true).
  /// - Still throws on extraction/upload failures.
  Future<VetRecordParseResult> parseUploadedImageBytesForCaseLenient({
    required Uint8List imageBytes,
    required String caseId,
    String? petId,
    String? filename,
    String? contentType,
    double referralConfidenceThreshold = 60,
  }) async {
    final documentHash = crypto.sha256.convert(imageBytes).toString();
    final storageRef = await _uploadImageBytesToCaseStorage(
      imageBytes,
      caseId,
      filename,
      petId: petId,
      contentType: contentType,
    );
    final downloadUrl = await storageRef.getDownloadURL();

    final extractedText = await _extractTextFromImage(
      downloadUrl,
      gsPath: _toGsPath(storageRef),
    );

    final textRef = await _uploadExtractedText(
      caseId: caseId,
      sourceFilename: filename,
      extractedText: extractedText,
    );
    final extractedTextUrl = await textRef.getDownloadURL();

    if (extractedText.trim().isEmpty) {
      await _saveCaseVetRecordFailure(
        caseId: caseId,
        petId: petId,
        pdfUrl: null,
        imageUrl: downloadUrl,
        extractedTextUrl: extractedTextUrl,
        error: 'No text extracted from image${_aiDebugTag()}',
        sourceType: 'image',
        sourceFilename: filename,
        documentHash: documentHash,
      );
      throw VetHistoryParseException('No text extracted from image');
    }

    try {
      final parsedData = await _parseWithAI(extractedText);
      final confidence = _estimateConfidence(
        extractedText: extractedText,
        parsedData: parsedData,
      );

      final vetRecordDocId = await _saveToCaseFirestore(
        caseId: caseId,
        petId: petId,
        parsedData: parsedData,
        pdfUrl: null,
        imageUrl: downloadUrl,
        extractedTextUrl: extractedTextUrl,
        confidence: confidence,
        sourceType: 'image',
        sourceFilename: filename,
        documentHash: documentHash,
      );

      if (confidence < referralConfidenceThreshold) {
        await _firestore.collection('underwriting_cases').doc(caseId).update({
          'status': 'referred',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _firestore
            .collection('underwriting_cases')
            .doc(caseId)
            .collection('events')
            .add({
              'eventType': 'referred_low_confidence_vet_parse',
              'payload': {
                'confidence': confidence,
                'threshold': referralConfidenceThreshold,
                'vetRecordDocId': vetRecordDocId,
                'sourceType': 'image',
              },
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      return VetRecordParseResult(
        parsedData: parsedData,
        extractedText: extractedText,
        aiFailed: false,
        confidence: confidence,
        documentHash: documentHash,
      );
    } catch (e) {
      await _saveCaseVetRecordFailure(
        caseId: caseId,
        petId: petId,
        pdfUrl: null,
        imageUrl: downloadUrl,
        extractedTextUrl: extractedTextUrl,
        error: '${e.toString()}${_aiDebugTag()}',
        sourceType: 'image',
        sourceFilename: filename,
        documentHash: documentHash,
      );

      if (0 < referralConfidenceThreshold) {
        await _firestore.collection('underwriting_cases').doc(caseId).update({
          'status': 'referred',
          'updatedAt': FieldValue.serverTimestamp(),
        });
        await _firestore
            .collection('underwriting_cases')
            .doc(caseId)
            .collection('events')
            .add({
              'eventType': 'referred_vet_parse_failed',
              'payload': {
                'confidence': 0,
                'threshold': referralConfidenceThreshold,
                'sourceType': 'image',
              },
              'createdAt': FieldValue.serverTimestamp(),
            });
      }

      return VetRecordParseResult(
        parsedData: _emptyVetRecordData(),
        extractedText: extractedText,
        aiFailed: true,
        confidence: 0,
        documentHash: documentHash,
      );
    }
  }

  VetRecordData _emptyVetRecordData() {
    return VetRecordData(
      vaccinations: const [],
      treatments: const [],
      medications: const [],
      allergies: const [],
      surgeries: const [],
      diagnoses: const [],
      previousClaims: const [],
      lastCheckup: null,
    );
  }

  Future<String> _saveCaseVetRecordFailure({
    required String caseId,
    String? petId,
    String? pdfUrl,
    String? imageUrl,
    String? extractedTextUrl,
    required String error,
    String? sourceType,
    String? sourceFilename,
    String? documentHash,
  }) async {
    final docRef = _firestore
        .collection('underwriting_cases')
        .doc(caseId)
        .collection('vet_records')
        .doc();

    await docRef.set({
      ..._emptyVetRecordData().toJson(),
      'id': docRef.id,
      'caseId': caseId,
      'petId': petId,
      'pdfUrl': pdfUrl,
      'imageUrl': imageUrl,
      if (documentHash != null && documentHash.trim().isNotEmpty)
        'documentHash': documentHash,
      'sourceType': sourceType ?? (pdfUrl != null ? 'pdf' : null),
      'sourceFilename': sourceFilename,
      'extractedTextUrl': extractedTextUrl,
      'confidence': 0,
      'parsedAt': FieldValue.serverTimestamp(),
      'status': 'parse_failed',
      'error': error,
    });

    await _firestore
        .collection('underwriting_cases')
        .doc(caseId)
        .collection('events')
        .add({
          'eventType': 'vet_record_parse_failed',
          'payload': {'vetRecordDocId': docRef.id, 'error': error},
          'createdAt': FieldValue.serverTimestamp(),
        });

    return docRef.id;
  }

  /// Parse veterinary records from text input (for testing or manual entry)
  Future<VetRecordData> parseText(String text) async {
    try {
      final parsedData = await _parseWithAI(text);
      return parsedData;
    } catch (e) {
      throw VetHistoryParseException('Failed to parse text: $e');
    }
  }

  /// Parse and save veterinary records with petId
  Future<VetRecordData> parseAndSave({
    required String text,
    required String petId,
  }) async {
    try {
      final parsedData = await _parseWithAI(text);
      await _saveToFirestore(petId, parsedData, null);
      return parsedData;
    } catch (e) {
      throw VetHistoryParseException('Failed to parse and save: $e');
    }
  }

  /// Upload PDF to Firebase Storage
  Future<Reference> _uploadToStorage(
    File pdfFile,
    String petId,
    String? filename,
  ) async {
    final fileName =
        filename ?? 'vet_records_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final storageRef = _storage.ref().child('vet_records/$petId/$fileName');

    await storageRef.putFile(
      pdfFile,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'petId': petId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    return storageRef;
  }

  Future<Reference> _uploadBytesToStorage(
    Uint8List pdfBytes,
    String petId,
    String? filename,
  ) async {
    final fileName =
        filename ?? 'vet_records_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final storageRef = _storage.ref().child('vet_records/$petId/$fileName');

    await storageRef.putData(
      pdfBytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'petId': petId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    return storageRef;
  }

  Future<Reference> _uploadToCaseStorage(
    File pdfFile,
    String caseId,
    String? filename, {
    String? petId,
  }) async {
    final fileName =
        filename ?? 'vet_record_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final storageRef = _storage.ref().child(
      'vet_records/cases/$caseId/$fileName',
    );

    await storageRef.putFile(
      pdfFile,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'caseId': caseId,
          if (petId != null) 'petId': petId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    return storageRef;
  }

  Future<Reference> _uploadBytesToCaseStorage(
    Uint8List pdfBytes,
    String caseId,
    String? filename, {
    String? petId,
  }) async {
    final fileName =
        filename ?? 'vet_record_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final storageRef = _storage.ref().child(
      'vet_records/cases/$caseId/$fileName',
    );

    await storageRef.putData(
      pdfBytes,
      SettableMetadata(
        contentType: 'application/pdf',
        customMetadata: {
          'caseId': caseId,
          if (petId != null) 'petId': petId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    return storageRef;
  }

  Future<Reference> _uploadExtractedText({
    required String caseId,
    required String? sourceFilename,
    required String extractedText,
  }) async {
    final base = (sourceFilename ?? 'vet_record').replaceAll(
      RegExp(r'\.(pdf|png|jpg|jpeg|webp|heic)$', caseSensitive: false),
      '',
    );
    final textName = '${base}_${DateTime.now().millisecondsSinceEpoch}.txt';
    final ref = _storage.ref().child(
      'vet_records/cases/$caseId/extracted/$textName',
    );

    await ref.putData(
      utf8.encode(extractedText),
      SettableMetadata(
        contentType: 'text/plain',
        customMetadata: {
          'caseId': caseId,
          'createdAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    return ref;
  }

  /// Extract text from PDF using Cloud Function
  String _toGsPath(Reference ref) {
    return 'gs://${ref.bucket}/${ref.fullPath}';
  }

  /// Extract text from PDF using Cloud Function
  Future<String> _extractTextFromPdf(
    String downloadUrl, {
    String? gsPath,
  }) async {
    const maxAttempts = 3;
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse(_cloudFunctionUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'pdfUrl': downloadUrl,
                if (gsPath != null) 'gsPath': gsPath,
              }),
            )
            .timeout(Duration(seconds: 35 + (attempt * 10)));

        if (response.statusCode != 200) {
          throw VetHistoryParseException(
            'PDF text extraction failed: ${response.statusCode} - ${response.body}',
          );
        }

        final data = jsonDecode(response.body);
        final text = (data is Map) ? (data['text'] as String?) : null;
        if (text == null) {
          throw VetHistoryParseException(
            'PDF text extraction returned unexpected response payload',
          );
        }

        // If extraction is intermittently empty (cold starts / transient errors),
        // retry once or twice before giving up.
        if (text.trim().isEmpty) {
          throw VetHistoryParseException('PDF text extraction returned empty text');
        }

        return text;
      } catch (e) {
        lastError = e;
        if (attempt >= maxAttempts) break;
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }

    throw VetHistoryParseException('PDF text extraction failed: $lastError');
  }

  /// Extract text from an image using Cloud Function
  Future<String> _extractTextFromImage(
    String downloadUrl, {
    String? gsPath,
  }) async {
    const maxAttempts = 3;
    Object? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        final response = await http
            .post(
              Uri.parse(_cloudFunctionImageUrl),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'imageUrl': downloadUrl,
                if (gsPath != null) 'gsPath': gsPath,
              }),
            )
            .timeout(Duration(seconds: 35 + (attempt * 10)));

        if (response.statusCode != 200) {
          throw VetHistoryParseException(
            'Image text extraction failed: ${response.statusCode} - ${response.body}',
          );
        }

        final data = jsonDecode(response.body);
        final text = (data is Map) ? (data['text'] as String?) : null;
        if (text == null) {
          throw VetHistoryParseException(
            'Image text extraction returned unexpected response payload',
          );
        }

        if (text.trim().isEmpty) {
          throw VetHistoryParseException('Image text extraction returned empty text');
        }

        return text;
      } catch (e) {
        lastError = e;
        if (attempt >= maxAttempts) break;
        await Future.delayed(Duration(milliseconds: 300 * attempt));
      }
    }

    throw VetHistoryParseException('Image text extraction failed: $lastError');
  }

  Future<Reference> _uploadImageBytesToCaseStorage(
    Uint8List imageBytes,
    String caseId,
    String? filename, {
    String? petId,
    String? contentType,
  }) async {
    final safeType = (contentType == null || contentType.trim().isEmpty)
        ? 'image/jpeg'
        : contentType;
    final extension = _extensionFromContentType(safeType);
    final fileName =
        filename ??
        'vet_record_image_${DateTime.now().millisecondsSinceEpoch}.$extension';

    final storageRef = _storage.ref().child(
      'vet_records/cases/$caseId/images/$fileName',
    );

    await storageRef.putData(
      imageBytes,
      SettableMetadata(
        contentType: safeType,
        customMetadata: {
          'caseId': caseId,
          if (petId != null) 'petId': petId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      ),
    );

    return storageRef;
  }

  String _extensionFromContentType(String contentType) {
    final lower = contentType.toLowerCase();
    if (lower.contains('png')) return 'png';
    if (lower.contains('webp')) return 'webp';
    if (lower.contains('heic')) return 'heic';
    return 'jpg';
  }

  /// Parse veterinary records using AI (GPT-4 or Claude)
  Future<VetRecordData> _parseWithAI(String text) async {
    // Retry AI parsing a couple of times to smooth over occasional
    // function timeouts / model hiccups / JSON formatting glitches.
    const maxAttempts = 4;

    Object? lastError;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // If the extracted text is very large, chunk it to avoid model context limits
        // and reduce the chance of JSON truncation.
        if (_shouldChunkText(text)) {
          return await _parseWithAIChunked(text);
        }

        final prompt = _buildAIPrompt(text);
        final aiResponse = await _aiService.generateText(
          prompt,
          options: {
            'response_format': {'type': 'json_object'},
            // Vet record JSON can be large; avoid truncation.
            'max_tokens': 3000,
            // Vet parsing is a high-value, high-reliability action. Keep Gemini
            // as the default provider, but allow opt-in OpenAI fallback if
            // Gemini returns empty output / times out / errors.
            'allowOpenAIFallback': true,
            // Lower temperature improves JSON consistency.
            'temperature': 0.0,
          },
        );

        final parsedJson = _decodeJsonResponse(aiResponse);
        final sanitized = _sanitizeVetJson(parsedJson);
        return VetRecordData.fromAIJson(sanitized);
      } catch (e) {
        lastError = e;
        if (attempt >= maxAttempts) break;

        // Small backoff before retrying.
        await Future.delayed(Duration(milliseconds: 250 * attempt));
      }
    }

    throw VetHistoryParseException('AI parsing failed: $lastError');
  }

  bool _shouldChunkText(String text) {
    // Heuristic: characters, not tokens. This errs on the safe side.
    // (Long PDFs can exceed context limits once wrapped in prompts.)
    return text.trim().length > 30000;
  }

  Future<VetRecordData> _parseWithAIChunked(String text) async {
    final chunks = _splitIntoOverlappingChunks(
      text,
      maxChunkChars: 18000,
      overlapChars: 800,
    );

    Map<String, dynamic> merged = _emptyVetJson();

    for (var i = 0; i < chunks.length; i++) {
      final chunk = chunks[i];
      final prompt = _buildChunkedAIPrompt(
        chunkText: chunk,
        chunkIndex: i + 1,
        totalChunks: chunks.length,
      );

      const maxAttempts = 2;
      Object? lastError;
      for (var attempt = 1; attempt <= maxAttempts; attempt++) {
        try {
          final aiResponse = await _aiService.generateText(
            prompt,
            options: {
              'response_format': {'type': 'json_object'},
              'max_tokens': 2500,
              'allowOpenAIFallback': true,
              'temperature': 0.0,
            },
          );

          final parsed = _decodeJsonResponse(aiResponse);
          final sanitized = _sanitizeVetJson(parsed);
          merged = _mergeVetJson(merged, sanitized);
          lastError = null;
          break;
        } catch (e) {
          lastError = e;
          if (attempt >= maxAttempts) break;
          await Future.delayed(Duration(milliseconds: 250 * attempt));
        }
      }

      if (lastError != null) {
        throw VetHistoryParseException(
          'AI parsing failed for chunk ${i + 1}/${chunks.length}: $lastError',
        );
      }
    }

    return VetRecordData.fromAIJson(merged);
  }

  List<String> _splitIntoOverlappingChunks(
    String text, {
    required int maxChunkChars,
    required int overlapChars,
  }) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return const [];

    final chunks = <String>[];
    var start = 0;
    while (start < trimmed.length) {
      final end = min(trimmed.length, start + maxChunkChars);
      chunks.add(trimmed.substring(start, end));

      if (end >= trimmed.length) break;
      start = max(0, end - overlapChars);
    }
    return chunks;
  }

  String _buildChunkedAIPrompt({
    required String chunkText,
    required int chunkIndex,
    required int totalChunks,
  }) {
    return '''
You are a veterinary records parser.

This is chunk $chunkIndex of $totalChunks from a larger veterinary record. Extract ONLY the information present in this chunk.

VETERINARY RECORD CHUNK:
$chunkText

Extract and return a JSON object with the following structure:
{
  "diagnoses": [
    {
      "condition": "string (medical condition name)",
      "date": "string (ISO 8601 date)",
      "status": "string (active, resolved, chronic)",
      "severity": "string (mild, moderate, severe)",
      "notes": "string (additional details)"
    }
  ],
  "medications": [
    {
      "name": "string (medication name)",
      "dosage": "string (e.g., 10mg twice daily)",
      "startDate": "string (ISO 8601 date)",
      "endDate": "string or null (ISO 8601 date if ended)",
      "purpose": "string (reason for medication)"
    }
  ],
  "vaccinations": [
    {
      "name": "string (vaccine name, e.g., Rabies, DHPP)",
      "date": "string (ISO 8601 date)",
      "expiryDate": "string or null (ISO 8601 date)",
      "veterinarian": "string or null"
    }
  ],
  "allergies": [
    "string (allergen name)"
  ],
  "surgeries": [
    {
      "procedure": "string (surgery name)",
      "date": "string (ISO 8601 date)",
      "complications": "string or null",
      "outcome": "string (successful, complications, etc.)"
    }
  ],
  "previousClaims": [
    {
      "date": "string (ISO 8601 date)",
      "condition": "string (reason for claim)",
      "amount": "number or null (claim amount if mentioned)",
      "status": "string (approved, denied, pending)"
    }
  ],
  "treatments": [
    {
      "diagnosis": "string",
      "date": "string (ISO 8601 date)",
      "treatment": "string (treatment provided)",
      "notes": "string or null"
    }
  ],
  "lastCheckup": "string or null (ISO 8601 date of most recent checkup)"
}
Important:
- Use ISO 8601 format for all dates (YYYY-MM-DD)
- If information is not present in THIS chunk, use null or empty arrays
- Be accurate; do not invent

Return only valid JSON, no additional text.
''';
  }

  Map<String, dynamic> _decodeJsonResponse(String response) {
    String cleaned = response.trim();

    // Remove common markdown wrappers.
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```json\n?'), '')
          .replaceFirst(RegExp(r'^```\n?'), '')
          .replaceFirst(RegExp(r'\n?```$'), '');
    }

    // First attempt: direct JSON.
    try {
      final decoded = jsonDecode(cleaned);
      if (decoded is Map<String, dynamic>) return decoded;
      throw VetHistoryParseException('AI returned non-object JSON');
    } catch (_) {
      // Second attempt: extract the first JSON object from surrounding text.
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start != -1 && end != -1 && end > start) {
        final candidate = cleaned.substring(start, end + 1).trim();
        final decoded = jsonDecode(candidate);
        if (decoded is Map<String, dynamic>) return decoded;
        throw VetHistoryParseException('AI returned non-object JSON');
      }

      throw VetHistoryParseException('AI returned invalid JSON');
    }
  }

  Map<String, dynamic> _emptyVetJson() {
    return {
      'diagnoses': <dynamic>[],
      'medications': <dynamic>[],
      'vaccinations': <dynamic>[],
      'allergies': <dynamic>[],
      'surgeries': <dynamic>[],
      'previousClaims': <dynamic>[],
      'treatments': <dynamic>[],
      'lastCheckup': null,
    };
  }

  Map<String, dynamic> _mergeVetJson(
    Map<String, dynamic> base,
    Map<String, dynamic> add,
  ) {
    final merged = <String, dynamic>{...base};
    for (final key in _emptyVetJson().keys) {
      if (key == 'lastCheckup') {
        merged[key] = _pickLatestIsoDate(base[key], add[key]);
        continue;
      }

      if (key == 'allergies') {
        final a = (base[key] as List<dynamic>? ?? []).cast<dynamic>();
        final b = (add[key] as List<dynamic>? ?? []).cast<dynamic>();
        final set = <String>{};
        for (final v in [...a, ...b]) {
          if (v is! String) continue;
          final norm = v.trim();
          if (norm.isEmpty) continue;
          set.add(norm);
        }
        merged[key] = set.toList();
        continue;
      }

      final a = (base[key] as List<dynamic>? ?? []).cast<dynamic>();
      final b = (add[key] as List<dynamic>? ?? []).cast<dynamic>();
      merged[key] = _dedupeListOfMaps([...a, ...b]);
    }
    return merged;
  }

  List<dynamic> _dedupeListOfMaps(List<dynamic> items) {
    final out = <dynamic>[];
    final seen = <String>{};
    for (final item in items) {
      if (item is! Map) continue;
      final normalized = _deepSortMap(item);
      final sig = jsonEncode(normalized);
      if (seen.add(sig)) {
        out.add(item);
      }
    }
    return out;
  }

  dynamic _deepSortMap(dynamic value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      final out = <String, dynamic>{};
      for (final k in keys) {
        out[k] = _deepSortMap(value[k]);
      }
      return out;
    }
    if (value is List) {
      return value.map(_deepSortMap).toList();
    }
    return value;
  }

  String? _pickLatestIsoDate(dynamic a, dynamic b) {
    final da = _tryParseDate(a);
    final db = _tryParseDate(b);
    if (da == null && db == null) return null;
    if (da == null) return db!.toIso8601String().split('T').first;
    if (db == null) return da.toIso8601String().split('T').first;
    return (db.isAfter(da) ? db : da).toIso8601String().split('T').first;
  }

  static final _monthNames = <String, int>{
    'jan': 1, 'january': 1,
    'feb': 2, 'february': 2,
    'mar': 3, 'march': 3,
    'apr': 4, 'april': 4,
    'may': 5,
    'jun': 6, 'june': 6,
    'jul': 7, 'july': 7,
    'aug': 8, 'august': 8,
    'sep': 9, 'sept': 9, 'september': 9,
    'oct': 10, 'october': 10,
    'nov': 11, 'november': 11,
    'dec': 12, 'december': 12,
  };

  DateTime? _tryParseDate(dynamic v) {
    if (v is! String) return null;
    final s = v.trim();
    if (s.isEmpty) return null;

    // 1) ISO 8601 / standard DateTime.parse formats.
    try {
      return DateTime.parse(s);
    } catch (_) {}

    final lower = s.toLowerCase();

    // 2) "Month YYYY" or "Month DD, YYYY" or "DD Month YYYY".
    final mdyMatch = RegExp(
      r'(\w+)\s+(\d{1,2}),?\s+(\d{4})',
    ).firstMatch(lower);
    if (mdyMatch != null) {
      final month = _monthNames[mdyMatch.group(1)];
      final day = int.tryParse(mdyMatch.group(2) ?? '');
      final year = int.tryParse(mdyMatch.group(3) ?? '');
      if (month != null && day != null && year != null && year > 1900) {
        return DateTime(year, month, day);
      }
    }

    // 3) "DD Month YYYY"
    final dmyMatch = RegExp(
      r'(\d{1,2})\s+(\w+)\s+(\d{4})',
    ).firstMatch(lower);
    if (dmyMatch != null) {
      final day = int.tryParse(dmyMatch.group(1) ?? '');
      final month = _monthNames[dmyMatch.group(2)];
      final year = int.tryParse(dmyMatch.group(3) ?? '');
      if (day != null && month != null && year != null && year > 1900) {
        return DateTime(year, month, day);
      }
    }

    // 4) "Month YYYY" (no day).
    final myMatch = RegExp(
      r'(\w+)\s+(\d{4})',
    ).firstMatch(lower);
    if (myMatch != null) {
      final month = _monthNames[myMatch.group(1)];
      final year = int.tryParse(myMatch.group(2) ?? '');
      if (month != null && year != null && year > 1900) {
        return DateTime(year, month);
      }
    }

    // 5) MM/DD/YYYY or MM-DD-YYYY
    final slashMatch = RegExp(
      r'(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})',
    ).firstMatch(s);
    if (slashMatch != null) {
      final a = int.tryParse(slashMatch.group(1) ?? '');
      final b = int.tryParse(slashMatch.group(2) ?? '');
      final year = int.tryParse(slashMatch.group(3) ?? '');
      if (a != null && b != null && year != null && year > 1900) {
        // Assume MM/DD/YYYY when month <= 12.
        if (a >= 1 && a <= 12) return DateTime(year, a, b);
        if (b >= 1 && b <= 12) return DateTime(year, b, a);
      }
    }

    return null;
  }

  Map<String, dynamic> _sanitizeVetJson(Map<String, dynamic> raw) {
    final out = _emptyVetJson();

    out['allergies'] = (raw['allergies'] as List<dynamic>? ?? [])
        .whereType<String>()
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    out['lastCheckup'] = _pickLatestIsoDate(null, raw['lastCheckup']);

    out['vaccinations'] = _sanitizeList(raw['vaccinations'], (m) {
      final name = (m['name'] as String?)?.trim();
      final date = _tryParseDate(m['date']);
      if (name == null || name.isEmpty || date == null) return null;
      final expiry = _tryParseDate(m['expiryDate']);
      return {
        'name': name,
        'date': date.toIso8601String().split('T').first,
        'expiryDate': expiry?.toIso8601String().split('T').first,
        'veterinarian': (m['veterinarian'] as String?)?.trim(),
      };
    });

    out['treatments'] = _sanitizeList(raw['treatments'], (m) {
      final diagnosis = (m['diagnosis'] as String?)?.trim();
      final treatment = (m['treatment'] as String?)?.trim();
      final date = _tryParseDate(m['date']);
      if (diagnosis == null || diagnosis.isEmpty) return null;
      if (treatment == null || treatment.isEmpty) return null;
      if (date == null) return null;
      return {
        'diagnosis': diagnosis,
        'date': date.toIso8601String().split('T').first,
        'treatment': treatment,
        'notes': (m['notes'] as String?)?.trim(),
      };
    });

    out['medications'] = _sanitizeList(raw['medications'], (m) {
      final name = (m['name'] as String?)?.trim();
      final dosage = (m['dosage'] as String?)?.trim();
      final start = _tryParseDate(m['startDate']);
      if (name == null || name.isEmpty) return null;
      if (dosage == null || dosage.isEmpty) return null;
      if (start == null) return null;
      final end = _tryParseDate(m['endDate']);
      return {
        'name': name,
        'dosage': dosage,
        'startDate': start.toIso8601String().split('T').first,
        'endDate': end?.toIso8601String().split('T').first,
        'purpose': (m['purpose'] as String?)?.trim(),
      };
    });

    out['surgeries'] = _sanitizeList(raw['surgeries'], (m) {
      final procedure = (m['procedure'] as String?)?.trim();
      final date = _tryParseDate(m['date']);
      if (procedure == null || procedure.isEmpty || date == null) return null;
      return {
        'procedure': procedure,
        'date': date.toIso8601String().split('T').first,
        'complications': (m['complications'] as String?)?.trim(),
        'outcome': (m['outcome'] as String?)?.trim(),
      };
    });

    out['diagnoses'] = _sanitizeList(raw['diagnoses'], (m) {
      final condition = (m['condition'] as String?)?.trim();
      if (condition == null || condition.isEmpty) {
        debugPrint('[VetRecordParse] Dropped diagnosis: empty condition field '
            '(raw: ${m.keys.toList()})');
        return null;
      }

      final status = (m['status'] as String?)?.trim();
      final severity = (m['severity'] as String?)?.trim();
      final rawDate = m['date'];
      final date = _tryParseDate(rawDate);

      // Default missing fields instead of dropping the entire diagnosis.
      final effectiveDate = date ?? DateTime.now();
      const validStatuses = {'active', 'resolved', 'chronic'};
      final effectiveStatus =
          (status != null && validStatuses.contains(status.toLowerCase()))
              ? status.toLowerCase()
              : 'active';
      const validSeverities = {'mild', 'moderate', 'severe'};
      final effectiveSeverity =
          (severity != null && validSeverities.contains(severity.toLowerCase()))
              ? severity.toLowerCase()
              : 'unknown';

      if (date == null || status == null || severity == null) {
        debugPrint('[VetRecordParse] Diagnosis "$condition" recovered with '
            'defaults: date=${date == null ? "defaulted (raw=$rawDate)" : "ok"}, '
            'status=${status ?? "defaulted→$effectiveStatus"}, '
            'severity=${severity ?? "defaulted→$effectiveSeverity"}');
      }

      return {
        'condition': condition,
        'date': effectiveDate.toIso8601String().split('T').first,
        'status': effectiveStatus,
        'severity': effectiveSeverity,
        'notes': (m['notes'] as String?)?.trim(),
      };
    });

    out['previousClaims'] = _sanitizeList(raw['previousClaims'], (m) {
      final condition = (m['condition'] as String?)?.trim();
      final status = (m['status'] as String?)?.trim();
      final date = _tryParseDate(m['date']);
      if (condition == null || condition.isEmpty) return null;
      if (status == null || status.isEmpty) return null;
      if (date == null) return null;
      final amount = m['amount'];
      return {
        'date': date.toIso8601String().split('T').first,
        'condition': condition,
        'amount': amount is num ? amount.toDouble() : null,
        'status': status,
      };
    });

    debugPrint('[VetRecordParse] _sanitizeVetJson summary: '
        '${(out['diagnoses'] as List).length} diagnoses, '
        '${(out['treatments'] as List).length} treatments, '
        '${(out['medications'] as List).length} medications, '
        '${(out['vaccinations'] as List).length} vaccinations, '
        '${(out['surgeries'] as List).length} surgeries, '
        '${(out['allergies'] as List).length} allergies');

    return out;
  }

  List<dynamic> _sanitizeList(
    dynamic value,
    Map<String, dynamic>? Function(Map<String, dynamic> item) mapper,
  ) {
    if (value is! List) return <dynamic>[];
    final out = <dynamic>[];
    for (final e in value) {
      if (e is! Map) continue;
      final mapped = mapper(e.cast<String, dynamic>());
      if (mapped != null) out.add(mapped);
    }
    return _dedupeListOfMaps(out);
  }

  /// Build AI prompt for structured veterinary record extraction
  String _buildAIPrompt(String vetRecordText) {
    return '''
You are a veterinary records parser. Extract structured information from the following veterinary document.

VETERINARY RECORD:
$vetRecordText

Extract and return a JSON object with the following structure:
{
  "diagnoses": [
    {
      "condition": "string (medical condition name)",
      "date": "string (ISO 8601 date)",
      "status": "string (active, resolved, chronic)",
      "severity": "string (mild, moderate, severe)",
      "notes": "string (additional details)"
    }
  ],
  "medications": [
    {
      "name": "string (medication name)",
      "dosage": "string (e.g., 10mg twice daily)",
      "startDate": "string (ISO 8601 date)",
      "endDate": "string or null (ISO 8601 date if ended)",
      "purpose": "string (reason for medication)"
    }
  ],
  "vaccinations": [
    {
      "name": "string (vaccine name, e.g., Rabies, DHPP)",
      "date": "string (ISO 8601 date)",
      "expiryDate": "string or null (ISO 8601 date)",
      "veterinarian": "string or null"
    }
  ],
  "allergies": [
    "string (allergen name)"
  ],
  "surgeries": [
    {
      "procedure": "string (surgery name)",
      "date": "string (ISO 8601 date)",
      "complications": "string or null",
      "outcome": "string (successful, complications, etc.)"
    }
  ],
  "previousClaims": [
    {
      "date": "string (ISO 8601 date)",
      "condition": "string (reason for claim)",
      "amount": "number or null (claim amount if mentioned)",
      "status": "string (approved, denied, pending)"
    }
  ],
  "treatments": [
    {
      "diagnosis": "string",
      "date": "string (ISO 8601 date)",
      "treatment": "string (treatment provided)",
      "notes": "string or null"
    }
  ],
  "lastCheckup": "string or null (ISO 8601 date of most recent checkup)"
}

Important:
- Use ISO 8601 format for all dates (YYYY-MM-DD)
- If information is not present, use null or empty array as appropriate
- Extract all relevant medical history
- Be thorough but accurate - don't invent information
- Group related conditions appropriately

Return only valid JSON, no additional text.
''';
  }

  /// Save parsed veterinary history to Firestore
  Future<void> _saveToFirestore(
    String petId,
    VetRecordData data,
    String? pdfUrl,
  ) async {
    final docRef = _firestore
        .collection('pets')
        .doc(petId)
        .collection('parsed_history')
        .doc();

    await docRef.set({
      ...data.toJson(),
      'parsedAt': FieldValue.serverTimestamp(),
      'pdfUrl': pdfUrl,
      'id': docRef.id,
    });
  }

  Future<String> _saveToCaseFirestore({
    required String caseId,
    required VetRecordData parsedData,
    String? petId,
    String? pdfUrl,
    String? imageUrl,
    String? extractedTextUrl,
    required double confidence,
    String? sourceType,
    String? sourceFilename,
    String? documentHash,
  }) async {
    final docRef = _firestore
        .collection('underwriting_cases')
        .doc(caseId)
        .collection('vet_records')
        .doc();

    await docRef.set({
      ...parsedData.toJson(),
      'id': docRef.id,
      'caseId': caseId,
      'petId': petId,
      'pdfUrl': pdfUrl,
      'imageUrl': imageUrl,
      if (documentHash != null && documentHash.trim().isNotEmpty)
        'documentHash': documentHash,
      'sourceType': sourceType ?? (pdfUrl != null ? 'pdf' : null),
      'sourceFilename': sourceFilename,
      'extractedTextUrl': extractedTextUrl,
      'confidence': confidence,
      'parsedAt': FieldValue.serverTimestamp(),
      'status': 'parsed',
    });

    return docRef.id;
  }

  double _estimateConfidence({
    required String extractedText,
    required VetRecordData parsedData,
  }) {
    // Lightweight heuristic confidence score (0-100).
    var score = 40.0;
    if (extractedText.trim().length >= 500) score += 15;
    if (parsedData.diagnoses.isNotEmpty) score += 15;
    if (parsedData.treatments.isNotEmpty) score += 10;
    if (parsedData.medications.isNotEmpty) score += 10;
    if (parsedData.vaccinations.isNotEmpty) score += 5;
    if (parsedData.lastCheckup != null) score += 5;
    if (parsedData.allergies.isNotEmpty) score += 5;
    if (!validateParsedData(parsedData)) score -= 25;
    if (score < 0) score = 0;
    if (score > 100) score = 100;
    return score;
  }

  /// Retrieve parsed history from Firestore
  Future<List<VetRecordData>> getHistory(String petId) async {
    final snapshot = await _firestore
        .collection('pets')
        .doc(petId)
        .collection('parsed_history')
        .orderBy('parsedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => VetRecordData.fromJson(doc.data()))
        .toList();
  }

  /// Retrieve case-scoped parsed vet record history.
  Future<List<VetRecordData>> getCaseHistory(String caseId) async {
    final snapshot = await _firestore
        .collection('underwriting_cases')
        .doc(caseId)
        .collection('vet_records')
        .orderBy('parsedAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => VetRecordData.fromJson(doc.data()))
        .toList();
  }

  /// Get most recent parsed history for a pet
  Future<VetRecordData?> getMostRecentHistory(String petId) async {
    final histories = await getHistory(petId);
    return histories.isNotEmpty ? histories.first : null;
  }

  /// Validate parsed data
  bool validateParsedData(VetRecordData data) {
    if (data.vaccinations.isEmpty && data.treatments.isEmpty) {
      return false;
    }
    return true;
  }

  /// Extract medical conditions from vet records
  List<String> extractMedicalConditions(VetRecordData data) {
    final conditions = <String>{};

    for (final treatment in data.treatments) {
      if (treatment.diagnosis.isNotEmpty) {
        conditions.add(treatment.diagnosis);
      }
    }

    return conditions.toList();
  }
}

/// Model class for parsed veterinary record data
class VetRecordData {
  final List<Vaccination> vaccinations;
  final List<Treatment> treatments;
  final List<Medication> medications;
  final List<String> allergies;
  final List<Surgery> surgeries;
  final List<Diagnosis> diagnoses;
  final List<PreviousClaim> previousClaims;
  final DateTime? lastCheckup;

  VetRecordData({
    required this.vaccinations,
    required this.treatments,
    required this.medications,
    required this.allergies,
    required this.surgeries,
    this.diagnoses = const [],
    this.previousClaims = const [],
    this.lastCheckup,
  });

  Map<String, dynamic> toJson() {
    return {
      'vaccinations': vaccinations.map((v) => v.toJson()).toList(),
      'treatments': treatments.map((t) => t.toJson()).toList(),
      'medications': medications.map((m) => m.toJson()).toList(),
      'allergies': allergies,
      'surgeries': surgeries.map((s) => s.toJson()).toList(),
      'diagnoses': diagnoses.map((d) => d.toJson()).toList(),
      'previousClaims': previousClaims.map((c) => c.toJson()).toList(),
      'lastCheckup': lastCheckup?.toIso8601String(),
    };
  }

  factory VetRecordData.fromJson(Map<String, dynamic> json) {
    return VetRecordData(
      vaccinations: (json['vaccinations'] as List<dynamic>? ?? [])
          .map((v) => Vaccination.fromJson(v as Map<String, dynamic>))
          .toList(),
      treatments: (json['treatments'] as List<dynamic>? ?? [])
          .map((t) => Treatment.fromJson(t as Map<String, dynamic>))
          .toList(),
      medications: (json['medications'] as List<dynamic>? ?? [])
          .map((m) => Medication.fromJson(m as Map<String, dynamic>))
          .toList(),
      allergies: (json['allergies'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      surgeries: (json['surgeries'] as List<dynamic>? ?? [])
          .map((s) => Surgery.fromJson(s as Map<String, dynamic>))
          .toList(),
      diagnoses: (json['diagnoses'] as List<dynamic>? ?? [])
          .map((d) => Diagnosis.fromJson(d as Map<String, dynamic>))
          .toList(),
      previousClaims: (json['previousClaims'] as List<dynamic>? ?? [])
          .map((c) => PreviousClaim.fromJson(c as Map<String, dynamic>))
          .toList(),
      lastCheckup: json['lastCheckup'] != null
          ? DateTime.parse(json['lastCheckup'] as String)
          : null,
    );
  }

  /// Parse from AI-generated JSON response
  factory VetRecordData.fromAIJson(Map<String, dynamic> json) {
    return VetRecordData(
      diagnoses: (json['diagnoses'] as List<dynamic>? ?? [])
          .map((d) => Diagnosis.fromJson(d as Map<String, dynamic>))
          .toList(),
      medications: (json['medications'] as List<dynamic>? ?? [])
          .map((m) => Medication.fromJson(m as Map<String, dynamic>))
          .toList(),
      vaccinations: (json['vaccinations'] as List<dynamic>? ?? [])
          .map((v) => Vaccination.fromJson(v as Map<String, dynamic>))
          .toList(),
      allergies: (json['allergies'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      surgeries: (json['surgeries'] as List<dynamic>? ?? [])
          .map((s) => Surgery.fromJson(s as Map<String, dynamic>))
          .toList(),
      previousClaims: (json['previousClaims'] as List<dynamic>? ?? [])
          .map((c) => PreviousClaim.fromJson(c as Map<String, dynamic>))
          .toList(),
      treatments: (json['treatments'] as List<dynamic>? ?? [])
          .map((t) => Treatment.fromJson(t as Map<String, dynamic>))
          .toList(),
      lastCheckup: json['lastCheckup'] != null
          ? DateTime.parse(json['lastCheckup'] as String)
          : null,
    );
  }
}

class Vaccination {
  final String name;
  final DateTime date;
  final DateTime? expiryDate;
  final String? veterinarian;

  Vaccination({
    required this.name,
    required this.date,
    this.expiryDate,
    this.veterinarian,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'date': date.toIso8601String(),
    'expiryDate': expiryDate?.toIso8601String(),
    'veterinarian': veterinarian,
  };

  factory Vaccination.fromJson(Map<String, dynamic> json) => Vaccination(
    name: json['name'] as String,
    date: DateTime.parse(json['date'] as String),
    expiryDate: json['expiryDate'] != null
        ? DateTime.parse(json['expiryDate'] as String)
        : null,
    veterinarian: json['veterinarian'] as String?,
  );
}

class Treatment {
  final String diagnosis;
  final DateTime date;
  final String treatment;
  final String? notes;

  Treatment({
    required this.diagnosis,
    required this.date,
    required this.treatment,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'diagnosis': diagnosis,
    'date': date.toIso8601String(),
    'treatment': treatment,
    'notes': notes,
  };

  factory Treatment.fromJson(Map<String, dynamic> json) => Treatment(
    diagnosis: json['diagnosis'] as String,
    date: DateTime.parse(json['date'] as String),
    treatment: json['treatment'] as String,
    notes: json['notes'] as String?,
  );
}

class Medication {
  final String name;
  final String dosage;
  final DateTime startDate;
  final DateTime? endDate;
  final String? purpose;

  Medication({
    required this.name,
    required this.dosage,
    required this.startDate,
    this.endDate,
    this.purpose,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'dosage': dosage,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'purpose': purpose,
  };

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
    name: json['name'] as String,
    dosage: json['dosage'] as String,
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: json['endDate'] != null
        ? DateTime.parse(json['endDate'] as String)
        : null,
    purpose: json['purpose'] as String?,
  );
}

class Surgery {
  final String procedure;
  final DateTime date;
  final String? complications;
  final String? outcome;

  Surgery({
    required this.procedure,
    required this.date,
    this.complications,
    this.outcome,
  });

  Map<String, dynamic> toJson() => {
    'procedure': procedure,
    'date': date.toIso8601String(),
    'complications': complications,
    'outcome': outcome,
  };

  factory Surgery.fromJson(Map<String, dynamic> json) => Surgery(
    procedure: json['procedure'] as String,
    date: DateTime.parse(json['date'] as String),
    complications: json['complications'] as String?,
    outcome: json['outcome'] as String?,
  );
}

/// Model for diagnosed medical conditions
class Diagnosis {
  final String condition;
  final DateTime date;
  final String status; // active, resolved, chronic
  final String severity; // mild, moderate, severe
  final String? notes;

  Diagnosis({
    required this.condition,
    required this.date,
    required this.status,
    required this.severity,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'condition': condition,
    'date': date.toIso8601String(),
    'status': status,
    'severity': severity,
    'notes': notes,
  };

  factory Diagnosis.fromJson(Map<String, dynamic> json) => Diagnosis(
    condition: json['condition'] as String,
    date: DateTime.parse(json['date'] as String),
    status: json['status'] as String,
    severity: json['severity'] as String,
    notes: json['notes'] as String?,
  );
}

/// Model for previous insurance claims
class PreviousClaim {
  final DateTime date;
  final String condition;
  final double? amount;
  final String status; // approved, denied, pending

  PreviousClaim({
    required this.date,
    required this.condition,
    this.amount,
    required this.status,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'condition': condition,
    'amount': amount,
    'status': status,
  };

  factory PreviousClaim.fromJson(Map<String, dynamic> json) => PreviousClaim(
    date: DateTime.parse(json['date'] as String),
    condition: json['condition'] as String,
    amount: json['amount'] != null ? (json['amount'] as num).toDouble() : null,
    status: json['status'] as String,
  );
}

class VetHistoryParseException implements Exception {
  final String message;
  VetHistoryParseException(this.message);

  @override
  String toString() => 'VetHistoryParseException: $message';
}

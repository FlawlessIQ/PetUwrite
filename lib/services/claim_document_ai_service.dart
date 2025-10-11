import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../ai/ai_service.dart';

/// AI-powered document analysis for claim verification
/// Supports OCR (Google Cloud Vision / AWS Textract) + GPT-4 validation
class ClaimDocumentAIService {
  final FirebaseFirestore _firestore;
  final GPTService _gptService;
  final String? _googleVisionApiKey;
  final String? _awsAccessKey;
  final String? _awsSecretKey;
  
  // OCR provider preference (can be configured per deployment)
  final OCRProvider _ocrProvider;

  ClaimDocumentAIService({
    FirebaseFirestore? firestore,
    GPTService? gptService,
    String? googleVisionApiKey,
    String? awsAccessKey,
    String? awsSecretKey,
    OCRProvider ocrProvider = OCRProvider.googleVision,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _gptService = gptService ?? GPTService(
          apiKey: dotenv.env['OPENAI_API_KEY'] ?? '',
          model: 'gpt-4o', // Use GPT-4o for vision + analysis
        ),
        _googleVisionApiKey = googleVisionApiKey ?? dotenv.env['GOOGLE_VISION_API_KEY'],
        _awsAccessKey = awsAccessKey ?? dotenv.env['AWS_ACCESS_KEY_ID'],
        _awsSecretKey = awsSecretKey ?? dotenv.env['AWS_SECRET_ACCESS_KEY'],
        _ocrProvider = ocrProvider;

  /// Analyze claim document (PDF, JPG, PNG)
  /// Returns comprehensive analysis with extracted data + AI validation
  Future<ClaimDocumentAnalysis> analyzeDocument({
    required String filePath,
    required String claimId,
    required String documentId,
    double? userEnteredAmount,
  }) async {
    try {
      print('📄 Starting document analysis...');
      print('   File: $filePath');
      print('   Claim ID: $claimId');
      print('   Document ID: $documentId');

      // Step 1: Extract text via OCR
      print('🔍 Step 1: Running OCR...');
      final ocrResult = await _performOCR(filePath);
      
      if (!ocrResult.success) {
        throw Exception('OCR failed: ${ocrResult.error}');
      }

      final extractedText = ocrResult.text!;
      print('✅ OCR complete. Extracted ${extractedText.length} characters.');

      // Step 2: Parse key data points from extracted text
      print('📊 Step 2: Parsing key data points...');
      final parsedData = _parseVeterinaryInvoice(extractedText);
      print('✅ Parsed data: Provider=${parsedData['provider']}, Total=\$${parsedData['total']}');

      // Step 3: Cross-validate amount with user input
      print('🔄 Step 3: Cross-validating amounts...');
      final amountValidation = _validateAmount(
        extractedAmount: parsedData['total'],
        userAmount: userEnteredAmount,
      );
      print('✅ Validation: ${amountValidation['status']} (${amountValidation['message']})');

      // Step 4: Send to GPT-4o for contextual analysis
      print('🤖 Step 4: Running GPT-4o analysis...');
      final gptAnalysis = await _analyzeWithGPT4(
        extractedText: extractedText,
        parsedData: parsedData,
      );
      print('✅ GPT-4o analysis complete. Category: ${gptAnalysis['category']}');

      // Step 5: Calculate overall confidence score
      final confidenceScore = _calculateConfidenceScore(
        ocrConfidence: ocrResult.confidence ?? 0.9,
        parsingConfidence: parsedData['confidence'] ?? 0.7,
        gptConfidence: gptAnalysis['confidence'] ?? 0.8,
        amountMatch: amountValidation['match'] ?? false,
      );

      // Step 6: Build comprehensive analysis result
      final analysis = ClaimDocumentAnalysis(
        documentId: documentId,
        claimId: claimId,
        extractedText: extractedText,
        providerName: parsedData['provider'] ?? 'Unknown',
        serviceDate: parsedData['date'],
        diagnosisCodes: List<String>.from(parsedData['diagnosisCodes'] ?? []),
        procedureCodes: List<String>.from(parsedData['procedureCodes'] ?? []),
        totalCharge: parsedData['total'] ?? 0.0,
        currency: parsedData['currency'] ?? 'USD',
        isLegitimate: gptAnalysis['isLegitimate'] ?? true,
        treatment: gptAnalysis['treatment'] ?? 'Unknown',
        claimCategory: gptAnalysis['category'] ?? 'illness',
        confidenceScore: confidenceScore,
        summary: gptAnalysis['summary'] ?? 'Unable to analyze document',
        amountValidation: amountValidation,
        fraudFlags: List<String>.from(gptAnalysis['fraudFlags'] ?? []),
        analyzedAt: DateTime.now(),
        ocrProvider: _ocrProvider.name,
      );

      // Step 7: Store in Firestore
      print('💾 Step 7: Storing metadata in Firestore...');
      await _storeDocumentMetadata(analysis);
      print('✅ Analysis complete! Confidence: ${(confidenceScore * 100).toStringAsFixed(1)}%');

      return analysis;
    } catch (e, stackTrace) {
      print('❌ Document analysis failed: $e');
      print('Stack trace: $stackTrace');
      
      // Return error analysis
      return ClaimDocumentAnalysis.error(
        documentId: documentId,
        claimId: claimId,
        error: e.toString(),
      );
    }
  }

  /// Perform OCR using configured provider
  Future<OCRResult> _performOCR(String filePath) async {
    switch (_ocrProvider) {
      case OCRProvider.googleVision:
        return await _googleVisionOCR(filePath);
      case OCRProvider.awsTextract:
        return await _awsTextractOCR(filePath);
      case OCRProvider.mock:
        return _mockOCR(filePath);
    }
  }

  /// Google Cloud Vision OCR
  Future<OCRResult> _googleVisionOCR(String filePath) async {
    if (_googleVisionApiKey == null || _googleVisionApiKey.isEmpty) {
      return OCRResult(
        success: false,
        error: 'Google Vision API key not configured',
      );
    }

    try {
      // Read file as base64
      final bytes = await _readFileBytes(filePath);
      final base64Image = base64Encode(bytes);

      // Call Google Cloud Vision API
      final url = Uri.parse(
        'https://vision.googleapis.com/v1/images:annotate?key=$_googleVisionApiKey',
      );

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'requests': [
            {
              'image': {'content': base64Image},
              'features': [
                {'type': 'DOCUMENT_TEXT_DETECTION', 'maxResults': 1}
              ],
            }
          ],
        }),
      );

      if (response.statusCode != 200) {
        return OCRResult(
          success: false,
          error: 'Google Vision API error: ${response.statusCode}',
        );
      }

      final result = jsonDecode(response.body);
      final textAnnotations = result['responses'][0]['textAnnotations'];

      if (textAnnotations == null || textAnnotations.isEmpty) {
        return OCRResult(
          success: false,
          error: 'No text detected in image',
        );
      }

      // First annotation contains all text
      final fullText = textAnnotations[0]['description'];
      final confidence = textAnnotations[0]['confidence'] ?? 0.9;

      return OCRResult(
        success: true,
        text: fullText,
        confidence: confidence.toDouble(),
        provider: 'Google Cloud Vision',
      );
    } catch (e) {
      return OCRResult(
        success: false,
        error: 'Google Vision OCR failed: $e',
      );
    }
  }

  /// AWS Textract OCR
  Future<OCRResult> _awsTextractOCR(String filePath) async {
    if (_awsAccessKey == null || _awsSecretKey == null) {
      return OCRResult(
        success: false,
        error: 'AWS credentials not configured',
      );
    }

    try {
      // AWS Textract implementation
      // Note: This is a simplified version - production would use AWS SDK
      return OCRResult(
        success: false,
        error: 'AWS Textract integration pending - use Google Vision or Mock',
      );
    } catch (e) {
      return OCRResult(
        success: false,
        error: 'AWS Textract OCR failed: $e',
      );
    }
  }

  /// Mock OCR for testing/development
  OCRResult _mockOCR(String filePath) {
    // Simulate realistic veterinary invoice text
    final mockText = '''
HAPPY PAWS VETERINARY CLINIC
123 Main Street, San Francisco, CA 94102
Phone: (415) 555-0123
Tax ID: 12-3456789

INVOICE

Date of Service: October 8, 2025
Patient: Max (Dog, Golden Retriever)
Owner: John Smith
Account #: 12345

SERVICES PROVIDED:
- Examination (CPT: 99213)                    \$85.00
- X-Ray - Leg (CPT: 73590)                   \$250.00
- Fracture Repair - Tibia (CPT: 27758)       \$850.00
- Anesthesia (CPT: 00400)                    \$200.00
- Pain Medication (Gabapentin)                \$45.00
- E-Collar                                    \$25.00

DIAGNOSIS:
ICD-10: S82.201A - Unspecified fracture of tibia

Subtotal:                                   \$1,455.00
Tax (8.5%):                                  \$123.68
TOTAL AMOUNT DUE:                          \$1,578.68

Payment Status: PAID - Credit Card ending 4242
Transaction Date: October 8, 2025

Dr. Sarah Johnson, DVM
License #: CA-VET-98765
''';

    return OCRResult(
      success: true,
      text: mockText,
      confidence: 0.95,
      provider: 'Mock OCR (Development)',
    );
  }

  /// Parse veterinary invoice from extracted text
  Map<String, dynamic> _parseVeterinaryInvoice(String text) {
    final result = <String, dynamic>{
      'provider': null,
      'date': null,
      'diagnosisCodes': <String>[],
      'procedureCodes': <String>[],
      'total': null,
      'currency': 'USD',
      'confidence': 0.7,
    };

    try {
      // Parse provider name (usually at top of invoice)
      final providerMatch = RegExp(
        r'^([A-Z][A-Za-z\s&]+(?:VETERINARY|VET|ANIMAL|PET|CLINIC|HOSPITAL)[A-Za-z\s]*)',
        multiLine: true,
        caseSensitive: false,
      ).firstMatch(text);
      if (providerMatch != null) {
        result['provider'] = providerMatch.group(1)?.trim();
      }

      // Parse date (various formats)
      final datePatterns = [
        RegExp(r'Date(?:\s+of\s+Service)?:\s*([A-Za-z]+\s+\d{1,2},\s*\d{4})'),
        RegExp(r'Date(?:\s+of\s+Service)?:\s*(\d{1,2}[-/]\d{1,2}[-/]\d{2,4})'),
        RegExp(r'Service\s+Date:\s*([A-Za-z]+\s+\d{1,2},\s*\d{4})'),
      ];

      for (final pattern in datePatterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          result['date'] = _parseDate(match.group(1)!);
          break;
        }
      }

      // Parse diagnosis codes (ICD-10)
      final diagnosisPattern = RegExp(
        r'(?:ICD-10|Diagnosis Code|Diagnosis):\s*([A-Z]\d{2}(?:\.\d{1,3}[A-Z]?)?)',
        multiLine: true,
      );
      for (final match in diagnosisPattern.allMatches(text)) {
        result['diagnosisCodes'].add(match.group(1));
      }

      // Parse procedure codes (CPT)
      final procedurePattern = RegExp(
        r'(?:CPT|Code):\s*(\d{4,5}[A-Z]?)',
        multiLine: true,
      );
      for (final match in procedurePattern.allMatches(text)) {
        result['procedureCodes'].add(match.group(1));
      }

      // Parse total amount (prioritize TOTAL, then fall back to other amounts)
      final totalPatterns = [
        RegExp(r'TOTAL\s+AMOUNT\s+DUE:\s*\$?([\d,]+\.?\d{0,2})'),
        RegExp(r'TOTAL:\s*\$?([\d,]+\.?\d{0,2})'),
        RegExp(r'Amount\s+Due:\s*\$?([\d,]+\.?\d{0,2})'),
        RegExp(r'Balance\s+Due:\s*\$?([\d,]+\.?\d{0,2})'),
      ];

      for (final pattern in totalPatterns) {
        final match = pattern.firstMatch(text);
        if (match != null) {
          final amountStr = match.group(1)!.replaceAll(',', '');
          result['total'] = double.tryParse(amountStr);
          break;
        }
      }

      // Calculate confidence based on fields found
      int fieldsFound = 0;
      if (result['provider'] != null) fieldsFound++;
      if (result['date'] != null) fieldsFound++;
      if (result['diagnosisCodes'].isNotEmpty) fieldsFound++;
      if (result['procedureCodes'].isNotEmpty) fieldsFound++;
      if (result['total'] != null) fieldsFound++;

      result['confidence'] = fieldsFound / 5.0;

      return result;
    } catch (e) {
      print('Warning: Error parsing invoice: $e');
      return result;
    }
  }

  /// Parse date from string
  DateTime? _parseDate(String dateStr) {
    try {
      // Try common formats
      final formats = [
        RegExp(r'([A-Za-z]+)\s+(\d{1,2}),\s*(\d{4})'), // October 8, 2025
        RegExp(r'(\d{1,2})[-/](\d{1,2})[-/](\d{2,4})'), // 10/8/2025 or 10-8-2025
      ];

      for (final format in formats) {
        final match = format.firstMatch(dateStr);
        if (match != null) {
          if (format == formats[0]) {
            // Month name format
            final monthName = match.group(1)!;
            final day = int.parse(match.group(2)!);
            final year = int.parse(match.group(3)!);
            final month = _monthNameToNumber(monthName);
            return DateTime(year, month, day);
          } else {
            // Numeric format
            final month = int.parse(match.group(1)!);
            final day = int.parse(match.group(2)!);
            var year = int.parse(match.group(3)!);
            if (year < 100) year += 2000;
            return DateTime(year, month, day);
          }
        }
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Convert month name to number
  int _monthNameToNumber(String monthName) {
    const months = {
      'january': 1, 'jan': 1,
      'february': 2, 'feb': 2,
      'march': 3, 'mar': 3,
      'april': 4, 'apr': 4,
      'may': 5,
      'june': 6, 'jun': 6,
      'july': 7, 'jul': 7,
      'august': 8, 'aug': 8,
      'september': 9, 'sep': 9, 'sept': 9,
      'october': 10, 'oct': 10,
      'november': 11, 'nov': 11,
      'december': 12, 'dec': 12,
    };
    return months[monthName.toLowerCase()] ?? 1;
  }

  /// Validate extracted amount against user-entered amount
  Map<String, dynamic> _validateAmount({
    required double? extractedAmount,
    required double? userAmount,
  }) {
    if (extractedAmount == null) {
      return {
        'status': 'no_extracted_amount',
        'match': false,
        'message': 'Could not extract total from document',
        'discrepancy': null,
      };
    }

    if (userAmount == null) {
      return {
        'status': 'no_user_amount',
        'match': null,
        'message': 'User did not provide amount for comparison',
        'discrepancy': null,
      };
    }

    final difference = (extractedAmount - userAmount).abs();
    final percentDiff = (difference / extractedAmount) * 100;

    // Allow 5% variance or $10 (for rounding, taxes, etc.)
    final isMatch = difference <= 10.0 || percentDiff <= 5.0;

    return {
      'status': isMatch ? 'match' : 'mismatch',
      'match': isMatch,
      'message': isMatch
          ? 'Amount matches (${_formatCurrency(extractedAmount)})'
          : 'Amount mismatch: Document shows ${_formatCurrency(extractedAmount)}, '
              'user entered ${_formatCurrency(userAmount)} (${percentDiff.toStringAsFixed(1)}% difference)',
      'discrepancy': difference,
      'extractedAmount': extractedAmount,
      'userAmount': userAmount,
      'percentDifference': percentDiff,
    };
  }

  /// Analyze document with GPT-4o for legitimacy and classification
  Future<Map<String, dynamic>> _analyzeWithGPT4({
    required String extractedText,
    required Map<String, dynamic> parsedData,
  }) async {
    final prompt = '''
You are a veterinary insurance claim validator. Analyze this document and provide a JSON response.

EXTRACTED TEXT FROM DOCUMENT:
$extractedText

PARSED DATA:
Provider: ${parsedData['provider'] ?? 'Unknown'}
Date: ${parsedData['date']?.toString() ?? 'Unknown'}
Total: \$${parsedData['total'] ?? 'Unknown'}
Diagnosis Codes: ${parsedData['diagnosisCodes']?.join(', ') ?? 'None'}
Procedure Codes: ${parsedData['procedureCodes']?.join(', ') ?? 'None'}

QUESTIONS:
1. Is this a legitimate veterinary invoice or receipt?
2. What treatment/procedure was performed?
3. What claim category does this fall under? (accident, illness, wellness)
4. Confidence score (0.0-1.0) in the legitimacy
5. Are there any fraud indicators?

Return ONLY valid JSON in this format:
{
  "isLegitimate": true/false,
  "treatment": "brief description",
  "category": "accident" | "illness" | "wellness",
  "confidence": 0.0-1.0,
  "summary": "1-2 sentence summary",
  "fraudFlags": ["flag1", "flag2"] or []
}

JSON:''';

    try {
      final response = await _gptService.generateText(prompt);
      final jsonStr = response
          .trim()
          .replaceAll('```json', '')
          .replaceAll('```', '')
          .trim();

      final result = jsonDecode(jsonStr) as Map<String, dynamic>;
      
      return {
        'isLegitimate': result['isLegitimate'] ?? true,
        'treatment': result['treatment'] ?? 'Unknown treatment',
        'category': result['category'] ?? 'illness',
        'confidence': (result['confidence'] ?? 0.8).toDouble(),
        'summary': result['summary'] ?? 'Unable to analyze document',
        'fraudFlags': result['fraudFlags'] ?? [],
      };
    } catch (e) {
      print('Warning: GPT-4 analysis failed: $e');
      // Return safe defaults
      return {
        'isLegitimate': true,
        'treatment': 'Unable to analyze - manual review required',
        'category': 'illness',
        'confidence': 0.5,
        'summary': 'AI analysis unavailable',
        'fraudFlags': [],
      };
    }
  }

  /// Calculate overall confidence score
  double _calculateConfidenceScore({
    required double ocrConfidence,
    required double parsingConfidence,
    required double gptConfidence,
    required bool amountMatch,
  }) {
    // Weighted average
    final weights = {
      'ocr': 0.25,
      'parsing': 0.25,
      'gpt': 0.35,
      'amountMatch': 0.15,
    };

    final score = (ocrConfidence * weights['ocr']!) +
        (parsingConfidence * weights['parsing']!) +
        (gptConfidence * weights['gpt']!) +
        ((amountMatch ? 1.0 : 0.0) * weights['amountMatch']!);

    return score.clamp(0.0, 1.0);
  }

  /// Store document metadata in Firestore
  Future<void> _storeDocumentMetadata(ClaimDocumentAnalysis analysis) async {
    try {
      await _firestore
          .collection('claims')
          .doc(analysis.claimId)
          .collection('documents')
          .doc(analysis.documentId)
          .set(analysis.toMap());
    } catch (e) {
      print('Warning: Failed to store document metadata: $e');
      // Don't throw - this is not critical
    }
  }

  /// Read file bytes (cross-platform)
  Future<List<int>> _readFileBytes(String filePath) async {
    if (kIsWeb) {
      // Web implementation would use XHR/Fetch
      throw UnimplementedError('Web file reading not implemented');
    } else {
      final file = File(filePath);
      return await file.readAsBytes();
    }
  }

  /// Format currency
  String _formatCurrency(double amount) {
    return '\$${amount.toStringAsFixed(2)}';
  }

  /// Batch analyze multiple documents
  Future<List<ClaimDocumentAnalysis>> analyzeDocuments({
    required List<String> filePaths,
    required String claimId,
    double? userEnteredAmount,
  }) async {
    final results = <ClaimDocumentAnalysis>[];
    
    for (int i = 0; i < filePaths.length; i++) {
      final documentId = '${claimId}_doc_${i + 1}_${DateTime.now().millisecondsSinceEpoch}';
      
      try {
        final analysis = await analyzeDocument(
          filePath: filePaths[i],
          claimId: claimId,
          documentId: documentId,
          userEnteredAmount: userEnteredAmount,
        );
        results.add(analysis);
      } catch (e) {
        print('Error analyzing document ${i + 1}: $e');
        results.add(ClaimDocumentAnalysis.error(
          documentId: documentId,
          claimId: claimId,
          error: e.toString(),
        ));
      }
    }
    
    return results;
  }

  /// Get stored document analysis from Firestore
  Future<ClaimDocumentAnalysis?> getDocumentAnalysis({
    required String claimId,
    required String documentId,
  }) async {
    try {
      final doc = await _firestore
          .collection('claims')
          .doc(claimId)
          .collection('documents')
          .doc(documentId)
          .get();

      if (!doc.exists) return null;

      return ClaimDocumentAnalysis.fromMap(doc.data()!, documentId);
    } catch (e) {
      print('Error retrieving document analysis: $e');
      return null;
    }
  }

  /// Get all document analyses for a claim
  Future<List<ClaimDocumentAnalysis>> getClaimDocuments(String claimId) async {
    try {
      final snapshot = await _firestore
          .collection('claims')
          .doc(claimId)
          .collection('documents')
          .orderBy('analyzedAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => ClaimDocumentAnalysis.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      print('Error retrieving claim documents: $e');
      return [];
    }
  }
}

/// OCR Provider options
enum OCRProvider {
  googleVision,
  awsTextract,
  mock, // For development/testing
}

/// OCR Result
class OCRResult {
  final bool success;
  final String? text;
  final double? confidence;
  final String? provider;
  final String? error;

  OCRResult({
    required this.success,
    this.text,
    this.confidence,
    this.provider,
    this.error,
  });
}

/// Comprehensive claim document analysis result
class ClaimDocumentAnalysis {
  final String documentId;
  final String claimId;
  final String extractedText;
  final String providerName;
  final DateTime? serviceDate;
  final List<String> diagnosisCodes;
  final List<String> procedureCodes;
  final double totalCharge;
  final String currency;
  final bool isLegitimate;
  final String treatment;
  final String claimCategory;
  final double confidenceScore;
  final String summary;
  final Map<String, dynamic> amountValidation;
  final List<String> fraudFlags;
  final DateTime analyzedAt;
  final String ocrProvider;
  final String? error;

  ClaimDocumentAnalysis({
    required this.documentId,
    required this.claimId,
    required this.extractedText,
    required this.providerName,
    this.serviceDate,
    required this.diagnosisCodes,
    required this.procedureCodes,
    required this.totalCharge,
    required this.currency,
    required this.isLegitimate,
    required this.treatment,
    required this.claimCategory,
    required this.confidenceScore,
    required this.summary,
    required this.amountValidation,
    required this.fraudFlags,
    required this.analyzedAt,
    required this.ocrProvider,
    this.error,
  });

  /// Create error analysis
  factory ClaimDocumentAnalysis.error({
    required String documentId,
    required String claimId,
    required String error,
  }) {
    return ClaimDocumentAnalysis(
      documentId: documentId,
      claimId: claimId,
      extractedText: '',
      providerName: 'Unknown',
      serviceDate: null,
      diagnosisCodes: [],
      procedureCodes: [],
      totalCharge: 0.0,
      currency: 'USD',
      isLegitimate: false,
      treatment: 'Analysis failed',
      claimCategory: 'unknown',
      confidenceScore: 0.0,
      summary: 'Error: $error',
      amountValidation: {},
      fraudFlags: ['analysis_failed'],
      analyzedAt: DateTime.now(),
      ocrProvider: 'none',
      error: error,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'documentId': documentId,
      'claimId': claimId,
      'extractedText': extractedText,
      'providerName': providerName,
      'serviceDate': serviceDate != null ? Timestamp.fromDate(serviceDate!) : null,
      'diagnosisCodes': diagnosisCodes,
      'procedureCodes': procedureCodes,
      'totalCharge': totalCharge,
      'currency': currency,
      'isLegitimate': isLegitimate,
      'treatment': treatment,
      'claimCategory': claimCategory,
      'confidenceScore': confidenceScore,
      'summary': summary,
      'amountValidation': amountValidation,
      'fraudFlags': fraudFlags,
      'analyzedAt': Timestamp.fromDate(analyzedAt),
      'ocrProvider': ocrProvider,
      'error': error,
    };
  }

  /// Create from Firestore map
  factory ClaimDocumentAnalysis.fromMap(Map<String, dynamic> map, String documentId) {
    return ClaimDocumentAnalysis(
      documentId: documentId,
      claimId: map['claimId'] as String,
      extractedText: map['extractedText'] as String,
      providerName: map['providerName'] as String,
      serviceDate: map['serviceDate'] != null
          ? (map['serviceDate'] as Timestamp).toDate()
          : null,
      diagnosisCodes: List<String>.from(map['diagnosisCodes'] ?? []),
      procedureCodes: List<String>.from(map['procedureCodes'] ?? []),
      totalCharge: (map['totalCharge'] as num).toDouble(),
      currency: map['currency'] as String,
      isLegitimate: map['isLegitimate'] as bool,
      treatment: map['treatment'] as String,
      claimCategory: map['claimCategory'] as String,
      confidenceScore: (map['confidenceScore'] as num).toDouble(),
      summary: map['summary'] as String,
      amountValidation: Map<String, dynamic>.from(map['amountValidation'] ?? {}),
      fraudFlags: List<String>.from(map['fraudFlags'] ?? []),
      analyzedAt: (map['analyzedAt'] as Timestamp).toDate(),
      ocrProvider: map['ocrProvider'] as String,
      error: map['error'] as String?,
    );
  }

  /// Check if analysis has errors
  bool get hasError => error != null;

  /// Check if amount validation passed
  bool get amountValidationPassed => amountValidation['match'] == true;

  /// Check if document has fraud flags
  bool get hasFraudFlags => fraudFlags.isNotEmpty;

  /// Get risk level based on confidence and flags
  String get riskLevel {
    if (hasFraudFlags || !isLegitimate) return 'high';
    if (confidenceScore < 0.5 || !amountValidationPassed) return 'medium';
    return 'low';
  }
}

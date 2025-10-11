import 'dart:io';
import 'dart:convert';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../ai/ai_service.dart';

/// Service for parsing veterinary history documents with AI
/// Integrates Firebase Storage, PDF extraction, and AI parsing
class VetHistoryParser {
  final AIService _aiService;
  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;
  final String _cloudFunctionUrl;
  
  VetHistoryParser({
    required AIService aiService,
    FirebaseStorage? storage,
    FirebaseFirestore? firestore,
    String? cloudFunctionUrl,
  })  : _aiService = aiService,
        _storage = storage ?? FirebaseStorage.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _cloudFunctionUrl = cloudFunctionUrl ?? 
            'https://us-central1-pet-underwriter-ai.cloudfunctions.net/extractPdfText';
  
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
      
      // 2. Extract text from PDF using Cloud Function
      final extractedText = await _extractTextFromPdf(downloadUrl);
      
      // 3. Parse text with AI
      final parsedData = await _parseWithAI(extractedText);
      
      // 4. Save to Firestore
      await _saveToFirestore(petId, parsedData, downloadUrl);
      
      return parsedData;
    } catch (e) {
      throw VetHistoryParseException('Failed to parse uploaded PDF: $e');
    }
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
    final fileName = filename ?? 'vet_records_${DateTime.now().millisecondsSinceEpoch}.pdf';
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
  
  /// Extract text from PDF using Cloud Function
  Future<String> _extractTextFromPdf(String downloadUrl) async {
    final response = await http.post(
      Uri.parse(_cloudFunctionUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'pdfUrl': downloadUrl}),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['text'] as String;
    } else {
      throw VetHistoryParseException(
        'PDF text extraction failed: ${response.statusCode} - ${response.body}',
      );
    }
  }
  
  /// Parse veterinary records using AI (GPT-4 or Claude)
  Future<VetRecordData> _parseWithAI(String text) async {
    final prompt = _buildAIPrompt(text);
    
    try {
      final aiResponse = await _aiService.generateText(
        prompt,
        options: {'response_format': {'type': 'json_object'}},
      );
      
      final parsedJson = jsonDecode(aiResponse);
      return VetRecordData.fromAIJson(parsedJson);
    } catch (e) {
      throw VetHistoryParseException('AI parsing failed: $e');
    }
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

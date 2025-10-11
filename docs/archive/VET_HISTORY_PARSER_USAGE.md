# VetHistoryParser - Complete Usage Guide

## Overview

The `VetHistoryParser` service provides AI-powered parsing of veterinary records with Firebase integration. It accepts PDF uploads, extracts text using serverless functions, and uses GPT-4 or Claude to structure the data.

## Features

✅ **PDF Upload to Firebase Storage**
- Automatic upload to `vet_records/{petId}/` path
- Supports any PDF format
- Metadata tracking (petId, upload timestamp)

✅ **Serverless PDF Text Extraction**
- Cloud Function using PDF.js
- Handles multi-page documents
- Automatic or on-demand processing

✅ **AI-Powered Structured Parsing**
- Extracts: diagnoses, medications, allergies, surgeries, vaccinations, previous claims
- Uses GPT-4 or Claude with structured JSON output
- Handles various document formats and handwriting (with OCR)

✅ **Firestore Storage**
- Saves to `pets/{petId}/parsed_history` collection
- Includes PDF URL reference
- Queryable and retrievable

## Setup

### 1. Install Dependencies

```yaml
# pubspec.yaml
dependencies:
  firebase_storage: ^12.0.0
  cloud_firestore: ^5.0.0
  http: ^1.1.0
```

### 2. Deploy Cloud Functions

```bash
cd functions
npm install
firebase deploy --only functions:extractPdfText,functions:processPdfOnUpload
```

### 3. Configure Firebase Storage Rules

```
// storage.rules
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /vet_records/{petId}/{filename} {
      allow read, write: if request.auth != null && 
        request.auth.uid == getPetOwner(petId);
      allow read: if request.auth != null && 
        hasAdminRole(request.auth.uid);
    }
  }
}

function getPetOwner(petId) {
  return firestore.get(/databases/(default)/documents/pets/$(petId)).data.ownerId;
}
```

### 4. Initialize the Parser

```dart
import 'package:pet_underwriter_ai/services/vet_history_parser.dart';
import 'package:pet_underwriter_ai/ai/ai_service.dart';

// Create AI service
final aiService = GPTService(
  apiKey: 'your-openai-api-key',
  model: 'gpt-4',
);

// Create parser
final parser = VetHistoryParser(
  aiService: aiService,
  cloudFunctionUrl: 'https://us-central1-pet-underwriter-ai.cloudfunctions.net/extractPdfText',
);
```

## Usage

### Method 1: Upload and Parse PDF

```dart
final pdfFile = File('/path/to/vet_records.pdf');
const petId = 'pet_12345';

try {
  final parsedData = await parser.parseUploadedPdf(
    pdfFile: pdfFile,
    petId: petId,
    filename: 'buddy_records_2024.pdf', // Optional
  );
  
  // Access parsed data
  print('Diagnoses: ${parsedData.diagnoses.length}');
  print('Medications: ${parsedData.medications.length}');
  print('Previous Claims: ${parsedData.previousClaims.length}');
  
} on VetHistoryParseException catch (e) {
  print('Parse error: ${e.message}');
}
```

### Method 2: Parse Text Directly

```dart
const vetRecordText = '''
Patient: Buddy
Diagnosis: Arthritis (chronic)
Medications: Carprofen 75mg twice daily
...
''';

final parsedData = await parser.parseText(vetRecordText);
```

### Method 3: Parse and Save

```dart
// Parse text and automatically save to Firestore
final parsedData = await parser.parseAndSave(
  text: vetRecordText,
  petId: 'pet_12345',
);
```

### Retrieve Parsed History

```dart
// Get all parsed histories for a pet
final histories = await parser.getHistory('pet_12345');

// Get most recent
final mostRecent = await parser.getMostRecentHistory('pet_12345');
```

## Data Structure

### VetRecordData

```dart
class VetRecordData {
  final List<Diagnosis> diagnoses;
  final List<Medication> medications;
  final List<Vaccination> vaccinations;
  final List<String> allergies;
  final List<Surgery> surgeries;
  final List<PreviousClaim> previousClaims;
  final List<Treatment> treatments;
  final DateTime? lastCheckup;
}
```

### Diagnosis

```dart
class Diagnosis {
  final String condition;        // e.g., "Osteoarthritis"
  final DateTime date;           // First diagnosed
  final String status;           // "active", "resolved", "chronic"
  final String severity;         // "mild", "moderate", "severe"
  final String? notes;
}
```

### Medication

```dart
class Medication {
  final String name;             // e.g., "Carprofen"
  final String dosage;           // e.g., "75mg twice daily"
  final DateTime startDate;
  final DateTime? endDate;       // null if ongoing
  final String? purpose;         // e.g., "Pain management"
}
```

### Vaccination

```dart
class Vaccination {
  final String name;             // e.g., "Rabies", "DHPP"
  final DateTime date;
  final DateTime? expiryDate;
  final String? veterinarian;
}
```

### PreviousClaim

```dart
class PreviousClaim {
  final DateTime date;
  final String condition;        // Reason for claim
  final double? amount;          // Claim amount
  final String status;           // "approved", "denied", "pending"
}
```

### Surgery

```dart
class Surgery {
  final String procedure;
  final DateTime date;
  final String? complications;
  final String? outcome;
}
```

## Cloud Functions

### extractPdfText (HTTP)

**Endpoint**: `POST /extractPdfText`

**Request**:
```json
{
  "pdfUrl": "https://storage.googleapis.com/..."
}
```

**Response**:
```json
{
  "text": "Extracted text from PDF...",
  "metadata": {
    "pages": 3,
    "info": {...}
  }
}
```

### processPdfOnUpload (Storage Trigger)

Automatically triggers when PDF is uploaded to `vet_records/` folder.

1. Extracts text from PDF
2. Saves to `pets/{petId}/pdf_extractions` collection
3. Can be retrieved for processing

### getPdfProcessingStatus (Callable)

```dart
final callable = FirebaseFunctions.instance.httpsCallable('getPdfProcessingStatus');
final result = await callable.call({
  'petId': 'pet_12345',
});

final extractions = result.data['extractions'];
```

## AI Prompt Structure

The parser sends this structured prompt to GPT-4/Claude:

```
You are a veterinary records parser. Extract structured information...

VETERINARY RECORD:
[Document text here]

Extract and return a JSON object with:
{
  "diagnoses": [...],
  "medications": [...],
  "vaccinations": [...],
  "allergies": [...],
  "surgeries": [...],
  "previousClaims": [...],
  "treatments": [...],
  "lastCheckup": "..."
}
```

The AI returns structured JSON that maps directly to the data models.

## Firestore Structure

### Parsed History Storage

```
pets/{petId}/parsed_history/{docId}
├── diagnoses: [...]
├── medications: [...]
├── vaccinations: [...]
├── allergies: [...]
├── surgeries: [...]
├── previousClaims: [...]
├── treatments: [...]
├── lastCheckup: "2024-10-07"
├── parsedAt: Timestamp
├── pdfUrl: "https://storage..."
└── id: "docId"
```

### PDF Extraction Cache (from Storage Trigger)

```
pets/{petId}/pdf_extractions/{docId}
├── filePath: "vet_records/pet_123/file.pdf"
├── extractedText: "..."
├── pages: 3
├── extractedAt: Timestamp
├── status: "extracted"
└── metadata: {...}
```

## Error Handling

```dart
try {
  final parsedData = await parser.parseUploadedPdf(
    pdfFile: pdfFile,
    petId: petId,
  );
} on VetHistoryParseException catch (e) {
  // Parsing-specific error
  print('Parse error: ${e.message}');
} on FirebaseException catch (e) {
  // Firebase error (Storage, Firestore)
  print('Firebase error: ${e.code} - ${e.message}');
} on HttpException catch (e) {
  // Cloud Function error
  print('HTTP error: $e');
} catch (e) {
  // Other errors
  print('Unexpected error: $e');
}
```

## Complete Flow Example

```dart
import 'dart:io';
import 'package:pet_underwriter_ai/services/vet_history_parser.dart';
import 'package:pet_underwriter_ai/ai/ai_service.dart';

Future<void> processVetRecords() async {
  // 1. Initialize
  final aiService = GPTService(
    apiKey: String.fromEnvironment('OPENAI_API_KEY'),
    model: 'gpt-4',
  );
  
  final parser = VetHistoryParser(aiService: aiService);
  
  // 2. User uploads PDF
  final pdfFile = await pickPdfFile(); // Your file picker
  const petId = 'pet_12345';
  
  // 3. Show loading indicator
  showLoadingDialog('Processing veterinary records...');
  
  try {
    // 4. Upload and parse
    final parsedData = await parser.parseUploadedPdf(
      pdfFile: pdfFile,
      petId: petId,
    );
    
    // 5. Validate data
    if (parsedData.diagnoses.isEmpty && 
        parsedData.medications.isEmpty &&
        parsedData.vaccinations.isEmpty) {
      throw VetHistoryParseException('No valid data found in document');
    }
    
    // 6. Display results to user
    showParsedDataReview(parsedData);
    
    // 7. Allow user to edit/confirm
    final confirmed = await getUserConfirmation();
    
    if (confirmed) {
      // 8. Use data for risk scoring
      await calculateRiskWithVetHistory(petId, parsedData);
      
      // 9. Continue to quote generation
      navigateToQuotePage();
    }
    
  } on VetHistoryParseException catch (e) {
    showErrorDialog('Could not parse document: ${e.message}');
  } finally {
    hideLoadingDialog();
  }
}
```

## Integration with RiskScoringEngine

```dart
// Parse vet history
final parser = VetHistoryParser(aiService: aiService);
final vetHistory = await parser.parseUploadedPdf(
  pdfFile: pdfFile,
  petId: pet.id,
);

// Use in risk scoring
final riskEngine = RiskScoringEngine(aiService: aiService);
final riskScore = await riskEngine.calculateRiskScore(
  pet: pet,
  owner: owner,
  vetHistory: vetHistory,  // ← Include parsed history
  quoteId: quote.id,
);
```

## Performance

- **PDF Upload**: 500ms - 2s (depends on file size)
- **Text Extraction**: 1-3s (Cloud Function processing)
- **AI Parsing**: 3-6s (GPT-4 API call)
- **Firestore Save**: <100ms
- **Total**: 5-11 seconds for complete flow

## Costs

### Firebase Storage
- Storage: $0.026/GB/month
- Download: $0.12/GB
- Typical vet record PDF: 1-5 MB

### Cloud Functions
- Invocations: First 2M free, then $0.40/million
- Compute time: First 400K GB-seconds free
- Text extraction: ~2-3 seconds per PDF

### OpenAI GPT-4
- ~2,000 tokens per veterinary record
- Cost: ~$0.06 per parse

### Total Cost Estimate
- **Per document**: ~$0.06-0.08
- **1,000 documents/month**: ~$60-80

## Security Considerations

1. **Authentication**: Only pet owners can upload records
2. **Storage Rules**: Files scoped to petId
3. **API Keys**: Stored securely on backend
4. **Data Privacy**: Medical records are sensitive - use encryption
5. **Rate Limiting**: Prevent abuse of parsing service

## Firestore Security Rules

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /pets/{petId}/parsed_history/{docId} {
      allow read: if request.auth != null && 
        (request.auth.uid == getPetOwner(petId) || isAdmin());
      allow write: if request.auth != null && 
        request.auth.uid == getPetOwner(petId);
    }
    
    match /pets/{petId}/pdf_extractions/{docId} {
      allow read: if request.auth != null && 
        request.auth.uid == getPetOwner(petId);
      allow write: if false; // Only Cloud Functions can write
    }
  }
  
  function getPetOwner(petId) {
    return get(/databases/$(database)/documents/pets/$(petId)).data.ownerId;
  }
  
  function isAdmin() {
    return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
  }
}
```

## Testing

```dart
// Use mock AI service for testing
class MockAIService implements AIService {
  @override
  Future<String> generateText(String prompt, {Map<String, dynamic>? options}) async {
    return '''
    {
      "diagnoses": [
        {
          "condition": "Test Condition",
          "date": "2024-01-01",
          "status": "active",
          "severity": "mild"
        }
      ],
      "medications": [],
      "vaccinations": [],
      "allergies": [],
      "surgeries": [],
      "previousClaims": [],
      "treatments": [],
      "lastCheckup": null
    }
    ''';
  }
  
  @override
  Future<Map<String, dynamic>> parseStructuredData(String text) async {
    return {};
  }
}

// Test parsing
final mockParser = VetHistoryParser(aiService: MockAIService());
final result = await mockParser.parseText('test text');
expect(result.diagnoses.length, 1);
```

## Troubleshooting

### Issue: PDF text extraction fails

**Solution**: 
- Check Cloud Function logs
- Verify PDF is not password-protected
- Ensure PDF contains text (not just images)
- For scanned documents, add OCR preprocessing

### Issue: AI parsing returns empty data

**Solution**:
- Check AI API key is valid
- Verify document contains medical information
- Review AI prompt for your document type
- Check AI service logs for errors

### Issue: Firestore permission denied

**Solution**:
- Verify user is authenticated
- Check security rules
- Ensure petId ownership is correct

## Next Steps

1. Deploy Cloud Functions
2. Configure Storage and Firestore rules
3. Test with sample PDF
4. Integrate into quote flow
5. Monitor costs and usage

## Support Files

- Implementation: `lib/services/vet_history_parser.dart`
- Cloud Functions: `functions/pdfExtraction.js`
- Examples: `examples/vet_history_parser_example.dart`
- This Guide: `VET_HISTORY_PARSER_USAGE.md`

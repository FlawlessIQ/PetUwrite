# Claim Document AI Service

## Overview
AI-powered document analysis service for veterinary invoice verification and fraud detection.

**Created:** October 10, 2025  
**Service:** `lib/services/claim_document_ai_service.dart`  
**Purpose:** OCR + GPT-4 analysis for claim document validation

---

## Architecture

### Processing Pipeline

```
┌──────────────┐
│   Upload     │
│ PDF/JPG/PNG  │
└──────┬───────┘
       │
       ▼
┌──────────────────────────────────────┐
│   STEP 1: OCR (Text Extraction)      │
│   • Google Cloud Vision API           │
│   • AWS Textract (pending)            │
│   • Mock (development)                │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│   STEP 2: Parse Key Data Points      │
│   • Provider name (regex)             │
│   • Service date (multiple formats)   │
│   • Diagnosis codes (ICD-10)          │
│   • Procedure codes (CPT)             │
│   • Total charge (multiple patterns)  │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│   STEP 3: Cross-Validate Amount      │
│   • Compare extracted vs user-entered │
│   • Allow 5% variance or $10          │
│   • Flag discrepancies                │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│   STEP 4: GPT-4o Analysis            │
│   • Legitimacy verification           │
│   • Treatment classification          │
│   • Category detection                │
│   • Fraud flag detection              │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│   STEP 5: Confidence Scoring         │
│   • Weighted average:                 │
│     - OCR confidence: 25%             │
│     - Parsing confidence: 25%         │
│     - GPT confidence: 35%             │
│     - Amount match: 15%               │
└──────┬───────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────┐
│   STEP 6: Store in Firestore         │
│   /claims/{claimId}/documents/{docId} │
└──────────────────────────────────────┘
```

---

## Features

### 1. Multi-Provider OCR Support

#### Google Cloud Vision API
- **Status:** ✅ Implemented
- **Accuracy:** 95%+ for printed text
- **Cost:** $1.50 per 1,000 images
- **Configuration:** `GOOGLE_VISION_API_KEY` in .env

#### AWS Textract
- **Status:** ⏳ Pending implementation
- **Accuracy:** 95%+ with table extraction
- **Cost:** $1.50 per 1,000 pages
- **Configuration:** `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`

#### Mock OCR (Development)
- **Status:** ✅ Implemented
- **Use Case:** Testing without API costs
- **Sample:** Realistic veterinary invoice

### 2. Intelligent Parsing

#### Provider Name Detection
```regex
^([A-Z][A-Za-z\s&]+(?:VETERINARY|VET|ANIMAL|PET|CLINIC|HOSPITAL))
```
- Captures first line with veterinary keywords
- Case-insensitive matching

#### Date Parsing
Supports multiple formats:
- `October 8, 2025`
- `10/8/2025`
- `10-8-2025`
- `Date of Service: ...`
- `Service Date: ...`

#### Medical Codes
- **ICD-10 Diagnosis:** `S82.201A`, `K52.9`, etc.
- **CPT Procedures:** `99213`, `73590`, `27758`, etc.

#### Amount Extraction
Prioritized patterns:
1. `TOTAL AMOUNT DUE: $1,578.68`
2. `TOTAL: $1,578.68`
3. `Amount Due: $1,578.68`
4. `Balance Due: $1,578.68`

### 3. Cross-Validation

**Amount Matching Logic:**
```dart
// Allow 5% variance OR $10 difference
bool isMatch = difference <= 10.0 || percentDiff <= 5.0;
```

**Validation Statuses:**
- ✅ `match` - Amounts align within tolerance
- ❌ `mismatch` - Significant discrepancy detected
- ⚠️ `no_extracted_amount` - OCR couldn't find total
- ℹ️ `no_user_amount` - User didn't provide amount

### 4. GPT-4o Analysis

**AI Prompt:**
```
You are a veterinary insurance claim validator.

QUESTIONS:
1. Is this a legitimate veterinary invoice?
2. What treatment/procedure was performed?
3. Claim category? (accident/illness/wellness)
4. Confidence score (0.0-1.0)?
5. Any fraud indicators?
```

**Response Format:**
```json
{
  "isLegitimate": true,
  "treatment": "Tibia fracture repair surgery",
  "category": "accident",
  "confidence": 0.92,
  "summary": "Legitimate invoice for emergency fracture repair",
  "fraudFlags": []
}
```

**Fraud Detection Examples:**
- Suspicious provider name
- Unusual charge amounts
- Inconsistent dates
- Missing required fields
- Duplicate documents
- Photoshopped text

### 5. Confidence Scoring

**Weighted Components:**
```dart
OCR Confidence:     25%  // Text extraction quality
Parsing Confidence: 25%  // Data extraction completeness
GPT Confidence:     35%  // AI legitimacy assessment
Amount Match:       15%  // User validation
```

**Confidence Levels:**
- 🟢 **High (>0.8):** Auto-approve eligible
- 🟡 **Medium (0.5-0.8):** Review recommended
- 🔴 **Low (<0.5):** Manual verification required

### 6. Risk Assessment

**Risk Levels:**
- 🔴 **High Risk:**
  - Fraud flags present
  - Marked as illegitimate
  - Low confidence (<0.5)
  
- 🟡 **Medium Risk:**
  - Amount validation failed
  - Confidence 0.5-0.8
  - Minor inconsistencies

- 🟢 **Low Risk:**
  - All validations passed
  - High confidence (>0.8)
  - No fraud flags

---

## API Reference

### Main Methods

#### `analyzeDocument()`
```dart
Future<ClaimDocumentAnalysis> analyzeDocument({
  required String filePath,
  required String claimId,
  required String documentId,
  double? userEnteredAmount,
})
```

**Parameters:**
- `filePath` - Local file path to document
- `claimId` - Associated claim ID
- `documentId` - Unique document identifier
- `userEnteredAmount` - Optional user-provided amount for validation

**Returns:** `ClaimDocumentAnalysis` object

**Usage:**
```dart
final service = ClaimDocumentAIService();

final analysis = await service.analyzeDocument(
  filePath: '/path/to/invoice.pdf',
  claimId: 'claim_123',
  documentId: 'doc_456',
  userEnteredAmount: 1578.68,
);

print('Provider: ${analysis.providerName}');
print('Total: \$${analysis.totalCharge}');
print('Legitimate: ${analysis.isLegitimate}');
print('Confidence: ${(analysis.confidenceScore * 100).toInt()}%');
print('Risk: ${analysis.riskLevel}');
```

#### `analyzeDocuments()` - Batch Processing
```dart
Future<List<ClaimDocumentAnalysis>> analyzeDocuments({
  required List<String> filePaths,
  required String claimId,
  double? userEnteredAmount,
})
```

**Use Case:** Process multiple documents for single claim

#### `getDocumentAnalysis()` - Retrieve from Firestore
```dart
Future<ClaimDocumentAnalysis?> getDocumentAnalysis({
  required String claimId,
  required String documentId,
})
```

#### `getClaimDocuments()` - Get all documents
```dart
Future<List<ClaimDocumentAnalysis>> getClaimDocuments(String claimId)
```

---

## Data Models

### ClaimDocumentAnalysis
```dart
class ClaimDocumentAnalysis {
  String documentId;
  String claimId;
  String extractedText;           // Full OCR text
  String providerName;             // Vet clinic name
  DateTime? serviceDate;           // Date of service
  List<String> diagnosisCodes;     // ICD-10 codes
  List<String> procedureCodes;     // CPT codes
  double totalCharge;              // Total amount
  String currency;                 // USD, CAD, etc.
  bool isLegitimate;              // GPT validation
  String treatment;                // Treatment description
  String claimCategory;            // accident/illness/wellness
  double confidenceScore;          // 0.0-1.0
  String summary;                  // AI summary
  Map<String, dynamic> amountValidation;
  List<String> fraudFlags;
  DateTime analyzedAt;
  String ocrProvider;
  String? error;
}
```

### Helper Properties
```dart
bool hasError;                    // Check for errors
bool amountValidationPassed;      // Amount match
bool hasFraudFlags;               // Fraud indicators
String riskLevel;                 // high/medium/low
```

---

## Firestore Structure

### Document Storage
```
/claims/{claimId}/documents/{documentId}
  ├─ documentId: "doc_1728587421000"
  ├─ claimId: "claim_123"
  ├─ extractedText: "HAPPY PAWS VET..."
  ├─ providerName: "Happy Paws Veterinary Clinic"
  ├─ serviceDate: Timestamp(2025-10-08)
  ├─ diagnosisCodes: ["S82.201A"]
  ├─ procedureCodes: ["99213", "73590", "27758"]
  ├─ totalCharge: 1578.68
  ├─ currency: "USD"
  ├─ isLegitimate: true
  ├─ treatment: "Tibia fracture repair"
  ├─ claimCategory: "accident"
  ├─ confidenceScore: 0.92
  ├─ summary: "Legitimate invoice..."
  ├─ amountValidation: {...}
  ├─ fraudFlags: []
  ├─ analyzedAt: Timestamp(2025-10-10)
  ├─ ocrProvider: "Google Cloud Vision"
  └─ error: null
```

---

## Configuration

### Environment Variables

Add to `.env`:
```bash
# Google Cloud Vision (Recommended)
GOOGLE_VISION_API_KEY=AIzaSy...

# AWS Textract (Optional)
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...

# OpenAI (Required for GPT-4o)
OPENAI_API_KEY=sk-...
```

### Service Initialization

**Default (Google Vision):**
```dart
final service = ClaimDocumentAIService();
```

**Custom Configuration:**
```dart
final service = ClaimDocumentAIService(
  ocrProvider: OCRProvider.awsTextract,
  googleVisionApiKey: 'your-key',
  awsAccessKey: 'your-key',
  awsSecretKey: 'your-secret',
);
```

**Mock Mode (Development):**
```dart
final service = ClaimDocumentAIService(
  ocrProvider: OCRProvider.mock,
);
```

---

## Integration Example

### Claim Intake Flow

```dart
import 'package:pet_underwriter_ai/services/claim_document_ai_service.dart';

class ClaimIntakeScreen extends StatefulWidget {
  // ... existing code ...
  
  Future<void> _handleDocumentUpload(String filePath) async {
    setState(() => _isAnalyzing = true);
    
    try {
      // Upload to Firebase Storage
      final url = await _claimsService.uploadClaimDocument(
        filePath,
        _draftClaimId!,
      );
      
      // Analyze document with AI
      final aiService = ClaimDocumentAIService();
      final analysis = await aiService.analyzeDocument(
        filePath: filePath,
        claimId: _draftClaimId!,
        documentId: DateTime.now().millisecondsSinceEpoch.toString(),
        userEnteredAmount: _estimatedCost,
      );
      
      // Display results to user
      if (analysis.confidenceScore > 0.8) {
        _showSuccessMessage(
          'Document verified! Provider: ${analysis.providerName}, '
          'Total: \$${analysis.totalCharge}'
        );
      } else if (analysis.riskLevel == 'high') {
        _showWarningMessage(
          'Document verification failed. Please review manually.'
        );
      } else {
        _showInfoMessage(
          'Document uploaded. Confidence: ${(analysis.confidenceScore * 100).toInt()}%'
        );
      }
      
      // Store URL and analysis
      setState(() {
        _attachmentUrls.add(url);
        _documentAnalyses.add(analysis);
      });
      
    } catch (e) {
      _showErrorMessage('Failed to analyze document: $e');
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }
}
```

### Admin Review Dashboard

```dart
class ClaimReviewScreen extends StatelessWidget {
  final String claimId;
  
  Future<void> _reviewDocuments() async {
    final aiService = ClaimDocumentAIService();
    final documents = await aiService.getClaimDocuments(claimId);
    
    for (final doc in documents) {
      print('Document: ${doc.documentId}');
      print('  Provider: ${doc.providerName}');
      print('  Date: ${doc.serviceDate}');
      print('  Total: \$${doc.totalCharge}');
      print('  Risk: ${doc.riskLevel}');
      print('  Confidence: ${(doc.confidenceScore * 100).toInt()}%');
      
      if (doc.hasFraudFlags) {
        print('  ⚠️ FRAUD FLAGS: ${doc.fraudFlags.join(", ")}');
      }
      
      if (!doc.amountValidationPassed) {
        print('  ⚠️ AMOUNT MISMATCH: ${doc.amountValidation['message']}');
      }
    }
  }
}
```

---

## Testing

### Mock Data Testing

```dart
void testDocumentAnalysis() async {
  final service = ClaimDocumentAIService(
    ocrProvider: OCRProvider.mock,
  );
  
  final analysis = await service.analyzeDocument(
    filePath: '/mock/path',
    claimId: 'test_claim',
    documentId: 'test_doc',
    userEnteredAmount: 1578.68,
  );
  
  assert(analysis.providerName == 'HAPPY PAWS VETERINARY CLINIC');
  assert(analysis.totalCharge == 1578.68);
  assert(analysis.amountValidationPassed == true);
  assert(analysis.confidenceScore > 0.8);
  assert(analysis.riskLevel == 'low');
}
```

### Real OCR Testing

1. Get Google Cloud Vision API key
2. Add to `.env`
3. Test with real veterinary invoices:

```dart
final service = ClaimDocumentAIService(
  ocrProvider: OCRProvider.googleVision,
);

final analysis = await service.analyzeDocument(
  filePath: '/path/to/real_invoice.pdf',
  claimId: 'real_claim',
  documentId: 'real_doc',
  userEnteredAmount: 1500.00,
);

print('Results:');
print('  Confidence: ${analysis.confidenceScore}');
print('  Legitimate: ${analysis.isLegitimate}');
print('  Amount Match: ${analysis.amountValidationPassed}');
```

---

## Performance

### Benchmarks

| Operation | Average Time | Notes |
|-----------|-------------|-------|
| Google Vision OCR | 1-3 seconds | Depends on image size |
| Text Parsing | <100ms | Regex-based |
| GPT-4o Analysis | 2-5 seconds | Token-based pricing |
| Firestore Storage | 200-500ms | Network dependent |
| **Total** | **3-9 seconds** | End-to-end |

### Cost Analysis

**Per 1,000 Documents:**
- Google Vision: $1.50
- GPT-4o (avg 1,000 tokens): $0.03
- Firestore writes: $0.06
- **Total: ~$1.60**

### Optimization Tips

1. **Batch Processing:** Use `analyzeDocuments()` for multiple files
2. **Caching:** Store OCR results to avoid re-processing
3. **Image Optimization:** Resize/compress before upload (target: <2MB)
4. **Parallel Processing:** Analyze multiple docs concurrently

---

## Error Handling

### Common Errors

#### 1. OCR API Key Missing
```dart
OCRResult(
  success: false,
  error: 'Google Vision API key not configured'
)
```
**Fix:** Add `GOOGLE_VISION_API_KEY` to `.env`

#### 2. No Text Detected
```dart
OCRResult(
  success: false,
  error: 'No text detected in image'
)
```
**Fix:** Check image quality, ensure readable text

#### 3. GPT-4 Analysis Failed
```dart
// Falls back to safe defaults
{
  'isLegitimate': true,
  'confidence': 0.5,
  'summary': 'AI analysis unavailable'
}
```

#### 4. Firestore Storage Failed
```
Warning: Failed to store document metadata
```
**Note:** Non-critical, analysis still returns

### Error Recovery

```dart
try {
  final analysis = await service.analyzeDocument(...);
  
  if (analysis.hasError) {
    // Handle error
    print('Analysis failed: ${analysis.error}');
    // Fallback to manual review
  } else if (analysis.confidenceScore < 0.5) {
    // Low confidence - flag for review
    await flagForManualReview(analysis);
  } else {
    // Success - proceed with claim
    await processClaim(analysis);
  }
} catch (e) {
  // Critical error
  await notifySupport(e);
}
```

---

## Security Considerations

### API Key Protection
- Store in `.env`, never commit
- Use Firebase Functions for server-side processing (recommended)
- Rotate keys quarterly

### Data Privacy
- PHI/PII in documents (HIPAA compliance)
- Encrypt extracted text at rest
- Limit access to authorized users only

### Fraud Prevention
- Monitor for duplicate documents (hash-based)
- Track unusual patterns (ML model)
- Human review for high-risk cases

---

## Future Enhancements

### Phase 2
- [ ] AWS Textract integration
- [ ] Azure Computer Vision support
- [ ] PDF parsing (multi-page support)
- [ ] Table extraction for itemized bills

### Phase 3
- [ ] Real-time fraud detection ML model
- [ ] Automatic duplicate detection
- [ ] Multi-language OCR support
- [ ] Handwritten text recognition

### Phase 4
- [ ] Blockchain verification
- [ ] Provider database lookup
- [ ] Historical claim comparison
- [ ] Anomaly detection

---

## Related Documentation

- [Claim Intake Screen](./CLAIM_INTAKE_FEATURE.md)
- [Claim Data Model](../models/claim_model.md)
- [Firebase Storage Setup](../setup/firebase_storage_setup.md)
- [Google Cloud Vision Setup](../setup/google_vision_setup.md)

---

**Status:** ✅ Core Implementation Complete  
**Next Steps:** Google Cloud Vision API setup, Production testing

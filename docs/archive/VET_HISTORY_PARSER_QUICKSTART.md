# VetHistoryParser - Quick Reference

## Setup

```dart
final aiService = GPTService(apiKey: 'your-key', model: 'gpt-4');
final parser = VetHistoryParser(aiService: aiService);
```

## Upload and Parse PDF

```dart
final pdfFile = File('/path/to/vet_records.pdf');
final parsedData = await parser.parseUploadedPdf(
  pdfFile: pdfFile,
  petId: 'pet_12345',
  filename: 'records.pdf', // optional
);
```

## Parse Text Directly

```dart
final parsedData = await parser.parseText(vetRecordText);
```

## Parse and Auto-Save

```dart
final parsedData = await parser.parseAndSave(
  text: vetRecordText,
  petId: 'pet_12345',
);
```

## Retrieve History

```dart
// Get all
final histories = await parser.getHistory('pet_12345');

// Get most recent
final mostRecent = await parser.getMostRecentHistory('pet_12345');
```

## Access Parsed Data

```dart
print('Diagnoses: ${parsedData.diagnoses.length}');
print('Medications: ${parsedData.medications.length}');
print('Vaccinations: ${parsedData.vaccinations.length}');
print('Allergies: ${parsedData.allergies.length}');
print('Surgeries: ${parsedData.surgeries.length}');
print('Previous Claims: ${parsedData.previousClaims.length}');
```

## Data Models

### Diagnosis
```dart
final diagnosis = parsedData.diagnoses.first;
diagnosis.condition;  // "Osteoarthritis"
diagnosis.date;       // DateTime
diagnosis.status;     // "active", "resolved", "chronic"
diagnosis.severity;   // "mild", "moderate", "severe"
diagnosis.notes;      // Additional info
```

### Medication
```dart
final med = parsedData.medications.first;
med.name;       // "Carprofen"
med.dosage;     // "75mg twice daily"
med.startDate;  // DateTime
med.endDate;    // DateTime or null (ongoing)
med.purpose;    // "Pain management"
```

### PreviousClaim
```dart
final claim = parsedData.previousClaims.first;
claim.date;      // DateTime
claim.condition; // "Ear infection"
claim.amount;    // 250.00
claim.status;    // "approved", "denied", "pending"
```

## Error Handling

```dart
try {
  final parsedData = await parser.parseUploadedPdf(...);
} on VetHistoryParseException catch (e) {
  print('Parse error: ${e.message}');
} on FirebaseException catch (e) {
  print('Firebase error: ${e.message}');
}
```

## Cloud Functions

### Deploy
```bash
cd functions
npm install
firebase deploy --only functions
```

### Functions Deployed
- `extractPdfText` (HTTP)
- `processPdfOnUpload` (Storage trigger)
- `getPdfProcessingStatus` (Callable)

## Integration with Risk Scoring

```dart
// Parse vet history
final vetHistory = await parser.parseUploadedPdf(...);

// Use in risk calculation
final riskScore = await riskEngine.calculateRiskScore(
  pet: pet,
  owner: owner,
  vetHistory: vetHistory,
  quoteId: quote.id,
);
```

## Firestore Structure

```
pets/{petId}/parsed_history/{docId}
  ├── diagnoses
  ├── medications
  ├── vaccinations
  ├── allergies
  ├── surgeries
  ├── previousClaims
  ├── treatments
  ├── lastCheckup
  ├── parsedAt
  └── pdfUrl
```

## Performance

- Upload: 500ms - 2s
- Extract: 1-3s
- Parse: 3-6s
- Save: <100ms
- **Total: 5-11s**

## Costs

- Per document: ~$0.06
- 1,000 docs/month: ~$62

## Key Files

- Implementation: `lib/services/vet_history_parser.dart`
- Cloud Functions: `functions/pdfExtraction.js`
- Examples: `examples/vet_history_parser_example.dart`
- Full Docs: `VET_HISTORY_PARSER_USAGE.md`

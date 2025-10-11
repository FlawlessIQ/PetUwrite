# RiskScoringEngine - Quick Reference

## Setup (One-time)

```dart
// Choose your AI provider
final aiService = GPTService(
  apiKey: 'your-openai-api-key',
  model: 'gpt-4o',
);
// OR
final aiService = VertexAIService(
  projectId: 'your-gcp-project',
  location: 'us-central1',
  apiKey: 'your-vertex-key',
  model: 'gemini-pro',
);

// Create engine
final riskEngine = RiskScoringEngine(aiService: aiService);
```

## Basic Usage

```dart
// Calculate risk score with AI analysis
final riskScore = await riskEngine.calculateRiskScore(
  pet: pet,                    // Required
  owner: owner,                // Required (for zip code)
  vetHistory: vetHistory,      // Optional
  quoteId: 'quote_123',        // Optional (enables auto-save)
);

// Access results
print('Score: ${riskScore.overallScore}/100');
print('Level: ${riskScore.riskLevel}');
print('AI Analysis:\n${riskScore.aiAnalysis}');
```

## Key Methods

| Method | Purpose | Auto-saves? |
|--------|---------|-------------|
| `calculateRiskScore()` | Main calculation + AI analysis | ✅ If quoteId provided |
| `storeRiskScore()` | Manual Firestore save | N/A |
| `getRiskScore()` | Retrieve from Firestore | N/A |

## Required Parameters

```dart
calculateRiskScore(
  pet: Pet,          // Must include: age, breed, weight, gender
  owner: Owner,      // Must include: address.zipCode, address.state
  
  // Optional but recommended:
  vetHistory: VetRecordData?,
  additionalData: Map<String, dynamic>?,
  quoteId: String?,  // Provide to auto-save
)
```

## What AI Analyzes

1. **Pet Profile**: Age, breed, species, weight, gender, pre-existing conditions
2. **Location**: Zip code, state, city (for regional risk factors)
3. **Medical History**: Vaccinations, treatments, surgeries, medications
4. **Traditional Score**: Your calculated risk scores by category

## What AI Returns

- Risk score validation/adjustment (0-100)
- Top risk categories with specifics
- Breed-specific health considerations
- Geographic risk factors (climate, diseases, costs)
- Preventive care recommendations
- Coverage recommendations (deductibles, limits)
- Expected claim probability

## Firestore Structure

```
quotes/{quoteId}/risk_score/{riskScoreId}
  ├── id: "risk_xxx"
  ├── petId: "pet_xxx"
  ├── overallScore: 52.5
  ├── riskLevel: "RiskLevel.medium"
  ├── categoryScores: {...}
  ├── riskFactors: [...]
  └── aiAnalysis: "..."
```

## Error Handling

```dart
try {
  final riskScore = await riskEngine.calculateRiskScore(...);
} on RiskScoringException catch (e) {
  print('Risk scoring failed: ${e.message}');
} catch (e) {
  print('Unexpected error: $e');
}
```

## Testing

```dart
// Use mock AI service for tests
final mockAI = MockAIService(
  mockResponse: 'Risk Assessment: ...',
);
final testEngine = RiskScoringEngine(aiService: mockAI);
```

## Performance

- Traditional calculation: ~50ms
- AI API call: 2-5 seconds
- Firestore save: <100ms
- **Total: 3-6 seconds**

## Costs

- **GPT-4o**: ~$0.015 per assessment
- **Vertex AI**: ~$0.002 per assessment

## Common Patterns

### Pattern 1: Quote Flow
```dart
final riskScore = await riskEngine.calculateRiskScore(
  pet: pet,
  owner: owner,
  quoteId: quote.id,  // Auto-saves
);
final pricing = calculatePricing(riskScore);
```

### Pattern 2: Re-assessment
```dart
// Get existing score
final existing = await riskEngine.getRiskScore(quoteId: quoteId);

// Recalculate if needed
if (petInfoChanged) {
  final newScore = await riskEngine.calculateRiskScore(
    pet: updatedPet,
    owner: owner,
    quoteId: quoteId,
  );
}
```

### Pattern 3: No Auto-save
```dart
// Calculate without saving
final riskScore = await riskEngine.calculateRiskScore(
  pet: pet,
  owner: owner,
  // Don't provide quoteId
);

// Save later if needed
if (userAcceptsQuote) {
  await riskEngine.storeRiskScore(
    quoteId: quote.id,
    riskScore: riskScore,
  );
}
```

## Dependencies

```yaml
# pubspec.yaml
dependencies:
  cloud_firestore: ^5.0.0
  http: ^1.1.0  # For AI API calls
```

## API Keys Configuration

```dart
// Environment variables (recommended)
const openAiKey = String.fromEnvironment('OPENAI_API_KEY');
const vertexProject = String.fromEnvironment('VERTEX_PROJECT_ID');

// Or use a config service
final config = await ConfigService.load();
final aiService = GPTService(apiKey: config.openAiKey);
```

## Firestore Security Rules

```javascript
match /quotes/{quoteId}/risk_score/{riskScoreId} {
  allow read, write: if request.auth != null && 
    get(/databases/$(database)/documents/quotes/$(quoteId)).data.ownerId == request.auth.uid;
}
```

## Tips

✅ **DO**:
- Provide vet history for better AI analysis
- Use quoteId for automatic Firestore storage
- Handle AI failures gracefully (fallback included)
- Show loading indicator (3-6 second wait)
- Monitor API costs

❌ **DON'T**:
- Call AI API for every keystroke (cache results)
- Skip error handling
- Forget to configure API keys
- Expose API keys in client code

## Files

- Implementation: `lib/services/risk_scoring_engine.dart`
- Documentation: `RISK_SCORING_USAGE.md`
- Examples: `examples/risk_scoring_example.dart`
- Tests: `test/services/risk_scoring_engine_test.dart`
- Summary: `IMPLEMENTATION_SUMMARY.md`

## Support

Need help? Check:
1. `RISK_SCORING_USAGE.md` for detailed documentation
2. `examples/risk_scoring_example.dart` for working code
3. `test/services/risk_scoring_engine_test.dart` for test patterns
4. AI service documentation (`lib/ai/ai_service.dart`)

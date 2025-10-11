# RiskScoringEngine Usage Guide

## Overview

The `RiskScoringEngine` class provides comprehensive pet insurance risk assessment by combining traditional actuarial methods with AI-powered analysis from GPT-4o or Vertex AI.

## Features

✅ **Traditional Risk Scoring**
- Age-based risk assessment
- Breed-specific health risks
- Pre-existing condition analysis
- Medical history evaluation
- Lifestyle risk factors

✅ **AI-Powered Enhancement**
- Calls external AI API (GPT-4o or Vertex AI)
- Comprehensive risk analysis with natural language insights
- Breed-specific health considerations
- Geographic risk factors (climate, regional diseases, vet costs)
- Personalized recommendations

✅ **Firestore Integration**
- Automatic storage under `quotes/{quoteId}/risk_score`
- Updates quote document with risk summary
- Retrieval methods for historical risk scores

## Setup

### 1. Initialize AI Service

Choose either GPT or Vertex AI:

```dart
// Option 1: Using GPT-4o
final aiService = GPTService(
  apiKey: 'your-openai-api-key',
  model: 'gpt-4o',
);

// Option 2: Using Vertex AI
final aiService = VertexAIService(
  projectId: 'your-gcp-project-id',
  location: 'us-central1',
  apiKey: 'your-vertex-ai-key',
  model: 'gemini-pro',
);
```

### 2. Create RiskScoringEngine Instance

```dart
final riskEngine = RiskScoringEngine(
  aiService: aiService,
  firestore: FirebaseFirestore.instance, // Optional, defaults to instance
);
```

## Basic Usage

### Calculate Risk Score with AI Analysis

```dart
import 'package:pet_underwriter_ai/models/pet.dart';
import 'package:pet_underwriter_ai/models/owner.dart';
import 'package:pet_underwriter_ai/services/risk_scoring_engine.dart';
import 'package:pet_underwriter_ai/services/vet_history_parser.dart';
import 'package:pet_underwriter_ai/ai/ai_service.dart';

Future<void> assessPetRisk() async {
  // Create pet profile
  final pet = Pet(
    id: 'pet_123',
    name: 'Max',
    species: 'dog',
    breed: 'German Shepherd',
    dateOfBirth: DateTime(2018, 5, 15),
    gender: 'Male',
    weight: 35.0,
    isNeutered: true,
    preExistingConditions: ['Hip Dysplasia'],
  );
  
  // Create owner profile (for location-based risk)
  final owner = Owner(
    id: 'owner_123',
    firstName: 'John',
    lastName: 'Doe',
    email: 'john@example.com',
    phoneNumber: '555-1234',
    address: Address(
      street: '123 Main St',
      city: 'San Francisco',
      state: 'CA',
      zipCode: '94102',
      country: 'USA',
    ),
  );
  
  // Optional: Parse veterinary records
  final vetHistory = await VetHistoryParser().parseVetRecords(
    'Vet records text here...',
  );
  
  // Initialize AI service and engine
  final aiService = GPTService(
    apiKey: 'your-api-key',
    model: 'gpt-4o',
  );
  
  final riskEngine = RiskScoringEngine(aiService: aiService);
  
  // Calculate risk score (includes AI analysis and Firestore storage)
  final riskScore = await riskEngine.calculateRiskScore(
    pet: pet,
    owner: owner,
    vetHistory: vetHistory,
    quoteId: 'quote_456', // Will auto-save to Firestore
  );
  
  // Access results
  print('Overall Risk Score: ${riskScore.overallScore}/100');
  print('Risk Level: ${riskScore.riskLevel}');
  print('\nAI Analysis:\n${riskScore.aiAnalysis}');
  print('\nRisk Factors:');
  for (final factor in riskScore.riskFactors) {
    print('- ${factor.description} (Impact: ${factor.impact})');
  }
}
```

## Advanced Usage

### Retrieve Stored Risk Score

```dart
// Get most recent risk score for a quote
final riskScore = await riskEngine.getRiskScore(
  quoteId: 'quote_456',
);

// Get specific risk score by ID
final specificScore = await riskEngine.getRiskScore(
  quoteId: 'quote_456',
  riskScoreId: 'risk_1234567890',
);
```

### Manual Storage (without auto-save)

```dart
// Calculate without auto-saving
final riskScore = await riskEngine.calculateRiskScore(
  pet: pet,
  owner: owner,
  // Don't provide quoteId to skip auto-save
);

// Store manually later
await riskEngine.storeRiskScore(
  quoteId: 'quote_456',
  riskScore: riskScore,
);
```

### Additional Data for Lifestyle Risk

```dart
final riskScore = await riskEngine.calculateRiskScore(
  pet: pet,
  owner: owner,
  additionalData: {
    'indoorOutdoor': 'outdoor',
    'exerciseLevel': 'high',
    'dietType': 'premium',
  },
);
```

## AI Prompt Structure

The engine sends the following data to the AI API:

1. **Pet Profile**: age, breed, species, weight, gender, neutered status, pre-existing conditions
2. **Owner Location**: zip code, state, city (for geographic risk factors)
3. **Medical History**: vaccinations, treatments, surgeries, medications, allergies
4. **Traditional Risk Assessment**: calculated scores by category, risk factors
5. **Analysis Request**: Asks AI to validate/adjust score and provide comprehensive analysis

## Response Format

The AI returns:

```
Overall Risk Assessment: [Score 0-100 with justification]

Top Risk Categories:
1. [Category]: [Specific concerns]
2. [Category]: [Specific concerns]
...

Breed-specific Considerations:
- [Health issues common to breed]

Geographic Risk Factors:
- [Climate/regional disease risks for location]
- [Veterinary cost considerations]

Preventive Care Recommendations:
- [Specific preventive measures]

Coverage Recommendations:
- [Deductible levels]
- [Coverage limits]

Expected Claim Probability: [Percentage in next 12 months]
```

## Firestore Data Structure

Risk scores are stored at:

```
quotes/{quoteId}/risk_score/{riskScoreId}
```

Document structure:
```json
{
  "id": "risk_1234567890",
  "petId": "pet_123",
  "calculatedAt": "2025-10-07T12:00:00Z",
  "overallScore": 52.3,
  "riskLevel": "RiskLevel.medium",
  "categoryScores": {
    "age": 50.0,
    "breed": 55.0,
    "preExisting": 35.0,
    "medicalHistory": 40.0,
    "lifestyle": 30.0
  },
  "riskFactors": [
    {
      "category": "breed",
      "description": "German Shepherd has known breed-specific health issues",
      "impact": 2.5,
      "severity": "Severity.medium"
    }
  ],
  "aiAnalysis": "AI-generated comprehensive analysis text..."
}
```

The quote document is also updated:
```json
{
  "riskScoreId": "risk_1234567890",
  "riskScore": 52.3,
  "riskLevel": "RiskLevel.medium",
  "lastRiskAssessment": Timestamp
}
```

## Error Handling

```dart
try {
  final riskScore = await riskEngine.calculateRiskScore(
    pet: pet,
    owner: owner,
    quoteId: 'quote_456',
  );
} on RiskScoringException catch (e) {
  print('Risk scoring failed: ${e.message}');
} catch (e) {
  print('Unexpected error: $e');
}
```

## Configuration

### API Keys

Set your API keys in environment variables or configuration:

```dart
// For GPT-4o
const String openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');

// For Vertex AI
const String vertexProjectId = String.fromEnvironment('VERTEX_PROJECT_ID');
const String vertexApiKey = String.fromEnvironment('VERTEX_API_KEY');
```

### Firestore Security Rules

Ensure your `firestore.rules` allow access to the risk_score subcollection:

```
match /quotes/{quoteId}/risk_score/{riskScoreId} {
  allow read, write: if request.auth != null && 
    get(/databases/$(database)/documents/quotes/$(quoteId)).data.ownerId == request.auth.uid;
}
```

## Integration with Quote Flow

Typical workflow:

```dart
// 1. User enters pet information
final pet = await getPetInfoFromForm();
final owner = await getOwnerInfoFromForm();

// 2. User uploads vet records (optional)
final vetRecordsText = await uploadVetRecords();
final vetHistory = await VetHistoryParser().parseVetRecords(vetRecordsText);

// 3. Create quote
final quote = await createQuote(pet: pet, owner: owner);

// 4. Calculate risk score (auto-saves to Firestore)
final riskScore = await riskEngine.calculateRiskScore(
  pet: pet,
  owner: owner,
  vetHistory: vetHistory,
  quoteId: quote.id,
);

// 5. Generate pricing based on risk score
final pricing = await calculatePricing(riskScore: riskScore);

// 6. Show user their quote with risk insights
displayQuoteToUser(
  quote: quote,
  riskScore: riskScore,
  pricing: pricing,
);
```

## Testing

For testing without making actual AI API calls:

```dart
// Create a mock AI service
class MockAIService implements AIService {
  @override
  Future<String> generateText(String prompt, {Map<String, dynamic>? options}) async {
    return 'Mock AI Analysis: Risk is moderate for this pet.';
  }
  
  @override
  Future<Map<String, dynamic>> parseStructuredData(String text) async {
    return {};
  }
}

// Use in tests
final mockEngine = RiskScoringEngine(aiService: MockAIService());
```

## Performance Considerations

- **AI API Calls**: Typically 2-5 seconds for GPT-4o, 1-3 seconds for Vertex AI
- **Firestore Writes**: Usually < 100ms
- **Total Processing Time**: 3-6 seconds per risk assessment

For better UX, show a loading indicator during risk calculation.

## Costs

### OpenAI GPT-4o
- ~1,500 tokens per request
- Cost: ~$0.015 per assessment

### Google Vertex AI (Gemini)
- ~1,500 tokens per request
- Cost: ~$0.002 per assessment

## Next Steps

1. Configure your AI API keys
2. Test with sample pet data
3. Integrate into your quote flow
4. Monitor AI responses and adjust prompts if needed
5. Set up cost tracking for AI API usage

## Support

For issues or questions:
- Check `lib/services/risk_scoring_engine.dart` for implementation details
- Review `lib/ai/ai_service.dart` for AI service configuration
- See `lib/models/risk_score.dart` for data structure

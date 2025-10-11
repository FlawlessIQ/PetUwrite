# Explainable AI Implementation Guide

## Overview

The Explainable AI feature provides transparent, human-readable explanations for risk scores calculated by the `RiskScoringEngine`. It breaks down each risk factor's contribution to the final score, making AI decisions auditable and understandable.

## Architecture

### Data Flow

```
1. RiskScoringEngine.calculateRiskScore()
   ↓
2. _generateExplainabilityData()
   - Analyzes pet age, breed, medical history, lifestyle
   - Creates FeatureContribution objects
   - Calculates baseline (50) + contributions = final score
   ↓
3. storeExplainability()
   - Saves to Firestore: quotes/{id}/explainability
   ↓
4. ExplainabilityChart (UI)
   - Fetches explainability data
   - Displays visual bar chart
   - Shows positive/negative contributions
```

### Key Components

#### 1. Data Models (`lib/models/explainability_data.dart`)

**FeatureContribution**
```dart
class FeatureContribution {
  final String feature;      // e.g., "Senior (8-10 years)"
  final double impact;        // e.g., +10.0 or -5.0
  final String notes;         // e.g., "Increased risk for age-related conditions"
  final String category;      // "age", "breed", "medical", "lifestyle", "geographic"
}
```

**ExplainabilityData**
```dart
class ExplainabilityData {
  final String id;
  final String quoteId;
  final DateTime createdAt;
  final double baselineScore;           // Always 50.0
  final List<FeatureContribution> contributions;
  final double finalScore;
  final String overallSummary;          // Human-readable summary
}
```

Helper properties:
- `riskIncreasingFactors` - Contributions with positive impact (sorted desc)
- `riskDecreasingFactors` - Contributions with negative impact (sorted asc)
- `totalPositiveImpact` - Sum of all positive contributions
- `totalNegativeImpact` - Sum of all negative contributions
- `getTopFeatures(n)` - Top N most impactful features
- `contributionsByCategory` - Features grouped by category

#### 2. Risk Scoring Engine (`lib/services/risk_scoring_engine.dart`)

**Modified Methods:**

```dart
Future<RiskScore> calculateRiskScore({...}) async {
  // ... existing risk calculation ...
  
  // Generate explainability
  final explainability = _generateExplainabilityData(
    quoteId: quoteId!,
    pet: pet,
    owner: owner,
    vetHistory: vetHistory,
    categoryScores: categoryScores,
    riskFactors: riskFactors,
    finalScore: finalScore,
    additionalData: additionalData,
  );
  
  // Store in Firestore
  await storeExplainability(
    quoteId: quoteId,
    explainability: explainability,
  );
  
  return riskScore;
}
```

**New Methods:**

`_generateExplainabilityData()` - Creates feature contributions:
- Age factors (puppy, young adult, senior, geriatric)
- Breed factors (high-risk, low-risk, average)
- Pre-existing conditions
- Neutered status
- Weight (overweight, underweight)
- Vaccination status
- Surgery history
- Medications
- Allergies
- Checkup history
- Geographic factors (state-based vet costs)
- Lifestyle (indoor/outdoor)
- Previous insurance

`storeExplainability()` - Saves to Firestore:
```dart
_firestore
  .collection('quotes')
  .doc(quoteId)
  .collection('explainability')
  .doc(explainability.id)
  .set(explainability.toJson())
```

#### 3. UI Components (`lib/widgets/explainability_chart.dart`)

**ExplainabilityChart** - Full visual breakdown:
- Score summary bar (Baseline + Risk Factors + Protective = Final)
- Category tabs with impact totals
- Horizontal bar chart for each feature
  - Red/orange bars (right) = risk-increasing
  - Green bars (left) = risk-decreasing
  - Bar width proportional to impact magnitude
- Feature notes displayed below each bar

**ExplainabilityChartCompact** - Compact version:
- Final score
- Top risk factor
- Top protective factor
- Expandable to full view

#### 4. Admin Dashboard Integration (`lib/screens/admin_dashboard.dart`)

The explainability chart is displayed in `QuoteDetailsView` between the AI Analysis and Pet Information sections:

```dart
// AI Analysis Card
_buildSectionCard(title: 'AI Analysis', ...),

// Explainability Chart
_buildExplainabilitySection(),  // <-- NEW

// Pet Information Card
_buildSectionCard(title: 'Pet Information', ...),
```

The `_buildExplainabilitySection()` method:
- Fetches latest explainability data from Firestore
- Shows loading state while fetching
- Handles errors gracefully
- Displays "No data available" if explainability not yet generated
- Renders `ExplainabilityChart` with full data

## Feature Contribution Logic

### Age Contributions

| Age Range | Impact | Notes |
|-----------|--------|-------|
| < 1 year | +5.0 | Young pets have higher accident risk |
| 1-3 years | -5.0 | Lowest risk age group |
| 4-7 years | 0.0 | Average risk age group |
| 8-10 years | +10.0 | Increased risk for age-related conditions |
| 10+ years | +20.0 | High risk for chronic conditions and cancer |

### Breed Contributions

**High-Risk Breeds** (+12.0):
- German Shepherd (hip dysplasia, digestive issues)
- Golden Retriever (60%+ cancer risk)
- Labrador Retriever (obesity, joint problems)
- Bulldog (respiratory, skin problems)
- French Bulldog (brachycephalic syndrome)
- Persian Cat (kidney disease, breathing)
- Maine Coon (heart disease)

**Low-Risk Breeds** (-8.0):
- Australian Cattle Dog
- Border Collie
- Poodle
- Mixed Breed (hybrid vigor)
- Domestic Shorthair Cat
- Siamese Cat

**Average Breeds** (0.0): All others

### Medical History Contributions

| Factor | Impact | Calculation |
|--------|--------|-------------|
| Pre-existing conditions | +8.0 per condition | Multiplied by count |
| No pre-existing conditions | -5.0 | Clean health history |
| No vaccination records | +8.0 | Disease risk |
| Up-to-date vaccinations (3+) | -4.0 | Good preventive care |
| Previous surgeries | +3.0 per surgery | History of interventions |
| Multiple medications (2+) | +4.0 per medication | Chronic conditions |
| Known allergies | +2.0 per allergy | Management complexity |
| Recent checkup (< 1 year) | -3.0 | Regular preventive care |
| No checkup (> 2 years) | +5.0 | Lack of preventive care |

### Lifestyle Contributions

| Factor | Impact | Notes |
|--------|--------|-------|
| Spayed/Neutered | -3.0 | Reduced cancer risk |
| Not neutered | +4.0 | Higher reproductive cancer risk |
| Overweight (> 120% ideal) | +6.0 | Diabetes, joint issues |
| Underweight (< 80% ideal) | +5.0 | May indicate health issues |
| Indoor pet | -2.0 | Lower accident risk |
| Outdoor pet | +6.0 | Higher injury/infection risk |
| Previous insurance | -5.0 | Commitment to healthcare |

### Geographic Contributions

| State Group | Impact | Notes |
|-------------|--------|-------|
| High-cost states (CA, NY, MA, WA, CT) | +4.0 | Higher veterinary costs |
| Low-cost states (MS, AR, OK, WV, KY) | -2.0 | Lower veterinary costs |
| Other states | 0.0 | Average costs |

## Firestore Schema

### Collection Structure
```
quotes/
  {quoteId}/
    explainability/
      {explainabilityId}/
        - id: string
        - quoteId: string
        - createdAt: Timestamp
        - baselineScore: number (50.0)
        - contributions: array [
            {
              feature: string
              impact: number
              notes: string
              category: string
            }
          ]
        - finalScore: number
        - overallSummary: string
```

### Example Document
```json
{
  "id": "exp_abc123",
  "quoteId": "quote_xyz789",
  "createdAt": "2024-01-15T10:30:00Z",
  "baselineScore": 50.0,
  "contributions": [
    {
      "feature": "Senior (8-10 years)",
      "impact": 10.0,
      "notes": "Increased risk for age-related conditions",
      "category": "age"
    },
    {
      "feature": "Golden Retriever (High-Risk Breed)",
      "impact": 12.0,
      "notes": "High cancer risk (60%+ lifetime risk)",
      "category": "breed"
    },
    {
      "feature": "Spayed/Neutered",
      "impact": -3.0,
      "notes": "Reduced risk of certain cancers",
      "category": "lifestyle"
    },
    {
      "feature": "Up-to-date Vaccinations",
      "impact": -4.0,
      "notes": "Good preventive care",
      "category": "medical"
    }
  ],
  "finalScore": 65.0,
  "overallSummary": "Risk Score Breakdown:\n- Baseline: 50.0\n- Total Risk-Increasing: +22.0\n- Total Risk-Decreasing: -7.0\n- Final Score: 65.0"
}
```

## Usage Examples

### 1. Generate Explainability During Risk Scoring

```dart
final riskScoringEngine = RiskScoringEngine();

final riskScore = await riskScoringEngine.calculateRiskScore(
  pet: pet,
  owner: owner,
  vetHistory: vetHistory,
  quoteId: quoteId, // Required for storage
  additionalData: {
    'indoor': true,
    'hasInsurance': false,
  },
);

// Explainability data automatically generated and stored
```

### 2. Display Explainability Chart

```dart
// Full chart
ExplainabilityChart(
  explainability: explainabilityData,
  maxFeatures: 10,
  showCategories: true,
)

// Compact chart
ExplainabilityChartCompact(
  explainability: explainabilityData,
  onExpand: () {
    // Show full chart in modal or navigate
  },
)
```

### 3. Fetch Explainability Data

```dart
final snapshot = await FirebaseFirestore.instance
  .collection('quotes')
  .doc(quoteId)
  .collection('explainability')
  .orderBy('createdAt', descending: true)
  .limit(1)
  .get();

if (snapshot.docs.isNotEmpty) {
  final explainability = ExplainabilityData.fromJson(
    snapshot.docs.first.data(),
  );
  
  print('Final Score: ${explainability.finalScore}');
  print('Top Risk Factors:');
  for (var factor in explainability.riskIncreasingFactors.take(5)) {
    print('- ${factor.feature}: +${factor.impact}');
  }
}
```

### 4. Analyze Contributions Programmatically

```dart
// Get top 5 most impactful features (positive or negative)
final topFeatures = explainability.getTopFeatures(5);

// Get all medical-related contributions
final medicalFactors = explainability.contributionsByCategory['medical'] ?? [];

// Calculate total positive impact
final totalRisk = explainability.totalPositiveImpact;

// Get all protective factors sorted by impact
final protectiveFactors = explainability.riskDecreasingFactors;
```

## UI Screenshots (Conceptual)

### Full Explainability Chart
```
┌─────────────────────────────────────────────────────────────┐
│ 🔍 Risk Score Explanation                              ℹ️   │
├─────────────────────────────────────────────────────────────┤
│  Baseline: 50  +  Risk Factors: +22  +  Protective: -7      │
│  ────────────────────────────────────────────→ Final: 65    │
├─────────────────────────────────────────────────────────────┤
│ Chips: [Age +10] [Breed +12] [Medical -4] [Lifestyle -3]   │
├─────────────────────────────────────────────────────────────┤
│ 🐕 Golden Retriever (High-Risk Breed)            +12.0      │
│               ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓→                            │
│    High cancer risk (60%+ lifetime risk)                    │
│                                                              │
│ 🎂 Senior (8-10 years)                           +10.0      │
│               ▓▓▓▓▓▓▓▓▓▓▓▓→                                 │
│    Increased risk for age-related conditions                │
│                                                              │
│ 💉 Up-to-date Vaccinations                       -4.0       │
│     ←▓▓▓▓▓▓                                                 │
│    Good preventive care                                     │
└─────────────────────────────────────────────────────────────┘
```

### Compact Chart
```
┌─────────────────────────────────────────┐
│ 🔍 Risk Explanation               ▼     │
├─────────────────────────────────────────┤
│ Final Score     Top Risk: Golden Ret.   │
│   65.0              +12.0               │
│                                         │
│ Top Protective: Vaccinations (-4.0)     │
└─────────────────────────────────────────┘
```

## Testing

### Unit Tests

```dart
test('ExplainabilityData calculation', () {
  final contributions = [
    FeatureContribution(
      feature: 'Senior age',
      impact: 10.0,
      notes: 'High risk',
      category: 'age',
    ),
    FeatureContribution(
      feature: 'Good vaccinations',
      impact: -5.0,
      notes: 'Protective',
      category: 'medical',
    ),
  ];
  
  final explainability = ExplainabilityData(
    id: 'test',
    quoteId: 'quote123',
    createdAt: DateTime.now(),
    baselineScore: 50.0,
    contributions: contributions,
    finalScore: 55.0,
    overallSummary: 'Test',
  );
  
  expect(explainability.totalPositiveImpact, 10.0);
  expect(explainability.totalNegativeImpact, -5.0);
  expect(explainability.riskIncreasingFactors.length, 1);
  expect(explainability.riskDecreasingFactors.length, 1);
});
```

### Integration Test

```dart
testWidgets('ExplainabilityChart renders correctly', (tester) async {
  final explainability = ExplainabilityData(...);
  
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: ExplainabilityChart(explainability: explainability),
    ),
  ));
  
  expect(find.text('Risk Score Explanation'), findsOneWidget);
  expect(find.text('Baseline'), findsOneWidget);
  expect(find.text('Final Score'), findsOneWidget);
});
```

## Best Practices

1. **Always Generate on Risk Calculation**: Explainability should be generated every time a risk score is calculated, never separately.

2. **Store Immediately**: Store explainability data immediately after generation to ensure consistency.

3. **Use Latest Data**: When displaying, always fetch the most recent explainability record (orderBy createdAt desc, limit 1).

4. **Handle Missing Data**: UI should gracefully handle cases where explainability data doesn't exist yet.

5. **Keep Impacts Reasonable**: Contributions should generally be in the -10 to +20 range to maintain score bounds (0-100).

6. **Meaningful Notes**: Each contribution should have a clear, concise note explaining why it impacts the score.

7. **Category Consistency**: Use consistent category names across all contributions.

## Troubleshooting

### Explainability Data Not Showing

**Problem**: Chart shows "No data available"

**Solutions**:
1. Check that `quoteId` is provided to `calculateRiskScore()`
2. Verify Firestore permissions allow write to `quotes/{id}/explainability`
3. Check for errors in `storeExplainability()` method
4. Ensure `_generateExplainabilityData()` returns valid data

### Score Doesn't Match Contributions

**Problem**: Baseline + contributions ≠ final score

**Solutions**:
1. Verify `finalScore` parameter passed to `_generateExplainabilityData()` is correct
2. Check that all risk factors are captured in contributions
3. Ensure no contributions are being skipped or duplicated

### UI Performance Issues

**Problem**: Chart is slow to render

**Solutions**:
1. Reduce `maxFeatures` parameter (default 10)
2. Use `ExplainabilityChartCompact` for list views
3. Implement pagination for very large contribution lists
4. Cache explainability data in state

## Future Enhancements

1. **Historical Comparison**: Show how score changes over time with updated pet info
2. **Interactive Explanations**: Allow users to click features for more details
3. **What-If Analysis**: Show how score would change if factors were different
4. **Export to PDF**: Include explainability chart in policy documents
5. **AI-Generated Summaries**: Use LLM to generate natural language explanations
6. **Feature Importance Ranking**: Machine learning to determine most predictive features
7. **Breed-Specific Deep Dive**: Link to detailed breed health information

## References

- [Explainable AI Overview](https://en.wikipedia.org/wiki/Explainable_artificial_intelligence)
- [Model Interpretability in Machine Learning](https://christophm.github.io/interpretable-ml-book/)
- [LIME - Local Interpretable Model-agnostic Explanations](https://github.com/marcotcr/lime)
- [SHAP - SHapley Additive exPlanations](https://github.com/slundberg/shap)

---

**Implementation Complete**: ✅ All components implemented and integrated
- ✅ ExplainabilityData model
- ✅ RiskScoringEngine explainability generation
- ✅ ExplainabilityChart UI component
- ✅ Admin dashboard integration

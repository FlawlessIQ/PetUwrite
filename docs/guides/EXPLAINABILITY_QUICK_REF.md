# Explainability Feature - Quick Reference

## 📋 Quick Start

### Generate Explainability
```dart
final riskScore = await RiskScoringEngine().calculateRiskScore(
  pet: pet,
  owner: owner,
  vetHistory: vetHistory,
  quoteId: quoteId, // Required!
  additionalData: {'indoor': true},
);
// Explainability auto-generated and stored ✅
```

### Display Chart
```dart
// Full version
ExplainabilityChart(
  explainability: explainabilityData,
  maxFeatures: 10,
  showCategories: true,
)

// Compact version
ExplainabilityChartCompact(
  explainability: explainabilityData,
  onExpand: () => showFullChart(),
)
```

### Fetch Data
```dart
final snapshot = await FirebaseFirestore.instance
  .collection('quotes')
  .doc(quoteId)
  .collection('explainability')
  .orderBy('createdAt', descending: true)
  .limit(1)
  .get();

final explainability = ExplainabilityData.fromJson(
  snapshot.docs.first.data(),
);
```

## 🎯 Impact Values Reference

| Factor | Range | Description |
|--------|-------|-------------|
| Age (young) | -5.0 to +5.0 | 1-3 years = protective |
| Age (senior) | +10.0 to +20.0 | 8+ years = increased risk |
| High-risk breed | +12.0 | Known health issues |
| Low-risk breed | -8.0 | Generally healthy |
| Pre-existing condition | +8.0 each | Multiplied by count |
| Neutered | -3.0 | Reduced cancer risk |
| Not neutered | +4.0 | Higher risk |
| Overweight | +6.0 | Obesity-related issues |
| Vaccinations (up-to-date) | -4.0 | Good preventive care |
| No vaccinations | +8.0 | Disease risk |
| Surgeries | +3.0 each | History of interventions |
| Medications | +4.0 each | Chronic conditions |
| Indoor pet | -2.0 | Lower accident risk |
| Outdoor pet | +6.0 | Higher injury risk |
| High-cost state | +4.0 | CA, NY, MA, WA, CT |
| Low-cost state | -2.0 | MS, AR, OK, WV, KY |

## 📁 File Structure

```
lib/
├── models/
│   └── explainability_data.dart         # Data models
├── services/
│   └── risk_scoring_engine.dart         # Generation logic
├── widgets/
│   └── explainability_chart.dart        # UI components
└── screens/
    └── admin_dashboard.dart             # Integration
```

## 🔑 Key Classes

### FeatureContribution
```dart
FeatureContribution(
  feature: 'Senior (8-10 years)',
  impact: 10.0,                  // Can be + or -
  notes: 'Increased risk for age-related conditions',
  category: 'age',               // age, breed, medical, lifestyle, geographic
)
```

### ExplainabilityData
```dart
ExplainabilityData(
  id: 'exp_123',
  quoteId: 'quote_456',
  createdAt: DateTime.now(),
  baselineScore: 50.0,           // Always 50
  contributions: [...],
  finalScore: 65.0,
  overallSummary: '...',
)
```

## 🛠️ Helper Methods

```dart
// Get risk-increasing factors (sorted desc)
explainability.riskIncreasingFactors

// Get protective factors (sorted asc)
explainability.riskDecreasingFactors

// Get top N features by absolute impact
explainability.getTopFeatures(5)

// Group by category
explainability.contributionsByCategory

// Sum positive impacts
explainability.totalPositiveImpact

// Sum negative impacts
explainability.totalNegativeImpact
```

## 🗄️ Firestore Path

```
quotes/
  {quoteId}/
    explainability/
      {explainabilityId}/
        - id
        - quoteId
        - createdAt
        - baselineScore
        - contributions []
        - finalScore
        - overallSummary
```

## 🎨 UI Features

### Full Chart
- ✅ Score summary bar (Baseline → Risk Factors → Protective → Final)
- ✅ Category chips with totals
- ✅ Horizontal bar chart (red = risk, green = protective)
- ✅ Feature notes below each bar
- ✅ Configurable max features

### Compact Chart
- ✅ Final score
- ✅ Top risk factor
- ✅ Top protective factor
- ✅ Expandable

## ⚠️ Common Issues

### "No data available"
- ✓ Check `quoteId` is not null
- ✓ Verify Firestore permissions
- ✓ Check `storeExplainability()` didn't error

### Score mismatch
- ✓ Ensure all risk factors are captured
- ✓ Verify baseline = 50.0
- ✓ Check contribution impacts are correct

### Performance slow
- ✓ Reduce `maxFeatures` (default 10)
- ✓ Use `ExplainabilityChartCompact` in lists
- ✓ Implement caching

## 📊 Example Output

```
Baseline: 50.0
+ Golden Retriever (High-Risk): +12.0
+ Senior (8-10 years): +10.0
+ Not Neutered: +4.0
- Up-to-date Vaccinations: -4.0
- Indoor Pet: -2.0
= Final Score: 70.0
```

## 🧪 Testing

```dart
// Unit test
test('calculates impacts correctly', () {
  final explainability = ExplainabilityData(...);
  expect(explainability.totalPositiveImpact, 26.0);
  expect(explainability.totalNegativeImpact, -6.0);
  expect(explainability.finalScore, 70.0);
});

// Widget test
testWidgets('renders chart', (tester) async {
  await tester.pumpWidget(
    MaterialApp(home: ExplainabilityChart(explainability: data)),
  );
  expect(find.text('Risk Score Explanation'), findsOneWidget);
});
```

## 📝 Best Practices

1. ✅ Always generate explainability with risk score
2. ✅ Store immediately after generation
3. ✅ Fetch latest (orderBy createdAt desc, limit 1)
4. ✅ Handle missing data gracefully in UI
5. ✅ Keep impact values in -10 to +20 range
6. ✅ Use clear, concise notes
7. ✅ Use consistent category names

## 🔗 Related Docs

- [Full Implementation Guide](./EXPLAINABILITY_GUIDE.md)
- [Risk Scoring Engine](./lib/services/risk_scoring_engine.dart)
- [Admin Dashboard](../admin/ADMIN_DASHBOARD_GUIDE.md)

---

**Status**: ✅ Fully implemented and integrated

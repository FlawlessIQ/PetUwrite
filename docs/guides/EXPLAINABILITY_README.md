# 🔍 Explainable AI Feature

## Overview

The Explainable AI feature provides transparent, visual explanations of how the AI risk scoring engine arrives at its decisions. Every risk score is accompanied by a detailed breakdown showing:

- **Baseline Score**: Starting point (always 50)
- **Risk-Increasing Factors**: Positive contributions (shown in red)
- **Protective Factors**: Negative contributions (shown in green)
- **Final Score**: Baseline + all contributions

## ✨ Features

### 📊 Visual Bar Chart
- Horizontal bar chart with positive (right) and negative (left) contributions
- Bar width proportional to impact magnitude
- Color-coded: red for risk, green for protective
- Each factor includes explanatory notes

### 📁 Category Grouping
- **Age**: Young, adult, senior, geriatric
- **Breed**: High-risk, low-risk, average
- **Medical**: Pre-existing conditions, vaccinations, medications, surgeries
- **Lifestyle**: Neutered status, indoor/outdoor, weight
- **Geographic**: State-based veterinary cost variations

### 🎯 Actionable Insights
- Top risk factors highlighted
- Top protective factors shown
- Overall summary with calculations
- Helps underwriters make informed decisions

## 🚀 Quick Start

### Generate Explainability

```dart
final riskScore = await RiskScoringEngine().calculateRiskScore(
  pet: pet,
  owner: owner,
  vetHistory: vetHistory,
  quoteId: quoteId, // Required!
);
// Explainability automatically generated and stored ✅
```

### Display Full Chart

```dart
ExplainabilityChart(
  explainability: explainabilityData,
  maxFeatures: 10,
  showCategories: true,
)
```

### Display Compact Chart

```dart
ExplainabilityChartCompact(
  explainability: explainabilityData,
  onExpand: () => showFullChart(),
)
```

## 📖 Documentation

- **[Complete Guide](EXPLAINABILITY_GUIDE.md)** - Comprehensive implementation documentation
- **[Quick Reference](EXPLAINABILITY_QUICK_REF.md)** - Developer quick start guide
- **[Summary](EXPLAINABILITY_SUMMARY.md)** - Implementation summary and status
- **[Examples](lib/examples/explainability_example.dart)** - Working code examples
- **[Tests](test/explainability_test.dart)** - Unit tests

## 📂 File Structure

```
lib/
├── models/
│   └── explainability_data.dart       # FeatureContribution & ExplainabilityData classes
├── services/
│   └── risk_scoring_engine.dart       # Generation logic (_generateExplainabilityData)
├── widgets/
│   └── explainability_chart.dart      # UI components (Full & Compact charts)
├── screens/
│   └── admin_dashboard.dart           # Integration in QuoteDetailsView
└── examples/
    └── explainability_example.dart    # Usage examples

test/
└── explainability_test.dart           # Unit tests

docs/
├── EXPLAINABILITY_GUIDE.md
├── EXPLAINABILITY_QUICK_REF.md
└── EXPLAINABILITY_SUMMARY.md
```

## 🎨 Example Output

```
┌─────────────────────────────────────────────────┐
│ 🔍 Risk Score Explanation                       │
├─────────────────────────────────────────────────┤
│  Baseline  +  Risk    +  Protective  →  Final   │
│    50.0    + +26.0    +    -7.0      =   69.0   │
├─────────────────────────────────────────────────┤
│ [Age +10] [Breed +12] [Medical -4] [Lifestyle]  │
├─────────────────────────────────────────────────┤
│                                                  │
│ 🐕 Golden Retriever (High-Risk)       +12.0     │
│         ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓→                       │
│    High cancer risk (60%+ lifetime risk)        │
│                                                  │
│ 🎂 Senior (8-10 years)                +10.0     │
│         ▓▓▓▓▓▓▓▓▓▓▓▓→                           │
│    Increased risk for age-related conditions    │
│                                                  │
│ 💉 Up-to-date Vaccinations            -4.0      │
│      ←▓▓▓▓▓▓                                    │
│    Good preventive care                         │
│                                                  │
│ 🏠 Spayed/Neutered                    -3.0      │
│      ←▓▓▓▓                                      │
│    Reduced risk of certain cancers              │
└─────────────────────────────────────────────────┘
```

## 📊 Impact Value Ranges

| Category | Range | Examples |
|----------|-------|----------|
| **Age** | -5 to +20 | Young: -5, Senior: +10, Geriatric: +20 |
| **Breed** | -8 to +12 | Low-risk: -8, High-risk: +12 |
| **Pre-existing** | +8 each | Multiplied by condition count |
| **Medical** | -4 to +8 | Vaccinated: -4, No records: +8 |
| **Lifestyle** | -5 to +6 | Indoor: -2, Outdoor: +6, Neutered: -3 |
| **Geographic** | -2 to +4 | High-cost state: +4, Low-cost: -2 |

## 🔄 How It Works

```
1. User submits quote
         ↓
2. RiskScoringEngine calculates score
   - Traditional actuarial factors
   - AI analysis
         ↓
3. _generateExplainabilityData() creates contributions
   - Analyzes each risk factor
   - Creates FeatureContribution objects
   - Calculates baseline (50) + contributions
         ↓
4. storeExplainability() saves to Firestore
   - Path: quotes/{id}/explainability
         ↓
5. Admin Dashboard displays chart
   - Fetches latest explainability data
   - Renders visual bar chart
   - Shows to underwriter
```

## 🗄️ Data Structure

### FeatureContribution

```dart
{
  "feature": "Senior (8-10 years)",
  "impact": 10.0,
  "notes": "Increased risk for age-related conditions",
  "category": "age"
}
```

### ExplainabilityData

```dart
{
  "id": "exp_abc123",
  "quoteId": "quote_xyz789",
  "createdAt": Timestamp,
  "baselineScore": 50.0,
  "contributions": [...],
  "finalScore": 69.0,
  "overallSummary": "Risk Score Breakdown: ..."
}
```

## 🧪 Testing

```bash
# Run unit tests
flutter test test/explainability_test.dart

# Run all tests
flutter test
```

## 🎯 Integration Points

### 1. Risk Scoring Engine
Automatically generates explainability when calculating risk scores:

```dart
// In risk_scoring_engine.dart
final explainability = _generateExplainabilityData(...);
await storeExplainability(quoteId: quoteId, explainability: explainability);
```

### 2. Admin Dashboard
Displays explainability chart in quote details:

```dart
// In admin_dashboard.dart QuoteDetailsView
_buildExplainabilitySection()  // Fetches and displays chart
```

### 3. Future: Customer View
Can be integrated into customer-facing quote results:

```dart
// In quote_result_screen.dart
ExplainabilityChartCompact(
  explainability: explainability,
  onExpand: () => showFullExplanation(),
)
```

## 🔒 Security

### Firestore Rules

```javascript
match /quotes/{quoteId}/explainability/{explainabilityId} {
  // Users can read their own
  allow read: if isAuthenticated() && isOwner();
  
  // Underwriters can read all
  allow read: if isUnderwriter();
  
  // Only system can write
  allow write: if false;
}
```

## 🚀 Deployment

### Checklist

- [x] Code implementation complete
- [x] No compilation errors
- [x] Documentation written
- [ ] Update Firestore security rules
- [ ] Test with production data
- [ ] Train underwriters on new feature
- [ ] Monitor Firestore usage
- [ ] Set up error logging

## 📈 Future Enhancements

- [ ] **Historical Tracking** - Show score changes over time
- [ ] **Interactive Features** - Click factors for details
- [ ] **What-If Analysis** - Show impact of changing factors
- [ ] **Export to PDF** - Include in policy documents
- [ ] **AI Summaries** - Natural language explanations
- [ ] **Mobile Optimization** - Responsive design
- [ ] **Recommendations** - Suggest actions to improve score

## 🤝 Contributing

When adding new risk factors:

1. Add contribution logic to `_generateExplainabilityData()`
2. Use appropriate category (age, breed, medical, lifestyle, geographic)
3. Keep impacts in reasonable range (-10 to +20)
4. Provide clear, concise notes
5. Update tests
6. Update documentation

## 📞 Support

For questions or issues:

- Check [EXPLAINABILITY_GUIDE.md](EXPLAINABILITY_GUIDE.md) for comprehensive docs
- See [EXPLAINABILITY_QUICK_REF.md](EXPLAINABILITY_QUICK_REF.md) for quick answers
- Review [lib/examples/explainability_example.dart](lib/examples/explainability_example.dart) for examples

## ✅ Status

**Implementation**: Complete ✅  
**Testing**: Unit tests written ✅  
**Documentation**: Complete ✅  
**Integration**: Admin Dashboard ✅  
**Production Ready**: Pending QA testing ⏳

---

Built with ❤️ to make AI decisions transparent and trustworthy.

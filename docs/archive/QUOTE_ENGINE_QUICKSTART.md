# QuoteEngine Quick Reference

## 🚀 Generate Quotes in 3 Lines

```dart
final engine = QuoteEngine();
final plans = engine.generateQuote(riskScore: score, zipCode: '10001');
// Returns [Basic, Plus, Elite] plans
```

## 📊 Display with UI

```dart
PlanCards(
  plans: plans,
  showComparison: true,
  onSelectPlan: (plan) => checkout(plan),
)
```

## 💰 Pricing Formula

```
Base = $35
Risk = (score/100) × 1.5
Region = State multiplier (NY: +10%, CA: +8%, etc.)
Plan = Basic: 85% | Plus: 115% | Elite: 150%
Discount = 2 pets: 5% | 3 pets: 10% | 4+: 15%

Final = Base × (1+Risk) × Region × Plan × (1-Discount)
```

## 📋 Plan Comparison

| | Basic | Plus | Elite |
|---|---|---|---|
| **Premium** | 85% base | 115% base | 150% base |
| **Deductible** | $500 | $250 | $100 |
| **Co-pay** | 20% | 10% | 0% |
| **Max Coverage** | $10K | $15K | $25K |
| **Wellness** | ❌ | $250/yr | $500/yr |

## 🧮 Calculate Coverage

```dart
// Out-of-pocket for $5K claim
final youPay = engine.calculateOutOfPocket(
  plan: plan, 
  claimAmount: 5000.0,
);

// Insurance coverage amount
final weCover = engine.calculateCoverageAmount(
  plan: plan,
  claimAmount: 5000.0,
);
```

## 🏠 Regional Adjustments

- **NY**: +10% (NYC: automatic detection)
- **CA**: +8%
- **MA**: +9%
- **WA**: +7%
- **IL**: +6%
- **TX**: +2%
- **FL**: +3%
- **Others**: No adjustment

## 👨‍👩‍👧‍👦 Multi-Pet Discounts

```dart
1 pet  → 0% off
2 pets → 5% off
3 pets → 10% off
4+ pets → 15% off
```

## 📱 Full Example

```dart
// 1. Get risk score
final riskScore = await RiskScoringEngine()
  .calculateRiskScore(pet: myPet, owner: myOwner);

// 2. Generate quotes
final plans = QuoteEngine().generateQuote(
  riskScore: riskScore,
  zipCode: '10001',
  numberOfPets: 2,  // 5% discount
  state: 'NY',      // +10% adjustment
);

// 3. Display plans
return Scaffold(
  body: PlanCards(
    plans: plans,
    selectedPlan: selectedPlan,
    showComparison: true,
    onSelectPlan: (plan) {
      setState(() => selectedPlan = plan);
      Navigator.push(/* checkout */);
    },
  ),
);
```

## 🎯 Plan Features

### Basic
- Accidents & Illnesses
- Emergency Care
- Hospitalization
- Surgery
- Prescriptions
- 24/7 Helpline

### Plus (Most Popular)
- **Everything in Basic**
- Wellness ($250/yr)
- Dental Disease
- Alternative Therapies
- Hereditary Conditions
- Cancer Coverage

### Elite
- **Everything in Plus**
- Enhanced Wellness ($500/yr)
- Full Dental Coverage
- Exam Fees Covered
- Physical Therapy
- End of Life Care
- Travel Protection

## ⚡ Quick Methods

```dart
final engine = QuoteEngine();

// Generate 3 plans
final plans = engine.generateQuote(
  riskScore: score,
  zipCode: zip,
  numberOfPets: 2,
  state: 'NY',
);

// Annual cost
final yearly = engine.calculateAnnualCost(plans[0]);

// Out-of-pocket
final cost = engine.calculateOutOfPocket(
  plan: plans[1],
  claimAmount: 5000.0,
);

// Coverage amount
final covered = engine.calculateCoverageAmount(
  plan: plans[2],
  claimAmount: 10000.0,
);

// Compare plans
final comparison = engine.comparePlans(plans);
```

## 📐 Coverage Examples

### Basic Plan ($500 deductible, 20% co-pay)
| Claim | You Pay | We Cover |
|-------|---------|----------|
| $500 | $500 | $0 |
| $1,000 | $600 | $400 |
| $5,000 | $1,400 | $3,600 |
| $10,000 | $2,400 | $7,600 |

### Plus Plan ($250 deductible, 10% co-pay)
| Claim | You Pay | We Cover |
|-------|---------|----------|
| $500 | $275 | $225 |
| $1,000 | $325 | $675 |
| $5,000 | $725 | $4,275 |
| $10,000 | $1,225 | $8,775 |

### Elite Plan ($100 deductible, 0% co-pay)
| Claim | You Pay | We Cover |
|-------|---------|----------|
| $500 | $100 | $400 |
| $1,000 | $100 | $900 |
| $5,000 | $100 | $4,900 |
| $10,000 | $100 | $9,900 |

## 🔧 PlanCards Widget Props

```dart
PlanCards({
  required List<Plan> plans,        // 3 plans to display
  Plan? selectedPlan,               // Currently selected
  bool showComparison = false,      // Show claim examples
  Function(Plan)? onSelectPlan,     // Selection callback
})
```

## 🎨 Widget Features

- ✅ Responsive (mobile/desktop layouts)
- ✅ Hover animations
- ✅ Gradient backgrounds (Plus/Elite)
- ✅ "Most Popular" badge (Plus)
- ✅ Expandable features list
- ✅ Modal for full details
- ✅ Coverage comparison mode

## 💡 Best Practices

```dart
// ✅ DO: Use real risk scores
final score = await riskEngine.calculateRiskScore(...);

// ✅ DO: Cache quotes in Firestore
await saveQuote(quoteId, plans);

// ✅ DO: Show comparison mode
PlanCards(showComparison: true);

// ✅ DO: Reset selection when regenerating
setState(() {
  plans = newPlans;
  selectedPlan = null;
});

// ❌ DON'T: Use mock scores in production
// ❌ DON'T: Generate quotes without location
// ❌ DON'T: Forget to apply multi-pet discount
```

## 🧪 Test with Example

```bash
flutter run examples/quote_engine_example.dart
```

Features:
- Risk scenario selector
- Multi-pet slider
- Location picker
- Live quote updates
- Comparison tables

## 📚 See Also

- `QUOTE_ENGINE_USAGE.md` - Full documentation
- `RISK_SCORING_USAGE.md` - Risk assessment
- `VET_HISTORY_PARSER_USAGE.md` - Medical records
- `examples/quote_engine_example.dart` - Interactive demo

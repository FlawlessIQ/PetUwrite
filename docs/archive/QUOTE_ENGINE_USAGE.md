# QuoteEngine Documentation

## Overview

The `QuoteEngine` is a comprehensive pricing engine for generating pet insurance quotes. It calculates premiums based on risk scores, geographic location, and provides three coverage tiers (Basic, Plus, Elite) with multi-pet discounts.

## Features

✅ **Dynamic Pricing** - Calculates premiums using risk scores and regional adjustments  
✅ **Three Plan Tiers** - Basic, Plus, and Elite coverage options  
✅ **Multi-Pet Discounts** - Automatic discounts for 2+ pets (5%, 10%, 15%)  
✅ **Regional Pricing** - Location-based adjustments for high-cost areas  
✅ **Coverage Calculations** - Estimate out-of-pocket costs for any claim amount  
✅ **Plan Comparison** - Side-by-side comparison with example scenarios  
✅ **UI Components** - Beautiful `PlanCards` widget for displaying quotes

---

## Pricing Formula

```
Base Premium = $35

Risk Multiplier = (Risk Score / 100) × 1.5

Regional Multiplier = State-based adjustment (e.g., NY = +10%)

Plan Multiplier = 
  - Basic: 0.85 (15% discount from base)
  - Plus: 1.15 (15% premium)
  - Elite: 1.5 (50% premium)

Multi-Pet Discount = 
  - 2 pets: 5%
  - 3 pets: 10%
  - 4+ pets: 15%

Final Premium = Base × (1 + Risk Multiplier) × Regional Multiplier × Plan Multiplier × (1 - Multi-Pet Discount)
```

---

## Quick Start

### 1. Generate Quotes

```dart
import 'package:pet_underwriter_ai/services/quote_engine.dart';
import 'package:pet_underwriter_ai/models/risk_score.dart';

// Initialize the engine
final engine = QuoteEngine();

// Generate quotes for a pet with medium risk
final plans = engine.generateQuote(
  riskScore: myRiskScore,  // From RiskScoringEngine
  zipCode: '10001',
  numberOfPets: 1,
  state: 'NY',
);

// Returns List<Plan> with 3 options: Basic, Plus, Elite
print('Monthly premiums:');
for (final plan in plans) {
  print('${plan.name}: \$${plan.monthlyPremium.toStringAsFixed(2)}');
}
```

### 2. Display Plans with PlanCards Widget

```dart
import 'package:pet_underwriter_ai/widgets/plan_cards.dart';

class QuoteScreen extends StatefulWidget {
  @override
  State<QuoteScreen> createState() => _QuoteScreenState();
}

class _QuoteScreenState extends State<QuoteScreen> {
  Plan? selectedPlan;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PlanCards(
        plans: myPlans,
        selectedPlan: selectedPlan,
        showComparison: true,  // Show example claim scenarios
        onSelectPlan: (plan) {
          setState(() => selectedPlan = plan);
          // Navigate to checkout
        },
      ),
    );
  }
}
```

### 3. Calculate Coverage for Claims

```dart
// Estimate out-of-pocket cost for a $5,000 surgery
final outOfPocket = engine.calculateOutOfPocket(
  plan: plusPlan,
  claimAmount: 5000.0,
);

print('You pay: \$${outOfPocket.toStringAsFixed(2)}');

// Calculate how much insurance covers
final coverage = engine.calculateCoverageAmount(
  plan: plusPlan,
  claimAmount: 5000.0,
);

print('We cover: \$${coverage.toStringAsFixed(2)}');
```

---

## Plan Tiers Comparison

| Feature | Basic | Plus | Elite |
|---------|-------|------|-------|
| **Monthly Premium** | 85% of base | 115% of base | 150% of base |
| **Annual Deductible** | $500 | $250 | $100 |
| **Co-pay** | 20% | 10% | 0% (100% coverage) |
| **Max Annual Coverage** | $10,000 | $15,000 | $25,000 |
| **Wellness Care** | ❌ | ✅ ($250/year) | ✅ ($500/year) |
| **Dental** | ❌ | ✅ Disease only | ✅ Full coverage |
| **Alternative Therapy** | ❌ | ✅ | ✅ |
| **End of Life Care** | ❌ | ❌ | ✅ |

### Basic Plan

**Best for:** Budget-conscious owners with young, healthy pets

**Includes:**
- Accidents & Illnesses
- Emergency Care
- Hospitalization
- Surgery
- Prescription Medications
- 24/7 Vet Helpline

**Excludes:**
- Pre-existing conditions
- Wellness care
- Dental cleaning
- Breeding costs

### Plus Plan (Most Popular)

**Best for:** Comprehensive coverage with wellness benefits

**Includes:**
- Everything in Basic
- Wellness Care (up to $250/year)
- Dental Accidents & Disease
- Alternative Therapies
- Behavioral Therapy
- Hereditary Conditions
- Chronic Conditions
- Cancer Coverage

**Excludes:**
- Pre-existing conditions
- Cosmetic procedures
- Breeding costs

### Elite Plan

**Best for:** Maximum protection with premium benefits

**Includes:**
- Everything in Plus
- Enhanced Wellness Care (up to $500/year)
- Dental Cleaning & Preventive
- Exam Fees Covered
- Unlimited Vet Visits
- Specialty & Emergency Care
- Physical Therapy
- End of Life Care
- Cremation/Burial (up to $1,000)
- Travel Protection
- Lost Pet Recovery

**Excludes:**
- Pre-existing conditions (partial coverage after 1 year)
- Breeding/Pregnancy

---

## Regional Pricing Adjustments

The engine applies location-based multipliers to account for regional cost differences:

```dart
static const Map<String, double> _regionalAdjustments = {
  'NY': 1.10,  // +10% for New York
  'CA': 1.08,  // +8% for California
  'MA': 1.09,  // +9% for Massachusetts
  'WA': 1.07,  // +7% for Washington
  'IL': 1.06,  // +6% for Illinois
  'TX': 1.02,  // +2% for Texas
  'FL': 1.03,  // +3% for Florida
  'DEFAULT': 1.0,  // No adjustment for other states
};
```

**High-Cost ZIP Codes:**
- NYC (10001-10299): Automatically applies NY multiplier
- Add more patterns as needed using `_isHighCostZipCode()`

---

## Multi-Pet Discounts

Encourage customers to insure all their pets:

| Number of Pets | Discount | Savings on $50/mo |
|----------------|----------|-------------------|
| 1 pet | 0% | $0 |
| 2 pets | 5% | $2.50/mo |
| 3 pets | 10% | $5.00/mo |
| 4+ pets | 15% | $7.50/mo |

```dart
// Generate quote for 3 pets
final plans = engine.generateQuote(
  riskScore: myRiskScore,
  zipCode: '10001',
  numberOfPets: 3,  // 10% discount applied
  state: 'NY',
);

// Check discount on each plan
for (final plan in plans) {
  print('Discount: \$${plan.discountAmount.toStringAsFixed(2)}/mo');
}
```

---

## Complete Examples

### Example 1: Low-Risk Pet in Texas

```dart
// Young, healthy Labrador in Austin, TX
final lowRiskScore = RiskScore(
  id: 'risk_1',
  petId: 'pet_1',
  overallScore: 25,
  riskLevel: RiskLevel.low,
  categoryScores: {'age': 20, 'breed': 30},
  riskFactors: ['Young and healthy'],
  recommendations: ['Regular checkups'],
  createdAt: DateTime.now(),
);

final engine = QuoteEngine();
final plans = engine.generateQuote(
  riskScore: lowRiskScore,
  zipCode: '78701',
  numberOfPets: 1,
  state: 'TX',  // +2% regional adjustment
);

// Expected monthly premiums:
// Basic: ~$30 (85% × $35 × 1.375 × 1.02)
// Plus: ~$41 (115% × $35 × 1.375 × 1.02)
// Elite: ~$53 (150% × $35 × 1.375 × 1.02)
```

### Example 2: High-Risk Pet in NYC (Multi-Pet Discount)

```dart
// Senior Bulldog with health issues in Manhattan
final highRiskScore = RiskScore(
  id: 'risk_2',
  petId: 'pet_2',
  overallScore: 85,
  riskLevel: RiskLevel.high,
  categoryScores: {'age': 90, 'breed': 85, 'medical_history': 90},
  riskFactors: ['Senior', 'Breed predisposition', 'Chronic conditions'],
  recommendations: ['Frequent monitoring', 'Specialist care'],
  createdAt: DateTime.now(),
);

final plans = engine.generateQuote(
  riskScore: highRiskScore,
  zipCode: '10001',  // NYC
  numberOfPets: 2,  // 5% multi-pet discount
  state: 'NY',  // +10% regional adjustment
);

// Expected monthly premiums (after 5% discount):
// Basic: ~$51 (85% × $35 × 2.275 × 1.10 × 0.95)
// Plus: ~$69 (115% × $35 × 2.275 × 1.10 × 0.95)
// Elite: ~$90 (150% × $35 × 2.275 × 1.10 × 0.95)
```

### Example 3: Calculate Out-of-Pocket Costs

```dart
final engine = QuoteEngine();
final plusPlan = plans[1];  // Plus plan

// Scenario 1: Minor illness ($500)
final minor = engine.calculateOutOfPocket(
  plan: plusPlan,
  claimAmount: 500.0,
);
// Result: $250 deductible + $25 co-pay (10%) = $275

// Scenario 2: Major surgery ($5,000)
final major = engine.calculateOutOfPocket(
  plan: plusPlan,
  claimAmount: 5000.0,
);
// Result: $250 deductible + $475 co-pay (10% of $4,750) = $725

// Scenario 3: Emergency ($10,000)
final emergency = engine.calculateOutOfPocket(
  plan: plusPlan,
  claimAmount: 10000.0,
);
// Result: $250 deductible + $975 co-pay (10% of $9,750) = $1,225
```

### Example 4: Compare Plans with PlanComparison

```dart
final engine = QuoteEngine();
final comparison = engine.comparePlans(plans);

// Get coverage breakdown for a $5,000 claim
final breakdown = comparison.getCoverageBreakdown(
  ClaimScenario(
    description: 'ACL Surgery',
    claimAmount: 5000.0,
  ),
);

for (final entry in breakdown.entries) {
  final plan = entry.key;
  final data = entry.value;
  
  print('${plan.name}:');
  print('  Out of Pocket: \$${data['outOfPocket']}');
  print('  Coverage: \$${data['coverage']}');
  print('  Coverage %: ${(data['coverage']! / data['claimAmount']! * 100).toStringAsFixed(1)}%');
}
```

---

## PlanCards Widget Features

The `PlanCards` widget provides a beautiful, responsive UI for displaying insurance plans:

### Features

✅ **Responsive Layout** - Single column on mobile, side-by-side on desktop  
✅ **Interactive Cards** - Hover effects and animations  
✅ **Gradient Design** - Premium look for Plus/Elite plans  
✅ **Feature Lists** - Expandable features with "Show More" button  
✅ **Comparison Mode** - Toggle to show example claim scenarios  
✅ **Selection State** - Highlight selected plan  
✅ **Discount Badges** - Show multi-pet savings prominently

### Customization

```dart
PlanCards(
  plans: myPlans,
  selectedPlan: selectedPlan,
  showComparison: true,  // Show claim examples
  onSelectPlan: (plan) {
    // Handle plan selection
    setState(() => selectedPlan = plan);
    navigateToCheckout(plan);
  },
)
```

### Modal Features Sheet

Users can tap "Show More" to view all features and exclusions in a draggable bottom sheet:

- ✅ All included features with checkmarks
- ❌ All exclusions clearly marked
- Scrollable content for long lists
- Clean, organized presentation

---

## Integration with RiskScoringEngine

The `QuoteEngine` works seamlessly with the `RiskScoringEngine`:

```dart
import 'package:pet_underwriter_ai/services/risk_scoring_engine.dart';
import 'package:pet_underwriter_ai/services/quote_engine.dart';

// Step 1: Calculate risk score
final riskEngine = RiskScoringEngine();
final riskScore = await riskEngine.calculateRiskScore(
  pet: myPet,
  owner: myOwner,
  vetRecordData: myVetHistory,
);

// Step 2: Generate quotes using risk score
final quoteEngine = QuoteEngine();
final plans = quoteEngine.generateQuote(
  riskScore: riskScore,
  zipCode: myOwner.address.zipCode,
  numberOfPets: myOwner.numberOfPets,
  state: myOwner.address.state,
);

// Step 3: Display plans
return PlanCards(
  plans: plans,
  onSelectPlan: (plan) => checkout(plan),
);
```

---

## Best Practices

### 1. Always Use Real Risk Scores

```dart
// ❌ Don't create mock risk scores in production
final mockScore = RiskScore(overallScore: 50, ...);

// ✅ Always calculate from actual pet data
final realScore = await riskEngine.calculateRiskScore(
  pet: pet,
  owner: owner,
  vetRecordData: vetHistory,
);
```

### 2. Cache Generated Quotes

```dart
// Store quotes in Firestore for audit trail
await FirebaseFirestore.instance
  .collection('quotes')
  .doc(quoteId)
  .set({
    'plans': plans.map((p) => p.toJson()).toList(),
    'riskScore': riskScore.toJson(),
    'zipCode': zipCode,
    'numberOfPets': numberOfPets,
    'createdAt': FieldValue.serverTimestamp(),
  });
```

### 3. Show Comparison Mode

```dart
// Always enable comparison mode for better transparency
PlanCards(
  plans: plans,
  showComparison: true,  // Helps users understand value
  onSelectPlan: onSelect,
)
```

### 4. Handle State Changes Properly

```dart
// Update quotes when parameters change
void _updateQuotes() {
  final newPlans = engine.generateQuote(
    riskScore: riskScore,
    zipCode: zipCode,
    numberOfPets: numberOfPets,
    state: state,
  );
  
  setState(() {
    plans = newPlans;
    selectedPlan = null;  // Reset selection
  });
}
```

---

## API Reference

### QuoteEngine Methods

#### `generateQuote()`
```dart
List<Plan> generateQuote({
  required RiskScore riskScore,
  required String zipCode,
  int numberOfPets = 1,
  String? state,
})
```
Generates 3 plan options (Basic, Plus, Elite) with calculated premiums.

#### `calculateOutOfPocket()`
```dart
double calculateOutOfPocket({
  required Plan plan,
  required double claimAmount,
})
```
Calculates total out-of-pocket cost (deductible + co-pay) for a claim.

#### `calculateCoverageAmount()`
```dart
double calculateCoverageAmount({
  required Plan plan,
  required double claimAmount,
})
```
Calculates how much insurance covers for a claim (capped at max annual coverage).

#### `calculateAnnualCost()`
```dart
double calculateAnnualCost(Plan plan)
```
Returns annual premium (monthly × 12).

#### `comparePlans()`
```dart
PlanComparison comparePlans(List<Plan> plans)
```
Creates a comparison object with predefined claim scenarios.

### Plan Properties

```dart
class Plan {
  final PlanType type;              // basic, plus, elite
  final String name;                // "Basic Coverage"
  final String description;         // Plan description
  final double monthlyPremium;      // Monthly cost
  final double annualDeductible;    // Annual deductible
  final double coPayPercentage;     // Co-pay % (0-100)
  final double maxAnnualCoverage;   // Max coverage per year
  final double? maxLifetimeCoverage; // Lifetime limit (null = unlimited)
  final int numberOfPets;           // Number of pets insured
  final double multiPetDiscount;    // Discount applied (0.0-1.0)
  final List<String> features;      // Included features
  final List<String> exclusions;    // Exclusions
  
  // Computed properties
  double get annualPremium;         // Monthly × 12
  double get discountAmount;        // Dollar amount saved
  String get coveragePercentage;    // "80%", "90%", "100%"
}
```

---

## Testing

See `examples/quote_engine_example.dart` for a complete interactive demo with:
- Risk scenario selector (Low, Medium, High)
- Multi-pet discount slider
- Location selector
- Live quote generation
- Plan comparison table
- Coverage breakdown for common scenarios

Run the example:
```bash
flutter run examples/quote_engine_example.dart
```

---

## Performance Considerations

- Quote generation is **synchronous** and very fast (~1ms)
- No external API calls required
- Plan objects are lightweight (~2KB each)
- PlanCards widget efficiently renders with `LayoutBuilder`
- Hover animations use `AnimatedContainer` for smooth transitions

---

## Future Enhancements

Potential improvements for future versions:

1. **Dynamic Regional Data** - Fetch real-time cost-of-living data by ZIP code
2. **Seasonal Pricing** - Adjust premiums based on time of year
3. **Breed-Specific Plans** - Custom plans for high-risk breeds
4. **Family Plans** - Special pricing for insuring multiple family members' pets
5. **Payment Plans** - Option for quarterly/annual payment with discounts
6. **Price Lock Guarantee** - Guaranteed rates for X years
7. **Loyalty Discounts** - Reduce premiums for long-term customers
8. **Referral Bonuses** - Discounts for referring other customers

---

## Support

For questions or issues with the QuoteEngine:

1. Check the [Quick Start](#quick-start) section
2. Review [Complete Examples](#complete-examples)
3. Run the interactive demo: `flutter run examples/quote_engine_example.dart`
4. See also: `RISK_SCORING_USAGE.md` for risk assessment integration

**Related Documentation:**
- `lib/services/risk_scoring_engine.dart` - Risk assessment
- `lib/services/vet_history_parser.dart` - Medical history parsing
- `lib/widgets/plan_cards.dart` - UI component source code

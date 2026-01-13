import 'package:pet_underwriter_ai/models/risk_score.dart';
import 'package:pet_underwriter_ai/services/quote_engine.dart';
import 'package:pet_underwriter_ai/services/product_catalog.dart';

String formatUsd(double value) => '\$${value.toStringAsFixed(2)}';

RiskScore riskScoreFor(RiskLevel level) {
  return RiskScore(
    id: 'risk-${level.name}',
    petId: 'pet-1',
    calculatedAt: DateTime.utc(2025, 1, 1),
    overallScore: 50,
    riskLevel: level,
    categoryScores: const {},
    riskFactors: const [],
  );
}

void main() {
  final engine = QuoteEngine();

  const states = <({String code, String zip})>[
    (code: 'PA', zip: '19104'),
    (code: 'CA', zip: '94105'),
    (code: 'NY', zip: '10001'),
  ];

  const riskBands = <RiskLevel>[
    RiskLevel.low,
    RiskLevel.medium,
    RiskLevel.high,
  ];

  const ageYears = 3;

  final rows = <List<String>>[];
  rows.add([
    'State',
    'Risk',
    'Basic',
    'Standard',
    'Plus',
    'Premium',
    'Unlimited',
  ]);

  for (final st in states) {
    for (final risk in riskBands) {
      final basePlans = engine.generateQuote(
        riskScore: riskScoreFor(risk),
        zipCode: st.zip,
        state: st.code,
        numberOfPets: 1,
        ageYears: ageYears,
      );

      final basePlan = basePlans.first;
      final basePremium = basePlan.pricingBasePremium;
      final discount = basePlan.multiPetDiscount;
      final regionalMultiplier = basePlan.pricingBreakdown?.regionalMultiplier ?? 1.0;
      final regionalKey = basePlan.pricingBreakdown?.regionalKey ?? 'DEFAULT';

      const dayOneSkus = <({PlanType tier, int reimb, int ded, int? limit})>[
        (tier: PlanType.basic, reimb: 70, ded: 500, limit: 10000),
        (tier: PlanType.standard, reimb: 80, ded: 250, limit: 10000),
        (tier: PlanType.plus, reimb: 80, ded: 250, limit: 20000),
        (tier: PlanType.premium, reimb: 90, ded: 250, limit: 20000),
        (tier: PlanType.unlimited, reimb: 80, ded: 250, limit: null),
      ];

      String premiumFor(PlanType tier) {
        final sku = dayOneSkus.firstWhere((s) => s.tier == tier);
        if (!ProductCatalog.isCoverageAllowed(
          riskBand: risk,
          ageYears: ageYears,
          reimbursementPercent: sku.reimb,
          annualDeductible: sku.ded,
          annualLimit: sku.limit,
        )) {
          return '—';
        }

        final plan = engine.buildPlan(
          tier: tier,
          basePremium: basePremium,
          riskBand: risk,
          numberOfPets: 1,
          discount: discount,
          regionalMultiplier: regionalMultiplier,
          regionalKey: regionalKey,
          ageYears: ageYears,
          reimbursementPercent: sku.reimb,
          annualDeductible: sku.ded,
          annualLimit: sku.limit,
          addOns: const [],
        );
        return formatUsd(plan.monthlyPremium);
      }

      rows.add([
        st.code,
        risk.name,
        premiumFor(PlanType.basic),
        premiumFor(PlanType.standard),
        premiumFor(PlanType.plus),
        premiumFor(PlanType.premium),
        premiumFor(PlanType.unlimited),
      ]);
    }
  }

  // Print markdown table
  final header = rows.first;
  final sep = List.filled(header.length, '---');

  String mdRow(List<String> cols) => '| ${cols.join(' | ')} |';

  print(mdRow(header));
  print(mdRow(sep));
  for (final r in rows.skip(1)) {
    print(mdRow(r));
  }
}

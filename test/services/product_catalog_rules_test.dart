import 'package:flutter_test/flutter_test.dart';

import 'package:pet_underwriter_ai/models/risk_score.dart';
import 'package:pet_underwriter_ai/services/quote_engine.dart';
import 'package:pet_underwriter_ai/services/product_catalog.dart';

void main() {
  group('ProductCatalog availability matrix', () {
    test('Unlimited is only offered for low/medium risk and age <= 7', () {
      expect(
        ProductCatalog.annualLimitOptionsFor(riskBand: RiskLevel.low, ageYears: 7),
        contains(null),
      );
      expect(
        ProductCatalog.annualLimitOptionsFor(riskBand: RiskLevel.medium, ageYears: 7),
        contains(null),
      );

      expect(
        ProductCatalog.annualLimitOptionsFor(riskBand: RiskLevel.low, ageYears: 8),
        isNot(contains(null)),
      );
      expect(
        ProductCatalog.annualLimitOptionsFor(riskBand: RiskLevel.high, ageYears: 3),
        isNot(contains(null)),
      );
      expect(
        ProductCatalog.annualLimitOptionsFor(riskBand: RiskLevel.veryHigh, ageYears: 3),
        isNot(contains(null)),
      );

      // Conservative behavior when age is unknown.
      expect(
        ProductCatalog.annualLimitOptionsFor(riskBand: RiskLevel.low, ageYears: null),
        isNot(contains(null)),
      );
    });

    test('Max reimbursement by risk band', () {
      expect(ProductCatalog.reimbursementOptionsFor(riskBand: RiskLevel.veryHigh), [70]);
      expect(ProductCatalog.reimbursementOptionsFor(riskBand: RiskLevel.high), [70, 80]);
      expect(ProductCatalog.reimbursementOptionsFor(riskBand: RiskLevel.medium), [70, 80, 90]);
      expect(ProductCatalog.reimbursementOptionsFor(riskBand: RiskLevel.low), [70, 80, 90]);
    });

    test('Min deductible by risk band', () {
      expect(ProductCatalog.annualDeductibleOptionsFor(riskBand: RiskLevel.veryHigh).first, 500);
      expect(ProductCatalog.annualDeductibleOptionsFor(riskBand: RiskLevel.high).first, 250);
      expect(ProductCatalog.annualDeductibleOptionsFor(riskBand: RiskLevel.medium).first, 100);
      expect(ProductCatalog.annualDeductibleOptionsFor(riskBand: RiskLevel.low).first, 100);
    });

    test('Finite annual limits by risk band', () {
      expect(ProductCatalog.finiteAnnualLimitOptionsFor(RiskLevel.veryHigh), [5000, 10000]);
      expect(ProductCatalog.finiteAnnualLimitOptionsFor(RiskLevel.high), [5000, 10000, 15000]);
      expect(ProductCatalog.finiteAnnualLimitOptionsFor(RiskLevel.medium), [5000, 10000, 15000, 20000]);
      expect(ProductCatalog.finiteAnnualLimitOptionsFor(RiskLevel.low), [5000, 10000, 15000, 20000]);
    });
  });

  group('QuoteEngine lever coercion', () {
    test('Invalid coverage levers are coerced to allowed values', () {
      final engine = QuoteEngine();

      final plan = engine.buildPlan(
        tier: PlanType.basic,
        basePremium: 50.0,
        riskBand: RiskLevel.veryHigh,
        numberOfPets: 1,
        discount: 0.0,
        regionalMultiplier: 1.0,
        regionalKey: 'DEFAULT',
        ageYears: 10,
        reimbursementPercent: 90, // not allowed for veryHigh
        annualDeductible: 100, // not allowed for veryHigh
        annualLimit: null, // not allowed for veryHigh
        addOns: const [],
      );

      // veryHigh allows only 70% reimbursement.
      expect(plan.reimbursementPercent, 70);

      // veryHigh min deductible is 500.
      expect(plan.annualDeductible.toInt(), 500);

      // veryHigh allows finite limits [5k, 10k] and no Unlimited.
      expect(plan.isUnlimitedAnnualCoverage, isFalse);
      expect(plan.maxAnnualCoverage.toInt(), 10000);

      final breakdown = plan.pricingBreakdown;
      expect(breakdown, isNotNull);
      expect(breakdown!.wasCoerced, isTrue);
      expect(breakdown.coercionReasons, isNotEmpty);
      expect(breakdown.requestedReimbursementPercent, 90);
      expect(breakdown.requestedAnnualDeductible, 100);
      expect(breakdown.requestedAnnualLimit, isNull);
      expect(breakdown.reimbursementPercent, 70);
      expect(breakdown.annualDeductible, 500);
      expect(breakdown.annualLimit, 10000);
    });
  });
}

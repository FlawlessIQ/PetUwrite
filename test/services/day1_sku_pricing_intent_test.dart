import 'package:flutter_test/flutter_test.dart';

import 'package:pet_underwriter_ai/models/risk_score.dart';
import 'package:pet_underwriter_ai/services/quote_engine.dart';
import 'package:pet_underwriter_ai/services/product_catalog.dart';

void main() {
  group('Day-1 SKU pricing intent (non-fragile)', () {
    test('SKU premiums preserve expected relativities (base-rate independent)', () {
      final engine = QuoteEngine();

      // Use a fixed basePremium so tests don't depend on baseRiskRate.
      const basePremium = 100.0;

      Plan plan(
        PlanType tier, {
        required int reimb,
        required int ded,
        required int? limit,
      }) {
        return engine.buildPlan(
          tier: tier,
          basePremium: basePremium,
          riskBand: RiskLevel.medium,
          numberOfPets: 1,
          discount: 0.0,
          regionalMultiplier: 1.0,
          regionalKey: 'DEFAULT',
          ageYears: 3,
          reimbursementPercent: reimb,
          annualDeductible: ded,
          annualLimit: limit,
          addOns: const [],
        );
      }

      final basic = plan(PlanType.basic, reimb: 70, ded: 500, limit: 10000);
      final standard = plan(PlanType.standard, reimb: 80, ded: 250, limit: 10000);
      final plus = plan(PlanType.plus, reimb: 80, ded: 250, limit: 20000);
      final premium = plan(PlanType.premium, reimb: 90, ded: 250, limit: 20000);
      final unlimited = plan(PlanType.unlimited, reimb: 80, ded: 250, limit: null);

      // Monotonic ordering (commercial intent).
      expect(standard.monthlyPremium, greaterThan(basic.monthlyPremium));
      expect(plus.monthlyPremium, greaterThan(standard.monthlyPremium));
      expect(premium.monthlyPremium, greaterThan(plus.monthlyPremium));
      expect(unlimited.monthlyPremium, greaterThan(premium.monthlyPremium));

      // Ratio bands: tolerate small tuning, fail large drifts.
      double ratio(Plan a, Plan b) => a.monthlyPremium / b.monthlyPremium;

      expect(ratio(standard, basic), inInclusiveRange(1.10, 1.25));
      expect(ratio(plus, standard), inInclusiveRange(1.15, 1.30));
      expect(ratio(premium, plus), inInclusiveRange(1.05, 1.20));
      expect(ratio(unlimited, premium), inInclusiveRange(1.05, 1.25));
    });
  });
}

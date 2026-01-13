import 'package:flutter_test/flutter_test.dart';

import 'package:pet_underwriter_ai/config/pricing_config.dart';
import 'package:pet_underwriter_ai/models/risk_score.dart';
import 'package:pet_underwriter_ai/services/quote_engine.dart';
import 'package:pet_underwriter_ai/services/product_catalog.dart';

void main() {
  group('QuoteEngine pricing (risk bands + breakdown)', () {
    final engine = QuoteEngine();

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

    double pricingBasePremiumFor(RiskLevel level) {
      final plans = engine.generateQuote(
        riskScore: riskScoreFor(level),
        zipCode: '99999',
        state: 'XX',
        numberOfPets: 1,
      );
      return plans.first.pricingBasePremium;
    }

    test('Higher risk band yields >= premium (same levers)', () {
      double premiumFor(RiskLevel level) {
        final base = pricingBasePremiumFor(level);
        const reimbursement = 70;
        final plan = engine.buildPlan(
          tier: PlanType.basic,
          basePremium: base,
          riskBand: level,
          numberOfPets: 1,
          discount: 0.0,
          regionalMultiplier: 1.0,
          regionalKey: 'DEFAULT',
          reimbursementPercent: reimbursement,
          annualDeductible: 500,
          annualLimit: 10000,
          addOns: const [],
        );
        return plan.monthlyPremium;
      }

      final low = premiumFor(RiskLevel.low);
      final medium = premiumFor(RiskLevel.medium);
      final high = premiumFor(RiskLevel.high);
      final veryHigh = premiumFor(RiskLevel.veryHigh);

      expect(medium, greaterThanOrEqualTo(low));
      expect(high, greaterThanOrEqualTo(medium));
      expect(veryHigh, greaterThanOrEqualTo(high));
    });

    test('Higher reimbursement increases premium (same risk/levers)', () {
      final base = pricingBasePremiumFor(RiskLevel.medium);
      final p70 = engine.buildPlan(
        tier: PlanType.basic,
        basePremium: base,
        riskBand: RiskLevel.medium,
        numberOfPets: 1,
        discount: 0.0,
        regionalMultiplier: 1.0,
        regionalKey: 'DEFAULT',
        reimbursementPercent: 70,
        annualDeductible: 500,
        annualLimit: 10000,
        addOns: const [],
      );
      final p80 = engine.buildPlan(
        tier: PlanType.basic,
        basePremium: base,
        riskBand: RiskLevel.medium,
        numberOfPets: 1,
        discount: 0.0,
        regionalMultiplier: 1.0,
        regionalKey: 'DEFAULT',
        reimbursementPercent: 80,
        annualDeductible: 500,
        annualLimit: 10000,
        addOns: const [],
      );
      final p90 = engine.buildPlan(
        tier: PlanType.basic,
        basePremium: base,
        riskBand: RiskLevel.medium,
        numberOfPets: 1,
        discount: 0.0,
        regionalMultiplier: 1.0,
        regionalKey: 'DEFAULT',
        reimbursementPercent: 90,
        annualDeductible: 500,
        annualLimit: 10000,
        addOns: const [],
      );

      expect(p80.monthlyPremium, greaterThanOrEqualTo(p70.monthlyPremium));
      expect(p90.monthlyPremium, greaterThanOrEqualTo(p80.monthlyPremium));
    });

    test('Lower deductible increases premium (same risk/levers)', () {
      final base = pricingBasePremiumFor(RiskLevel.medium);
      final d1000 = engine.buildPlan(
        tier: PlanType.basic,
        basePremium: base,
        riskBand: RiskLevel.medium,
        numberOfPets: 1,
        discount: 0.0,
        regionalMultiplier: 1.0,
        regionalKey: 'DEFAULT',
        reimbursementPercent: 80,
        annualDeductible: 1000,
        annualLimit: 10000,
        addOns: const [],
      );
      final d500 = engine.buildPlan(
        tier: PlanType.basic,
        basePremium: base,
        riskBand: RiskLevel.medium,
        numberOfPets: 1,
        discount: 0.0,
        regionalMultiplier: 1.0,
        regionalKey: 'DEFAULT',
        reimbursementPercent: 80,
        annualDeductible: 500,
        annualLimit: 10000,
        addOns: const [],
      );
      final d250 = engine.buildPlan(
        tier: PlanType.basic,
        basePremium: base,
        riskBand: RiskLevel.medium,
        numberOfPets: 1,
        discount: 0.0,
        regionalMultiplier: 1.0,
        regionalKey: 'DEFAULT',
        reimbursementPercent: 80,
        annualDeductible: 250,
        annualLimit: 10000,
        addOns: const [],
      );

      expect(d500.monthlyPremium, greaterThanOrEqualTo(d1000.monthlyPremium));
      expect(d250.monthlyPremium, greaterThanOrEqualTo(d500.monthlyPremium));
    });

    test('Unlimited annual limit is higher than finite limits', () {
      final base = pricingBasePremiumFor(RiskLevel.medium);
      final finite = engine.buildPlan(
        tier: PlanType.basic,
        basePremium: base,
        riskBand: RiskLevel.medium,
        numberOfPets: 1,
        discount: 0.0,
        regionalMultiplier: 1.0,
        regionalKey: 'DEFAULT',
        ageYears: 3,
        reimbursementPercent: 80,
        annualDeductible: 500,
        annualLimit: 20000,
        addOns: const [],
      );
      final unlimited = engine.buildPlan(
        tier: PlanType.basic,
        basePremium: base,
        riskBand: RiskLevel.medium,
        numberOfPets: 1,
        discount: 0.0,
        regionalMultiplier: 1.0,
        regionalKey: 'DEFAULT',
        ageYears: 3,
        reimbursementPercent: 80,
        annualDeductible: 500,
        annualLimit: null,
        addOns: const [],
      );

      expect(unlimited.monthlyPremium, greaterThan(finite.monthlyPremium));
    });

    test('PricingBreakdown matches final premium', () {
      final base = pricingBasePremiumFor(RiskLevel.high);
      final plan = engine.buildPlan(
        tier: PlanType.plus,
        basePremium: base,
        riskBand: RiskLevel.high,
        numberOfPets: 1,
        discount: 0.0,
        regionalMultiplier: 1.0,
        regionalKey: 'DEFAULT',
        reimbursementPercent: 80,
        annualDeductible: 500,
        annualLimit: 15000,
        addOns: const [AddOnType.examFees, AddOnType.rehab],
      );

      final breakdown = plan.pricingBreakdown;
      expect(breakdown, isNotNull);
      expect(plan.monthlyPremium, breakdown!.finalMonthlyPremium);
      expect(breakdown.pricingVersion, PricingConfig.version);
    });
  });
}

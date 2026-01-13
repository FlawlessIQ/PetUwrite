import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:pet_underwriter_ai/models/risk_score.dart';
import 'package:pet_underwriter_ai/services/quote_engine.dart';
import 'package:pet_underwriter_ai/services/product_catalog.dart';

class _PetProfile {
  final String species; // "dog" | "cat" (for reporting)
  final int ageYears;
  final RiskLevel riskBand;
  final double overallScore;
  final String label;

  const _PetProfile({
    required this.species,
    required this.ageYears,
    required this.riskBand,
    required this.overallScore,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
        'species': species,
        'ageYears': ageYears,
        'riskBand': riskBand.name,
        'overallScore': overallScore,
        'label': label,
      };
}

class _StateScenario {
  final String state;
  final String zip;
  final String label;

  const _StateScenario({
    required this.state,
    required this.zip,
    required this.label,
  });

  Map<String, dynamic> toJson() => {
        'state': state,
        'zip': zip,
        'label': label,
      };
}

class _CoverageLevers {
  final int reimbursementPercent;
  final int annualDeductible;
  final int? annualLimit;

  const _CoverageLevers({
    required this.reimbursementPercent,
    required this.annualDeductible,
    required this.annualLimit,
  });

  Map<String, dynamic> toJson() => {
        'reimbursementPercent': reimbursementPercent,
        'annualDeductible': annualDeductible,
        'annualLimit': annualLimit,
      };
}

RiskScore _riskScoreFor(_PetProfile profile) {
  return RiskScore(
    id: 'validation-${profile.label}',
    petId: 'pet-${profile.label}',
    calculatedAt: DateTime.utc(2025, 1, 1),
    overallScore: profile.overallScore,
    riskLevel: profile.riskBand,
    categoryScores: const {},
    riskFactors: const [],
  );
}

List<AddOnType> _parseAddOnsFromPlan(Plan plan) {
  return plan.selectedAddOns
      .map(
        (s) => AddOnType.values.firstWhere(
          (e) => e.name == s || e.toString() == s,
          orElse: () => AddOnType.examFees,
        ),
      )
      .toList();
}

int? _annualLimitFromPlan(Plan plan) {
  if (plan.isUnlimitedAnnualCoverage || plan.maxAnnualCoverage.isInfinite) return null;
  return plan.maxAnnualCoverage.toInt();
}

Map<String, dynamic> _computeSummary(List<double> premiums) {
  if (premiums.isEmpty) {
    return {
      'count': 0,
      'min': null,
      'max': null,
      'median': null,
    };
  }

  final sorted = [...premiums]..sort();
  final min = sorted.first;
  final max = sorted.last;

  final mid = sorted.length ~/ 2;
  final median = sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2.0;

  return {
    'count': sorted.length,
    'min': min,
    'max': max,
    'median': median,
  };
}

void main() {
  group('Pricing validation snapshot (deterministic, no network)', () {
    test('Generates snapshot JSON and passes sanity checks', () {
      final engine = QuoteEngine();

      const profiles = <_PetProfile>[
        _PetProfile(
          species: 'dog',
          ageYears: 1,
          riskBand: RiskLevel.low,
          overallScore: 10,
          label: 'dog_age1_low',
        ),
        _PetProfile(
          species: 'dog',
          ageYears: 3,
          riskBand: RiskLevel.medium,
          overallScore: 45,
          label: 'dog_age3_medium',
        ),
        _PetProfile(
          species: 'dog',
          ageYears: 7,
          riskBand: RiskLevel.high,
          overallScore: 70,
          label: 'dog_age7_high',
        ),
        _PetProfile(
          species: 'dog',
          ageYears: 10,
          riskBand: RiskLevel.veryHigh,
          overallScore: 90,
          label: 'dog_age10_veryHigh',
        ),
        _PetProfile(
          species: 'cat',
          ageYears: 3,
          riskBand: RiskLevel.medium,
          overallScore: 45,
          label: 'cat_age3_medium',
        ),
      ];

      const states = <_StateScenario>[
        _StateScenario(state: 'PA', zip: '19104', label: 'average_cost'),
        _StateScenario(state: 'CA', zip: '94107', label: 'ca'),
        _StateScenario(state: 'NY', zip: '10001', label: 'ny'),
      ];

      const coverages = <_CoverageLevers>[
        // Seed set; the generator below will filter to only allowed combos.
        _CoverageLevers(reimbursementPercent: 70, annualDeductible: 1000, annualLimit: 5000),
        _CoverageLevers(reimbursementPercent: 80, annualDeductible: 250, annualLimit: 10000),
        _CoverageLevers(reimbursementPercent: 90, annualDeductible: 100, annualLimit: 20000),
        _CoverageLevers(reimbursementPercent: 80, annualDeductible: 250, annualLimit: null),
      ];

      const addOnCombos = <List<AddOnType>>[
        [],
        [AddOnType.examFees],
        [AddOnType.examFees, AddOnType.dentalPlus],
      ];

      final entries = <Map<String, dynamic>>[];
      final premiums = <double>[];

      for (final profile in profiles) {
        for (final stateScenario in states) {
          final basePlans = engine.generateQuote(
            riskScore: _riskScoreFor(profile),
            zipCode: stateScenario.zip,
            state: stateScenario.state,
            numberOfPets: 1,
            ageYears: profile.ageYears,
          );

          final basePlan = basePlans.firstWhere(
            (p) => p.type == PlanType.basic,
            orElse: () => basePlans.first,
          );
          final basePremium = basePlan.pricingBasePremium;
          final discount = basePlan.multiPetDiscount;
          final regionalMultiplier = basePlan.pricingBreakdown?.regionalMultiplier ?? 1.0;
          final regionalKey = basePlan.pricingBreakdown?.regionalKey ?? 'DEFAULT';

          for (final coverage in coverages) {
            for (final addOns in addOnCombos) {
              if (!ProductCatalog.isCoverageAllowed(
                riskBand: profile.riskBand,
                ageYears: profile.ageYears,
                reimbursementPercent: coverage.reimbursementPercent,
                annualDeductible: coverage.annualDeductible,
                annualLimit: coverage.annualLimit,
              )) {
                continue;
              }

              final plan = engine.buildPlan(
                tier: PlanType.basic,
                basePremium: basePremium,
                riskBand: profile.riskBand,
                numberOfPets: 1,
                discount: discount,
                regionalMultiplier: regionalMultiplier,
                regionalKey: regionalKey,
                ageYears: profile.ageYears,
                reimbursementPercent: coverage.reimbursementPercent,
                annualDeductible: coverage.annualDeductible,
                annualLimit: coverage.annualLimit,
                addOns: addOns,
              );

              final breakdown = plan.pricingBreakdown;
              expect(breakdown, isNotNull, reason: 'PricingBreakdown must be present for snapshotting');

              final entry = {
                'petProfile': profile.toJson(),
                'state': stateScenario.toJson(),
                'riskBand': plan.riskBand.name,
                'coverageLevers': coverage.toJson(),
                'addOns': addOns.map((e) => e.name).toList(),
                'pricingVersion': breakdown!.pricingVersion,
                'pricingBreakdown': breakdown.toJson(),
                'finalMonthlyPremium': plan.monthlyPremium,
              };

              entries.add(entry);
              premiums.add(plan.monthlyPremium);
            }
          }

          // Invariant: rebuilding a generated plan should preserve premium.
          // This catches double-counting risk/region/discount or missing factors.
          final rebuilt = engine.buildPlan(
            tier: basePlan.type,
            basePremium: basePlan.pricingBasePremium,
            riskBand: basePlan.riskBand,
            numberOfPets: basePlan.numberOfPets,
            discount: basePlan.multiPetDiscount,
            regionalMultiplier: basePlan.pricingBreakdown?.regionalMultiplier ?? 1.0,
            regionalKey: basePlan.pricingBreakdown?.regionalKey ?? 'DEFAULT',
            ageYears: profile.ageYears,
            reimbursementPercent: basePlan.reimbursementPercent,
            annualDeductible: basePlan.annualDeductible.toInt(),
            annualLimit: _annualLimitFromPlan(basePlan),
            addOns: _parseAddOnsFromPlan(basePlan),
          );

          expect(
            (rebuilt.monthlyPremium - basePlan.monthlyPremium).abs(),
            lessThanOrEqualTo(0.01),
            reason: r'Rebuilding generated Basic plan must match within $0.01',
          );
        }
      }

      // Write snapshot JSON file.
      final snapshotPath = 'pricing/validation/pricing_validation_snapshot.json';
      final snapshotFile = File(snapshotPath)..createSync(recursive: true);

      final summary = _computeSummary(premiums);
      final payload = {
        'generatedAt': DateTime.now().toUtc().toIso8601String(),
        'entryCount': entries.length,
        'summary': summary,
        'entries': entries,
      };

      snapshotFile.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(payload));

      // Console summary (brief): min/max/median.
      // ignore: avoid_print
      print('Pricing snapshot written: $snapshotPath');
      // ignore: avoid_print
      print('Premium summary: count=${summary['count']} min=${summary['min']} max=${summary['max']} median=${summary['median']}');

      // ---- Automated sanity checks (fail loudly) ----

      // Higher reimbursement ⇒ higher premium (all else equal)
      for (final profile in profiles) {
        for (final stateScenario in states) {
          final basePlans = engine.generateQuote(
            riskScore: _riskScoreFor(profile),
            zipCode: stateScenario.zip,
            state: stateScenario.state,
            numberOfPets: 1,
            ageYears: profile.ageYears,
          );
          final base = basePlans.firstWhere(
            (p) => p.type == PlanType.basic,
            orElse: () => basePlans.first,
          );
          final basePremium = base.pricingBasePremium;
          final regionalMultiplier = base.pricingBreakdown?.regionalMultiplier ?? 1.0;
          final regionalKey = base.pricingBreakdown?.regionalKey ?? 'DEFAULT';

          final allowedReimbursements = ProductCatalog.reimbursementOptionsFor(riskBand: profile.riskBand);
          if (allowedReimbursements.length < 2) continue;

          double premiumFor(int reimbursementPercent) {
            final p = engine.buildPlan(
              tier: PlanType.basic,
              basePremium: basePremium,
              riskBand: profile.riskBand,
              numberOfPets: 1,
              discount: base.multiPetDiscount,
              regionalMultiplier: regionalMultiplier,
              regionalKey: regionalKey,
              ageYears: profile.ageYears,
              reimbursementPercent: reimbursementPercent,
              annualDeductible: 500,
              annualLimit: 10000,
              addOns: const [],
            );
            return p.monthlyPremium;
          }

          final sorted = [...allowedReimbursements]..sort();
          for (var i = 1; i < sorted.length; i++) {
            final prev = premiumFor(sorted[i - 1]);
            final next = premiumFor(sorted[i]);
            expect(next, greaterThanOrEqualTo(prev), reason: '${sorted[i]}% reimbursement should not be cheaper than ${sorted[i - 1]}%');
          }
        }
      }

      // Lower deductible ⇒ higher premium
      for (final profile in profiles) {
        for (final stateScenario in states) {
          final basePlans = engine.generateQuote(
            riskScore: _riskScoreFor(profile),
            zipCode: stateScenario.zip,
            state: stateScenario.state,
            numberOfPets: 1,
            ageYears: profile.ageYears,
          );
          final base = basePlans.firstWhere(
            (p) => p.type == PlanType.basic,
            orElse: () => basePlans.first,
          );
          final basePremium = base.pricingBasePremium;
          final regionalMultiplier = base.pricingBreakdown?.regionalMultiplier ?? 1.0;
          final regionalKey = base.pricingBreakdown?.regionalKey ?? 'DEFAULT';

          final allowedDeductibles = ProductCatalog.annualDeductibleOptionsFor(riskBand: profile.riskBand);
          if (allowedDeductibles.length < 2) continue;

          double premiumFor(int deductible) {
            final p = engine.buildPlan(
              tier: PlanType.basic,
              basePremium: basePremium,
              riskBand: profile.riskBand,
              numberOfPets: 1,
              discount: base.multiPetDiscount,
              regionalMultiplier: regionalMultiplier,
              regionalKey: regionalKey,
              ageYears: profile.ageYears,
              reimbursementPercent: 80,
              annualDeductible: deductible,
              annualLimit: 10000,
              addOns: const [],
            );
            return p.monthlyPremium;
          }

          final sorted = [...allowedDeductibles]..sort();
          // Lower deductible means higher premium.
          for (var i = 1; i < sorted.length; i++) {
            final higherDed = premiumFor(sorted[i]);
            final lowerDed = premiumFor(sorted[i - 1]);
            expect(lowerDed, greaterThanOrEqualTo(higherDed), reason: r'Lower deductible should not be cheaper');
          }
        }
      }

      // Unlimited limit > $20k
      for (final profile in profiles) {
        for (final stateScenario in states) {
          if (!ProductCatalog.allowUnlimitedAnnualLimit(riskBand: profile.riskBand, ageYears: profile.ageYears)) {
            continue;
          }

          final basePlans = engine.generateQuote(
            riskScore: _riskScoreFor(profile),
            zipCode: stateScenario.zip,
            state: stateScenario.state,
            numberOfPets: 1,
            ageYears: profile.ageYears,
          );
          final base = basePlans.firstWhere(
            (p) => p.type == PlanType.basic,
            orElse: () => basePlans.first,
          );
          final basePremium = base.pricingBasePremium;
          final regionalMultiplier = base.pricingBreakdown?.regionalMultiplier ?? 1.0;
          final regionalKey = base.pricingBreakdown?.regionalKey ?? 'DEFAULT';

          final finite20k = engine.buildPlan(
            tier: PlanType.basic,
            basePremium: basePremium,
            riskBand: profile.riskBand,
            numberOfPets: 1,
            discount: base.multiPetDiscount,
            regionalMultiplier: regionalMultiplier,
            regionalKey: regionalKey,
            ageYears: profile.ageYears,
            reimbursementPercent: 80,
            annualDeductible: 500,
            annualLimit: 20000,
            addOns: const [],
          );

          final unlimited = engine.buildPlan(
            tier: PlanType.basic,
            basePremium: basePremium,
            riskBand: profile.riskBand,
            numberOfPets: 1,
            discount: base.multiPetDiscount,
            regionalMultiplier: regionalMultiplier,
            regionalKey: regionalKey,
            ageYears: profile.ageYears,
            reimbursementPercent: 80,
            annualDeductible: 500,
            annualLimit: null,
            addOns: const [],
          );

          expect(unlimited.monthlyPremium, greaterThan(finite20k.monthlyPremium), reason: r'Unlimited must exceed $20k');
        }
      }

      // CA ≥ average state ≥ low-cost state
      // Compare CA and NY against DEFAULT, and verify multipliers differ from DEFAULT.
      const def = _StateScenario(state: 'AL', zip: '35005', label: 'default');
      const ca = _StateScenario(state: 'CA', zip: '94107', label: 'ca');
      const ny = _StateScenario(state: 'NY', zip: '10001', label: 'ny');

      for (final profile in profiles) {
        Plan basePlanFor(_StateScenario s) {
          final plans = engine.generateQuote(
            riskScore: _riskScoreFor(profile),
            zipCode: s.zip,
            state: s.state,
            numberOfPets: 1,
            ageYears: profile.ageYears,
          );
          return plans.firstWhere(
            (p) => p.type == PlanType.basic,
            orElse: () => plans.first,
          );
        }

        final defPlan = basePlanFor(def);
        final caPlan = basePlanFor(ca);
        final nyPlan = basePlanFor(ny);

        final defMult = defPlan.pricingBreakdown?.regionalMultiplier ?? 1.0;
        final caMult = caPlan.pricingBreakdown?.regionalMultiplier ?? 1.0;
        final nyMult = nyPlan.pricingBreakdown?.regionalMultiplier ?? 1.0;

        expect(caMult, isNot(equals(defMult)), reason: 'CA multiplier should differ from DEFAULT');
        expect(nyMult, isNot(equals(defMult)), reason: 'NY multiplier should differ from DEFAULT');

        // Use identical levers; compare final premium ordering.
        final defPremium = engine.buildPlan(
          tier: PlanType.basic,
          basePremium: defPlan.pricingBasePremium,
          riskBand: defPlan.riskBand,
          numberOfPets: 1,
          discount: defPlan.multiPetDiscount,
          regionalMultiplier: defMult,
          regionalKey: defPlan.pricingBreakdown?.regionalKey ?? 'DEFAULT',
          reimbursementPercent: 80,
          annualDeductible: 500,
          annualLimit: 10000,
          addOns: const [],
        ).monthlyPremium;

        final caPremium = engine.buildPlan(
          tier: PlanType.basic,
          basePremium: caPlan.pricingBasePremium,
          riskBand: caPlan.riskBand,
          numberOfPets: 1,
          discount: caPlan.multiPetDiscount,
          regionalMultiplier: caMult,
          regionalKey: caPlan.pricingBreakdown?.regionalKey ?? 'DEFAULT',
          reimbursementPercent: 80,
          annualDeductible: 500,
          annualLimit: 10000,
          addOns: const [],
        ).monthlyPremium;

        final nyPremium = engine.buildPlan(
          tier: PlanType.basic,
          basePremium: nyPlan.pricingBasePremium,
          riskBand: nyPlan.riskBand,
          numberOfPets: 1,
          discount: nyPlan.multiPetDiscount,
          regionalMultiplier: nyMult,
          regionalKey: nyPlan.pricingBreakdown?.regionalKey ?? 'DEFAULT',
          reimbursementPercent: 80,
          annualDeductible: 500,
          annualLimit: 10000,
          addOns: const [],
        ).monthlyPremium;

        expect(caPremium, greaterThanOrEqualTo(defPremium), reason: 'CA should not be cheaper than DEFAULT');
        expect(nyPremium, greaterThanOrEqualTo(defPremium), reason: 'NY should not be cheaper than DEFAULT');
      }

      // High risk ≥ medium ≥ low risk (extend to veryHigh)
      for (final stateScenario in states) {
        double premiumForRisk(RiskLevel risk) {
          final profile = _PetProfile(
            species: 'dog',
            ageYears: 3,
            riskBand: risk,
            overallScore: risk == RiskLevel.low
                ? 10
                : risk == RiskLevel.medium
                    ? 45
                    : risk == RiskLevel.high
                        ? 70
                        : 90,
            label: 'risk_${risk.name}',
          );

          final basePlans = engine.generateQuote(
            riskScore: _riskScoreFor(profile),
            zipCode: stateScenario.zip,
            state: stateScenario.state,
            numberOfPets: 1,
            ageYears: profile.ageYears,
          );
          final base = basePlans.firstWhere(
            (p) => p.type == PlanType.basic,
            orElse: () => basePlans.first,
          );
          final basePremium = base.pricingBasePremium;
          final regionalMultiplier = base.pricingBreakdown?.regionalMultiplier ?? 1.0;
          final regionalKey = base.pricingBreakdown?.regionalKey ?? 'DEFAULT';

          return engine.buildPlan(
            tier: PlanType.basic,
            basePremium: basePremium,
            riskBand: risk,
            numberOfPets: 1,
            discount: base.multiPetDiscount,
            regionalMultiplier: regionalMultiplier,
            regionalKey: regionalKey,
            reimbursementPercent: 70,
            annualDeductible: 500,
            annualLimit: 10000,
            addOns: const [],
          ).monthlyPremium;
        }

        final lowP = premiumForRisk(RiskLevel.low);
        final medP = premiumForRisk(RiskLevel.medium);
        final highP = premiumForRisk(RiskLevel.high);
        final veryHighP = premiumForRisk(RiskLevel.veryHigh);

        expect(medP, greaterThanOrEqualTo(lowP), reason: 'Medium risk should not be cheaper than low');
        expect(highP, greaterThanOrEqualTo(medP), reason: 'High risk should not be cheaper than medium');
        expect(veryHighP, greaterThanOrEqualTo(highP), reason: 'Very high risk should not be cheaper than high');
      }
    });
  });
}

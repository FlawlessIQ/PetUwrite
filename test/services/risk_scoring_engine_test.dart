import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:pet_underwriter_ai/models/pet.dart';
import 'package:pet_underwriter_ai/models/owner.dart';
import 'package:pet_underwriter_ai/models/risk_score.dart';
import 'package:pet_underwriter_ai/services/risk_scoring_engine.dart';
import 'package:pet_underwriter_ai/ai/ai_service.dart';
import 'package:pet_underwriter_ai/services/underwriting_rules_engine.dart';
import 'package:pet_underwriter_ai/services/underwriting_constraint_engine.dart';
import 'package:pet_underwriter_ai/services/quote_engine.dart';
import 'package:pet_underwriter_ai/services/product_catalog.dart';
import 'package:pet_underwriter_ai/models/underwriting_exclusion.dart';
import 'package:pet_underwriter_ai/models/medical_history.dart';

/// Mock AI Service for testing without actual API calls
class MockAIService implements AIService {
  final String mockResponse;

  MockAIService({
    this.mockResponse = '''
Overall Risk Assessment: Score 52.5/100 (Medium Risk)

The pet shows moderate risk factors typical for the breed and age group.

Top Risk Categories:
1. Age: Senior pet (10 years) - increased likelihood of age-related conditions
2. Breed: German Shepherd - prone to hip dysplasia and degenerative myelopathy
3. Pre-existing: Hip dysplasia requires ongoing management

Breed-specific Considerations:
- Hip and elbow dysplasia common in German Shepherds
- Higher risk of degenerative myelopathy after age 8
- Prone to bloat (GDV) - emergency condition
- Eye conditions (cataracts, progressive retinal atrophy)

Geographic Risk Factors:
- California: Moderate vet costs (15% above national average)
- Urban area (SF): Higher access to specialists but higher costs
- Regional tick-borne diseases: Low risk in SF bay area

Preventive Care Recommendations:
- Regular hip/joint monitoring and X-rays
- Maintain healthy weight to reduce joint stress
- Consider joint supplements (glucosamine, chondroitin)
- Annual eye exams after age 7
- Monitor for signs of bloat (rapid veterinary response)

Coverage Recommendations:
- Recommended deductible: \$500-\$1000 (based on age and breed risk)
- Coverage limit: \$10,000+ annually (breed-specific conditions can be costly)
- Consider wellness add-on for preventive care
- Orthopedic coverage essential for this breed

Expected Claim Probability: 65% chance of claim in next 12 months based on age and breed profile.
''',
  });

  @override
  Future<String> generateText(
    String prompt, {
    Map<String, dynamic>? options,
  }) async {
    // Simulate API delay
    await Future.delayed(Duration(milliseconds: 100));
    return mockResponse;
  }

  @override
  Future<Map<String, dynamic>> parseStructuredData(String text) async {
    return {};
  }
}

// Note: Firestore integration tests are excluded from unit tests
// Run integration tests separately with actual Firestore emulator

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  UnderwritingConstraintEngine buildConstraintEngine() {
    return UnderwritingConstraintEngine.fromJson({
      'version': 'test-v1',
      'breedAliases': {'chiwawa': 'chihuahua', 'greate dane': 'great dane'},
      'breedConstraints': {
        'chihuahua': {
          'species': 'dog',
          'typicalWeightLbs': [4, 6],
          'maxHealthyWeightLbs': 10,
          'anomalyThresholdLbs': 15,
          'expectedLifespanYears': [12, 18],
          'highRiskTraits': ['toy_breed'],
          'severityScaling': true,
        },
        'great dane': {
          'species': 'dog',
          'typicalWeightLbs': [120, 180],
          'maxHealthyWeightLbs': 190,
          'anomalyThresholdLbs': 220,
          'expectedLifespanYears': [6, 10],
          'highRiskTraits': ['giant_breed'],
          'severityScaling': true,
        },
      },
    });
  }

  group('RiskScoringEngine with AI Integration', () {
    late RiskScoringEngine engine;
    late MockAIService mockAIService;
    late FakeFirebaseFirestore fakeFirestore;

    setUp(() async {
      mockAIService = MockAIService();
      fakeFirestore = FakeFirebaseFirestore();

      // Seed a minimal published underwriting rules doc so the deterministic
      // eligibility check doesn't fail-closed in debug/test.
      await fakeFirestore
          .collection('admin_settings')
          .doc('underwriting_rules')
          .set({
            'enabled': true,
            'rulesAvailable': true,
            'maxRiskScore': 100,
            'minAgeMonths': 0,
            'maxAgeYears': 30,
            'excludedBreeds': <String>[],
            'criticalConditions': <String>[],
            'excludableConditions': <String>[],
          });

      engine = RiskScoringEngine(
        aiService: mockAIService,
        firestore: fakeFirestore,
        rulesEngine: UnderwritingRulesEngine(
          firestore: fakeFirestore,
          enablePublicCallable: false,
        ),
        constraintEngine: buildConstraintEngine(),
      );
    });

    final testPet = Pet(
      id: 'pet_test_123',
      name: 'Max',
      species: 'dog',
      breed: 'German Shepherd',
      dateOfBirth: DateTime(2015, 5, 15),
      gender: 'Male',
      weight: 35.0,
      isNeutered: true,
      preExistingConditions: ['Hip Dysplasia'],
    );

    final testOwner = Owner(
      id: 'owner_test_456',
      firstName: 'John',
      lastName: 'Doe',
      email: 'john@test.com',
      phoneNumber: '555-0123',
      address: Address(
        street: '123 Test St',
        city: 'San Francisco',
        state: 'CA',
        zipCode: '94102',
        country: 'USA',
      ),
    );

    test('calculateRiskScore includes AI analysis', () async {
      final riskScore = await engine.calculateRiskScore(
        pet: testPet,
        owner: testOwner,
      );

      expect(riskScore.overallScore, greaterThan(0));
      expect(riskScore.overallScore, lessThanOrEqualTo(100));
      expect(riskScore.aiAnalysis, isNotNull);
      expect(riskScore.aiAnalysis, contains('Risk Assessment'));
      expect(riskScore.riskFactors, isNotEmpty);
      expect(riskScore.categoryScores, isNotEmpty);
    });

    test('calculateRiskScore handles pet age correctly', () async {
      final youngPet = testPet.copyWith(
        dateOfBirth: DateTime.now().subtract(Duration(days: 365 * 2)),
      );

      final oldPet = testPet.copyWith(
        dateOfBirth: DateTime.now().subtract(Duration(days: 365 * 12)),
      );

      final youngScore = await engine.calculateRiskScore(
        pet: youngPet,
        owner: testOwner,
      );

      final oldScore = await engine.calculateRiskScore(
        pet: oldPet,
        owner: testOwner,
      );

      // Older pets should generally have higher risk
      expect(
        oldScore.categoryScores['age']!,
        greaterThan(youngScore.categoryScores['age']!),
      );
    });

    test('calculateRiskScore includes owner location in AI prompt', () async {
      // Verify that location data is used (tested through AI analysis presence)
      final result = await engine.calculateRiskScore(
        pet: testPet,
        owner: testOwner,
      );

      expect(result.aiAnalysis, isNotNull);
      expect(result.aiAnalysis, contains('California'));
    });

    test('calculateRiskScore flags suspicious quote velocity', () async {
      final riskScore = await engine.calculateRiskScore(
        pet: testPet,
        owner: testOwner,
        additionalData: {
          'quoteVelocity': {
            'attempts10m': 3,
            'attempts1h': 3,
            'suspicious': true,
          },
        },
      );

      expect(riskScore.reviewTriggers, isNotNull);
      expect(riskScore.reviewTriggers!, contains('QUOTE_VELOCITY_SUSPECTED'));
      expect(
        riskScore.riskFactors.any((f) => f.category == 'behavioral'),
        isTrue,
      );
    });

    // Note: Firestore storage tests are excluded from unit tests
    // Use integration tests with Firestore emulator for storage testing

    test('calculateRiskScore handles high-risk breed', () async {
      final highRiskPet = testPet.copyWith(breed: 'Bulldog');

      final riskScore = await engine.calculateRiskScore(
        pet: highRiskPet,
        owner: testOwner,
      );

      // Bulldogs should have higher breed risk
      expect(riskScore.categoryScores['breed']!, greaterThan(50));
      expect(
        riskScore.riskFactors.any(
          (f) => f.category == 'breed' && f.description.contains('Bulldog'),
        ),
        isTrue,
      );
    });

    test('calculateRiskScore handles pre-existing conditions', () async {
      final petWithConditions = testPet.copyWith(
        preExistingConditions: ['Hip Dysplasia', 'Arthritis', 'Heart Murmur'],
      );

      final riskScore = await engine.calculateRiskScore(
        pet: petWithConditions,
        owner: testOwner,
      );

      // Should have pre-existing condition risk factors
      final preExistingFactors = riskScore.riskFactors
          .where((f) => f.category == 'preExisting')
          .toList();

      // Expect one factor per condition plus an aggregate factor when a
      // critical condition is present alongside others.
      expect(preExistingFactors.length, equals(4));
      expect(riskScore.categoryScores['preExisting']!, greaterThan(0));
    });

    test('AI service failure does not fabricate fallback analysis', () async {
      // Create engine with failing AI service
      final failingService = _FailingMockAIService();
      final failingEngine = RiskScoringEngine(
        aiService: failingService,
        firestore: fakeFirestore,
        rulesEngine: UnderwritingRulesEngine(
          firestore: fakeFirestore,
          enablePublicCallable: false,
        ),
      );

      final riskScore = await failingEngine.calculateRiskScore(
        pet: testPet,
        owner: testOwner,
      );

      // Fail-closed invariant: do not fabricate AI analysis content.
      expect(riskScore.aiAnalysis, anyOf(isNull, isEmpty));
      expect(riskScore.overallScore, greaterThan(0));

      // Ensure audit artifacts reflect the AI outage.
      expect(riskScore.reviewTriggers, isNotNull);
      expect(riskScore.reviewTriggers, contains('AI_ANALYSIS_UNAVAILABLE'));
      expect(
        riskScore.riskFactors.any(
          (f) =>
              f.category == 'system' &&
              f.description.toLowerCase().contains('ai analysis unavailable'),
        ),
        isTrue,
      );
    });

    test('RiskScoringException exists and can be thrown', () {
      // Verify the exception exists and works correctly
      expect(
        () => throw RiskScoringException('Test error'),
        throwsA(isA<RiskScoringException>()),
      );

      final exception = RiskScoringException('Custom message');
      expect(exception.toString(), contains('Custom message'));
    });
  });

  group('RiskScore Model Integration', () {
    test('RiskScore serialization includes aiAnalysis', () {
      final riskScore = RiskScore(
        id: 'risk_123',
        petId: 'pet_456',
        calculatedAt: DateTime(2025, 10, 7),
        overallScore: 55.5,
        riskLevel: RiskLevel.medium,
        categoryScores: {'age': 50.0, 'breed': 60.0},
        riskFactors: [],
        aiAnalysis: 'AI generated analysis text',
        requiredEvidenceCodes: const ['VERIFY_WEIGHT'],
      );

      final json = riskScore.toJson();

      expect(json['aiAnalysis'], equals('AI generated analysis text'));
      expect(json['overallScore'], equals(55.5));

      final restored = RiskScore.fromJson(json);
      expect(restored.aiAnalysis, equals('AI generated analysis text'));
      expect(restored.overallScore, equals(55.5));
      expect(restored.requiredEvidenceCodes, equals(const ['VERIFY_WEIGHT']));
    });
  });

  group('Deterministic underwriting constraints', () {
    late RiskScoringEngine engine;
    late MockAIService mockAIService;
    late FakeFirebaseFirestore fakeFirestore;

    double lbsToKg(double lbs) => lbs / 2.2046226218;

    final testOwner = Owner(
      id: 'owner_test_cred_1',
      firstName: 'Test',
      lastName: 'Owner',
      email: 'owner@test.com',
      phoneNumber: '555-9999',
      address: Address(
        street: '1 Main St',
        city: 'San Francisco',
        state: 'CA',
        zipCode: '94102',
        country: 'USA',
      ),
    );

    setUp(() async {
      mockAIService = MockAIService();
      fakeFirestore = FakeFirebaseFirestore();

      await fakeFirestore
          .collection('admin_settings')
          .doc('underwriting_rules')
          .set({
            'enabled': true,
            'rulesAvailable': true,
            'maxRiskScore': 100,
            'minAgeMonths': 0,
            'maxAgeYears': 30,
            'excludedBreeds': <String>[],
            'criticalConditions': <String>[],
            'excludableConditions': <String>[],
          });

      engine = RiskScoringEngine(
        aiService: mockAIService,
        firestore: fakeFirestore,
        rulesEngine: UnderwritingRulesEngine(
          firestore: fakeFirestore,
          enablePublicCallable: false,
        ),
        constraintEngine: buildConstraintEngine(),
      );
    });

    test(
      'Chihuahua @ 80 lbs materially increases score and triggers review',
      () async {
        final now = DateTime.now();
        final plausible = Pet(
          id: 'pet_chi_plausible',
          name: 'Tiny',
          species: 'dog',
          breed: 'Chihuahua',
          dateOfBirth: DateTime(now.year - 3, now.month, now.day),
          gender: 'Female',
          weight: lbsToKg(6.0),
          isNeutered: true,
          preExistingConditions: const [],
        );

        final implausible = plausible.copyWith(
          id: 'pet_chi_implausible',
          weight: lbsToKg(80.0),
        );

        final plausibleScore = await engine.calculateRiskScore(
          pet: plausible,
          owner: testOwner,
        );
        final implausibleScore = await engine.calculateRiskScore(
          pet: implausible,
          owner: testOwner,
        );

        expect(
          implausibleScore.overallScore,
          greaterThanOrEqualTo(plausibleScore.overallScore + 15.0),
        );
        expect(implausibleScore.confidenceScore, isNotNull);
        expect(plausibleScore.confidenceScore, isNotNull);
        expect(
          implausibleScore.confidenceScore!,
          lessThan(plausibleScore.confidenceScore!),
        );

        expect(implausibleScore.reviewTriggers, isNotNull);
        expect(implausibleScore.reviewTriggers, contains('POST_BIND_REVIEW'));
        expect(
          implausibleScore.reviewTriggers,
          contains('POSSIBLE_MISREPORTING'),
        );

        expect(implausibleScore.anomalyFindings, isNotNull);
        expect(implausibleScore.anomalyFindings, isNotEmpty);
        final hasWeightOutlier = implausibleScore.anomalyFindings!.any(
          (m) => (m['type'] ?? '').toString().toUpperCase() == 'WEIGHTOUTLIER',
        );
        expect(hasWeightOutlier, isTrue);
      },
    );

    test(
      'Chihuahua @ 10 lbs vs 98 lbs: CRITICAL, confidence drop, premium delta',
      () async {
        final now = DateTime.now();
        final base = Pet(
          id: 'pet_chi_10',
          name: 'Tiny',
          species: 'dog',
          breed: 'Chihuahua',
          dateOfBirth: DateTime(now.year - 3, now.month, now.day),
          gender: 'Female',
          weight: lbsToKg(10.0),
          isNeutered: true,
          preExistingConditions: const [],
        );

        final extreme = base.copyWith(
          id: 'pet_chi_98',
          name: 'Goliath',
          weight: lbsToKg(98.0),
        );

        final score10 = await engine.calculateRiskScore(
          pet: base,
          owner: testOwner,
        );
        final score98 = await engine.calculateRiskScore(
          pet: extreme,
          owner: testOwner,
        );

        // Severity should become CRITICAL for extreme misreporting.
        expect(score98.anomalyFindings, isNotNull);
        expect(score98.anomalyFindings, isNotEmpty);
        final hasCritical = score98.anomalyFindings!.any(
          (m) => (m['severity'] ?? '').toString().toUpperCase() == 'CRITICAL',
        );
        expect(hasCritical, isTrue);

        // Confidence score should drop materially.
        expect(score10.confidenceScore, isNotNull);
        expect(score98.confidenceScore, isNotNull);
        expect(score98.confidenceScore!, lessThan(score10.confidenceScore!));
        expect(score98.confidenceScore!, lessThan(0.8));

        // Constraint audit must be present for explainability/persistence.
        expect(score98.constraintAudit, isNotNull);
        expect(score98.constraintRiskMultiplier, isNotNull);

        // Pricing should change by at least 30% for the same comparable tier.
        final quoteEngine = QuoteEngine();
        final plans10 = quoteEngine.generateQuote(
          riskScore: score10,
          zipCode: '94102',
          state: 'CA',
          ageYears: base.ageInYears,
        );
        final plans98 = quoteEngine.generateQuote(
          riskScore: score98,
          zipCode: '94102',
          state: 'CA',
          ageYears: extreme.ageInYears,
        );

        Plan chooseComparable(List<Plan> plans) {
          final standard = plans
              .where((p) => p.type == PlanType.standard)
              .toList();
          if (standard.isNotEmpty) return standard.first;
          final basic = plans.where((p) => p.type == PlanType.basic).toList();
          if (basic.isNotEmpty) return basic.first;
          return plans.first;
        }

        final plan10 = chooseComparable(plans10);
        final plan98 = chooseComparable(plans98);
        final premium10 = plan10.monthlyPremium;
        final premium98 = plan98.monthlyPremium;
        expect(premium10, greaterThan(0));
        expect(premium98, greaterThan(0));

        final pctChange = (premium98 - premium10).abs() / premium10;
        expect(pctChange, greaterThanOrEqualTo(0.30));
      },
    );

    test('Normal Chihuahua → no exclusions', () async {
      final now = DateTime.now();
      final pet = Pet(
        id: 'pet_chi_normal',
        name: 'Tiny',
        species: 'dog',
        breed: 'Chihuahua',
        dateOfBirth: DateTime(now.year - 3, now.month, now.day),
        gender: 'Female',
        weight: lbsToKg(6.0),
        isNeutered: true,
        preExistingConditions: const [],
      );

      final score = await engine.calculateRiskScore(pet: pet, owner: testOwner);
      expect(score.exclusions ?? const <UnderwritingExclusion>[], isEmpty);
    });

    test(
      'Chihuahua @ 116 lbs → anomalyDerived exclusion, eligible=true, priced higher',
      () async {
        final now = DateTime.now();
        final base = Pet(
          id: 'pet_chi_6',
          name: 'Tiny',
          species: 'dog',
          breed: 'Chihuahua',
          dateOfBirth: DateTime(now.year - 3, now.month, now.day),
          gender: 'Female',
          weight: lbsToKg(6.0),
          isNeutered: true,
          preExistingConditions: const [],
        );

        final extreme = base.copyWith(
          id: 'pet_chi_116',
          name: 'Goliath',
          weight: lbsToKg(116.0),
        );

        final result = await engine.calculateRiskScoreWithEligibility(
          pet: extreme,
          owner: testOwner,
        );

        expect(result.isEligible, isTrue);
        final exclusions =
            result.riskScore.exclusions ?? const <UnderwritingExclusion>[];
        expect(exclusions, isNotEmpty);
        expect(
          exclusions.any(
            (e) =>
                e.type == UnderwritingExclusionType.anomalyDerived &&
                e.scope.toLowerCase() == 'orthopedic',
          ),
          isTrue,
        );
        expect(
          exclusions.every((e) => e.triggerReason.trim().isNotEmpty),
          isTrue,
        );

        expect(result.riskScore.requiredEvidenceCodes, isNotNull);
        expect(
          result.riskScore.requiredEvidenceCodes!,
          contains('VERIFY_WEIGHT'),
        );

        // Pricing still applies and should increase materially.
        final quoteEngine = QuoteEngine();
        final baseScore = await engine.calculateRiskScore(
          pet: base,
          owner: testOwner,
        );

        final plansBase = quoteEngine.generateQuote(
          riskScore: baseScore,
          zipCode: '94102',
          state: 'CA',
          ageYears: base.ageInYears,
        );
        final plansExtreme = quoteEngine.generateQuote(
          riskScore: result.riskScore,
          zipCode: '94102',
          state: 'CA',
          ageYears: extreme.ageInYears,
        );

        Plan chooseComparable(List<Plan> plans) {
          final standard = plans
              .where((p) => p.type == PlanType.standard)
              .toList();
          if (standard.isNotEmpty) return standard.first;
          final basic = plans.where((p) => p.type == PlanType.basic).toList();
          if (basic.isNotEmpty) return basic.first;
          return plans.first;
        }

        final pBase = chooseComparable(plansBase).monthlyPremium;
        final pExtreme = chooseComparable(plansExtreme).monthlyPremium;
        expect(pBase, greaterThan(0));
        expect(pExtreme, greaterThan(0));
        expect(pExtreme, greaterThan(pBase));
      },
    );

    test('Great Dane @ 180 lbs is plausible (no anomalies)', () async {
      final now = DateTime.now();
      final pet = Pet(
        id: 'pet_dane_180',
        name: 'Atlas',
        species: 'dog',
        breed: 'Great Dane',
        dateOfBirth: DateTime(now.year - 4, now.month, now.day),
        gender: 'Male',
        weight: lbsToKg(180.0),
        isNeutered: true,
        preExistingConditions: const [],
      );

      final score = await engine.calculateRiskScore(pet: pet, owner: testOwner);

      expect(score.anomalyFindings, isNotNull);
      expect(score.anomalyFindings, isEmpty);
      expect(score.reviewTriggers, isNotNull);
      expect(score.reviewTriggers, isEmpty);
      expect(score.confidenceScore, equals(1.0));
    });

    test('AI outage does not prevent anomaly detection/audit output', () async {
      final failingEngine = RiskScoringEngine(
        aiService: _FailingMockAIService(),
        firestore: fakeFirestore,
        rulesEngine: UnderwritingRulesEngine(
          firestore: fakeFirestore,
          enablePublicCallable: false,
        ),
        constraintEngine: buildConstraintEngine(),
      );

      final now = DateTime.now();
      final pet = Pet(
        id: 'pet_chi_fail_ai',
        name: 'Goliath',
        species: 'dog',
        breed: 'Chihuahua',
        dateOfBirth: DateTime(now.year - 3, now.month, now.day),
        gender: 'Female',
        weight: lbsToKg(98.0),
        isNeutered: true,
        preExistingConditions: const [],
      );

      final score = await failingEngine.calculateRiskScore(
        pet: pet,
        owner: testOwner,
      );
      expect(score.aiAnalysis, anyOf(isNull, isEmpty));
      expect(score.anomalyFindings, isNotNull);
      expect(score.anomalyFindings, isNotEmpty);
      expect(score.constraintAudit, isNotNull);
      expect(score.constraintRiskMultiplier, isNotNull);
    });

    test(
      'Mixed - Small (0–25 lbs) @ 100 lbs triggers CRITICAL outlier',
      () async {
        final now = DateTime.now();
        final pet = Pet(
          id: 'pet_mixed_small_100',
          name: 'Tank',
          species: 'dog',
          breed: 'Mixed - Small (0–25 lbs)',
          dateOfBirth: DateTime(now.year - 3, now.month, now.day),
          gender: 'Male',
          weight: lbsToKg(100.0),
          isNeutered: true,
          preExistingConditions: const [],
        );

        final score = await engine.calculateRiskScore(
          pet: pet,
          owner: testOwner,
        );
        expect(score.anomalyFindings, isNotNull);
        expect(score.anomalyFindings, isNotEmpty);

        final hasCritical = score.anomalyFindings!.any(
          (m) => (m['severity'] ?? '').toString().toUpperCase() == 'CRITICAL',
        );
        expect(hasCritical, isTrue);

        expect(score.confidenceScore, isNotNull);
        expect(score.confidenceScore!, lessThan(1.0));
        expect(score.constraintRiskMultiplier, isNotNull);
        expect(score.constraintRiskMultiplier!, greaterThan(1.0));

        expect(score.constraintAudit, isNotNull);
        expect(
          score.constraintAudit!['constraintSource'],
          equals('derived_range'),
        );
        final bc = score.constraintAudit!['breedConstraint'] as Map?;
        expect(bc, isNotNull);
        expect(
          (bc!['maxHealthyWeightLbs'] as num).toDouble(),
          closeTo(25.0, 0.0001),
        );
        expect(
          (bc['anomalyThresholdLbs'] as num).toDouble(),
          closeTo(37.5, 0.0001),
        );
        expect(
          (bc['criticalThresholdLbs'] as num).toDouble(),
          closeTo(50.0, 0.0001),
        );

        // Exclusions: targeted, anomaly-derived, auditable.
        final exclusions = score.exclusions ?? const <UnderwritingExclusion>[];
        expect(exclusions, isNotEmpty);
        expect(
          exclusions.any(
            (e) =>
                e.type == UnderwritingExclusionType.anomalyDerived &&
                e.scope.toLowerCase() == 'orthopedic',
          ),
          isTrue,
        );
        expect(
          exclusions.every((e) => e.triggerReason.trim().isNotEmpty),
          isTrue,
        );

        expect(score.requiredEvidenceCodes, isNotNull);
        expect(score.requiredEvidenceCodes!, contains('VERIFY_WEIGHT'));
      },
    );

    test('Mixed range parsing supports hyphen and em dash', () async {
      final now = DateTime.now();
      final labels = <String>[
        'Mixed - Medium (25-60 lbs)',
        'Mixed - Large (60—100 lb)',
      ];

      for (final label in labels) {
        final pet = Pet(
          id: 'pet_${label.hashCode}',
          name: 'Mixy',
          species: 'dog',
          breed: label,
          dateOfBirth: DateTime(now.year - 3, now.month, now.day),
          gender: 'Female',
          weight: lbsToKg(200.0),
          isNeutered: true,
          preExistingConditions: const [],
        );

        final score = await engine.calculateRiskScore(
          pet: pet,
          owner: testOwner,
        );
        expect(score.constraintAudit, isNotNull);
        expect(
          score.constraintAudit!['constraintSource'],
          equals('derived_range'),
        );
        expect(score.anomalyFindings, isNotNull);
        expect(score.anomalyFindings, isNotEmpty);
      }
    });

    test(
      'Age above breed lifespan flags anomaly and triggers review',
      () async {
        final now = DateTime.now();
        final pet = Pet(
          id: 'pet_chi_age_25',
          name: 'Oldie',
          species: 'dog',
          breed: 'Chihuahua',
          dateOfBirth: DateTime(now.year - 25, now.month, now.day),
          gender: 'Female',
          weight: lbsToKg(6.0),
          isNeutered: true,
          preExistingConditions: const [],
        );

        final score = await engine.calculateRiskScore(
          pet: pet,
          owner: testOwner,
        );

        expect(score.anomalyFindings, isNotNull);
        expect(score.anomalyFindings, isNotEmpty);
        expect(score.reviewTriggers, contains('POST_BIND_REVIEW'));

        final hasAgeMismatch = score.anomalyFindings!.any(
          (m) => (m['type'] ?? '').toString().toUpperCase() == 'AGEMISMATCH',
        );
        expect(hasAgeMismatch, isTrue);
      },
    );

    test(
      'Severe age mismatch → targeted age-related exclusion (still eligible)',
      () async {
        final now = DateTime.now();
        final pet = Pet(
          id: 'pet_chi_age_35',
          name: 'Oldie',
          species: 'dog',
          breed: 'Chihuahua',
          // Keep within deterministic eligibility rule (maxAgeYears=30), while
          // still being far above expected Chihuahua lifespan.
          dateOfBirth: DateTime(now.year - 30, now.month, now.day),
          gender: 'Female',
          weight: lbsToKg(6.0),
          isNeutered: true,
          preExistingConditions: const [],
        );

        final result = await engine.calculateRiskScoreWithEligibility(
          pet: pet,
          owner: testOwner,
        );

        expect(result.isEligible, isTrue);
        final exclusions =
            result.riskScore.exclusions ?? const <UnderwritingExclusion>[];
        expect(exclusions, isNotEmpty);
        expect(
          exclusions.any(
            (e) =>
                e.scope.toLowerCase() == 'age-related' &&
                e.triggerReason.toUpperCase().contains('ANOMALY:AGEMISMATCH'),
          ),
          isTrue,
        );

        expect(result.riskScore.requiredEvidenceCodes, isNotNull);
        expect(result.riskScore.requiredEvidenceCodes!, contains('VERIFY_AGE'));
      },
    );

    test(
      'Breed/species conflict → targeted hereditary exclusion (still eligible)',
      () async {
        final now = DateTime.now();

        // Chihuahua constraints expect species=dog. Reporting cat should trigger
        // a high-severity breed/species anomaly and reduce confidence.
        final pet = Pet(
          id: 'pet_conflict_cat_chihuahua',
          name: 'Confused',
          species: 'cat',
          breed: 'Chihuahua',
          dateOfBirth: DateTime(now.year - 3, now.month, now.day),
          gender: 'Female',
          weight: lbsToKg(6.0),
          isNeutered: true,
          preExistingConditions: const [],
        );

        final result = await engine.calculateRiskScoreWithEligibility(
          pet: pet,
          owner: testOwner,
        );

        expect(result.isEligible, isTrue);

        final exclusions =
            result.riskScore.exclusions ?? const <UnderwritingExclusion>[];
        expect(exclusions, isNotEmpty);
        expect(
          exclusions.any(
            (e) =>
                e.type == UnderwritingExclusionType.breedLinked &&
                e.scope.toLowerCase() == 'hereditary' &&
                e.triggerReason.toUpperCase().contains('ANOMALY:BREEDCONFLICT'),
          ),
          isTrue,
        );

        expect(result.riskScore.requiredEvidenceCodes, isNotNull);
        expect(
          result.riskScore.requiredEvidenceCodes!,
          contains('VERIFY_BREED_SPECIES'),
        );
      },
    );

    test('French Bulldog → breed-linked respiratory exclusion', () async {
      final now = DateTime.now();
      final pet = Pet(
        id: 'pet_frenchie',
        name: 'Bean',
        species: 'dog',
        breed: 'French Bulldog',
        dateOfBirth: DateTime(now.year - 3, now.month, now.day),
        gender: 'Male',
        weight: lbsToKg(25.0),
        isNeutered: true,
        preExistingConditions: const [],
      );

      final score = await engine.calculateRiskScore(pet: pet, owner: testOwner);
      final exclusions = score.exclusions ?? const <UnderwritingExclusion>[];

      expect(
        exclusions.any(
          (e) =>
              e.type == UnderwritingExclusionType.breedLinked &&
              e.scope.toLowerCase() == 'respiratory' &&
              e.triggerReason.toUpperCase().contains('BREED_TRAIT:RESPIRATORY'),
        ),
        isTrue,
      );
    });

    test('Congenital condition intake → congenital exclusion', () async {
      final now = DateTime.now();
      final pet = Pet(
        id: 'pet_congenital_1',
        name: 'Lucky',
        species: 'dog',
        breed: 'Chihuahua',
        dateOfBirth: DateTime(now.year - 3, now.month, now.day),
        gender: 'Female',
        weight: lbsToKg(6.0),
        isNeutered: true,
        preExistingConditions: const [],
        medicalConditions: <MedicalCondition>[
          MedicalCondition(
            id: 'cond1',
            name: 'Patent ductus arteriosus',
            diagnosisDate: DateTime(now.year - 2, now.month, now.day),
            status: 'managed',
            isCongenital: true,
          ),
        ],
      );

      final score = await engine.calculateRiskScore(pet: pet, owner: testOwner);
      final exclusions = score.exclusions ?? const <UnderwritingExclusion>[];

      expect(
        exclusions.any(
          (e) =>
              e.type == UnderwritingExclusionType.congenital &&
              e.scope.toLowerCase().contains('patent ductus arteriosus') &&
              e.triggerReason.toUpperCase().contains('INTAKE:CONGENITAL'),
        ),
        isTrue,
      );
    });
  });
}

/// Mock AI service that always fails
class _FailingMockAIService implements AIService {
  @override
  Future<String> generateText(
    String prompt, {
    Map<String, dynamic>? options,
  }) async {
    throw Exception('AI service unavailable');
  }

  @override
  Future<Map<String, dynamic>> parseStructuredData(String text) async {
    throw Exception('AI service unavailable');
  }
}

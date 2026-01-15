import 'package:flutter_test/flutter_test.dart';
import 'package:pet_underwriter_ai/models/medical_condition_fact.dart';
import 'package:pet_underwriter_ai/models/pet.dart';
import 'package:pet_underwriter_ai/models/risk_score.dart';
import 'package:pet_underwriter_ai/models/underwriting_decision.dart';
import 'package:pet_underwriter_ai/models/underwriting_status.dart';
import 'package:pet_underwriter_ai/services/underwriting_integrity_engine.dart';
import 'package:pet_underwriter_ai/services/underwriting_rules_engine.dart';
import 'package:pet_underwriter_ai/services/vet_history_parser.dart';

Pet _pet() {
  return Pet(
    id: 'p1',
    name: 'Buddy',
    species: 'dog',
    breed: 'Mixed',
    dateOfBirth: DateTime(2020, 1, 1),
    gender: 'male',
    weight: 10.0,
    isNeutered: true,
    preExistingConditions: const ['HCM'],
  );
}

RiskScore _riskScore() {
  return RiskScore(
    id: 'r1',
    petId: 'p1',
    calculatedAt: DateTime(2025, 1, 1),
    overallScore: 42.0,
    riskLevel: RiskLevel.medium,
    categoryScores: const {'age': 10.0},
    riskFactors: const [],
    aiAnalysis: null,
  );
}

void main() {
  group('UnderwritingIntegrityEngine', () {
    test('disclosed conditions without vet records => need more info (no pricing)',
        () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [
          MedicalConditionFact(
            conditionCode: 'HEART_MURMUR',
            severity: MedicalConditionSeverity.unknown,
            chronicity: MedicalConditionChronicity.unknown,
            confirmedBy: MedicalConditionConfirmedBy.unknown,
            status: MedicalConditionStatus.confirmed,
          ),
        ],
        medicalFactsRequired: true,
        aiFailure: false,
        vetDocumentHashes: const [],
        rawVetTextsForIntegrity: const [],
        aiVetExtractionForIntegrity: const [],
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.needMoreInfo);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'VET_RECORDS_REQUIRED');
      expect(
        assessment.requiredEvidence.any((e) => e.code == 'PROVIDE_MEDICAL_HISTORY'),
        true,
      );
    });

    test('risk score mismatch => need more info (no pricing)', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final badRisk = RiskScore(
        id: 'r_bad',
        petId: 'p1',
        calculatedAt: DateTime(2025, 1, 1),
        overallScore: 10.0,
        riskLevel: RiskLevel.high,
        categoryScores: const {'age': 10.0},
        riskFactors: const [],
        aiAnalysis: null,
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: badRisk,
        medicalFacts: const [],
        medicalFactsRequired: false,
        aiFailure: false,
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.needMoreInfo);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'RISK_SCORE_MISMATCH');
      expect(
        assessment.requiredEvidence.any((e) => e.code == 'RISK_SCORE_RECALCULATE'),
        true,
      );
    });

    test('pet identity species mismatch => declined (no pricing)', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [],
        medicalFactsRequired: false,
        aiFailure: false,
        rawVetTextsForIntegrity: const ['Patient: Buddy\nSpecies: Cat\n'],
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.declined);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'PET_IDENTITY_SPECIES_MISMATCH');
      expect(assessment.decision, isNotNull);
    });

    test('pet identity name mismatch blocks critical deny (need more info)', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      // Simulate a vet-derived confirmed critical condition, but with a record
      // that appears to belong to a different pet name.
      final assessment = await engine.assess(
        pet: Pet(
          id: 'p_name_mismatch',
          name: 'Ted',
          species: 'cat',
          breed: 'Domestic Shorthair',
          dateOfBirth: DateTime(2020, 1, 1),
          gender: 'male',
          weight: 4.0,
          isNeutered: true,
          preExistingConditions: const ['Heart Disease'],
        ),
        riskScore: _riskScore(),
        medicalFacts: const [
          MedicalConditionFact(
            conditionCode: 'CHF',
            severity: MedicalConditionSeverity.unknown,
            chronicity: MedicalConditionChronicity.unknown,
            confirmedBy: MedicalConditionConfirmedBy.unknown,
            status: MedicalConditionStatus.confirmed,
          ),
        ],
        medicalFactsRequired: true,
        aiFailure: false,
        rawVetTextsForIntegrity: const [
          'Happy Paws Vet\nPatient: Oliver\nSpecies: Cat\nDx: CHF\n',
        ],
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.needMoreInfo);
      expect(assessment.pricingEnabled, false);
      expect(
        assessment.reason == 'PET_IDENTITY_NAME_MISMATCH' ||
            assessment.reason == 'INTEGRITY_CHECKS_REQUIRED',
        true,
      );
      expect(
        assessment.requiredEvidence.any((e) => e.code == 'PET_IDENTITY_CONFIRMATION'),
        true,
      );
    });

    test('diagnostic results pending => need more info (no pricing)', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
        now: () => DateTime(2026, 1, 14),
      );

      final dated = VetRecordData(
        vaccinations: const [],
        treatments: const [],
        medications: const [],
        allergies: const [],
        surgeries: const [],
        diagnoses: const [],
        previousClaims: const [],
        lastCheckup: DateTime(2025, 12, 1),
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [],
        medicalFactsRequired: false,
        aiFailure: false,
        aiVetExtractionForIntegrity: [dated],
        rawVetTextsForIntegrity: const [
          'Happy Paws Veterinary Clinic\nPhone: (555) 555-5555\nLabs pending; awaiting results'
        ],
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.needMoreInfo);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'DIAGNOSTIC_RESULTS_PENDING');
      expect(
        assessment.requiredEvidence.any((e) => e.code == 'DIAGNOSTIC_RESULTS'),
        true,
      );
    });

    test('stale vet record => need more info (no pricing)', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
        now: () => DateTime(2026, 1, 14),
      );

      final stale = VetRecordData(
        vaccinations: const [],
        treatments: const [],
        medications: const [],
        allergies: const [],
        surgeries: const [],
        diagnoses: const [],
        previousClaims: const [],
        lastCheckup: DateTime(2023, 1, 1),
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [],
        medicalFactsRequired: false,
        aiFailure: false,
        aiVetExtractionForIntegrity: [stale],
        rawVetTextsForIntegrity: const ['Clinic header here'],
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.needMoreInfo);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'VET_RECORD_TOO_OLD');
      expect(
        assessment.requiredEvidence.any((e) => e.code == 'RECENT_VET_RECORD'),
        true,
      );
    });

    test('free email in vet record => need more info (no pricing)', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
        now: () => DateTime(2026, 1, 14),
      );

      final dated = VetRecordData(
        vaccinations: const [],
        treatments: const [],
        medications: const [],
        allergies: const [],
        surgeries: const [],
        diagnoses: const [],
        previousClaims: const [],
        lastCheckup: DateTime(2025, 12, 1),
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [],
        medicalFactsRequired: false,
        aiFailure: false,
        aiVetExtractionForIntegrity: [dated],
        rawVetTextsForIntegrity: const [
          'Happy Paws Veterinary Clinic\nContact: happyvet@gmail.com\nPhone: (555) 555-5555'
        ],
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.needMoreInfo);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'VET_RECORD_FREE_EMAIL_DETECTED');
      expect(
        assessment.requiredEvidence.any((e) => e.code == 'VET_RECORD_OFFICIAL_CONTACT'),
        true,
      );
    });

    test('vet document reuse => need more info (no pricing)', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
        vetDocumentReuseCheck: ({
          required vetDocumentHashes,
          underwritingCaseId,
        }) async {
          return const VetDocumentReuseCheckResult.needMoreInfo(
            reason: 'VET_DOCUMENT_REUSE_DETECTED',
            matchedCaseIds: ['case_other'],
          );
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [],
        medicalFactsRequired: false,
        aiFailure: false,
        vetDocumentHashes: const ['hash1'],
        underwritingCaseId: 'case_current',
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.needMoreInfo);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'VET_DOCUMENT_REUSE_DETECTED');
      expect(
        assessment.requiredEvidence.any((e) => e.code == 'VET_DOCUMENT_INTEGRITY'),
        true,
      );
    });

    test('vet document reuse multi-case => declined (no pricing)', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
        vetDocumentReuseCheck: ({
          required vetDocumentHashes,
          underwritingCaseId,
        }) async {
          return const VetDocumentReuseCheckResult.decline(
            reason: 'VET_DOCUMENT_REUSE_MULTI_CASE',
            matchedCaseIds: ['c1', 'c2'],
          );
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [],
        medicalFactsRequired: false,
        aiFailure: false,
        vetDocumentHashes: const ['hash1'],
        underwritingCaseId: 'case_current',
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.declined);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'VET_DOCUMENT_REUSE_MULTI_CASE');
      expect(assessment.decision, isNotNull);
    });

    test('denies deterministic critical condition when confirmed', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [
          MedicalConditionFact(
            conditionCode: 'HCM',
            severity: MedicalConditionSeverity.unknown,
            chronicity: MedicalConditionChronicity.unknown,
            confirmedBy: MedicalConditionConfirmedBy.unknown,
            status: MedicalConditionStatus.confirmed,
          ),
        ],
        medicalFactsRequired: true,
        aiFailure: false,
        vetDocumentHashes: const ['hash_ok'],
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.denied);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'CRITICAL_CONDITION_HCM');
      expect(assessment.decision, isNotNull);
    });

    test('AI failure + confirmed critical still denies (no pricing)', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [
          MedicalConditionFact(
            conditionCode: 'HCM',
            severity: MedicalConditionSeverity.unknown,
            chronicity: MedicalConditionChronicity.unknown,
            confirmedBy: MedicalConditionConfirmedBy.unknown,
            status: MedicalConditionStatus.confirmed,
          ),
        ],
        medicalFactsRequired: true,
        aiFailure: true,
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.denied);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'CRITICAL_CONDITION_HCM');
    });

    test('suspected HCM triggers deterministic decline (no pricing)', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [
          MedicalConditionFact(
            conditionCode: 'HCM',
            severity: MedicalConditionSeverity.unknown,
            chronicity: MedicalConditionChronicity.unknown,
            confirmedBy: MedicalConditionConfirmedBy.unknown,
            status: MedicalConditionStatus.suspected,
          ),
        ],
        medicalFactsRequired: true,
        aiFailure: false,
        vetDocumentHashes: const ['hash_ok'],
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.declined);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'SUSPECTED_CRITICAL_CONDITION');
      expect(assessment.decision, isNotNull);
    });

    test('rule-out suspected HCM => need more info (self-serve, no pricing)',
        () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [
          MedicalConditionFact(
            conditionCode: 'HCM',
            severity: MedicalConditionSeverity.unknown,
            chronicity: MedicalConditionChronicity.unknown,
            confirmedBy: MedicalConditionConfirmedBy.unknown,
            status: MedicalConditionStatus.suspected,
          ),
        ],
        medicalFactsRequired: true,
        aiFailure: false,
        ruleOutConditionCodes: const {'HCM'},
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.needMoreInfo);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'MISSING_OR_UNCERTAIN_MEDICAL_FACTS');
      expect(assessment.decision, isNull);
      expect(assessment.requiredEvidence, isNotEmpty);
    });

    test('declines when required evidence is not provided (zero-human loop-breaker)',
        () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [],
        medicalFactsRequired: false,
        aiFailure: false,
        userFailedToProvideRequiredEvidence: true,
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.declined);
      expect(assessment.pricingEnabled, isFalse);
      expect(assessment.reason, 'REQUIRED_EVIDENCE_NOT_PROVIDED');
      expect(assessment.decision, isNotNull);
      expect(assessment.decision!.outcome, UnderwritingOutcome.decline);
    });

    test('AI failure + suspected HCM still declines (suspected critical)', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [
          MedicalConditionFact(
            conditionCode: 'HCM',
            severity: MedicalConditionSeverity.unknown,
            chronicity: MedicalConditionChronicity.unknown,
            confirmedBy: MedicalConditionConfirmedBy.unknown,
            status: MedicalConditionStatus.suspected,
          ),
        ],
        medicalFactsRequired: true,
        aiFailure: true,
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.declined);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'SUSPECTED_CRITICAL_CONDITION');
    });

    test('AI failure first occurrence => need more info (no pricing)', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [
          MedicalConditionFact(
            conditionCode: 'HEART_MURMUR',
            severity: MedicalConditionSeverity.unknown,
            chronicity: MedicalConditionChronicity.unknown,
            confirmedBy: MedicalConditionConfirmedBy.unknown,
            status: MedicalConditionStatus.suspected,
          ),
        ],
        medicalFactsRequired: true,
        aiFailure: true,
        aiFailureCount: 1,
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.needMoreInfo);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'AI_FAILURE');
      expect(assessment.requiredEvidence, isNotEmpty);
    });

    test('AI failure persistent => declined (no pricing)', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [
          MedicalConditionFact(
            conditionCode: 'HEART_MURMUR',
            severity: MedicalConditionSeverity.unknown,
            chronicity: MedicalConditionChronicity.unknown,
            confirmedBy: MedicalConditionConfirmedBy.unknown,
            status: MedicalConditionStatus.suspected,
          ),
        ],
        medicalFactsRequired: true,
        aiFailure: true,
        aiFailureCount: 2,
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.declined);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'AI_FAILURE_PERSISTED');
      expect(assessment.decision, isNotNull);
    });

    test('non-critical suspected => need more info (no pricing)', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [
          MedicalConditionFact(
            conditionCode: 'HIP_DYSPLASIA',
            severity: MedicalConditionSeverity.mild,
            chronicity: MedicalConditionChronicity.chronic,
            confirmedBy: MedicalConditionConfirmedBy.generalist,
            status: MedicalConditionStatus.suspected,
          ),
        ],
        medicalFactsRequired: true,
        aiFailure: false,
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.needMoreInfo);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'MISSING_OR_UNCERTAIN_MEDICAL_FACTS');
      expect(assessment.decision, isNull);
      expect(assessment.requiredEvidence, isNotEmpty);
    });

    test('approved with exclusions when non-critical confirmed conditions exist',
        () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [
          MedicalConditionFact(
            conditionCode: 'HIP_DYSPLASIA',
            severity: MedicalConditionSeverity.mild,
            chronicity: MedicalConditionChronicity.chronic,
            confirmedBy: MedicalConditionConfirmedBy.generalist,
            status: MedicalConditionStatus.confirmed,
          ),
        ],
        medicalFactsRequired: true,
        aiFailure: false,
        vetDocumentHashes: const ['hash_ok'],
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.approved);
      expect(assessment.pricingEnabled, true);
      expect(assessment.reason, 'APPROVED_WITH_EXCLUSIONS');
      expect(assessment.decision, isNotNull);
      expect(assessment.decision!.outcome.toString(), contains('approveWithExclusions'));
      expect(assessment.decision!.exclusions.length, 1);
      expect(assessment.decision!.exclusions.first.conditionName, 'HIP_DYSPLASIA');
    });

    test('confirmed MASS_OR_TUMOR is treated as non-critical exclusion (not denial)',
        () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [
          MedicalConditionFact(
            conditionCode: 'MASS_OR_TUMOR',
            severity: MedicalConditionSeverity.mild,
            chronicity: MedicalConditionChronicity.chronic,
            confirmedBy: MedicalConditionConfirmedBy.generalist,
            status: MedicalConditionStatus.confirmed,
          ),
        ],
        medicalFactsRequired: true,
        aiFailure: false,
        vetDocumentHashes: const ['hash_ok'],
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.approved);
      expect(assessment.pricingEnabled, true);
      expect(assessment.reason, 'APPROVED_WITH_EXCLUSIONS');
      expect(assessment.decision, isNotNull);
      expect(
        assessment.decision!.exclusions.any(
          (e) => e.conditionName.toUpperCase() == 'MASS_OR_TUMOR',
        ),
        true,
      );
    });

    test('denies deterministic critical condition when ACTIVE_CANCER is confirmed',
        () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [
          MedicalConditionFact(
            conditionCode: 'ACTIVE_CANCER',
            severity: MedicalConditionSeverity.unknown,
            chronicity: MedicalConditionChronicity.unknown,
            confirmedBy: MedicalConditionConfirmedBy.unknown,
            status: MedicalConditionStatus.confirmed,
          ),
        ],
        medicalFactsRequired: true,
        aiFailure: false,
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.denied);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'CRITICAL_CONDITION_ACTIVE_CANCER');
      expect(assessment.decision, isNotNull);
    });

    test('missing medical facts => need more info and pricing disabled', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.eligible();
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [],
        medicalFactsRequired: true,
        aiFailure: false,
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.needMoreInfo);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'MISSING_OR_UNCERTAIN_MEDICAL_FACTS');
      expect(assessment.requiredEvidence, isNotEmpty);
    });

    test('rules unavailable => declined and pricing disabled', () async {
      final engine = UnderwritingIntegrityEngine(
        deterministicEligibility: ({required pet, required riskScore}) async {
          return EligibilityResult.ineligible(
            reason: 'Rules unavailable',
            ruleViolated: 'RULES_UNAVAILABLE',
          );
        },
      );

      final assessment = await engine.assess(
        pet: _pet(),
        riskScore: _riskScore(),
        medicalFacts: const [
          MedicalConditionFact(
            conditionCode: 'HIP_DYSPLASIA',
            severity: MedicalConditionSeverity.mild,
            chronicity: MedicalConditionChronicity.chronic,
            confirmedBy: MedicalConditionConfirmedBy.generalist,
            status: MedicalConditionStatus.confirmed,
          ),
        ],
        medicalFactsRequired: true,
        aiFailure: false,
      );

      expect(assessment.underwritingStatus, UnderwritingStatus.declined);
      expect(assessment.pricingEnabled, false);
      expect(assessment.reason, 'RULES_UNAVAILABLE');
      expect(assessment.decision, isNotNull);
    });
  });
}

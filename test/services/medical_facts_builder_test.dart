import 'package:flutter_test/flutter_test.dart';
import 'package:pet_underwriter_ai/models/medical_condition_fact.dart';
import 'package:pet_underwriter_ai/models/medical_history.dart';
import 'package:pet_underwriter_ai/services/medical_facts_builder.dart';

void main() {
  group('MedicalFactsBuilder', () {
    test('AI failure + HCM text => produces confirmed HCM fact', () {
      final builder = MedicalFactsBuilder();

      final result = builder.build(
        userEnteredConditions: const [],
        userFactsByConditionId: const {},
        aiVetExtraction: const [],
        rawVetTexts: const [
          'Echocardiogram: echo consistent with HCM. Recommend cardiology follow-up.',
        ],
        aiFailure: true,
      );

      expect(result.aiFailure, true);
      expect(result.criticalConditionDetected, true);
      expect(
        result.facts.any(
          (f) => f.conditionCode == 'HCM' && f.status == MedicalConditionStatus.confirmed,
        ),
        true,
      );
    });

    test('HCM rule-out language => does not confirm HCM', () {
      final builder = MedicalFactsBuilder();

      final result = builder.build(
        userEnteredConditions: const [],
        userFactsByConditionId: const {},
        aiVetExtraction: const [],
        rawVetTexts: const [
          'Heart murmur noted. Rule out HCM. Recommend echo for evaluation.',
        ],
        aiFailure: true,
      );

      expect(
        result.facts.any(
          (f) => f.conditionCode == 'HCM' && f.status == MedicalConditionStatus.confirmed,
        ),
        false,
      );
      expect(
        result.facts.any(
          (f) => f.conditionCode == 'HCM' && f.status == MedicalConditionStatus.suspected,
        ),
        true,
      );

      expect(result.ruleOutConditionCodes.contains('HCM'), true);
    });

    test('Echo recommended (not performed) => does not confirm HCM', () {
      final builder = MedicalFactsBuilder();

      final result = builder.build(
        userEnteredConditions: const [],
        userFactsByConditionId: const {},
        aiVetExtraction: const [],
        rawVetTexts: const [
          'Possible HCM; echocardiogram recommended to evaluate for HCM.',
        ],
        aiFailure: true,
      );

      expect(
        result.facts.any(
          (f) => f.conditionCode == 'HCM' && f.status == MedicalConditionStatus.confirmed,
        ),
        false,
      );
      expect(
        result.facts.any(
          (f) => f.conditionCode == 'HCM' && f.status == MedicalConditionStatus.suspected,
        ),
        true,
      );

      expect(result.ruleOutConditionCodes.contains('HCM'), true);
    });

    test('AI failure + murmur only => produces suspected HEART_MURMUR (no confirmed critical)',
        () {
      final builder = MedicalFactsBuilder();

      final result = builder.build(
        userEnteredConditions: const [],
        userFactsByConditionId: const {},
        aiVetExtraction: const [],
        rawVetTexts: const [
          'Physical exam: grade 2/6 systolic murmur noted. No echo performed.',
        ],
        aiFailure: true,
      );

      expect(result.aiFailure, true);
      expect(result.criticalConditionDetected, false);
      expect(
        result.facts.any(
          (f) => f.conditionCode == 'HEART_MURMUR' && f.status == MedicalConditionStatus.suspected,
        ),
        true,
      );
      expect(
        result.facts.any(
          (f) => f.conditionCode == 'HCM' && f.status == MedicalConditionStatus.confirmed,
        ),
        false,
      );
    });

    test('Benign mass/tumor language does not trigger ACTIVE_CANCER', () {
      final builder = MedicalFactsBuilder();

      final result = builder.build(
        userEnteredConditions: const [],
        userFactsByConditionId: const {},
        aiVetExtraction: const [],
        rawVetTexts: const [
          'Small benign lipoma mass on flank. No evidence of malignancy.',
        ],
        aiFailure: false,
      );

      expect(
        result.facts.any((f) => f.conditionCode == 'ACTIVE_CANCER'),
        false,
      );
    });

    test('Malignant lymphoma with diagnosis language triggers confirmed ACTIVE_CANCER', () {
      final builder = MedicalFactsBuilder();

      final result = builder.build(
        userEnteredConditions: const [],
        userFactsByConditionId: const {},
        aiVetExtraction: const [],
        rawVetTexts: const [
          'Diagnosed malignant lymphoma after biopsy.',
        ],
        aiFailure: false,
      );

      expect(
        result.facts.any(
          (f) => f.conditionCode == 'ACTIVE_CANCER' && f.status == MedicalConditionStatus.confirmed,
        ),
        true,
      );
    });

    test('CKD IRIS stage 4 with diagnosis language confirms CKD_STAGE_3_PLUS', () {
      final builder = MedicalFactsBuilder();

      final result = builder.build(
        userEnteredConditions: const [],
        userFactsByConditionId: const {},
        aiVetExtraction: const [],
        rawVetTexts: const [
          'Diagnosis: CKD IRIS stage 4. Started renal diet.',
        ],
        aiFailure: false,
      );

      expect(
        result.facts.any(
          (f) => f.conditionCode == 'CKD_STAGE_3_PLUS' && f.status == MedicalConditionStatus.confirmed,
        ),
        true,
      );
    });

    test('User-entered condition without user facts does not guess fields', () {
      final builder = MedicalFactsBuilder();

      final condition = MedicalCondition(
        id: 'c1',
        name: 'Hip dysplasia',
        diagnosisDate: DateTime(2024, 1, 1),
        status: 'active',
      );

      final result = builder.build(
        userEnteredConditions: [condition],
        userFactsByConditionId: const {},
        aiVetExtraction: const [],
        rawVetTexts: const [],
        aiFailure: false,
      );

      expect(result.facts.length, 1);
      final fact = result.facts.first;
      expect(fact.conditionCode, 'HIP_DYSPLASIA');
      expect(fact.severity, MedicalConditionSeverity.unknown);
      expect(fact.chronicity, MedicalConditionChronicity.unknown);
      expect(fact.confirmedBy, MedicalConditionConfirmedBy.unknown);
    });
  });
}

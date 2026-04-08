import 'package:flutter_test/flutter_test.dart';
import 'package:pet_underwriter_ai/services/integrity_gate_result.dart';
import 'package:pet_underwriter_ai/services/diagnostic_timing_guard.dart';
import 'package:pet_underwriter_ai/services/medical_facts_builder.dart';
import 'package:pet_underwriter_ai/services/vet_history_parser.dart';

/// Focused test for the Rocky / German Shepherd / Chronic Hip Dysplasia
/// scenario where a vet PDF is uploaded and the AI returns a diagnosis
/// with a fuzzy date and/or missing severity.
void main() {
  group('Vet record parse — Rocky German Shepherd hip dysplasia', () {

    test('VetRecordData.fromJson builds correctly from sanitized output', () {
      // This simulates the output of _sanitizeVetJson after the fix:
      // diagnoses are preserved even with defaulted severity/status.
      final json = <String, dynamic>{
        'diagnoses': [
          {
            'condition': 'Chronic Hip Dysplasia',
            'date': '2024-03-01',
            'status': 'chronic',
            'severity': 'unknown',
            'notes': null,
          },
        ],
        'medications': <dynamic>[],
        'vaccinations': <dynamic>[],
        'treatments': <dynamic>[],
        'surgeries': <dynamic>[],
        'allergies': <dynamic>[],
        'previousClaims': <dynamic>[],
        'lastCheckup': null,
      };

      final record = VetRecordData.fromJson(json);
      expect(record.diagnoses, hasLength(1));
      expect(record.diagnoses[0].condition, 'Chronic Hip Dysplasia');
      expect(record.diagnoses[0].date, DateTime(2024, 3, 1));
      expect(record.diagnoses[0].status, 'chronic');
      expect(record.diagnoses[0].severity, 'unknown');
    });

    test('diagnosis with all defaults round-trips through fromJson', () {
      // Simulates the worst case: only condition was provided, everything
      // else was defaulted by the relaxed sanitizer.
      final today = DateTime.now();
      final dateStr = '${today.year}-'
          '${today.month.toString().padLeft(2, '0')}-'
          '${today.day.toString().padLeft(2, '0')}';

      final json = <String, dynamic>{
        'diagnoses': [
          {
            'condition': 'Chronic Hip Dysplasia',
            'date': dateStr,
            'status': 'active',
            'severity': 'unknown',
            'notes': null,
          },
        ],
        'medications': <dynamic>[],
        'vaccinations': <dynamic>[],
        'treatments': <dynamic>[],
        'surgeries': <dynamic>[],
        'allergies': <dynamic>[],
        'previousClaims': <dynamic>[],
        'lastCheckup': null,
      };

      final record = VetRecordData.fromJson(json);
      expect(record.diagnoses, hasLength(1));
      expect(record.diagnoses[0].condition, 'Chronic Hip Dysplasia');
      expect(record.diagnoses[0].status, 'active');
      expect(record.diagnoses[0].severity, 'unknown');
    });

    test('MedicalFactsBuilder produces facts from AI vet extraction', () {
      final vetRecord = VetRecordData(
        diagnoses: [
          Diagnosis(
            condition: 'Chronic Hip Dysplasia',
            date: DateTime(2024, 3, 1),
            status: 'chronic',
            severity: 'unknown',
          ),
        ],
        medications: const [],
        vaccinations: const [],
        treatments: const [],
        surgeries: const [],
        allergies: const [],
        previousClaims: const [],
      );

      final builder = MedicalFactsBuilder();
      final result = builder.build(
        userEnteredConditions: const [],
        aiVetExtraction: [vetRecord],
        rawVetTexts: const ['Chronic Hip Dysplasia diagnosed March 2024.'],
        aiFailure: false,
      );

      expect(result.facts, isNotEmpty,
          reason: 'Facts builder should produce facts from the vet extraction');
      expect(
        result.facts.any((f) => f.conditionCode.isNotEmpty),
        true,
        reason: 'At least one fact should exist from AI vet extraction',
      );
    });

    test('MedicalFactsBuilder with empty diagnoses — raw text backstop only', () {
      // What used to happen before the fix: sanitizer dropped everything.
      final emptyRecord = VetRecordData(
        diagnoses: const [],
        medications: const [],
        vaccinations: const [],
        treatments: const [],
        surgeries: const [],
        allergies: const [],
        previousClaims: const [],
      );

      final builder = MedicalFactsBuilder();
      final _ = builder.build(
        userEnteredConditions: const [],
        aiVetExtraction: [emptyRecord],
        rawVetTexts: const ['Chronic Hip Dysplasia diagnosed March 2024.'],
        aiFailure: false,
      );

      final withoutText = builder.build(
        userEnteredConditions: const [],
        aiVetExtraction: [emptyRecord],
        rawVetTexts: const [],
        aiFailure: false,
      );

      // With empty diagnoses but raw text, the backstop may find keywords.
      // Without raw text, nothing is produced — this was the broken state.
      expect(withoutText.facts, isEmpty,
          reason: 'No facts when both AI extraction and raw text are empty');
    });

    test('DiagnosticTimingGuard passes when diagnosis dates are present', () {
      final vetRecord = VetRecordData(
        diagnoses: [
          Diagnosis(
            condition: 'Chronic Hip Dysplasia',
            date: DateTime.now().subtract(const Duration(days: 90)),
            status: 'chronic',
            severity: 'unknown',
          ),
        ],
        medications: const [],
        vaccinations: const [],
        treatments: const [],
        surgeries: const [],
        allergies: const [],
        previousClaims: const [],
      );

      final guard = DiagnosticTimingGuard();
      final result = guard.check(
        aiVetExtraction: [vetRecord],
        rawVetTexts: const ['Hip dysplasia diagnosed 3 months ago.'],
      );

      expect(result.action, IntegrityGateAction.pass,
          reason:
              'Guard should pass when a recent diagnosis date is available');
    });

    test('DiagnosticTimingGuard fails when no dates are present', () {
      // Before the fix: all diagnoses dropped → no dates → NEED_MORE_INFO
      final emptyRecord = VetRecordData(
        diagnoses: const [],
        medications: const [],
        vaccinations: const [],
        treatments: const [],
        surgeries: const [],
        allergies: const [],
        previousClaims: const [],
      );

      final guard = DiagnosticTimingGuard();
      final result = guard.check(
        aiVetExtraction: [emptyRecord],
        rawVetTexts: const ['Hip dysplasia diagnosed 3 months ago.'],
      );

      expect(result.action, IntegrityGateAction.needMoreInfo,
          reason:
              'Guard should fail when no structured dates are available');
    });
  });
}

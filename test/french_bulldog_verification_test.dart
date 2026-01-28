import 'dart:io';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_underwriter_ai/services/underwriting_constraint_engine.dart';
import 'package:pet_underwriter_ai/models/pet.dart';
import 'package:pet_underwriter_ai/models/anomaly_flag.dart';

void main() {
  test('Verify French Bulldog 65lbs triggers anomaly/risk', () async {
    // 1. Read the actual asset file from disk
    final file = File('assets/underwriting_constraints/breed_constraints.v1.json');
    if (!file.existsSync()) {
      fail('Asset file not found at ${file.path}');
    }
    final jsonString = file.readAsStringSync();
    final jsonMap = jsonDecode(jsonString);

    // 2. Initialize the engine with the real data
    final engine = UnderwritingConstraintEngine.fromJson(jsonMap);

    // 3. Create the "Ted" scenario
    // 65 lbs is approx 29.5 kg
    final pet = Pet(
      id: 'test-ted',
      name: 'Ted',
      species: 'Dog',
      breed: 'French Bulldog',
      dateOfBirth: DateTime.now().subtract(const Duration(days: 365 * 5)), // 5 years old
      weight: 29.5, // 65 lbs = 29.48 kg
      gender: 'Male',
      isNeutered: true,
      preExistingConditions: [],
    );

    // 4. Run the check
    final assessment = engine.assess(pet: pet);
    final findings = assessment.anomalyFindings;

    // 5. Assert EXPECTED findings
    // We expect at least one finding of type weightOutlier
    final weightFindings = findings.where((f) => f.type == AnomalyFlagType.weightOutlier).toList();
    
    expect(weightFindings, isNotEmpty, reason: 'Should have weightOutlier warnings for 65lb Frenchie');
    
    final finding = weightFindings.first;
    print('Found warning: ${finding.explanation} [Severity: ${finding.severity}]');

    // Check severity - expected to be HIGH or CRITICAL for massive overweight (65 vs max healthy 35)
    // 65 is almost double 35, likely CRITICAL or HIGH
    expect(
      finding.severity == AnomalySeverity.high || finding.severity == AnomalySeverity.critical, 
      isTrue,
      reason: 'Severity should be high or critical for 65lb Frenchie'
    );
     
    expect(
      finding.explanation.toLowerCase(), 
      anyOf(contains('overweight'), contains('expected maximum'))
    );
  });
}

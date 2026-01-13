import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pet_underwriter_ai/models/underwriting_case.dart';
import 'package:pet_underwriter_ai/services/underwriting_decision_engine.dart';
import 'package:pet_underwriter_ai/services/underwriting_rules_engine.dart';

void main() {
  group('UnderwritingDecisionEngine', () {
    test('buildFromEligibility declines when ineligible', () {
      final engine = UnderwritingDecisionEngine();
      final decision = engine.buildFromEligibility(
        eligibility: EligibilityResult.ineligible(
          reason: 'Cancer is excluded',
          ruleViolated: 'critical_condition',
        ),
      );

      expect(decision.outcome.toString(), contains('decline'));
      expect(decision.exclusions, isEmpty);
      expect(decision.reasonCodes, contains('UW_DECLINE'));
      expect(decision.reasonCodes.join(','), contains('UW_RULE_CRITICAL_CONDITION'));
      expect(decision.decidedBy, 'system');
    });

    test('buildFromEligibility approves with exclusions when exclusions present', () {
      final engine = UnderwritingDecisionEngine();
      final decision = engine.buildFromEligibility(
        eligibility: EligibilityResult.eligibleWithExclusions(
          excludedConditions: ['Hip dysplasia', ''],
        ),
        effectiveDate: DateTime(2025, 1, 1),
      );

      expect(decision.outcome.toString(), contains('approveWithExclusions'));
      expect(decision.exclusions.length, 1);
      expect(decision.exclusions.first.conditionName, 'Hip dysplasia');
      expect(decision.exclusions.first.effectiveDate, DateTime(2025, 1, 1));
      expect(decision.reasonCodes, ['UW_APPROVE_WITH_EXCLUSIONS']);
    });

    test('buildFromEligibility approves standard when eligible and no exclusions', () {
      final engine = UnderwritingDecisionEngine();
      final decision = engine.buildFromEligibility(
        eligibility: EligibilityResult.eligible(),
      );

      expect(decision.outcome.toString(), contains('approve'));
      expect(decision.reasonCodes, ['UW_APPROVE_STANDARD']);
      expect(decision.exclusions, isEmpty);
    });
  });

  group('UnderwritingCase.fromJson', () {
    test('parses Firestore Timestamp for createdAt/updatedAt', () {
      final created = Timestamp.fromMillisecondsSinceEpoch(1700000000000);
      final updated = Timestamp.fromMillisecondsSinceEpoch(1700000005000);

      final c = UnderwritingCase.fromJson('case1', {
        'userId': 'u1',
        'status': 'referred',
        'triggerReasons': ['test'],
        'createdAt': created,
        'updatedAt': updated,
      });

      expect(c.createdAt.millisecondsSinceEpoch, created.toDate().millisecondsSinceEpoch);
      expect(c.updatedAt.millisecondsSinceEpoch, updated.toDate().millisecondsSinceEpoch);
    });
  });
}

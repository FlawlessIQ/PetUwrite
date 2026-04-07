import 'package:flutter_test/flutter_test.dart';

import 'package:pet_underwriter_ai/models/policy.dart';

void main() {
  Map<String, dynamic> buildPolicyJson({
    required String status,
    required String paymentSchedule,
  }) {
    return {
      'id': 'pol_123',
      'policyNumber': 'CLV-12345',
      'ownerId': 'owner_1',
      'petId': 'pet_1',
      'quoteId': 'quote_1',
      'issuedAt': '2026-04-01T00:00:00.000Z',
      'effectiveDate': '2026-04-02T00:00:00.000Z',
      'expirationDate': '2027-04-02T00:00:00.000Z',
      'status': status,
      'paymentSchedule': paymentSchedule,
      'claims': const [],
      'plan': {
        'id': 'plan_1',
        'name': 'Clovara Essential',
        'tier': 'PlanTier.basic',
        'monthlyPremium': 42.5,
        'annualDeductible': 500.0,
        'reimbursementPercentage': 80.0,
        'annualLimit': 10000.0,
        'coveredConditions': ['accidents'],
        'exclusions': ['pre-existing conditions'],
        'includesWellness': false,
        'includesDental': false,
      },
    };
  }

  test('Policy.fromJson accepts plain status and payment schedule strings', () {
    final policy = Policy.fromJson(
      buildPolicyJson(
        status: 'active',
        paymentSchedule: 'monthly',
      ),
    );

    expect(policy.status, PolicyStatus.active);
    expect(policy.paymentSchedule, PaymentSchedule.monthly);
  });

  test('Policy.fromJson still accepts legacy enum-style serialized strings', () {
    final policy = Policy.fromJson(
      buildPolicyJson(
        status: 'PolicyStatus.cancelled',
        paymentSchedule: 'PaymentSchedule.annually',
      ),
    );

    expect(policy.status, PolicyStatus.cancelled);
    expect(policy.paymentSchedule, PaymentSchedule.annually);
  });
}

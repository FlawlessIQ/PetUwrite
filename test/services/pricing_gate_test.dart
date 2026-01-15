import 'package:flutter_test/flutter_test.dart';
import 'package:pet_underwriter_ai/services/pricing_gate.dart';

void main() {
  group('PricingGate', () {
    test('allows pricing only when pricingEnabled + APPROVED + integrityPassed',
        () {
      expect(
        PricingGate.isPricingAllowed({
          'pricingEnabled': true,
          'underwritingStatus': 'APPROVED',
          'integrityPassed': true,
        }),
        true,
      );

      expect(
        PricingGate.isPricingAllowed({
          'pricingEnabled': true,
          'underwritingStatus': 'APPROVED',
          'integrityPassed': false,
        }),
        false,
      );

      expect(
        PricingGate.isPricingAllowed({
          'pricingEnabled': true,
          'underwritingStatus': 'NEED_MORE_INFO',
          'integrityPassed': true,
        }),
        false,
      );

      expect(
        PricingGate.isPricingAllowed({
          'pricingEnabled': true,
          'underwritingStatus': 'DECLINED',
          'integrityPassed': true,
        }),
        false,
      );

      expect(
        PricingGate.isPricingAllowed({
          'pricingEnabled': true,
          'underwritingStatus': 'DENIED',
          'integrityPassed': true,
        }),
        false,
      );

      expect(
        PricingGate.isPricingAllowed({
          'pricingEnabled': true,
          'underwritingStatus': 'INCOMPLETE',
          'integrityPassed': true,
        }),
        false,
      );

      expect(
        PricingGate.isPricingAllowed({
          'pricingEnabled': false,
          'underwritingStatus': 'APPROVED',
          'integrityPassed': true,
        }),
        false,
      );
    });

    test('blockReason prefers underwritingReason', () {
      expect(
        PricingGate.blockReason({
          'underwritingReason': 'AI_FAILURE',
        }),
        'AI_FAILURE',
      );

      expect(
        PricingGate.blockReason({
          'underwritingReason': '   ',
        }),
        'UNDERWRITING_INCOMPLETE',
      );
    });
  });
}

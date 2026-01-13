import '../models/policy_exclusion.dart';
import '../models/underwriting_decision.dart';
import 'underwriting_rules_engine.dart';

/// Deterministic coverage-structuring decision engine.
///
/// Inputs are rule/eligibility outputs (not LLM decisions). Produces a
/// first-class [UnderwritingDecision] with reason codes and exclusions.
class UnderwritingDecisionEngine {
  static const int currentVersion = 1;

  UnderwritingDecision buildFromEligibility({
    required EligibilityResult eligibility,
    DateTime? effectiveDate,
    UnderwritingPricingAdjustments? pricingAdjustments,
  }) {
    final decidedAt = DateTime.now();
    final effDate = effectiveDate ?? decidedAt;

    if (!eligibility.eligible) {
      final reasonCodes = <String>{
        'UW_DECLINE',
        if ((eligibility.ruleViolated ?? '').trim().isNotEmpty)
          'UW_RULE_${eligibility.ruleViolated}'.toUpperCase(),
      }.toList();

      return UnderwritingDecision(
        outcome: UnderwritingOutcome.decline,
        reasonCodes: reasonCodes,
        exclusions: const [],
        pricingAdjustments:
            pricingAdjustments ?? UnderwritingPricingAdjustments.defaultAdjustments(),
        decidedAt: decidedAt,
        decidedBy: 'system',
        version: currentVersion,
      );
    }

    if (eligibility.hasExclusions && eligibility.excludedConditions.isNotEmpty) {
      final exclusions = eligibility.excludedConditions
          .where((c) => c.trim().isNotEmpty)
          .map(
            (condition) => PolicyExclusion(
              conditionName: condition,
              scope: 'condition',
              effectiveDate: effDate,
              notes: 'Pre-existing condition exclusion',
            ),
          )
          .toList();

      return UnderwritingDecision(
        outcome: UnderwritingOutcome.approveWithExclusions,
        reasonCodes: const ['UW_APPROVE_WITH_EXCLUSIONS'],
        exclusions: exclusions,
        pricingAdjustments:
            pricingAdjustments ?? UnderwritingPricingAdjustments.defaultAdjustments(),
        decidedAt: decidedAt,
        decidedBy: 'system',
        version: currentVersion,
      );
    }

    return UnderwritingDecision(
      outcome: UnderwritingOutcome.approve,
      reasonCodes: const ['UW_APPROVE_STANDARD'],
      exclusions: const [],
      pricingAdjustments:
          pricingAdjustments ?? UnderwritingPricingAdjustments.defaultAdjustments(),
      decidedAt: decidedAt,
      decidedBy: 'system',
      version: currentVersion,
    );
  }
}

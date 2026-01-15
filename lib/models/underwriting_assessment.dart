import 'underwriting_decision.dart';
import 'underwriting_status.dart';
import 'evidence_requirement.dart';

class UnderwritingAssessment {
  final UnderwritingStatus underwritingStatus;
  final bool pricingEnabled;

  /// Deterministic decision snapshot (system-produced). May be null when
  /// we are missing required evidence and have no decisive outcome.
  final UnderwritingDecision? decision;

  /// Deterministic, self-serve checklist of required evidence.
  ///
  /// Non-empty when underwritingStatus == NEED_MORE_INFO.
  final List<EvidenceRequirement> requiredEvidence;

  /// Human-readable reason for gating.
  final String reason;

  const UnderwritingAssessment({
    required this.underwritingStatus,
    required this.pricingEnabled,
    required this.reason,
    this.decision,
    this.requiredEvidence = const [],
  });
}

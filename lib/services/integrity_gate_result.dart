import '../models/evidence_requirement.dart';

enum IntegrityGateAction {
  pass,
  needMoreInfo,
  decline,
}

/// Deterministic, auditable integrity gate output.
class IntegrityGateResult {
  final IntegrityGateAction action;

  /// Machine-readable reason code.
  final String reason;

  /// Evidence requirements (only meaningful for needMoreInfo).
  final List<EvidenceRequirement> requiredEvidence;

  const IntegrityGateResult._({
    required this.action,
    required this.reason,
    required this.requiredEvidence,
  });

  const IntegrityGateResult.pass()
      : this._(
          action: IntegrityGateAction.pass,
          reason: 'OK',
          requiredEvidence: const [],
        );

  const IntegrityGateResult.needMoreInfo({
    required String reason,
    required List<EvidenceRequirement> requiredEvidence,
  }) : this._(
          action: IntegrityGateAction.needMoreInfo,
          reason: reason,
          requiredEvidence: requiredEvidence,
        );

  const IntegrityGateResult.decline({required String reason})
      : this._(
          action: IntegrityGateAction.decline,
          reason: reason,
          requiredEvidence: const [],
        );
}

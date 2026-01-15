// Strict medical fact model used for underwriting decisions.
//
// Non-negotiable: underwriting logic must ONLY operate on this structure.
// If any required field is missing, underwriting must fail closed.

enum MedicalConditionSeverity { unknown, mild, moderate, severe }

enum MedicalConditionChronicity { unknown, acute, chronic, progressive }

enum MedicalConditionConfirmedBy { unknown, none, generalist, specialist }

enum MedicalConditionStatus { unknown, suspected, confirmed, resolved }

class MedicalConditionFact {
  /// Canonical code, e.g. "HCM", "CHF", "ACTIVE_CANCER", "CKD_STAGE_3_PLUS".
  final String conditionCode;

  final MedicalConditionSeverity severity;
  final MedicalConditionChronicity chronicity;
  final MedicalConditionConfirmedBy confirmedBy;
  final MedicalConditionStatus status;

  const MedicalConditionFact({
    required this.conditionCode,
    required this.severity,
    required this.chronicity,
    required this.confirmedBy,
    required this.status,
  });

  /// True when the fact is sufficient for deterministic underwriting decisions.
  ///
  /// We intentionally do NOT require severity/chronicity/confirmedBy because
  /// customers should not be asked to self-determine these clinical attributes.
  /// If those details are needed, the system must request verifiable evidence
  /// (e.g. vet records) rather than forcing user selection.
  bool get isComplete =>
      conditionCode.trim().isNotEmpty && status != MedicalConditionStatus.unknown;

  Map<String, dynamic> toJson() {
    return {
      'conditionCode': conditionCode,
      'severity': severity.name,
      'chronicity': chronicity.name,
      'confirmedBy': confirmedBy.name,
      'status': status.name,
    };
  }

  factory MedicalConditionFact.fromJson(Map<String, dynamic> json) {
    final code = (json['conditionCode'] ?? '').toString();


    MedicalConditionSeverity? parseSeverity() {
      final raw = (json['severity'] ?? '').toString().trim();
      for (final v in MedicalConditionSeverity.values) {
        if (v.name == raw) return v;
      }
      return null;
    }

    MedicalConditionChronicity? parseChronicity() {
      final raw = (json['chronicity'] ?? '').toString().trim();
      for (final v in MedicalConditionChronicity.values) {
        if (v.name == raw) return v;
      }
      return null;
    }

    MedicalConditionConfirmedBy? parseConfirmedBy() {
      final raw = (json['confirmedBy'] ?? '').toString().trim();
      for (final v in MedicalConditionConfirmedBy.values) {
        if (v.name == raw) return v;
      }
      return null;
    }

    MedicalConditionStatus? parseStatus() {
      final raw = (json['status'] ?? '').toString().trim();
      for (final v in MedicalConditionStatus.values) {
        if (v.name == raw) return v;
      }
      return null;
    }

    return MedicalConditionFact(
      conditionCode: code,
      severity: parseSeverity() ?? MedicalConditionSeverity.unknown,
      chronicity: parseChronicity() ?? MedicalConditionChronicity.unknown,
      confirmedBy: parseConfirmedBy() ?? MedicalConditionConfirmedBy.unknown,
      status: parseStatus() ?? MedicalConditionStatus.unknown,
    );
  }
}

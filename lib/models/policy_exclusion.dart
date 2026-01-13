/// Policy exclusion object used for underwriting decisions and bound policies.
class PolicyExclusion {
  final String conditionName;
  final String scope; // e.g. "condition", "body_system", "diagnosis_group"
  final DateTime effectiveDate;
  final String? notes;

  const PolicyExclusion({
    required this.conditionName,
    required this.scope,
    required this.effectiveDate,
    this.notes,
  });

  factory PolicyExclusion.fromJson(Map<String, dynamic> json) {
    return PolicyExclusion(
      conditionName: (json['conditionName'] ?? '').toString(),
      scope: (json['scope'] ?? 'condition').toString(),
      effectiveDate: DateTime.parse((json['effectiveDate'] ?? DateTime.now().toIso8601String()).toString()),
      notes: json['notes']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conditionName': conditionName,
      'scope': scope,
      'effectiveDate': effectiveDate.toIso8601String(),
      'notes': notes,
    };
  }
}

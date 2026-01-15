class EvidenceRequirement {
  /// Machine-readable identifier.
  ///
  /// Examples:
  /// - ECHO_REPORT
  /// - PATHOLOGY_REPORT
  /// - RECENT_KIDNEY_LABS
  final String code;

  /// Short, user-facing title.
  final String title;

  /// User-facing details/instructions.
  final String details;

  const EvidenceRequirement({
    required this.code,
    required this.title,
    required this.details,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'title': title,
      'details': details,
    };
  }
}

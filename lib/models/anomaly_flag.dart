/// Deterministic anomaly findings emitted by the underwriting constraint engine.
///
/// Why this exists:
/// - We must not rely solely on AI free-text interpretation.
/// - We do not reject user inputs, but we *do* flag implausible combinations
///   and materially adjust risk/pricing while keeping an auditable trail.

enum AnomalyFlagType {
  weightOutlier,
  ageMismatch,
  breedConflict,
  ownerReportingRisk,
}

enum AnomalySeverity {
  low,
  medium,
  high,
  critical,
}

extension AnomalySeverityScore on AnomalySeverity {
  /// A normalized severity score in [0, 1] used for non-linear scaling.
  double get score {
    return switch (this) {
      AnomalySeverity.low => 0.15,
      AnomalySeverity.medium => 0.35,
      AnomalySeverity.high => 0.60,
      AnomalySeverity.critical => 0.90,
    };
  }
}

class AnomalyFlag {
  final AnomalyFlagType type;
  final AnomalySeverity severity;

  /// How much this should reduce confidence in the reported data.
  ///
  /// Range: [0, 1]. Example: 0.25 means confidence should drop by 25%.
  final double confidenceImpact;

  /// Human-readable explanation suitable for carrier review.
  final String explanation;

  const AnomalyFlag({
    required this.type,
    required this.severity,
    required this.confidenceImpact,
    required this.explanation,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name.toUpperCase(),
      'severity': severity.name.toUpperCase(),
      'confidenceImpact': confidenceImpact,
      'explanation': explanation,
    };
  }

  factory AnomalyFlag.fromJson(Map<String, dynamic> json) {
    final typeStr = (json['type'] ?? '').toString();
    final sevStr = (json['severity'] ?? '').toString();

    AnomalyFlagType parseType(String raw) {
      final normalized = raw.trim().toLowerCase();
      for (final v in AnomalyFlagType.values) {
        if (v.name.toLowerCase() == normalized) return v;
        if (v.name.toUpperCase() == raw) return v;
      }
      return switch (normalized) {
        'weight_outlier' || 'weightoutlier' || 'weight-outlier' =>
          AnomalyFlagType.weightOutlier,
        'age_mismatch' || 'agemismatch' || 'age-mismatch' =>
          AnomalyFlagType.ageMismatch,
        'breed_conflict' || 'breedconflict' || 'breed-conflict' =>
          AnomalyFlagType.breedConflict,
        'owner_reporting_risk' || 'ownerreportingrisk' || 'owner-reporting-risk' =>
          AnomalyFlagType.ownerReportingRisk,
        _ => AnomalyFlagType.ownerReportingRisk,
      };
    }

    AnomalySeverity parseSeverity(String raw) {
      final normalized = raw.trim().toLowerCase();
      for (final v in AnomalySeverity.values) {
        if (v.name.toLowerCase() == normalized) return v;
        if (v.name.toUpperCase() == raw) return v;
      }
      return switch (normalized) {
        'low' => AnomalySeverity.low,
        'medium' => AnomalySeverity.medium,
        'high' => AnomalySeverity.high,
        'critical' => AnomalySeverity.critical,
        _ => AnomalySeverity.medium,
      };
    }

    final impactRaw = json['confidenceImpact'];
    final impact = impactRaw is num ? impactRaw.toDouble() : double.tryParse('$impactRaw') ?? 0.0;

    return AnomalyFlag(
      type: parseType(typeStr),
      severity: parseSeverity(sevStr),
      confidenceImpact: impact.clamp(0.0, 1.0),
      explanation: (json['explanation'] ?? '').toString(),
    );
  }
}

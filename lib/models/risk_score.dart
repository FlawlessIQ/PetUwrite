/// Model class for risk assessment scoring
import 'underwriting_exclusion.dart';

class RiskScore {
  final String id;
  final String petId;
  final DateTime calculatedAt;
  final double overallScore; // 0-100
  final RiskLevel riskLevel;
  final Map<String, double> categoryScores;
  final List<RiskFactor> riskFactors;
  final String? aiAnalysis;

  /// Deterministic explainability artifacts (non-negotiable for auditability).
  ///
  /// These are intentionally optional for backward compatibility with stored
  /// historical documents.
  final double? confidenceScore; // 0-1
  final double? physiologicalRiskScore; // 0-100
  final double? credibilityRiskScore; // 0-100
  final double? constraintRiskMultiplier;
  final List<Map<String, dynamic>>? anomalyFindings;
  final List<String>? reviewTriggers;

  /// Deterministic snapshot of constraints used (breed ranges, entered weight, etc).
  ///
  /// JSON-safe and designed to be stored on quote/case records for audit.
  final Map<String, dynamic>? constraintAudit;

  /// Structured underwriting exclusions (rare, targeted, deterministic).
  ///
  /// These are applied after deterministic anomaly detection + eligibility,
  /// and are designed to be auditable and customer-explainable.
  final List<UnderwritingExclusion>? exclusions;

  /// Deterministic evidence requirements for verification-driven risk.
  ///
  /// These are lightweight “codes” that downstream flows can interpret
  /// (e.g., request vet records, verify weight/age/breed). Stored for audit.
  final List<String>? requiredEvidenceCodes;

  RiskScore({
    required this.id,
    required this.petId,
    required this.calculatedAt,
    required this.overallScore,
    required this.riskLevel,
    required this.categoryScores,
    required this.riskFactors,
    this.aiAnalysis,
    this.confidenceScore,
    this.physiologicalRiskScore,
    this.credibilityRiskScore,
    this.constraintRiskMultiplier,
    this.anomalyFindings,
    this.reviewTriggers,
    this.constraintAudit,
    this.exclusions,
    this.requiredEvidenceCodes,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'calculatedAt': calculatedAt.toIso8601String(),
      'overallScore': overallScore,
      'riskLevel': riskLevel.toString(),
      'categoryScores': categoryScores,
      'riskFactors': riskFactors.map((f) => f.toJson()).toList(),
      'aiAnalysis': aiAnalysis,
      if (confidenceScore != null) 'confidenceScore': confidenceScore,
      if (physiologicalRiskScore != null)
        'physiologicalRiskScore': physiologicalRiskScore,
      if (credibilityRiskScore != null)
        'credibilityRiskScore': credibilityRiskScore,
      if (constraintRiskMultiplier != null)
        'constraintRiskMultiplier': constraintRiskMultiplier,
      if (anomalyFindings != null) 'anomalyFindings': anomalyFindings,
      if (reviewTriggers != null) 'reviewTriggers': reviewTriggers,
      if (constraintAudit != null) 'constraintAudit': constraintAudit,
      if (exclusions != null)
        'exclusions': exclusions!.map((e) => e.toJson()).toList(),
      if (requiredEvidenceCodes != null)
        'requiredEvidenceCodes': requiredEvidenceCodes,
    };
  }

  factory RiskScore.fromJson(Map<String, dynamic> json) {
    final anomaliesRaw = json['anomalyFindings'];
    final anomalies = anomaliesRaw is List
        ? anomaliesRaw
              .whereType<Map>()
              .map((e) => e.cast<String, dynamic>())
              .toList(growable: false)
        : null;

    final exclusionsRaw = json['exclusions'];
    final exclusions = exclusionsRaw is List
        ? exclusionsRaw
              .whereType<Map>()
              .map(
                (e) =>
                    UnderwritingExclusion.fromJson(e.cast<String, dynamic>()),
              )
              .toList(growable: false)
        : null;

    return RiskScore(
      id: json['id'] as String,
      petId: json['petId'] as String,
      calculatedAt: DateTime.parse(json['calculatedAt'] as String),
      overallScore: (json['overallScore'] as num).toDouble(),
      riskLevel: RiskLevel.values.firstWhere(
        (e) => e.toString() == json['riskLevel'],
        orElse: () => RiskLevel.medium,
      ),
      categoryScores: Map<String, double>.from(json['categoryScores'] as Map),
      riskFactors: (json['riskFactors'] as List<dynamic>)
          .map((f) => RiskFactor.fromJson(f as Map<String, dynamic>))
          .toList(),
      aiAnalysis: json['aiAnalysis'] as String?,
      confidenceScore: (json['confidenceScore'] is num)
          ? (json['confidenceScore'] as num).toDouble()
          : double.tryParse('${json['confidenceScore']}'),
      physiologicalRiskScore: (json['physiologicalRiskScore'] is num)
          ? (json['physiologicalRiskScore'] as num).toDouble()
          : double.tryParse('${json['physiologicalRiskScore']}'),
      credibilityRiskScore: (json['credibilityRiskScore'] is num)
          ? (json['credibilityRiskScore'] as num).toDouble()
          : double.tryParse('${json['credibilityRiskScore']}'),
      constraintRiskMultiplier: (json['constraintRiskMultiplier'] is num)
          ? (json['constraintRiskMultiplier'] as num).toDouble()
          : double.tryParse('${json['constraintRiskMultiplier']}'),
      anomalyFindings: anomalies,
      reviewTriggers: (json['reviewTriggers'] is List)
          ? (json['reviewTriggers'] as List)
                .map((e) => e.toString())
                .toList(growable: false)
          : null,
      constraintAudit: (json['constraintAudit'] is Map)
          ? (json['constraintAudit'] as Map).cast<String, dynamic>()
          : null,
      exclusions: exclusions,
      requiredEvidenceCodes: (json['requiredEvidenceCodes'] is List)
          ? (json['requiredEvidenceCodes'] as List)
                .map((e) => e.toString())
                .toList(growable: false)
          : null,
    );
  }

  static RiskLevel getRiskLevelFromScore(double score) {
    if (score < 30) return RiskLevel.low;
    if (score < 60) return RiskLevel.medium;
    if (score < 80) return RiskLevel.high;
    return RiskLevel.veryHigh;
  }
}

/// Enum for risk levels
enum RiskLevel { low, medium, high, veryHigh }

/// Model class for individual risk factors
class RiskFactor {
  final String category; // 'age', 'breed', 'preExisting', 'medical history'
  final String description;
  final double impact; // -10 to +10
  final Severity severity;

  RiskFactor({
    required this.category,
    required this.description,
    required this.impact,
    required this.severity,
  });

  Map<String, dynamic> toJson() {
    return {
      'category': category,
      'description': description,
      'impact': impact,
      'severity': severity.toString(),
    };
  }

  factory RiskFactor.fromJson(Map<String, dynamic> json) {
    return RiskFactor(
      category: json['category'] as String,
      description: json['description'] as String,
      impact: (json['impact'] as num).toDouble(),
      severity: Severity.values.firstWhere(
        (e) => e.toString() == json['severity'],
        orElse: () => Severity.medium,
      ),
    );
  }
}

/// Enum for severity levels
enum Severity { low, medium, high, critical }

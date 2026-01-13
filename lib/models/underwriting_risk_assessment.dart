/// Underwriting risk assessment stored separately from decisions.
class UnderwritingRiskAssessment {
  final Map<String, double> actuarialScoreBreakdown;
  final Map<String, dynamic> aiInsights;
  final double confidence; // 0-100
  final List<String> explanations; // plain English, no model/provider mention
  final DateTime createdAt;

  const UnderwritingRiskAssessment({
    required this.actuarialScoreBreakdown,
    required this.aiInsights,
    required this.confidence,
    required this.explanations,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'actuarialScoreBreakdown': actuarialScoreBreakdown,
      'aiInsights': aiInsights,
      'confidence': confidence,
      'explanations': explanations,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory UnderwritingRiskAssessment.fromJson(Map<String, dynamic> json) {
    return UnderwritingRiskAssessment(
      actuarialScoreBreakdown: (json['actuarialScoreBreakdown'] as Map?)
              ?.map((k, v) => MapEntry(k.toString(), (v as num).toDouble())) ??
          const {},
      aiInsights: (json['aiInsights'] as Map?)?.cast<String, dynamic>() ?? const {},
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      explanations: (json['explanations'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      createdAt: DateTime.tryParse((json['createdAt'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}

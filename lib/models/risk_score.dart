/// Model class for risk assessment scoring
class RiskScore {
  final String id;
  final String petId;
  final DateTime calculatedAt;
  final double overallScore; // 0-100
  final RiskLevel riskLevel;
  final Map<String, double> categoryScores;
  final List<RiskFactor> riskFactors;
  final String? aiAnalysis;
  
  RiskScore({
    required this.id,
    required this.petId,
    required this.calculatedAt,
    required this.overallScore,
    required this.riskLevel,
    required this.categoryScores,
    required this.riskFactors,
    this.aiAnalysis,
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
    };
  }
  
  factory RiskScore.fromJson(Map<String, dynamic> json) {
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
enum RiskLevel {
  low,
  medium,
  high,
  veryHigh,
}

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
enum Severity {
  low,
  medium,
  high,
  critical,
}

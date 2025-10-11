import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a single feature contribution to the risk score
/// Used for explainable AI visualization
class FeatureContribution {
  final String feature;
  final double impact; // Can be positive or negative
  final String notes;
  final String category; // age, breed, medical, lifestyle, etc.

  FeatureContribution({
    required this.feature,
    required this.impact,
    required this.notes,
    required this.category,
  });

  Map<String, dynamic> toJson() => {
        'feature': feature,
        'impact': impact,
        'notes': notes,
        'category': category,
      };

  factory FeatureContribution.fromJson(Map<String, dynamic> json) {
    return FeatureContribution(
      feature: json['feature'] as String,
      impact: (json['impact'] as num).toDouble(),
      notes: json['notes'] as String,
      category: json['category'] as String,
    );
  }

  /// Helper to determine if this is a risk-increasing factor
  bool get isRiskIncreasing => impact > 0;

  /// Helper to get absolute impact value
  double get absoluteImpact => impact.abs();
}

/// Explainability data for a risk score calculation
/// Contains detailed breakdown of feature contributions
class ExplainabilityData {
  final String id;
  final String quoteId;
  final DateTime createdAt;
  final double baselineScore; // Starting point (e.g., 50)
  final List<FeatureContribution> contributions;
  final double finalScore;
  final String overallSummary;

  ExplainabilityData({
    required this.id,
    required this.quoteId,
    required this.createdAt,
    required this.baselineScore,
    required this.contributions,
    required this.finalScore,
    required this.overallSummary,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'quoteId': quoteId,
        'createdAt': Timestamp.fromDate(createdAt),
        'baselineScore': baselineScore,
        'contributions': contributions.map((c) => c.toJson()).toList(),
        'finalScore': finalScore,
        'overallSummary': overallSummary,
      };

  factory ExplainabilityData.fromJson(Map<String, dynamic> json) {
    return ExplainabilityData(
      id: json['id'] as String,
      quoteId: json['quoteId'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      baselineScore: (json['baselineScore'] as num).toDouble(),
      contributions: (json['contributions'] as List<dynamic>)
          .map((c) => FeatureContribution.fromJson(c as Map<String, dynamic>))
          .toList(),
      finalScore: (json['finalScore'] as num).toDouble(),
      overallSummary: json['overallSummary'] as String,
    );
  }

  /// Get contributions that increase risk (positive impact)
  List<FeatureContribution> get riskIncreasingFactors =>
      contributions.where((c) => c.impact > 0).toList()
        ..sort((a, b) => b.impact.compareTo(a.impact));

  /// Get contributions that decrease risk (negative impact)
  List<FeatureContribution> get riskDecreasingFactors =>
      contributions.where((c) => c.impact < 0).toList()
        ..sort((a, b) => a.impact.compareTo(b.impact));

  /// Get the top N most impactful features (regardless of direction)
  List<FeatureContribution> getTopFeatures(int n) {
    final sorted = List<FeatureContribution>.from(contributions)
      ..sort((a, b) => b.absoluteImpact.compareTo(a.absoluteImpact));
    return sorted.take(n).toList();
  }

  /// Calculate total positive impact
  double get totalPositiveImpact =>
      contributions.where((c) => c.impact > 0).fold(0.0, (sum, c) => sum + c.impact);

  /// Calculate total negative impact
  double get totalNegativeImpact =>
      contributions.where((c) => c.impact < 0).fold(0.0, (sum, c) => sum + c.impact);

  /// Group contributions by category
  Map<String, List<FeatureContribution>> get contributionsByCategory {
    final Map<String, List<FeatureContribution>> grouped = {};
    for (final contribution in contributions) {
      grouped.putIfAbsent(contribution.category, () => []).add(contribution);
    }
    return grouped;
  }
}

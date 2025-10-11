import 'package:flutter/material.dart';
import '../models/explainability_data.dart';

/// Visual bar chart widget that displays explainability feature contributions
/// Shows positive (risk-increasing) and negative (risk-decreasing) factors
class ExplainabilityChart extends StatelessWidget {
  final ExplainabilityData explainability;
  final int maxFeatures;
  final bool showCategories;

  const ExplainabilityChart({
    super.key,
    required this.explainability,
    this.maxFeatures = 10,
    this.showCategories = true,
  });

  @override
  Widget build(BuildContext context) {
    final topFeatures = explainability.getTopFeatures(maxFeatures);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 16),
            _buildScoreSummary(context),
            const SizedBox(height: 24),
            if (showCategories) ...[
              _buildCategoryTabs(context),
              const SizedBox(height: 16),
            ],
            _buildFeatureList(context, topFeatures),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.analytics, color: Colors.blue),
        const SizedBox(width: 8),
        Text(
          'Risk Score Explanation',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const Spacer(),
        Tooltip(
          message: 'Shows how each factor contributed to the final risk score',
          child: Icon(
            Icons.info_outline,
            color: Colors.grey[600],
            size: 20,
          ),
        ),
      ],
    );
  }

  Widget _buildScoreSummary(BuildContext context) {
    final positiveImpact = explainability.totalPositiveImpact;
    final negativeImpact = explainability.totalNegativeImpact;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildScoreItem(
            context,
            'Baseline',
            explainability.baselineScore,
            Colors.grey,
          ),
          const Icon(Icons.add, color: Colors.grey),
          _buildScoreItem(
            context,
            'Risk Factors',
            positiveImpact,
            Colors.red,
            showSign: true,
          ),
          const Icon(Icons.add, color: Colors.grey),
          _buildScoreItem(
            context,
            'Protective Factors',
            negativeImpact,
            Colors.green,
            showSign: true,
          ),
          const Icon(Icons.arrow_forward, color: Colors.grey),
          _buildScoreItem(
            context,
            'Final Score',
            explainability.finalScore,
            _getScoreColor(explainability.finalScore),
            isFinal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildScoreItem(
    BuildContext context,
    String label,
    double value,
    Color color, {
    bool showSign = false,
    bool isFinal = false,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Colors.grey[700],
              ),
        ),
        const SizedBox(height: 4),
        Text(
          '${showSign && value > 0 ? '+' : ''}${value.toStringAsFixed(1)}',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: color,
                fontWeight: isFinal ? FontWeight.bold : FontWeight.normal,
                fontSize: isFinal ? 20 : 16,
              ),
        ),
      ],
    );
  }

  Widget _buildCategoryTabs(BuildContext context) {
    final byCategory = explainability.contributionsByCategory;

    return Wrap(
      spacing: 8,
      children: byCategory.entries.map((entry) {
        final categoryImpact = entry.value.fold(0.0, (sum, c) => sum + c.impact);
        return Chip(
          avatar: Icon(
            _getCategoryIcon(entry.key),
            size: 16,
            color: categoryImpact > 0 ? Colors.red : Colors.green,
          ),
          label: Text(
            '${_capitalize(entry.key)} (${categoryImpact > 0 ? '+' : ''}${categoryImpact.toStringAsFixed(1)})',
          ),
          backgroundColor: categoryImpact > 0
              ? Colors.red.withOpacity(0.1)
              : Colors.green.withOpacity(0.1),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureList(
    BuildContext context,
    List<FeatureContribution> features,
  ) {
    return Column(
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: _buildFeatureBar(context, feature),
        );
      }).toList(),
    );
  }

  Widget _buildFeatureBar(
    BuildContext context,
    FeatureContribution feature,
  ) {
    final isPositive = feature.impact > 0;
    final maxImpact = explainability.contributions
        .map((c) => c.impact.abs())
        .reduce((a, b) => a > b ? a : b);
    final barWidth = (feature.impact.abs() / maxImpact).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              _getCategoryIcon(feature.category),
              size: 16,
              color: Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                feature.feature,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isPositive
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${isPositive ? '+' : ''}${feature.impact.toStringAsFixed(1)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: isPositive ? Colors.red[700] : Colors.green[700],
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            // Left side (negative/protective)
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: isPositive
                    ? const SizedBox()
                    : Container(
                        height: 24,
                        width: MediaQuery.of(context).size.width * 0.35 * barWidth,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green[300]!, Colors.green[600]!],
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            bottomLeft: Radius.circular(4),
                          ),
                        ),
                      ),
              ),
            ),
            // Center line
            Container(
              width: 2,
              height: 24,
              color: Colors.grey[400],
            ),
            // Right side (positive/risk)
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: isPositive
                    ? Container(
                        height: 24,
                        width: MediaQuery.of(context).size.width * 0.35 * barWidth,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.red[600]!, Colors.red[300]!],
                          ),
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(4),
                            bottomRight: Radius.circular(4),
                          ),
                        ),
                      )
                    : const SizedBox(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 24.0),
          child: Text(
            feature.notes,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'age':
        return Icons.cake;
      case 'breed':
        return Icons.pets;
      case 'medical':
        return Icons.medical_services;
      case 'lifestyle':
        return Icons.home;
      case 'geographic':
        return Icons.location_on;
      default:
        return Icons.info;
    }
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.red;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.amber;
    return Colors.green;
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

/// Compact version of the explainability chart for smaller displays
class ExplainabilityChartCompact extends StatelessWidget {
  final ExplainabilityData explainability;
  final VoidCallback? onExpand;

  const ExplainabilityChartCompact({
    super.key,
    required this.explainability,
    this.onExpand,
  });

  @override
  Widget build(BuildContext context) {
    final topRisk = explainability.riskIncreasingFactors.isNotEmpty
        ? explainability.riskIncreasingFactors.first
        : null;
    final topProtective = explainability.riskDecreasingFactors.isNotEmpty
        ? explainability.riskDecreasingFactors.first
        : null;

    return Card(
      child: InkWell(
        onTap: onExpand,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.analytics, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Risk Explanation',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  if (onExpand != null)
                    const Icon(Icons.expand_more, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Final Score',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      Text(
                        explainability.finalScore.toStringAsFixed(1),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _getScoreColor(explainability.finalScore),
                            ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (topRisk != null) ...[
                        Text(
                          'Top Risk: ${topRisk.feature}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Text(
                          '+${topRisk.impact.toStringAsFixed(1)}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              if (topProtective != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Top Protective: ${topProtective.feature} (${topProtective.impact.toStringAsFixed(1)})',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.green[700],
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return Colors.red;
    if (score >= 60) return Colors.orange;
    if (score >= 40) return Colors.amber;
    return Colors.green;
  }
}

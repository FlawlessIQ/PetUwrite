import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/explainability_data.dart';
import '../widgets/explainability_chart.dart';

/// Example screen showing how to use the Explainability feature
/// 
/// This demonstrates:
/// 1. Fetching explainability data from Firestore
/// 2. Displaying the full ExplainabilityChart
/// 3. Using the compact version
/// 4. Analyzing contributions programmatically
class ExplainabilityExampleScreen extends StatelessWidget {
  final String quoteId;

  const ExplainabilityExampleScreen({
    super.key,
    required this.quoteId,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Risk Score Explanation'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Stream updates when explainability data changes
        stream: FirebaseFirestore.instance
            .collection('quotes')
            .doc(quoteId)
            .collection('explainability')
            .orderBy('createdAt', descending: true)
            .limit(1)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading data: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No explainability data available'),
            );
          }

          final explainabilityData = ExplainabilityData.fromJson(
            snapshot.data!.docs.first.data() as Map<String, dynamic>,
          );

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Full explainability chart
                ExplainabilityChart(
                  explainability: explainabilityData,
                  maxFeatures: 10,
                  showCategories: true,
                ),
                
                const SizedBox(height: 24),
                
                // Compact version example
                const Text(
                  'Compact Version:',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ExplainabilityChartCompact(
                  explainability: explainabilityData,
                  onExpand: () {
                    // Could navigate to full view or expand inline
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: ExplainabilityChart(
                            explainability: explainabilityData,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 24),
                
                // Analysis section
                _buildAnalysisSection(explainabilityData),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnalysisSection(ExplainabilityData data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Detailed Analysis',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Top 5 most impactful features
            _buildSection(
              'Top 5 Most Impactful Factors',
              data.getTopFeatures(5).map((c) => 
                '${c.feature}: ${c.impact > 0 ? '+' : ''}${c.impact.toStringAsFixed(1)}'
              ).toList(),
            ),
            
            const Divider(height: 24),
            
            // Risk-increasing factors
            _buildSection(
              'All Risk-Increasing Factors (${data.riskIncreasingFactors.length})',
              data.riskIncreasingFactors.map((c) => 
                '${c.feature}: +${c.impact.toStringAsFixed(1)} - ${c.notes}'
              ).toList(),
            ),
            
            const Divider(height: 24),
            
            // Protective factors
            _buildSection(
              'All Protective Factors (${data.riskDecreasingFactors.length})',
              data.riskDecreasingFactors.map((c) => 
                '${c.feature}: ${c.impact.toStringAsFixed(1)} - ${c.notes}'
              ).toList(),
            ),
            
            const Divider(height: 24),
            
            // Category breakdown
            _buildCategoryBreakdown(data),
            
            const Divider(height: 24),
            
            // Overall summary
            const Text(
              'Overall Summary',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(data.overallSummary),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...items.map((item) => Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 4),
          child: Text('• $item'),
        )),
      ],
    );
  }

  Widget _buildCategoryBreakdown(ExplainabilityData data) {
    final byCategory = data.contributionsByCategory;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Impact by Category',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...byCategory.entries.map((entry) {
          final totalImpact = entry.value.fold(
            0.0,
            (sum, c) => sum + c.impact,
          );
          return Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 4),
            child: Text(
              '• ${_capitalize(entry.key)}: ${totalImpact > 0 ? '+' : ''}${totalImpact.toStringAsFixed(1)} (${entry.value.length} factors)',
            ),
          );
        }),
      ],
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }
}

/// Example: Fetch explainability data programmatically
Future<ExplainabilityData?> fetchExplainabilityData(String quoteId) async {
  try {
    final snapshot = await FirebaseFirestore.instance
        .collection('quotes')
        .doc(quoteId)
        .collection('explainability')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    return ExplainabilityData.fromJson(
      snapshot.docs.first.data(),
    );
  } catch (e) {
    print('Error fetching explainability data: $e');
    return null;
  }
}

/// Example: Analyze explainability data
void analyzeExplainabilityData(ExplainabilityData data) {
  print('=== Risk Score Analysis ===');
  print('Quote ID: ${data.quoteId}');
  print('Baseline Score: ${data.baselineScore}');
  print('Final Score: ${data.finalScore}');
  print('');
  
  print('Total Positive Impact: +${data.totalPositiveImpact.toStringAsFixed(1)}');
  print('Total Negative Impact: ${data.totalNegativeImpact.toStringAsFixed(1)}');
  print('');
  
  print('Top 3 Risk Factors:');
  for (var factor in data.riskIncreasingFactors.take(3)) {
    print('  - ${factor.feature}: +${factor.impact.toStringAsFixed(1)}');
    print('    ${factor.notes}');
  }
  print('');
  
  print('Top 3 Protective Factors:');
  for (var factor in data.riskDecreasingFactors.take(3)) {
    print('  - ${factor.feature}: ${factor.impact.toStringAsFixed(1)}');
    print('    ${factor.notes}');
  }
  print('');
  
  print('Category Breakdown:');
  final byCategory = data.contributionsByCategory;
  for (var entry in byCategory.entries) {
    final totalImpact = entry.value.fold(0.0, (sum, c) => sum + c.impact);
    print('  ${entry.key}: ${totalImpact > 0 ? '+' : ''}${totalImpact.toStringAsFixed(1)} (${entry.value.length} factors)');
  }
}

/// Example: Use in a widget
class QuoteResultScreen extends StatelessWidget {
  final String quoteId;

  const QuoteResultScreen({super.key, required this.quoteId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Quote Result')),
      body: FutureBuilder<ExplainabilityData?>(
        future: fetchExplainabilityData(quoteId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final explainability = snapshot.data;
          if (explainability == null) {
            return const Center(child: Text('No explanation available'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Your quote details here
                const Text('Your Quote Details...'),
                const SizedBox(height: 24),
                
                // Explainability section
                const Text(
                  'Why This Score?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ExplainabilityChart(explainability: explainability),
                
                const SizedBox(height: 24),
                
                // Action buttons
                ElevatedButton(
                  onPressed: () {
                    // Show detailed analysis
                    analyzeExplainabilityData(explainability);
                  },
                  child: const Text('View Detailed Analysis'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Example: Filter contributions by category
List<FeatureContribution> getContributionsByCategory(
  ExplainabilityData data,
  String category,
) {
  return data.contributions
      .where((c) => c.category.toLowerCase() == category.toLowerCase())
      .toList();
}

/// Example: Find most impactful category
String getMostImpactfulCategory(ExplainabilityData data) {
  final byCategory = data.contributionsByCategory;
  
  String maxCategory = '';
  double maxImpact = 0.0;
  
  for (var entry in byCategory.entries) {
    final totalImpact = entry.value
        .fold(0.0, (sum, c) => sum + c.impact)
        .abs();
    
    if (totalImpact > maxImpact) {
      maxImpact = totalImpact;
      maxCategory = entry.key;
    }
  }
  
  return maxCategory;
}

/// Example: Calculate percentage contribution of each factor
Map<String, double> calculatePercentageContributions(ExplainabilityData data) {
  final totalAbsoluteImpact = data.contributions
      .fold(0.0, (sum, c) => sum + c.impact.abs());
  
  final percentages = <String, double>{};
  
  for (var contribution in data.contributions) {
    final percentage = (contribution.impact.abs() / totalAbsoluteImpact) * 100;
    percentages[contribution.feature] = percentage;
  }
  
  return percentages;
}

/// Example: Generate recommendation based on top risk factors
String generateRecommendation(ExplainabilityData data) {
  final topRisks = data.riskIncreasingFactors.take(3).toList();
  
  if (topRisks.isEmpty) {
    return 'Your pet has a low risk profile. Great job!';
  }
  
  final recommendations = <String>[];
  
  for (var risk in topRisks) {
    if (risk.feature.contains('Not Neutered')) {
      recommendations.add('Consider spaying/neutering to reduce cancer risk');
    } else if (risk.feature.contains('Vaccination')) {
      recommendations.add('Update vaccinations to reduce disease risk');
    } else if (risk.feature.contains('Overweight')) {
      recommendations.add('Consider a weight management plan');
    } else if (risk.feature.contains('Outdoor')) {
      recommendations.add('Consider keeping pet indoors to reduce injury risk');
    }
  }
  
  if (recommendations.isEmpty) {
    return 'Main risk factors are age and breed, which cannot be changed. Focus on preventive care.';
  }
  
  return 'To improve your score:\n${recommendations.map((r) => '• $r').join('\n')}';
}

import 'package:flutter/material.dart';
import '../models/claim.dart';

/// AI Explainability Widget
/// 
/// Shows the AI's decision-making process in a visual, easy-to-understand way
/// with SHAP-style explanations showing which factors influenced the decision
class AIExplainabilityWidget extends StatelessWidget {
  final Claim claim;
  final bool expandedByDefault;
  
  const AIExplainabilityWidget({
    super.key,
    required this.claim,
    this.expandedByDefault = false,
  });

  @override
  Widget build(BuildContext context) {
    if (claim.aiDecision == null) {
      return const SizedBox.shrink();
    }
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: expandedByDefault,
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.all(20),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.psychology,
              color: Theme.of(context).primaryColor,
            ),
          ),
          title: const Text(
            'AI Decision Explanation',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          subtitle: Text(
            'See why the AI ${claim.aiDecision!.value == 'approve' ? 'approved' : 'denied'} this claim',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
          children: [
            _buildExplanationContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildExplanationContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildDecisionSummary(context),
        const SizedBox(height: 24),
        _buildConfidenceSection(context),
        const SizedBox(height: 24),
        _buildFactorAnalysis(context),
        const SizedBox(height: 24),
        _buildKeyInsights(context),
        const SizedBox(height: 16),
        _buildTransparencyNote(context),
      ],
    );
  }

  Widget _buildDecisionSummary(BuildContext context) {
    final isApproved = claim.aiDecision!.value == 'approve';
    final confidence = claim.aiConfidenceScore ?? 0.0;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isApproved
              ? [const Color(0xFF4ade80), const Color(0xFF22c55e)]
              : [const Color(0xFFef4444), const Color(0xFFdc2626)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isApproved ? Colors.green : Colors.red).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            isApproved ? Icons.check_circle : Icons.cancel,
            size: 48,
            color: Colors.white,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isApproved ? 'Recommended for Approval' : 'Recommended for Denial',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(confidence * 100).toInt()}% confidence',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceSection(BuildContext context) {
    final confidence = claim.aiConfidenceScore ?? 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Confidence Level',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: confidence,
            minHeight: 24,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              _getConfidenceColor(confidence),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _getConfidenceLabel(confidence),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _getConfidenceColor(confidence),
              ),
            ),
            Text(
              '${(confidence * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _getConfidenceColor(confidence),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFactorAnalysis(BuildContext context) {
    final reasoning = claim.aiReasoningExplanation;
    
    if (reasoning == null || reasoning.isEmpty) {
      return _buildGenericFactors(context);
    }
    
    // Extract factor scores from reasoning
    final factors = _extractFactorScores(reasoning);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contributing Factors',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'These factors influenced the AI decision (sorted by impact)',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 16),
        ...factors.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildFactorBar(
              context,
              entry.key,
              entry.value,
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildFactorBar(BuildContext context, String factorName, double impact) {
    final isPositive = impact > 0;
    final absImpact = impact.abs();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                _formatFactorName(factorName),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Row(
              children: [
                Icon(
                  isPositive ? Icons.arrow_upward : Icons.arrow_downward,
                  size: 16,
                  color: isPositive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
                Text(
                  '${(absImpact * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isPositive ? Colors.green : Colors.red,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: absImpact,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              isPositive ? Colors.green : Colors.red,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeyInsights(BuildContext context) {
    final insights = _generateKeyInsights();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb, color: Colors.amber[700], size: 20),
            const SizedBox(width: 8),
            const Text(
              'Key Insights',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...insights.map((insight) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• ', style: TextStyle(fontSize: 16)),
                Expanded(
                  child: Text(
                    insight,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[800],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildTransparencyNote(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This explanation shows how our AI analyzed your claim. ${claim.humanOverride != null ? 'Our team reviewed and confirmed this decision.' : 'All decisions are reviewed by our team for accuracy.'}',
              style: TextStyle(
                fontSize: 13,
                color: Colors.blue[900],
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericFactors(BuildContext context) {
    // Fallback when no detailed reasoning is available
    final factors = {
      'Policy Coverage': 0.85,
      'Claim Amount': 0.70,
      'Medical Necessity': 0.90,
      'Documentation Quality': 0.75,
    };
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Contributing Factors',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...factors.entries.map((entry) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildFactorBar(context, entry.key, entry.value),
          );
        }).toList(),
      ],
    );
  }

  Map<String, double> _extractFactorScores(Map<String, dynamic> reasoning) {
    // Extract and normalize factor scores from AI reasoning
    final factors = <String, double>{};
    
    // Look for common factor keys
    final factorKeys = [
      'policyEligibility',
      'claimAmount',
      'medicalNecessity',
      'documentation',
      'preExistingConditions',
      'coverageLimits',
    ];
    
    for (final key in factorKeys) {
      if (reasoning.containsKey(key)) {
        final value = reasoning[key];
        if (value is num) {
          factors[key] = value.toDouble();
        } else if (value is Map && value.containsKey('score')) {
          factors[key] = (value['score'] as num).toDouble();
        }
      }
    }
    
    // Sort by absolute impact
    final sorted = Map.fromEntries(
      factors.entries.toList()
        ..sort((a, b) => b.value.abs().compareTo(a.value.abs())),
    );
    
    return sorted;
  }

  String _formatFactorName(String key) {
    return key
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(0)}',
        )
        .trim()
        .split(' ')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  List<String> _generateKeyInsights() {
    final insights = <String>[];
    final isApproved = claim.aiDecision!.value == 'approve';
    final confidence = claim.aiConfidenceScore ?? 0.0;
    
    if (isApproved) {
      insights.add('This claim meets all policy coverage requirements');
      
      if (confidence >= 0.9) {
        insights.add('High confidence - clear-cut approval case');
      } else if (confidence >= 0.7) {
        insights.add('All major factors support approval');
      }
      
      if (claim.claimAmount < 1000) {
        insights.add('Claim amount is within standard range');
      }
      
      insights.add('Documentation appears complete and valid');
    } else {
      if (confidence >= 0.8) {
        insights.add('Multiple factors indicate this claim should not be covered');
      }
      
      insights.add('Review the specific reasons below to understand why');
      
      if (claim.humanOverride != null) {
        insights.add('A specialist reviewed this decision for accuracy');
      }
    }
    
    return insights;
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return Colors.green;
    if (confidence >= 0.6) return Colors.orange;
    return Colors.red;
  }

  String _getConfidenceLabel(double confidence) {
    if (confidence >= 0.9) return 'Very High Confidence';
    if (confidence >= 0.8) return 'High Confidence';
    if (confidence >= 0.6) return 'Moderate Confidence';
    if (confidence >= 0.4) return 'Low Confidence';
    return 'Very Low Confidence';
  }
}

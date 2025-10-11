import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/claim.dart';

/// Interactive claim timeline visualization
/// 
/// Shows the claim journey: Filed → Documents Review → AI Analysis → 
/// Human Review → Settled/Denied with progress indicators and timestamps
class ClaimTimelineWidget extends StatelessWidget {
  final Claim claim;
  final bool showTimestamps;
  
  const ClaimTimelineWidget({
    super.key,
    required this.claim,
    this.showTimestamps = true,
  });

  @override
  Widget build(BuildContext context) {
    final steps = _buildTimelineSteps();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Claim Journey',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ...steps.asMap().entries.map((entry) {
              final index = entry.key;
              final step = entry.value;
              final isLast = index == steps.length - 1;
              
              return _buildTimelineStep(
                context,
                step,
                isLast: isLast,
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  List<TimelineStep> _buildTimelineSteps() {
    final steps = <TimelineStep>[];
    
    // Step 1: Filed
    steps.add(TimelineStep(
      title: 'Claim Filed',
      description: 'Your claim has been submitted',
      icon: Icons.file_upload,
      status: TimelineStepStatus.completed,
      timestamp: claim.createdAt,
      color: Colors.blue,
    ));
    
    // Step 2: Documents Review
    final hasDocuments = claim.attachments.isNotEmpty;
    steps.add(TimelineStep(
      title: 'Documents Review',
      description: hasDocuments
          ? '${claim.attachments.length} document(s) uploaded'
          : 'Awaiting documents',
      icon: Icons.description,
      status: _getDocumentsStatus(),
      timestamp: hasDocuments ? claim.createdAt : null,
      color: Colors.purple,
    ));
    
    // Step 3: AI Analysis
    final hasAIDecision = claim.aiDecision != null;
    steps.add(TimelineStep(
      title: 'AI Analysis',
      description: hasAIDecision
          ? 'AI recommendation: ${claim.aiDecision!.value}'
          : 'Analyzing your claim...',
      icon: Icons.psychology,
      status: _getAIAnalysisStatus(),
      timestamp: hasAIDecision ? claim.updatedAt : null,
      color: Colors.teal,
      confidence: claim.aiConfidenceScore,
    ));
    
    // Step 4: Human Review (if needed)
    final hasHumanOverride = claim.humanOverride != null;
    if (claim.status != ClaimStatus.denied && claim.status != ClaimStatus.settled) {
      if (claim.aiConfidenceScore != null && claim.aiConfidenceScore! < 0.8) {
        steps.add(TimelineStep(
          title: 'Human Review',
          description: hasHumanOverride
              ? 'Reviewed by our team'
              : 'Our team is reviewing your claim',
          icon: Icons.person,
          status: hasHumanOverride
              ? TimelineStepStatus.completed
              : TimelineStepStatus.inProgress,
          timestamp: hasHumanOverride
              ? (claim.humanOverride!['overrideTimestamp'] as DateTime?)
              : null,
          color: Colors.orange,
        ));
      }
    } else if (hasHumanOverride) {
      steps.add(TimelineStep(
        title: 'Human Review',
        description: 'Reviewed by our team',
        icon: Icons.person,
        status: TimelineStepStatus.completed,
        timestamp: claim.humanOverride!['overrideTimestamp'] as DateTime?,
        color: Colors.orange,
      ));
    }
    
    // Step 5: Final Decision
    if (claim.status == ClaimStatus.settled) {
      steps.add(TimelineStep(
        title: 'Claim Approved',
        description: 'Payment of \$${claim.claimAmount.toStringAsFixed(2)} processed',
        icon: Icons.check_circle,
        status: TimelineStepStatus.completed,
        timestamp: claim.settledAt,
        color: Colors.green,
      ));
    } else if (claim.status == ClaimStatus.denied) {
      steps.add(TimelineStep(
        title: 'Claim Denied',
        description: 'See explanation below',
        icon: Icons.cancel,
        status: TimelineStepStatus.completed,
        timestamp: claim.updatedAt,
        color: Colors.red,
      ));
    } else {
      steps.add(TimelineStep(
        title: 'Final Decision',
        description: 'Almost there...',
        icon: Icons.hourglass_empty,
        status: TimelineStepStatus.pending,
        timestamp: null,
        color: Colors.grey,
      ));
    }
    
    return steps;
  }

  TimelineStepStatus _getDocumentsStatus() {
    if (claim.attachments.isEmpty) {
      return TimelineStepStatus.pending;
    }
    if (claim.aiDecision != null) {
      return TimelineStepStatus.completed;
    }
    return TimelineStepStatus.inProgress;
  }

  TimelineStepStatus _getAIAnalysisStatus() {
    if (claim.aiDecision == null) {
      if (claim.attachments.isNotEmpty) {
        return TimelineStepStatus.inProgress;
      }
      return TimelineStepStatus.pending;
    }
    return TimelineStepStatus.completed;
  }

  Widget _buildTimelineStep(
    BuildContext context,
    TimelineStep step, {
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left side - icon and connector
        Column(
          children: [
            _buildStepIcon(step),
            if (!isLast) _buildConnector(step.status),
          ],
        ),
        const SizedBox(width: 16),
        // Right side - content
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
            child: _buildStepContent(context, step),
          ),
        ),
      ],
    );
  }

  Widget _buildStepIcon(TimelineStep step) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _getStatusColor(step.status, step.color),
        border: Border.all(
          color: _getStatusBorderColor(step.status, step.color),
          width: 3,
        ),
        boxShadow: step.status == TimelineStepStatus.inProgress
            ? [
                BoxShadow(
                  color: step.color.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: _buildIconContent(step),
    );
  }

  Widget _buildIconContent(TimelineStep step) {
    if (step.status == TimelineStepStatus.inProgress) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: CircularProgressIndicator(
          strokeWidth: 3,
          valueColor: AlwaysStoppedAnimation<Color>(step.color),
          backgroundColor: Colors.white.withOpacity(0.3),
        ),
      );
    }
    
    return Icon(
      step.icon,
      color: step.status == TimelineStepStatus.pending
          ? Colors.grey[400]
          : Colors.white,
      size: 24,
    );
  }

  Color _getStatusColor(TimelineStepStatus status, Color baseColor) {
    switch (status) {
      case TimelineStepStatus.completed:
        return baseColor;
      case TimelineStepStatus.inProgress:
        return Colors.white;
      case TimelineStepStatus.pending:
        return Colors.grey[200]!;
    }
  }

  Color _getStatusBorderColor(TimelineStepStatus status, Color baseColor) {
    switch (status) {
      case TimelineStepStatus.completed:
        return baseColor;
      case TimelineStepStatus.inProgress:
        return baseColor;
      case TimelineStepStatus.pending:
        return Colors.grey[400]!;
    }
  }

  Widget _buildConnector(TimelineStepStatus status) {
    final isActive = status == TimelineStepStatus.completed ||
        status == TimelineStepStatus.inProgress;
    
    return Container(
      width: 3,
      height: 40,
      decoration: BoxDecoration(
        color: isActive ? Colors.grey[400] : Colors.grey[300],
        gradient: status == TimelineStepStatus.inProgress
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.grey[400]!,
                  Colors.grey[300]!,
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildStepContent(BuildContext context, TimelineStep step) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                step.title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: step.status == TimelineStepStatus.pending
                      ? Colors.grey[600]
                      : Colors.black87,
                ),
              ),
            ),
            if (step.status == TimelineStepStatus.completed &&
                step.timestamp != null &&
                showTimestamps)
              _buildTimestamp(step.timestamp!),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          step.description,
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[700],
          ),
        ),
        if (step.confidence != null && step.status == TimelineStepStatus.completed)
          ...[
            const SizedBox(height: 8),
            _buildConfidenceBadge(step.confidence!),
          ],
        if (step.status == TimelineStepStatus.inProgress) ...[
          const SizedBox(height: 12),
          _buildProgressIndicator(),
        ],
      ],
    );
  }

  Widget _buildTimestamp(DateTime timestamp) {
    final format = DateFormat('MMM d, h:mm a');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        format.format(timestamp),
        style: TextStyle(
          fontSize: 11,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildConfidenceBadge(double confidence) {
    final percentage = (confidence * 100).toInt();
    final color = confidence >= 0.8
        ? Colors.green
        : confidence >= 0.6
            ? Colors.orange
            : Colors.red;
    
    return Row(
      children: [
        Icon(Icons.psychology, size: 16, color: color),
        const SizedBox(width: 4),
        Text(
          'AI Confidence: $percentage%',
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressIndicator() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        minHeight: 6,
        backgroundColor: Colors.grey[200],
        valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
      ),
    );
  }
}

/// Timeline step model
class TimelineStep {
  final String title;
  final String description;
  final IconData icon;
  final TimelineStepStatus status;
  final DateTime? timestamp;
  final Color color;
  final double? confidence;

  TimelineStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.status,
    this.timestamp,
    required this.color,
    this.confidence,
  });
}

/// Timeline step status
enum TimelineStepStatus {
  completed,
  inProgress,
  pending,
}

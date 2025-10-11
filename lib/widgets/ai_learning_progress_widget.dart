import 'package:flutter/material.dart';
import 'package:pet_underwriter_ai/services/ai_retraining_service.dart';
import 'package:intl/intl.dart';

/// Dashboard widget showing AI model training progress
/// 
/// Displays:
/// - Total training records collected
/// - Current batch progress toward 500 records
/// - AI accuracy metrics (accuracy, precision, recall, F1)
/// - Label distribution visualization
/// - Recent batch exports
/// - Manual export trigger button
class AILearningProgressWidget extends StatefulWidget {
  const AILearningProgressWidget({super.key});

  @override
  State<AILearningProgressWidget> createState() => _AILearningProgressWidgetState();
}

class _AILearningProgressWidgetState extends State<AILearningProgressWidget> {
  final AIRetrainingService _retrainingService = AIRetrainingService();
  TrainingStats? _stats;
  List<TrainingBatch>? _recentBatches;
  bool _isLoading = true;
  bool _isExporting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stats = await _retrainingService.getTrainingStats();
      final batches = await _retrainingService.getRecentBatches(limit: 5);

      setState(() {
        _stats = stats;
        _recentBatches = batches;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerExport() async {
    if (_stats == null || _stats!.recordsInCurrentBatch == 0) {
      _showSnackBar('No records in current batch to export', isError: true);
      return;
    }

    // Get current batch ID from recent batches
    final currentBatch = _recentBatches?.firstWhere(
      (b) => b.status == 'active',
      orElse: () => _recentBatches!.first,
    );

    if (currentBatch == null) {
      _showSnackBar('No active batch found', isError: true);
      return;
    }

    // Confirm before exporting
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Export'),
        content: Text(
          'Export current batch with ${_stats!.recordsInCurrentBatch} records?\n\n'
          'This will prepare the data for AI model fine-tuning.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isExporting = true);

    try {
      await _retrainingService.triggerBatchExport(currentBatch.batchId);
      _showSnackBar('Batch export initiated successfully');
      await _loadData(); // Reload to show updated state
    } catch (e) {
      _showSnackBar('Export failed: $e', isError: true);
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            const SizedBox(height: 24),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              _buildError()
            else ...[
              _buildOverviewSection(),
              const Divider(height: 32),
              _buildBatchProgressSection(),
              const Divider(height: 32),
              _buildMetricsSection(),
              const Divider(height: 32),
              _buildLabelDistributionSection(),
              const Divider(height: 32),
              _buildRecentBatchesSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.psychology, size: 32, color: Theme.of(context).primaryColor),
            const SizedBox(width: 12),
            const Text(
              'AI Learning Progress',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _isLoading ? null : _loadData,
              tooltip: 'Refresh data',
            ),
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: _isExporting ? null : _triggerExport,
              icon: _isExporting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload),
              label: Text(_isExporting ? 'Exporting...' : 'Export Batch'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error loading training data',
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewSection() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Total Records',
            _stats!.totalRecords.toString(),
            Icons.dataset,
            Colors.blue,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Completed Batches',
            _stats!.completedBatches.toString(),
            Icons.archive,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Avg Accuracy',
            '${(_stats!.accuracyMetrics['accuracy']! * 100).toStringAsFixed(1)}%',
            Icons.track_changes,
            Colors.purple,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'F1 Score',
            _stats!.accuracyMetrics['f1Score']!.toStringAsFixed(3),
            Icons.analytics,
            Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchProgressSection() {
    final progress = _stats!.currentBatchProgress;
    final recordCount = _stats!.recordsInCurrentBatch;
    const targetSize = 500;
    final percentage = progress * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Current Batch Progress',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              '$recordCount / $targetSize records',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 24,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(
              percentage < 50 ? Colors.orange : Colors.green,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${percentage.toStringAsFixed(1)}% complete',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        if (percentage >= 100)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '✅ Batch ready for export',
              style: TextStyle(
                fontSize: 14,
                color: Colors.green[700],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMetricsSection() {
    final metrics = _stats!.accuracyMetrics;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Model Performance Metrics',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricBar(
                'Accuracy',
                metrics['accuracy']!,
                Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricBar(
                'Precision',
                metrics['precision']!,
                Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildMetricBar(
                'Recall',
                metrics['recall']!,
                Colors.orange,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildMetricBar(
                'F1 Score',
                metrics['f1Score']!,
                Colors.purple,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            Text(
              '${(value * 100).toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 8,
            backgroundColor: Colors.grey[200],
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildLabelDistributionSection() {
    final distribution = _stats!.labelDistribution;
    
    if (distribution.isEmpty) {
      return const SizedBox.shrink();
    }

    final total = distribution.values.fold<int>(0, (sum, count) => sum + count);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Label Distribution',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ...distribution.entries.map((entry) {
          final percentage = (entry.value / total) * 100;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatLabelName(entry.key),
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      '${entry.value} (${percentage.toStringAsFixed(1)}%)',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: entry.value / total,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      _getLabelColor(entry.key),
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

  String _formatLabelName(String label) {
    return label
        .split('_')
        .map((word) => word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }

  Color _getLabelColor(String label) {
    switch (label) {
      case 'approved_correct':
      case 'denied_correct':
        return Colors.green;
      case 'false_approval':
        return Colors.orange;
      case 'false_denial':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _buildRecentBatchesSection() {
    if (_recentBatches == null || _recentBatches!.isEmpty) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Batches',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16),
          Center(
            child: Text(
              'No batches completed yet',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recent Batches',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        ..._recentBatches!.map((batch) => _buildBatchItem(batch)).toList(),
      ],
    );
  }

  Widget _buildBatchItem(TrainingBatch batch) {
    final dateFormat = DateFormat('MMM d, yyyy HH:mm');
    final statusColor = _getBatchStatusColor(batch.status);
    final statusIcon = _getBatchStatusIcon(batch.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Batch ${batch.batchId.substring(batch.batchId.length - 8)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${batch.recordCount} records • ${dateFormat.format(batch.createdAt)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              batch.status.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: statusColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getBatchStatusColor(String status) {
    switch (status) {
      case 'active':
        return Colors.blue;
      case 'completed':
        return Colors.orange;
      case 'exported':
        return Colors.green;
      case 'export_failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getBatchStatusIcon(String status) {
    switch (status) {
      case 'active':
        return Icons.pending;
      case 'completed':
        return Icons.check_circle_outline;
      case 'exported':
        return Icons.cloud_done;
      case 'export_failed':
        return Icons.error_outline;
      default:
        return Icons.help_outline;
    }
  }
}

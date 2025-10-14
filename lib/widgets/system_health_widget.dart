import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/reconciliation_service.dart';

/// System Health Dashboard Widget
/// Displays reconciliation statistics, failed operations, and system health score
class SystemHealthWidget extends StatefulWidget {
  const SystemHealthWidget({super.key});

  @override
  State<SystemHealthWidget> createState() => _SystemHealthWidgetState();
}

class _SystemHealthWidgetState extends State<SystemHealthWidget> {
  final ReconciliationService _reconciliationService = ReconciliationService();

  SystemHealthScore? _healthScore;
  ReconciliationStats? _latestStats;
  List<FailedOperation>? _failedOperations;
  bool _isLoading = true;
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
      final results = await Future.wait([
        _reconciliationService.calculateSystemHealth(),
        _reconciliationService.getLatestReconciliationStats(),
        _reconciliationService.getFailedOperations(),
      ]);

      setState(() {
        _healthScore = results[0] as SystemHealthScore;
        _latestStats = results[1] as ReconciliationStats;
        _failedOperations = results[2] as List<FailedOperation>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.monitor_heart, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'System Health',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _loadData,
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),

          // Content
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 8),
                  Text(
                    'Error loading system health data',
                    style: TextStyle(
                      color: Colors.red[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _error!,
                    style: const TextStyle(fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                // Health Score Section
                _buildHealthScoreSection(),

                const Divider(height: 1),

                // Reconciliation Stats Section
                _buildReconciliationStatsSection(),

                const Divider(height: 1),

                // Failed Operations Section
                _buildFailedOperationsSection(),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildHealthScoreSection() {
    if (_healthScore == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Health Score Circle
          Row(
            children: [
              // Score Circle
              SizedBox(
                width: 120,
                height: 120,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 120,
                      height: 120,
                      child: CircularProgressIndicator(
                        value: _healthScore!.score / 100,
                        strokeWidth: 12,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          _getHealthColor(_healthScore!.status),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _healthScore!.score.toString(),
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _healthScore!.statusText,
                          style: TextStyle(
                            fontSize: 14,
                            color: _getHealthColor(_healthScore!.status),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 24),

              // Stats Grid
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildStatRow(
                      'Total Payouts',
                      _healthScore!.totalPayouts.toString(),
                      Icons.payment,
                      Colors.blue,
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow(
                      'Failed',
                      _healthScore!.failedPayouts.toString(),
                      Icons.error_outline,
                      Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow(
                      'Escalated',
                      _healthScore!.escalatedPayouts.toString(),
                      Icons.flag,
                      Colors.red,
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow(
                      'Failure Rate',
                      '${(_healthScore!.failureRate * 100).toStringAsFixed(2)}%',
                      Icons.trending_down,
                      _healthScore!.failureRate > 0.05 ? Colors.red : Colors.green,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Last Reconciliation Time
          if (_healthScore!.lastReconciliation != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16, color: Colors.grey),
                  const SizedBox(width: 8),
                  Text(
                    'Last reconciliation: ${_formatTimestamp(_healthScore!.lastReconciliation!)}',
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReconciliationStatsSection() {
    if (_latestStats == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Latest Reconciliation Run',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'States Fixed',
                  _latestStats!.mismatchedStatesFixed.toString(),
                  Icons.check_circle_outline,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Operations Retried',
                  _latestStats!.failedOperationsRetried.toString(),
                  Icons.refresh,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Successful Retries',
                  _latestStats!.successfulRetries.toString(),
                  Icons.done_all,
                  Colors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricCard(
                  'Escalated',
                  _latestStats!.escalatedToAdmin.toString(),
                  Icons.warning_amber,
                  Colors.orange,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Duration and timestamp
          Row(
            children: [
              Icon(Icons.timer, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                'Duration: ${_latestStats!.durationMs}ms',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
              const SizedBox(width: 16),
              Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 4),
              Text(
                _formatTimestamp(_latestStats!.startedAt),
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ),

          // Errors if any
          if (_latestStats!.hasErrors) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_latestStats!.errors.length} error(s) occurred during reconciliation',
                      style: TextStyle(
                        color: Colors.red[700],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFailedOperationsSection() {
    if (_failedOperations == null || _failedOperations!.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green[600], size: 24),
            const SizedBox(width: 12),
            const Text(
              'No failed operations ✨',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Failed Operations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _failedOperations!.length.toString(),
                  style: TextStyle(
                    color: Colors.red[900],
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Failed operations list
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _failedOperations!.take(5).length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final operation = _failedOperations![index];
              return _buildFailedOperationItem(operation);
            },
          ),

          if (_failedOperations!.length > 5) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                _showAllFailedOperations();
              },
              child: Text('View all ${_failedOperations!.length} failed operations'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFailedOperationItem(FailedOperation operation) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: operation.isEscalated ? Colors.red[100] : Colors.orange[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          operation.isEscalated ? Icons.flag : Icons.error_outline,
          color: operation.isEscalated ? Colors.red[700] : Colors.orange[700],
        ),
      ),
      title: Text(
        'Claim ${operation.claimId}',
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Amount: \$${operation.amount.toStringAsFixed(2)}'),
          Text(
            operation.failureType ?? 'Unknown failure',
            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
          ),
          if (operation.isEscalated)
            Text(
              'ESCALATED - Manual intervention required',
              style: TextStyle(
                color: Colors.red[700],
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            )
          else
            Text(
              'Retry ${operation.retryCount}/3',
              style: const TextStyle(fontSize: 12),
            ),
        ],
      ),
      trailing: operation.canRetry
          ? ElevatedButton.icon(
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              onPressed: () => _retryOperation(operation),
            )
          : null,
    );
  }

  Widget _buildStatRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey[600],
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 32, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.grey,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Color _getHealthColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.excellent:
        return Colors.green;
      case HealthStatus.good:
        return Colors.lightGreen;
      case HealthStatus.fair:
        return Colors.orange;
      case HealthStatus.poor:
        return Colors.deepOrange;
      case HealthStatus.critical:
        return Colors.red;
    }
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d, HH:mm').format(timestamp);
    }
  }

  Future<void> _retryOperation(FailedOperation operation) async {
    try {
      await _reconciliationService.retryFailedPayout(operation.payoutId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Retry initiated successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
      // Reload data after retry
      await Future.delayed(const Duration(seconds: 2));
      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Retry failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showAllFailedOperations() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          width: 800,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text(
                    'All Failed Operations',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _failedOperations!.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    return _buildFailedOperationItem(_failedOperations![index]);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';

/// Service for fetching and managing system health/reconciliation data
/// Provides data for the System Health dashboard widget
class ReconciliationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Get the latest reconciliation run statistics
  Future<ReconciliationStats> getLatestReconciliationStats() async {
    try {
      // Get most recent reconciliation run
      final snapshot = await _firestore
          .collection('reconciliation_runs')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return ReconciliationStats.empty();
      }

      final data = snapshot.docs.first.data();
      return ReconciliationStats.fromMap(data);
    } catch (e) {
      throw Exception('Failed to load reconciliation stats: $e');
    }
  }

  /// Get reconciliation history for the past 24 hours
  Future<List<ReconciliationStats>> getReconciliationHistory({
    int hours = 24,
  }) async {
    try {
      final cutoffTime = DateTime.now().subtract(Duration(hours: hours));

      final snapshot = await _firestore
          .collection('reconciliation_runs')
          .where('timestamp', isGreaterThan: Timestamp.fromDate(cutoffTime))
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => ReconciliationStats.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to load reconciliation history: $e');
    }
  }

  /// Get current failed operations that need attention
  Future<List<FailedOperation>> getFailedOperations() async {
    try {
      // Get payouts in failed or escalated state
      final snapshot = await _firestore
          .collection('payouts')
          .where('status', whereIn: ['failed', 'pending_retry', 'escalated'])
          .orderBy('updatedAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs
          .map((doc) => FailedOperation.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to load failed operations: $e');
    }
  }

  /// Get count of payouts by status for health indicators
  Future<Map<String, int>> getPayoutStatusCounts() async {
    try {
      final statuses = ['pending', 'completed', 'failed', 'pending_retry', 'escalated'];
      final counts = <String, int>{};

      for (final status in statuses) {
        final snapshot = await _firestore
            .collection('payouts')
            .where('status', isEqualTo: status)
            .count()
            .get();

        counts[status] = snapshot.count ?? 0;
      }

      return counts;
    } catch (e) {
      throw Exception('Failed to load payout status counts: $e');
    }
  }

  /// Get recent audit trail entries
  Future<List<AuditTrailEntry>> getRecentAuditTrail({int limit = 20}) async {
    try {
      final snapshot = await _firestore
          .collection('payout_audit_trail')
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => AuditTrailEntry.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to load audit trail: $e');
    }
  }

  /// Manually trigger retry for a failed payout (admin only)
  Future<void> retryFailedPayout(String payoutId) async {
    try {
      final result = await _functions
          .httpsCallable('retryFailedOperation')
          .call({'payoutId': payoutId});

      if (result.data['success'] != true) {
        throw Exception(result.data['message'] ?? 'Retry failed');
      }
    } catch (e) {
      throw Exception('Failed to retry payout: $e');
    }
  }

  /// Calculate system health score (0-100)
  Future<SystemHealthScore> calculateSystemHealth() async {
    try {
      final stats = await getLatestReconciliationStats();
      final statusCounts = await getPayoutStatusCounts();

      final totalPayouts = statusCounts.values.fold(0, (sum, count) => sum + count);
      final failedPayouts = (statusCounts['failed'] ?? 0) + 
                            (statusCounts['pending_retry'] ?? 0) + 
                            (statusCounts['escalated'] ?? 0);

      // Health score calculation
      int score = 100;

      // Deduct points for failures
      if (totalPayouts > 0) {
        final failureRate = failedPayouts / totalPayouts;
        if (failureRate > 0.05) {
          score -= 30; // >5% failure rate
        } else if (failureRate > 0.02) score -= 20; // >2% failure rate
        else if (failureRate > 0.01) score -= 10; // >1% failure rate
      }

      // Deduct points for escalated issues
      final escalatedCount = statusCounts['escalated'] ?? 0;
      if (escalatedCount > 5) {
        score -= 30;
      } else if (escalatedCount > 2) score -= 15;
      else if (escalatedCount > 0) score -= 5;

      // Deduct points for recent errors
      if (stats.errors.isNotEmpty) {
        score -= stats.errors.length * 2;
      }

      // Ensure score is in valid range
      score = score.clamp(0, 100);

      return SystemHealthScore(
        score: score,
        status: _getHealthStatus(score),
        totalPayouts: totalPayouts,
        failedPayouts: failedPayouts,
        escalatedPayouts: escalatedCount,
        lastReconciliation: stats.startedAt,
        failureRate: totalPayouts > 0 ? failedPayouts / totalPayouts : 0.0,
      );
    } catch (e) {
      throw Exception('Failed to calculate system health: $e');
    }
  }

  HealthStatus _getHealthStatus(int score) {
    if (score >= 90) return HealthStatus.excellent;
    if (score >= 75) return HealthStatus.good;
    if (score >= 50) return HealthStatus.fair;
    if (score >= 25) return HealthStatus.poor;
    return HealthStatus.critical;
  }
}

/// Reconciliation run statistics
class ReconciliationStats {
  final String reconciliationId;
  final DateTime startedAt;
  final DateTime? completedAt;
  final int mismatchedStatesFixed;
  final int failedOperationsRetried;
  final int successfulRetries;
  final int escalatedToAdmin;
  final int durationMs;
  final List<dynamic> errors;

  ReconciliationStats({
    required this.reconciliationId,
    required this.startedAt,
    this.completedAt,
    required this.mismatchedStatesFixed,
    required this.failedOperationsRetried,
    required this.successfulRetries,
    required this.escalatedToAdmin,
    required this.durationMs,
    required this.errors,
  });

  factory ReconciliationStats.fromMap(Map<String, dynamic> map) {
    return ReconciliationStats(
      reconciliationId: map['reconciliationId'] ?? '',
      startedAt: DateTime.parse(map['startedAt']),
      completedAt: map['completedAt'] != null 
          ? DateTime.parse(map['completedAt']) 
          : null,
      mismatchedStatesFixed: map['mismatchedStatesFixed'] ?? 0,
      failedOperationsRetried: map['failedOperationsRetried'] ?? 0,
      successfulRetries: map['successfulRetries'] ?? 0,
      escalatedToAdmin: map['escalatedToAdmin'] ?? 0,
      durationMs: map['durationMs'] ?? 0,
      errors: map['errors'] ?? [],
    );
  }

  factory ReconciliationStats.empty() {
    return ReconciliationStats(
      reconciliationId: 'none',
      startedAt: DateTime.now(),
      completedAt: DateTime.now(),
      mismatchedStatesFixed: 0,
      failedOperationsRetried: 0,
      successfulRetries: 0,
      escalatedToAdmin: 0,
      durationMs: 0,
      errors: [],
    );
  }

  bool get hasErrors => errors.isNotEmpty;
  bool get hasEscalations => escalatedToAdmin > 0;
  Duration get duration => Duration(milliseconds: durationMs);
}

/// Failed operation details
class FailedOperation {
  final String payoutId;
  final String claimId;
  final String status;
  final String? failureType;
  final String? lastError;
  final int retryCount;
  final DateTime? lastRetryAt;
  final DateTime? escalatedAt;
  final double amount;

  FailedOperation({
    required this.payoutId,
    required this.claimId,
    required this.status,
    this.failureType,
    this.lastError,
    required this.retryCount,
    this.lastRetryAt,
    this.escalatedAt,
    required this.amount,
  });

  factory FailedOperation.fromMap(String id, Map<String, dynamic> map) {
    return FailedOperation(
      payoutId: id,
      claimId: map['claimId'] ?? '',
      status: map['status'] ?? 'unknown',
      failureType: map['failureType'],
      lastError: map['lastError'],
      retryCount: map['retryCount'] ?? 0,
      lastRetryAt: map['lastRetryAt'] != null 
          ? (map['lastRetryAt'] as Timestamp).toDate()
          : null,
      escalatedAt: map['escalatedAt'] != null
          ? (map['escalatedAt'] as Timestamp).toDate()
          : null,
      amount: (map['amount'] ?? 0).toDouble(),
    );
  }

  bool get isEscalated => status == 'escalated';
  bool get canRetry => retryCount < 3 && !isEscalated;
}

/// Audit trail entry
class AuditTrailEntry {
  final String id;
  final String type;
  final String? claimId;
  final String? payoutId;
  final String? performedBy;
  final DateTime timestamp;
  final Map<String, dynamic> metadata;

  AuditTrailEntry({
    required this.id,
    required this.type,
    this.claimId,
    this.payoutId,
    this.performedBy,
    required this.timestamp,
    required this.metadata,
  });

  factory AuditTrailEntry.fromMap(String id, Map<String, dynamic> map) {
    return AuditTrailEntry(
      id: id,
      type: map['type'] ?? 'unknown',
      claimId: map['claimId'],
      payoutId: map['payoutId'],
      performedBy: map['performedBy'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      metadata: Map<String, dynamic>.from(map['metadata'] ?? {}),
    );
  }

  String get displayType {
    switch (type) {
      case 'state_reconciliation':
        return 'State Reconciled';
      case 'retry_attempt':
        return 'Retry Attempt';
      case 'retry_success':
        return 'Retry Success';
      case 'escalation':
        return 'Escalated';
      case 'manual_retry':
        return 'Manual Retry';
      default:
        return type;
    }
  }
}

/// System health score
class SystemHealthScore {
  final int score;
  final HealthStatus status;
  final int totalPayouts;
  final int failedPayouts;
  final int escalatedPayouts;
  final DateTime? lastReconciliation;
  final double failureRate;

  SystemHealthScore({
    required this.score,
    required this.status,
    required this.totalPayouts,
    required this.failedPayouts,
    required this.escalatedPayouts,
    this.lastReconciliation,
    required this.failureRate,
  });

  String get statusText {
    switch (status) {
      case HealthStatus.excellent:
        return 'Excellent';
      case HealthStatus.good:
        return 'Good';
      case HealthStatus.fair:
        return 'Fair';
      case HealthStatus.poor:
        return 'Poor';
      case HealthStatus.critical:
        return 'Critical';
    }
  }

  String get statusEmoji {
    switch (status) {
      case HealthStatus.excellent:
        return '🟢';
      case HealthStatus.good:
        return '🟡';
      case HealthStatus.fair:
        return '🟠';
      case HealthStatus.poor:
        return '🔴';
      case HealthStatus.critical:
        return '🚨';
    }
  }
}

enum HealthStatus {
  excellent,
  good,
  fair,
  poor,
  critical,
}

import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';

/// Service for sharing analytics reports via email
/// 
/// Uses SendGrid via Cloud Functions to send formatted
/// analytics reports to admin email addresses
class AnalyticsEmailService {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Share analytics report via email
  /// 
  /// Sends a formatted email with analytics summary and CSV attachment
  /// 
  /// Parameters:
  /// - [recipientEmail]: Email address to send report to
  /// - [analytics]: Analytics data map
  /// - [csvData]: CSV file content as string
  /// - [dateRange]: Human-readable date range (e.g., "Jan 1 - Jan 31, 2025")
  Future<void> shareAnalyticsReport({
    required String recipientEmail,
    required Map<String, dynamic> analytics,
    required String csvData,
    required String dateRange,
  }) async {
    try {
      // Call Cloud Function to send email
      final callable = _functions.httpsCallable('sendAnalyticsEmail');
      
      final result = await callable.call<Map<String, dynamic>>({
        'recipientEmail': recipientEmail,
        'dateRange': dateRange,
        'analytics': analytics,
        'csvData': csvData,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (result.data['success'] != true) {
        throw Exception(result.data['error'] ?? 'Failed to send email');
      }
    } catch (e) {
      throw Exception('Failed to share analytics report: $e');
    }
  }

  /// Format analytics summary for email body
  String formatEmailSummary(Map<String, dynamic> analytics, String dateRange) {
    final currencyFormat = NumberFormat.currency(symbol: '\$');
    final percentFormat = NumberFormat.percentPattern();
    
    final totalClaims = analytics['totalClaims'] ?? 0;
    final settledCount = analytics['settledCount'] ?? 0;
    final totalPaidOut = analytics['totalPaidOut'] ?? 0.0;
    final avgAmount = analytics['averageAmount'] ?? 0.0;
    final autoApprovalRate = analytics['autoApprovalRate'] ?? 0.0;
    
    final fraudData = analytics['fraudDetection'] as Map<String, dynamic>? ?? {};
    final fraudAccuracy = fraudData['accuracy'] ?? 0.0;
    
    final settlementData = analytics['settlementMetrics'] as Map<String, dynamic>? ?? {};
    final meanSettlement = settlementData['mean'] ?? 0.0;
    final p90Settlement = settlementData['p90'] ?? 0.0;

    return '''
Claims Analytics Report
Date Range: $dateRange
Generated: ${DateFormat('MMM d, yyyy HH:mm').format(DateTime.now())}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

SUMMARY METRICS

Total Claims: $totalClaims
Settled Claims: $settledCount
Auto-Approval Rate: ${percentFormat.format(autoApprovalRate)}

FINANCIAL METRICS

Total Paid Out: ${currencyFormat.format(totalPaidOut)}
Average Payout: ${currencyFormat.format(avgAmount)}

AI PERFORMANCE

Fraud Detection Accuracy: ${percentFormat.format(fraudAccuracy)}
Mean Settlement Time: ${_formatHours(meanSettlement)}
90th Percentile Settlement: ${_formatHours(p90Settlement)}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

A detailed CSV report is attached with complete breakdowns by:
• Breed, Region, and Claim Type
• Time Series Data
• AI Confidence Distribution
• Fraud Detection Details
• Settlement Time Metrics
''';
  }

  String _formatHours(double hours) {
    if (hours < 1) {
      return '${(hours * 60).toStringAsFixed(0)} minutes';
    } else if (hours < 24) {
      return '${hours.toStringAsFixed(1)} hours';
    } else {
      final days = hours / 24;
      return '${days.toStringAsFixed(1)} days';
    }
  }
}

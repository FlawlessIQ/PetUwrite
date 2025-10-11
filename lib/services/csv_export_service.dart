import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:intl/intl.dart';

/// Service for exporting analytics data to CSV format
/// 
/// Provides methods to convert various analytics data structures
/// into CSV format for download or email sharing
class CSVExportService {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$');
  final NumberFormat _percentFormat = NumberFormat.percentPattern();

  /// Export claims analytics to CSV string
  /// 
  /// Returns a complete CSV with multiple sections:
  /// - Summary metrics
  /// - Time series data
  /// - Payout breakdowns (breed, region, claim type)
  /// - AI performance metrics
  /// - Fraud detection stats
  /// - Settlement time metrics
  String exportClaimsAnalytics(Map<String, dynamic> analytics) {
    final sections = <List<List<dynamic>>>[];
    
    // Section 1: Summary Metrics
    sections.add(_buildSummarySection(analytics));
    sections.add([[]]);  // Blank row separator
    
    // Section 2: Time Series Data
    sections.add(_buildTimeSeriesSection(analytics));
    sections.add([[]]);
    
    // Section 3: Average Payout by Breed
    sections.add(_buildBreedBreakdownSection(analytics));
    sections.add([[]]);
    
    // Section 4: Average Payout by Region
    sections.add(_buildRegionBreakdownSection(analytics));
    sections.add([[]]);
    
    // Section 5: Average Payout by Claim Type
    sections.add(_buildClaimTypeBreakdownSection(analytics));
    sections.add([[]]);
    
    // Section 6: AI Confidence Distribution
    sections.add(_buildConfidenceHistogramSection(analytics));
    sections.add([[]]);
    
    // Section 7: Fraud Detection Metrics
    sections.add(_buildFraudDetectionSection(analytics));
    sections.add([[]]);
    
    // Section 8: Time-to-Settlement Metrics
    sections.add(_buildSettlementMetricsSection(analytics));
    
    // Flatten all sections
    final allRows = sections.expand((section) => section).toList();
    
    // Convert to CSV string
    return const ListToCsvConverter().convert(allRows);
  }

  List<List<dynamic>> _buildSummarySection(Map<String, dynamic> analytics) {
    return [
      ['CLAIMS ANALYTICS SUMMARY'],
      ['Generated:', _dateFormat.format(DateTime.now())],
      [],
      ['Metric', 'Value'],
      ['Total Claims', analytics['totalClaims'] ?? 0],
      ['Settled Claims', analytics['settledCount'] ?? 0],
      ['Auto-Approved', analytics['autoApproved'] ?? 0],
      ['Manual Review', analytics['manualApproved'] ?? 0],
      ['Denied', analytics['denied'] ?? 0],
      ['Pending', analytics['pending'] ?? 0],
      ['Total Paid Out', _currencyFormat.format(analytics['totalPaidOut'] ?? 0)],
      ['Average Payout', _currencyFormat.format(analytics['averageAmount'] ?? 0)],
      ['Auto-Approval Rate', _percentFormat.format(analytics['autoApprovalRate'] ?? 0)],
    ];
  }

  List<List<dynamic>> _buildTimeSeriesSection(Map<String, dynamic> analytics) {
    final rows = <List<dynamic>>[
      ['TIME SERIES DATA'],
      [],
      ['Month', 'Total Claims', 'Total Amount', 'Auto-Approved', 'Manual Review', 'Auto-Approval Rate'],
    ];
    
    final claimsByMonth = analytics['claimsByMonth'] as Map<String, dynamic>? ?? {};
    final amountsByMonth = analytics['amountsByMonth'] as Map<String, dynamic>? ?? {};
    final autoApprovalByMonth = analytics['autoApprovalByMonth'] as Map<String, dynamic>? ?? {};
    final manualReviewByMonth = analytics['manualReviewByMonth'] as Map<String, dynamic>? ?? {};
    
    // Get all unique months and sort them
    final months = <String>{
      ...claimsByMonth.keys,
      ...amountsByMonth.keys,
      ...autoApprovalByMonth.keys,
      ...manualReviewByMonth.keys,
    }.toList()..sort();
    
    for (final month in months) {
      final totalClaims = claimsByMonth[month] ?? 0;
      final totalAmount = amountsByMonth[month] ?? 0.0;
      final autoApproved = autoApprovalByMonth[month] ?? 0;
      final manualReview = manualReviewByMonth[month] ?? 0;
      final autoRate = (autoApproved + manualReview) > 0 
          ? autoApproved / (autoApproved + manualReview) 
          : 0.0;
      
      rows.add([
        month,
        totalClaims,
        _currencyFormat.format(totalAmount),
        autoApproved,
        manualReview,
        _percentFormat.format(autoRate),
      ]);
    }
    
    return rows;
  }

  List<List<dynamic>> _buildBreedBreakdownSection(Map<String, dynamic> analytics) {
    final rows = <List<dynamic>>[
      ['AVERAGE PAYOUT BY BREED'],
      [],
      ['Breed', 'Average Payout', 'Total Payout', 'Claim Count'],
    ];
    
    final avgPayouts = analytics['avgPayoutByBreed'] as Map<String, dynamic>? ?? {};
    final totalPayouts = analytics['payoutByBreed'] as Map<String, dynamic>? ?? {};
    
    // Sort by average payout descending
    final sortedBreeds = avgPayouts.keys.toList()
      ..sort((a, b) => (avgPayouts[b] ?? 0.0).compareTo(avgPayouts[a] ?? 0.0));
    
    for (final breed in sortedBreeds) {
      final avgPayout = avgPayouts[breed] ?? 0.0;
      final totalPayout = totalPayouts[breed] ?? 0.0;
      final count = totalPayout > 0 ? (totalPayout / avgPayout).round() : 0;
      
      rows.add([
        breed,
        _currencyFormat.format(avgPayout),
        _currencyFormat.format(totalPayout),
        count,
      ]);
    }
    
    return rows;
  }

  List<List<dynamic>> _buildRegionBreakdownSection(Map<String, dynamic> analytics) {
    final rows = <List<dynamic>>[
      ['AVERAGE PAYOUT BY REGION'],
      [],
      ['Region', 'Average Payout', 'Total Payout', 'Claim Count'],
    ];
    
    final avgPayouts = analytics['avgPayoutByRegion'] as Map<String, dynamic>? ?? {};
    final totalPayouts = analytics['payoutByRegion'] as Map<String, dynamic>? ?? {};
    
    // Sort by average payout descending
    final sortedRegions = avgPayouts.keys.toList()
      ..sort((a, b) => (avgPayouts[b] ?? 0.0).compareTo(avgPayouts[a] ?? 0.0));
    
    for (final region in sortedRegions) {
      final avgPayout = avgPayouts[region] ?? 0.0;
      final totalPayout = totalPayouts[region] ?? 0.0;
      final count = totalPayout > 0 ? (totalPayout / avgPayout).round() : 0;
      
      rows.add([
        region,
        _currencyFormat.format(avgPayout),
        _currencyFormat.format(totalPayout),
        count,
      ]);
    }
    
    return rows;
  }

  List<List<dynamic>> _buildClaimTypeBreakdownSection(Map<String, dynamic> analytics) {
    final rows = <List<dynamic>>[
      ['AVERAGE PAYOUT BY CLAIM TYPE'],
      [],
      ['Claim Type', 'Average Payout', 'Total Payout', 'Claim Count'],
    ];
    
    final avgPayouts = analytics['avgPayoutByClaimType'] as Map<String, dynamic>? ?? {};
    final totalPayouts = analytics['payoutByClaimType'] as Map<String, dynamic>? ?? {};
    
    // Sort by average payout descending
    final sortedTypes = avgPayouts.keys.toList()
      ..sort((a, b) => (avgPayouts[b] ?? 0.0).compareTo(avgPayouts[a] ?? 0.0));
    
    for (final claimType in sortedTypes) {
      final avgPayout = avgPayouts[claimType] ?? 0.0;
      final totalPayout = totalPayouts[claimType] ?? 0.0;
      final count = totalPayout > 0 ? (totalPayout / avgPayout).round() : 0;
      
      rows.add([
        claimType,
        _currencyFormat.format(avgPayout),
        _currencyFormat.format(totalPayout),
        count,
      ]);
    }
    
    return rows;
  }

  List<List<dynamic>> _buildConfidenceHistogramSection(Map<String, dynamic> analytics) {
    final rows = <List<dynamic>>[
      ['AI CONFIDENCE DISTRIBUTION'],
      [],
      ['Confidence Range', 'Claim Count', 'Percentage'],
    ];
    
    final confidenceBuckets = analytics['confidenceBuckets'] as Map<String, dynamic>? ?? {};
    final totalClaims = analytics['totalClaims'] ?? 0;
    
    // Ensure buckets are in order
    final bucketOrder = [
      '0-10%', '10-20%', '20-30%', '30-40%', '40-50%',
      '50-60%', '60-70%', '70-80%', '80-90%', '90-100%',
    ];
    
    for (final bucket in bucketOrder) {
      final count = confidenceBuckets[bucket] ?? 0;
      final percentage = totalClaims > 0 ? count / totalClaims : 0.0;
      
      rows.add([
        bucket,
        count,
        _percentFormat.format(percentage),
      ]);
    }
    
    return rows;
  }

  List<List<dynamic>> _buildFraudDetectionSection(Map<String, dynamic> analytics) {
    final fraudData = analytics['fraudDetection'] as Map<String, dynamic>? ?? {};
    
    return [
      ['FRAUD DETECTION METRICS'],
      [],
      ['Metric', 'Value'],
      ['AI Denials - Correct', fraudData['aiDenialsCorrect'] ?? 0],
      ['AI Denials - Overridden', fraudData['aiDenialsOverridden'] ?? 0],
      ['Total AI Denials', fraudData['totalAIDenials'] ?? 0],
      ['Fraud Detection Accuracy', _percentFormat.format(fraudData['accuracy'] ?? 0)],
    ];
  }

  List<List<dynamic>> _buildSettlementMetricsSection(Map<String, dynamic> analytics) {
    final settlementData = analytics['settlementMetrics'] as Map<String, dynamic>? ?? {};
    
    return [
      ['TIME-TO-SETTLEMENT METRICS'],
      [],
      ['Metric', 'Hours'],
      ['Mean Settlement Time', _formatHours(settlementData['mean'] ?? 0)],
      ['90th Percentile (P90)', _formatHours(settlementData['p90'] ?? 0)],
      ['99th Percentile (P99)', _formatHours(settlementData['p99'] ?? 0)],
      ['Total Settled Claims', settlementData['count'] ?? 0],
    ];
  }

  String _formatHours(double hours) {
    if (hours < 1) {
      return '${(hours * 60).toStringAsFixed(1)} minutes';
    } else if (hours < 24) {
      return '${hours.toStringAsFixed(1)} hours';
    } else {
      final days = hours / 24;
      return '${days.toStringAsFixed(1)} days';
    }
  }

  /// Generate a filename for the CSV export
  String generateFilename({String prefix = 'claims_analytics'}) {
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    return '${prefix}_$timestamp.csv';
  }
}

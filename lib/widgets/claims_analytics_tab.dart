import 'package:flutter/material.dart';
import '../services/claims_service.dart';
import '../models/claim.dart';

/// Claims Analytics Tab Widget for Admin Dashboard
class ClaimsAnalyticsTab extends StatelessWidget {
  const ClaimsAnalyticsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final claimsService = ClaimsService();

    return FutureBuilder<List<RiskBandAnalytics>>(
      future: claimsService.getClaimsAnalytics(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text(
                  'Error loading analytics',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  snapshot.error.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final analytics = snapshot.data ?? [];
        if (analytics.isEmpty || analytics.every((a) => a.claimCount == 0)) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No Claims Data Yet',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Claims analytics will appear here once claims are filed',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        // Calculate totals
        final totalClaims = analytics.fold<int>(0, (sum, a) => sum + a.claimCount);
        final activeBands = analytics.where((a) => a.claimCount > 0).toList();
        final avgClaimAmount = activeBands.isNotEmpty
            ? activeBands.fold<double>(0.0, (sum, a) => sum + a.averageClaimAmount) / activeBands.length
            : 0.0;

        return Column(
          children: [
            // Summary Cards
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.grey[100],
              child: Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      'Total Claims',
                      totalClaims.toString(),
                      Icons.receipt,
                      Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      'Avg Claim Amount',
                      '\$${avgClaimAmount.toStringAsFixed(0)}',
                      Icons.attach_money,
                      Colors.green,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildSummaryCard(
                      context,
                      'High Risk Claims',
                      analytics
                          .where((a) => a.bandIndex >= 8)
                          .fold<int>(0, (sum, a) => sum + a.claimCount)
                          .toString(),
                      Icons.warning,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
            ),
            // Risk Band Table
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Claims by Risk Score Band',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _buildRiskBandTable(analytics),
                      const SizedBox(height: 32),
                      Text(
                        'Heatmap Visualization',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 16),
                      _buildHeatmapVisualization(analytics),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskBandTable(List<RiskBandAnalytics> analytics) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
              ),
            ),
            child: Row(
              children: [
                Expanded(flex: 2, child: _buildHeaderCell('Risk Band')),
                Expanded(flex: 2, child: _buildHeaderCell('Claims')),
                Expanded(flex: 3, child: _buildHeaderCell('Avg Amount')),
                Expanded(flex: 3, child: _buildHeaderCell('Frequency')),
                Expanded(flex: 2, child: _buildHeaderCell('Approved')),
                Expanded(flex: 2, child: _buildHeaderCell('Denied')),
              ],
            ),
          ),
          // Table Rows
          ...analytics.map((band) => _buildRiskBandRow(band)),
        ],
      ),
    );
  }

  Widget _buildHeaderCell(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );
  }

  Widget _buildRiskBandRow(RiskBandAnalytics band) {
    final isHighRisk = band.bandIndex >= 8;
    final backgroundColor = isHighRisk ? Colors.red[50] : Colors.white;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              band.band,
              style: TextStyle(
                fontWeight: isHighRisk ? FontWeight.bold : FontWeight.normal,
                color: isHighRisk ? Colors.red[700] : Colors.black87,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(band.claimCount.toString()),
          ),
          Expanded(
            flex: 3,
            child: Text('\$${band.averageClaimAmount.toStringAsFixed(2)}'),
          ),
          Expanded(
            flex: 3,
            child: Text('${band.claimsFrequency.toStringAsFixed(1)}%'),
          ),
          Expanded(
            flex: 2,
            child: Text(
              band.approvedCount.toString(),
              style: TextStyle(color: Colors.green[700]),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              band.deniedCount.toString(),
              style: TextStyle(color: Colors.red[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapVisualization(List<RiskBandAnalytics> analytics) {
    return Container(
      height: 300,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Claims Heatmap: Risk Score vs. Claim Frequency',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: analytics.map((band) {
                final maxFrequency = analytics
                    .map((a) => a.claimsFrequency)
                    .reduce((a, b) => a > b ? a : b);
                final normalizedHeight = maxFrequency > 0
                    ? (band.claimsFrequency / maxFrequency) * 200
                    : 0.0;
                
                final color = _getHeatmapColor(band.claimsFrequency);

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (band.claimCount > 0)
                          Tooltip(
                            message: '${band.band}\n'
                                '${band.claimCount} claims\n'
                                '\$${band.averageClaimAmount.toStringAsFixed(0)} avg\n'
                                '${band.claimsFrequency.toStringAsFixed(1)}% frequency',
                            child: Container(
                              height: normalizedHeight.clamp(20, 200),
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          band.band.split('-')[0],
                          style: const TextStyle(fontSize: 10),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('Low', Colors.green[300]!),
              const SizedBox(width: 16),
              _buildLegendItem('Medium', Colors.orange[300]!),
              const SizedBox(width: 16),
              _buildLegendItem('High', Colors.red[300]!),
            ],
          ),
        ],
      ),
    );
  }

  Color _getHeatmapColor(double frequency) {
    if (frequency == 0) return Colors.grey[300]!;
    if (frequency < 10) return Colors.green[300]!;
    if (frequency < 25) return Colors.yellow[400]!;
    if (frequency < 50) return Colors.orange[400]!;
    return Colors.red[400]!;
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

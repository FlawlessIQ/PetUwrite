import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../admin_console/components/admin_kpi_card.dart';
import '../../admin_console/components/admin_section_card.dart';
import '../../theme/clovara_theme.dart';
import 'claims_review_tab.dart';

/// Claims Analytics Tab for Admin Dashboard
/// 
/// Features:
/// - Total claims by month (line chart)
/// - Average claim amount (bar chart)
/// - Auto-approve vs manual decision pie chart
/// - AI confidence distribution (histogram)
/// - Filters: breed, age range, region, vet provider
/// - Data fetched from Firestore with Cloud Functions aggregation
class ClaimsAnalyticsTab extends StatefulWidget {
  final VoidCallback? onOpenInbox;

  const ClaimsAnalyticsTab({
    super.key,
    this.onOpenInbox,
  });

  @override
  State<ClaimsAnalyticsTab> createState() => _ClaimsAnalyticsTabState();
}

class _ClaimsAnalyticsTabState extends State<ClaimsAnalyticsTab> {
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  
  // Filters
  String? _selectedBreed;
  String? _selectedAgeRange;
  String? _selectedRegion;
  String? _selectedVetProvider;
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 90));
  DateTime _endDate = DateTime.now();
  
  // Filter options
  List<String> _breeds = [];
  List<String> _regions = [];
  List<String> _vetProviders = [];
  
  // Analytics data
  Map<String, dynamic>? _analyticsData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFilterOptions();
    _loadAnalytics();
  }

  /// Load filter options from Firestore
  Future<void> _loadFilterOptions() async {
    try {
      final callable = _functions.httpsCallable('getClaimsAnalyticsFilterOptionsAdmin');
      final resp = await callable.call({
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
      });

      final data = (resp.data is Map)
          ? (resp.data as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      final breeds = (data['breeds'] as List?)?.cast<String>() ?? <String>[];
      final regions = (data['regions'] as List?)?.cast<String>() ?? <String>[];
      final sortedProviders =
          (data['vetProviders'] as List?)?.cast<String>() ?? <String>[];

      setState(() {
        _breeds = breeds;
        _regions = regions;
        _vetProviders = sortedProviders;
      });
    } catch (e) {
      print('Error loading filter options: $e');
    }
  }

  /// Load analytics data from Firestore (with Cloud Functions aggregation)
  Future<void> _loadAnalytics() async {
    setState(() => _isLoading = true);

    try {
      final callable = _functions.httpsCallable('getClaimsAnalytics');
      final resp = await callable.call({
        'startDate': _startDate.toIso8601String(),
        'endDate': _endDate.toIso8601String(),
        if (_selectedBreed != null) 'breed': _selectedBreed,
        if (_selectedAgeRange != null) 'ageRange': _selectedAgeRange,
        if (_selectedRegion != null) 'region': _selectedRegion,
        if (_selectedVetProvider != null) 'vetProvider': _selectedVetProvider,
      });

      final data = (resp.data is Map)
          ? (resp.data as Map).cast<String, dynamic>()
          : <String, dynamic>{};

      final analytics = _normalizeAnalyticsPayload(data);

      setState(() {
        _analyticsData = analytics;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _normalizeAnalyticsPayload(Map<String, dynamic> raw) {
    final claimsByMonthRaw = raw['claimsByMonth'];
    final amountsByMonthRaw = raw['amountsByMonth'];
    final confidenceRaw = raw['confidenceBuckets'];

    final claimsByMonth = <String, int>{};
    if (claimsByMonthRaw is Map) {
      for (final entry in claimsByMonthRaw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is num) claimsByMonth[key] = value.toInt();
      }
    }

    final amountsByMonth = <String, double>{};
    if (amountsByMonthRaw is Map) {
      for (final entry in amountsByMonthRaw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is num) amountsByMonth[key] = value.toDouble();
      }
    }

    final confidenceBuckets10 = <String, int>{};
    if (confidenceRaw is Map) {
      for (final entry in confidenceRaw.entries) {
        final key = entry.key.toString();
        final value = entry.value;
        if (value is num) confidenceBuckets10[key] = value.toInt();
      }
    }

    int bucket(String label) => confidenceBuckets10[label] ?? 0;

    final confidenceBuckets = <String, int>{
      '0-20%': bucket('0-10%') + bucket('10-20%'),
      '20-40%': bucket('20-30%') + bucket('30-40%'),
      '40-60%': bucket('40-50%') + bucket('50-60%'),
      '60-80%': bucket('60-70%') + bucket('70-80%'),
      '80-100%': bucket('80-90%') + bucket('90-100%'),
    };

    return {
      'claimsByMonth': claimsByMonth,
      'amountsByMonth': amountsByMonth,
      'autoApproved': (raw['autoApproved'] as num?)?.toInt() ?? 0,
      'manualApproved': (raw['manualApproved'] as num?)?.toInt() ?? 0,
      'denied': (raw['denied'] as num?)?.toInt() ?? 0,
      'pending': (raw['pending'] as num?)?.toInt() ?? 0,
      'confidenceBuckets': confidenceBuckets,
      'totalClaims': (raw['totalClaims'] as num?)?.toInt() ?? 0,
      'averageAmount': (raw['averageAmount'] as num?)?.toDouble() ?? 0,
      'totalPaidOut': (raw['totalPaidOut'] as num?)?.toDouble() ?? 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Filters section
        _buildFilters(),
        
        // Analytics content
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _analyticsData == null
                  ? _buildEmptyState()
                  : _buildAnalyticsContent(),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return AdminSectionCard(
      title: 'Filters',
      icon: Icons.filter_list,
      actions: [
        TextButton.icon(
          onPressed: widget.onOpenInbox ??
              () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ClaimsReviewTab()),
                );
              },
          icon: const Icon(Icons.open_in_new, size: 18),
          label: const Text('Open inbox'),
        ),
        TextButton.icon(
          onPressed: _clearFilters,
          icon: const Icon(Icons.clear, size: 18),
          label: const Text('Clear'),
        ),
        FilledButton.icon(
          onPressed: _loadAnalytics,
          icon: const Icon(Icons.refresh, size: 18),
          label: const Text('Refresh'),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Filter chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Date range
              _buildDateRangeChip(),
              
              // Breed filter
              _buildDropdownFilter(
                label: 'Breed',
                value: _selectedBreed,
                items: _breeds,
                onChanged: (value) => setState(() => _selectedBreed = value),
              ),
              
              // Age range filter
              _buildDropdownFilter(
                label: 'Age Range',
                value: _selectedAgeRange,
                items: ['0-2 years', '3-5 years', '6-8 years', '9+ years'],
                onChanged: (value) => setState(() => _selectedAgeRange = value),
              ),
              
              // Region filter
              _buildDropdownFilter(
                label: 'Region',
                value: _selectedRegion,
                items: _regions,
                onChanged: (value) => setState(() => _selectedRegion = value),
              ),
              
              // Vet provider filter
              _buildDropdownFilter(
                label: 'Vet Provider',
                value: _selectedVetProvider,
                items: _vetProviders,
                onChanged: (value) => setState(() => _selectedVetProvider = value),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateRangeChip() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final dateFormat = isMobile ? DateFormat('M/d/yy') : DateFormat('MMM d, yyyy');
        final theme = Theme.of(context);
        
        return ActionChip(
          avatar: const Icon(Icons.calendar_today, size: 16),
          label: Text(
            '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
          ),
          padding: EdgeInsets.symmetric(horizontal: isMobile ? 4 : 8),
          onPressed: () async {
            final DateTimeRange? picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2024),
              lastDate: DateTime.now(),
              initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
            );
            
            if (picked != null) {
              setState(() {
                _startDate = picked.start;
                _endDate = picked.end;
              });
              _loadFilterOptions();
              _loadAnalytics();
            }
          },
        );
      },
    );
  }

  Widget _buildDropdownFilter({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    if (items.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final theme = Theme.of(context);
        
        return SizedBox(
          width: isMobile ? 200 : 240,
          child: DropdownButtonFormField<String?>(
            value: value,
            isExpanded: true,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
            ),
            decoration: InputDecoration(
              labelText: label,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              labelStyle: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface.withOpacity(0.70),
              ),
            ),
            icon: const Icon(Icons.expand_more, size: 18),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text('All $label'),
              ),
              ...items.map(
                (item) => DropdownMenuItem<String?>(
                  value: item,
                  child: Text(item),
                ),
              ),
            ],
            onChanged: (newValue) {
              onChanged(newValue);
              _loadAnalytics();
            },
          ),
        );
      },
    );
  }

  void _clearFilters() {
    setState(() {
      _selectedBreed = null;
      _selectedAgeRange = null;
      _selectedRegion = null;
      _selectedVetProvider = null;
      _startDate = DateTime.now().subtract(const Duration(days: 90));
      _endDate = DateTime.now();
    });
    _loadFilterOptions();
    _loadAnalytics();
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.analytics_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No Claims Data',
            style: ClovaraTypography.h3.copyWith(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            'Analytics will appear here once claims are filed',
            style: ClovaraTypography.body.copyWith(color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsContent() {
    final data = _analyticsData!;
    
    return SingleChildScrollView(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Summary cards
          _buildSummaryCards(data),
          
          const SizedBox(height: 24),
          
          // Claims by month (line chart)
          _buildClaimsByMonthChart(data),
          
          const SizedBox(height: 24),
          
          // Row with two charts (stacked on mobile)
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 768;
              
              if (isMobile) {
                // Stack vertically on mobile
                return Column(
                  children: [
                    _buildDecisionDistributionChart(data),
                    const SizedBox(height: 16),
                    _buildConfidenceDistributionChart(data),
                  ],
                );
              } else {
                // Side by side on desktop/tablet
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildDecisionDistributionChart(data)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildConfidenceDistributionChart(data)),
                  ],
                );
              }
            },
          ),
          
          const SizedBox(height: 24),
          
          // Average amount by month (bar chart)
          _buildAverageAmountChart(data),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(Map<String, dynamic> data) {
    final autoApproved = (data['autoApproved'] as int?) ?? 0;
    final manualApproved = (data['manualApproved'] as int?) ?? 0;
    final denom = (autoApproved + manualApproved).clamp(1, 1 << 31);
    final autoRate = (autoApproved / denom) * 100;

    final cards = [
      AdminKpiCard(
        label: 'Total claims',
        value: '${data['totalClaims']}',
        icon: Icons.description_outlined,
        color: ClovaraColors.clover,
      ),
      AdminKpiCard(
        label: 'Average amount',
        value: '\$${data['averageAmount'].toStringAsFixed(2)}',
        icon: Icons.attach_money,
        color: ClovaraColors.kSuccessMint,
      ),
      AdminKpiCard(
        label: 'Total paid out',
        value: '\$${data['totalPaidOut'].toStringAsFixed(2)}',
        icon: Icons.paid_outlined,
        color: ClovaraColors.forest,
      ),
      AdminKpiCard(
        label: 'Auto-approval rate',
        value: '${autoRate.toStringAsFixed(1)}%',
        icon: Icons.auto_awesome_outlined,
        color: ClovaraColors.sunset,
      ),
    ];

    return AdminSectionCard(
      title: 'Summary',
      icon: Icons.insights_outlined,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final perRow = width >= 1100 ? 4 : (width >= 760 ? 2 : 1);
          final cardWidth = perRow == 1 ? width : (width - ((perRow - 1) * 12)) / perRow;

          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: cards.map((c) => SizedBox(width: cardWidth, child: c)).toList(),
          );
        },
      ),
    );
  }

  Widget _buildClaimsByMonthChart(Map<String, dynamic> data) {
    final claimsByMonth = data['claimsByMonth'] as Map<String, int>;
    
    if (claimsByMonth.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = claimsByMonth.entries.toList();

    return AdminSectionCard(
      title: 'Claims by Month',
      icon: Icons.show_chart,
      child: SizedBox(
        height: 250,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 1,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey[300]!,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: ClovaraTypography.bodySmall,
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= entries.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        entries[index].key,
                        style: ClovaraTypography.bodySmall,
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: entries.asMap().entries.map((e) {
                  return FlSpot(e.key.toDouble(), e.value.value.toDouble());
                }).toList(),
                isCurved: true,
                color: ClovaraColors.clover,
                barWidth: 3,
                dotData: const FlDotData(show: true),
                belowBarData: BarAreaData(
                  show: true,
                  color: ClovaraColors.clover.withOpacity(0.2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDecisionDistributionChart(Map<String, dynamic> data) {
    final autoApproved = data['autoApproved'] as int;
    final manualApproved = data['manualApproved'] as int;
    final denied = data['denied'] as int;
    final pending = data['pending'] as int;
    
    final total = autoApproved + manualApproved + denied + pending;
    if (total == 0) return const SizedBox.shrink();

    return AdminSectionCard(
      title: 'Decision Distribution',
      icon: Icons.pie_chart_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 200,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  if (autoApproved > 0)
                    PieChartSectionData(
                      value: autoApproved.toDouble(),
                      title: '${((autoApproved / total) * 100).toInt()}%',
                      color: ClovaraColors.kSuccessMint,
                      radius: 60,
                      titleStyle: ClovaraTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (manualApproved > 0)
                    PieChartSectionData(
                      value: manualApproved.toDouble(),
                      title: '${((manualApproved / total) * 100).toInt()}%',
                      color: ClovaraColors.sunset,
                      radius: 60,
                      titleStyle: ClovaraTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (denied > 0)
                    PieChartSectionData(
                      value: denied.toDouble(),
                      title: '${((denied / total) * 100).toInt()}%',
                      color: ClovaraColors.kError,
                      radius: 60,
                      titleStyle: ClovaraTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (pending > 0)
                    PieChartSectionData(
                      value: pending.toDouble(),
                      title: '${((pending / total) * 100).toInt()}%',
                      color: ClovaraColors.kWarmCoral,
                      radius: 60,
                      titleStyle: ClovaraTypography.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          _buildLegend([
            if (autoApproved > 0) ('Auto-Approved', ClovaraColors.kSuccessMint, autoApproved),
            if (manualApproved > 0) ('Manual Approved', ClovaraColors.sunset, manualApproved),
            if (denied > 0) ('Denied', ClovaraColors.kError, denied),
            if (pending > 0) ('Pending', ClovaraColors.kWarmCoral, pending),
          ]),
        ],
      ),
    );
  }

  Widget _buildConfidenceDistributionChart(Map<String, dynamic> data) {
    final confidenceBuckets = data['confidenceBuckets'] as Map<String, int>;

    return AdminSectionCard(
      title: 'AI Confidence Distribution',
      icon: Icons.bar_chart_outlined,
      child: SizedBox(
        height: 200,
        child: BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 5,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey[300]!,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 40,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      value.toInt().toString(),
                      style: ClovaraTypography.bodySmall,
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final labels = confidenceBuckets.keys.toList();
                    final index = value.toInt();
                    if (index < 0 || index >= labels.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        labels[index],
                        style: ClovaraTypography.bodySmall,
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: confidenceBuckets.entries.toList().asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.value.toDouble(),
                    color: _getConfidenceColor(e.value.key),
                    width: 30,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildAverageAmountChart(Map<String, dynamic> data) {
    final amountsByMonth = data['amountsByMonth'] as Map<String, double>;
    final claimsByMonth = data['claimsByMonth'] as Map<String, int>;
    
    if (amountsByMonth.isEmpty) return const SizedBox.shrink();

    final entries = amountsByMonth.entries.map((e) {
      final avgAmount = claimsByMonth[e.key]! > 0 
          ? e.value / claimsByMonth[e.key]!
          : 0.0;
      return MapEntry(e.key, avgAmount);
    }).toList();

    return AdminSectionCard(
      title: 'Average Claim Amount by Month',
      icon: Icons.stacked_bar_chart,
      child: SizedBox(
        height: 250,
        child: BarChart(
          BarChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 100,
              getDrawingHorizontalLine: (value) => FlLine(
                color: Colors.grey[300]!,
                strokeWidth: 1,
              ),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 50,
                  getTitlesWidget: (value, meta) {
                    return Text(
                      '\$${value.toInt()}',
                      style: ClovaraTypography.bodySmall,
                    );
                  },
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 30,
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index < 0 || index >= entries.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        entries[index].key,
                        style: ClovaraTypography.bodySmall,
                      ),
                    );
                  },
                ),
              ),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            barGroups: entries.asMap().entries.map((e) {
              return BarChartGroupData(
                x: e.key,
                barRods: [
                  BarChartRodData(
                    toY: e.value.value,
                    color: ClovaraColors.kSuccessMint,
                    width: 40,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildLegend(List<(String, Color, int)> items) {
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: item.$2,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '${item.$1}: ${item.$3}',
              style: ClovaraTypography.bodySmall,
            ),
          ],
        );
      }).toList(),
    );
  }

  Color _getConfidenceColor(String bucket) {
    switch (bucket) {
      case '0-20%':
        return ClovaraColors.kError;
      case '20-40%':
        return ClovaraColors.kWarmCoral;
      case '40-60%':
        return ClovaraColors.sunset;
      case '60-80%':
        return ClovaraColors.sunset;
      case '80-100%':
        return ClovaraColors.kSuccessMint;
      default:
        return Colors.grey;
    }
  }
}

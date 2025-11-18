import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../theme/clovara_theme.dart';

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
  const ClaimsAnalyticsTab({super.key});

  @override
  State<ClaimsAnalyticsTab> createState() => _ClaimsAnalyticsTabState();
}

class _ClaimsAnalyticsTabState extends State<ClaimsAnalyticsTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
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
      // Load unique breeds
      final petsSnapshot = await _firestore.collection('pets').get();
      final breeds = petsSnapshot.docs
          .map((doc) => doc.data()['breed'] as String?)
          .where((breed) => breed != null && breed.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
      breeds.sort();

      // Load unique regions (from owner addresses)
      final usersSnapshot = await _firestore.collection('users').get();
      final regions = usersSnapshot.docs
          .map((doc) {
            final address = doc.data()['address'] as Map<String, dynamic>?;
            return address?['state'] as String?;
          })
          .where((state) => state != null && state.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
      regions.sort();

      // Load unique vet providers (from claim documents)
      final claimsSnapshot = await _firestore
          .collection('claims')
          .where('status', whereIn: ['processing', 'settled', 'denied'])
          .get();
      
      final vetProviders = <String>{};
      for (final doc in claimsSnapshot.docs) {
        final documents = doc.data()['documents'] as List?;
        if (documents != null) {
          for (final docData in documents) {
            final metadata = docData['metadata'] as Map<String, dynamic>?;
            final provider = metadata?['providerName'] as String?;
            if (provider != null && provider.isNotEmpty) {
              vetProviders.add(provider);
            }
          }
        }
      }
      final sortedProviders = vetProviders.toList()..sort();

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
      // TODO: Replace with Cloud Function call for better performance
      // For now, we'll aggregate client-side for development
      
      // Query claims with filters
      Query query = _firestore.collection('claims');

      // Date range filter
      query = query
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(_startDate))
          .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(_endDate));

      final claimsSnapshot = await query.get();
      
      // Filter by breed, age, region, vet provider (client-side for now)
      var filteredClaims = claimsSnapshot.docs;

      // Apply client-side filters
      if (_selectedBreed != null || _selectedAgeRange != null || _selectedRegion != null || _selectedVetProvider != null) {
        final filteredList = <QueryDocumentSnapshot>[];
        
        for (final doc in filteredClaims) {
          final data = doc.data() as Map<String, dynamic>;
          bool includeDoc = true;
          
          // Breed filter
          if (_selectedBreed != null) {
            final petDoc = await _firestore.collection('pets').doc(data['petId']).get();
            if (petDoc.data()?['breed'] != _selectedBreed) {
              includeDoc = false;
            }
          }
          
          // Region filter
          if (_selectedRegion != null && includeDoc) {
            final ownerDoc = await _firestore.collection('users').doc(data['ownerId']).get();
            final address = ownerDoc.data()?['address'] as Map<String, dynamic>?;
            if (address?['state'] != _selectedRegion) {
              includeDoc = false;
            }
          }
          
          // Vet provider filter
          if (_selectedVetProvider != null && includeDoc) {
            final documents = data['documents'] as List?;
            bool hasProvider = false;
            if (documents != null) {
              for (final docData in documents) {
                final metadata = docData['metadata'] as Map<String, dynamic>?;
                if (metadata?['providerName'] == _selectedVetProvider) {
                  hasProvider = true;
                  break;
                }
              }
            }
            if (!hasProvider) {
              includeDoc = false;
            }
          }
          
          if (includeDoc) {
            filteredList.add(doc);
          }
        }
        
        filteredClaims = filteredList;
      }

      // Aggregate data
      final analytics = await _aggregateClaimsData(filteredClaims);

      setState(() {
        _analyticsData = analytics;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: $e');
      setState(() => _isLoading = false);
    }
  }

  /// Aggregate claims data for analytics
  Future<Map<String, dynamic>> _aggregateClaimsData(List<QueryDocumentSnapshot> claims) async {
    // Claims by month
    final claimsByMonth = <String, int>{};
    final amountsByMonth = <String, double>{};
    
    // Decision distribution
    int autoApproved = 0;
    int manualApproved = 0;
    int denied = 0;
    int pending = 0;
    
    // AI confidence distribution
    final confidenceBuckets = <String, int>{
      '0-20%': 0,
      '20-40%': 0,
      '40-60%': 0,
      '60-80%': 0,
      '80-100%': 0,
    };
    
    // Average amounts
    double totalAmount = 0;
    int settledCount = 0;

    for (final doc in claims) {
      final data = doc.data() as Map<String, dynamic>;
      
      // By month
      final createdAt = (data['createdAt'] as Timestamp).toDate();
      final monthKey = DateFormat('MMM yyyy').format(createdAt);
      claimsByMonth[monthKey] = (claimsByMonth[monthKey] ?? 0) + 1;
      
      // Amount by month
      final amount = (data['claimAmount'] as num?)?.toDouble() ?? 0;
      amountsByMonth[monthKey] = (amountsByMonth[monthKey] ?? 0) + amount;
      
      // Decision distribution
      final status = data['status'] as String?;
      final aiDecision = data['aiDecision'] as String?;
      final humanOverride = data['humanOverride'] as Map<String, dynamic>?;
      
      if (status == 'settled') {
        if (humanOverride == null && aiDecision == 'approve') {
          autoApproved++;
        } else {
          manualApproved++;
        }
        totalAmount += amount;
        settledCount++;
      } else if (status == 'denied') {
        denied++;
      } else {
        pending++;
      }
      
      // AI confidence distribution
      final aiConfidence = (data['aiConfidenceScore'] as num?)?.toDouble();
      if (aiConfidence != null) {
        if (aiConfidence < 0.2) {
          confidenceBuckets['0-20%'] = confidenceBuckets['0-20%']! + 1;
        } else if (aiConfidence < 0.4) {
          confidenceBuckets['20-40%'] = confidenceBuckets['20-40%']! + 1;
        } else if (aiConfidence < 0.6) {
          confidenceBuckets['40-60%'] = confidenceBuckets['40-60%']! + 1;
        } else if (aiConfidence < 0.8) {
          confidenceBuckets['60-80%'] = confidenceBuckets['60-80%']! + 1;
        } else {
          confidenceBuckets['80-100%'] = confidenceBuckets['80-100%']! + 1;
        }
      }
    }

    return {
      'claimsByMonth': claimsByMonth,
      'amountsByMonth': amountsByMonth,
      'autoApproved': autoApproved,
      'manualApproved': manualApproved,
      'denied': denied,
      'pending': pending,
      'confidenceBuckets': confidenceBuckets,
      'totalClaims': claims.length,
      'averageAmount': settledCount > 0 ? totalAmount / settledCount : 0,
      'totalPaidOut': totalAmount,
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;
              
              if (isMobile) {
                // Stack vertically on mobile
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.filter_list, color: ClovaraColors.forest, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Filters',
                          style: ClovaraTypography.h3.copyWith(
                            color: ClovaraColors.forest,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.clear, size: 18),
                            label: const Text('Clear'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _loadAnalytics,
                            icon: const Icon(Icons.refresh, size: 18),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ClovaraColors.clover,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              } else {
                // Horizontal on desktop
                return Row(
                  children: [
                    Icon(Icons.filter_list, color: ClovaraColors.forest),
                    const SizedBox(width: 8),
                    Text(
                      'Filters',
                      style: ClovaraTypography.h3.copyWith(
                        color: ClovaraColors.forest,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: _clearFilters,
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear All'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _loadAnalytics,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Refresh'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: ClovaraColors.clover,
                      ),
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),
          
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
        
        return ActionChip(
          avatar: const Icon(Icons.calendar_today, size: 16),
          label: Text(
            '${dateFormat.format(_startDate)} - ${dateFormat.format(_endDate)}',
            style: TextStyle(fontSize: isMobile ? 12 : 14),
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
        
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: isMobile ? 8 : 12,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButton<String>(
            value: value,
            hint: Text(
              label,
              style: TextStyle(fontSize: isMobile ? 12 : 14),
            ),
            underline: const SizedBox(),
            isDense: isMobile,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: Colors.black87,
            ),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text('All $label'),
              ),
              ...items.map((item) => DropdownMenuItem(
                    value: item,
                    child: Text(item),
                  )),
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
      padding: const EdgeInsets.all(16),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 768;
        final isTablet = constraints.maxWidth < 1024;
        
        // On mobile: 1 column, on tablet: 2 columns, on desktop: 4 columns
        final crossAxisCount = isMobile ? 1 : (isTablet ? 2 : 4);
        
        final cards = [
          _buildSummaryCard(
            'Total Claims',
            data['totalClaims'].toString(),
            Icons.description,
            ClovaraColors.clover,
          ),
          _buildSummaryCard(
            'Average Amount',
            '\$${data['averageAmount'].toStringAsFixed(2)}',
            Icons.attach_money,
            ClovaraColors.kSuccessMint,
          ),
          _buildSummaryCard(
            'Total Paid Out',
            '\$${data['totalPaidOut'].toStringAsFixed(2)}',
            Icons.paid,
            ClovaraColors.forest,
          ),
          _buildSummaryCard(
            'Auto-Approval Rate',
            '${((data['autoApproved'] / (data['autoApproved'] + data['manualApproved'] + 0.01)) * 100).toStringAsFixed(1)}%',
            Icons.auto_awesome,
            ClovaraColors.sunset,
          ),
        ];
        
        if (crossAxisCount == 1) {
          // Single column for mobile
          return Column(
            children: cards.map((card) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: card,
            )).toList(),
          );
        } else {
          // Grid layout for tablet/desktop
          return Wrap(
            spacing: 16,
            runSpacing: 12,
            children: cards.map((card) => SizedBox(
              width: (constraints.maxWidth - (crossAxisCount - 1) * 16) / crossAxisCount,
              child: card,
            )).toList(),
          );
        }
      },
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.trending_up, color: color, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: ClovaraTypography.h2.copyWith(
                color: ClovaraColors.forest,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: ClovaraTypography.bodySmall.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimsByMonthChart(Map<String, dynamic> data) {
    final claimsByMonth = data['claimsByMonth'] as Map<String, int>;
    
    if (claimsByMonth.isEmpty) {
      return const SizedBox.shrink();
    }

    final entries = claimsByMonth.entries.toList();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Claims by Month',
              style: ClovaraTypography.h3.copyWith(
                color: ClovaraColors.forest,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
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
          ],
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

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Decision Distribution',
              style: ClovaraTypography.h3.copyWith(
                color: ClovaraColors.forest,
              ),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            _buildLegend([
              if (autoApproved > 0) ('Auto-Approved', ClovaraColors.kSuccessMint, autoApproved),
              if (manualApproved > 0) ('Manual Approved', ClovaraColors.sunset, manualApproved),
              if (denied > 0) ('Denied', ClovaraColors.kError, denied),
              if (pending > 0) ('Pending', ClovaraColors.kWarmCoral, pending),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildConfidenceDistributionChart(Map<String, dynamic> data) {
    final confidenceBuckets = data['confidenceBuckets'] as Map<String, int>;
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Confidence Distribution',
              style: ClovaraTypography.h3.copyWith(
                color: ClovaraColors.forest,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
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
          ],
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

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Average Claim Amount by Month',
              style: ClovaraTypography.h3.copyWith(
                color: ClovaraColors.forest,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
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
          ],
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

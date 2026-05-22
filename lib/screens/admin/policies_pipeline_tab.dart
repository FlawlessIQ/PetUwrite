import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../admin_console/components/admin_kpi_card.dart';
import '../../admin_console/components/admin_bulk_actions_bar.dart';
import '../../admin_console/components/admin_selectable_data_table.dart';
import '../../admin_console/components/admin_section_card.dart';
import '../../admin_console/components/admin_status_chip.dart';
import '../../theme/clovara_theme.dart';

/// Clovara Policies Pipeline Tab - Comprehensive policy management and analytics
class PoliciesPipelineTab extends StatefulWidget {
  const PoliciesPipelineTab({super.key});

  @override
  State<PoliciesPipelineTab> createState() => _PoliciesPipelineTabState();
}

class _PoliciesPipelineTabState extends State<PoliciesPipelineTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _policiesTableKey = GlobalKey();

  String _statusFilter = 'all';
  String _dateFilter = '30'; // days
  String _sortBy = 'date_desc';
  String _searchQuery = '';
  final Set<String> _selectedPolicyIds = <String>{};

  int? _sortColumnIndex = 5; // created
  bool _sortAscending = false; // newest first

  /// Helper to parse date from either Timestamp or String format
  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Map<String, dynamic>? _map(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return null;
  }

  String _text(
    Map<String, dynamic>? data,
    List<String> keys, [
    String fallback = '',
  ]) {
    if (data == null) return fallback;
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return fallback;
  }

  double? _numValue(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(
          value.replaceAll(RegExp(r'[^0-9.]'), ''),
        );
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  double _monthlyPremium(Map<String, dynamic> policy) {
    final plan = _map(policy['plan']);
    return _numValue(plan, ['monthlyPremium', 'monthlyPrice', 'premium']) ??
        _numValue(policy, [
          'monthlyPremium',
          'premiumAmount',
          'monthlyPrice',
        ]) ??
        0;
  }

  String _ownerName(Map<String, dynamic>? owner) {
    final fullName = _text(owner, ['fullName', 'name']);
    if (fullName.isNotEmpty) return fullName;
    return '${_text(owner, ['firstName'])} ${_text(owner, ['lastName'])}'
        .trim();
  }

  bool _isEligibleQuote(Map<String, dynamic> quote) {
    final eligibility = _map(quote['eligibility']);
    if (eligibility == null) return false;
    if (eligibility['eligible'] == true) return true;
    final status = _text(eligibility, ['status']).toLowerCase();
    return status == 'eligible' ||
        status == 'approved' ||
        status == 'bind_ready';
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        controller: _scrollController,
        padding: EdgeInsets.zero,
        children: [
          // KPI Dashboard
          _buildKPIDashboard(),
          const SizedBox(height: 24),

          // Status Breakdown
          _buildStatusBreakdown(),
          const SizedBox(height: 24),

          // Conversion Funnel
          _buildConversionFunnel(),
          const SizedBox(height: 24),

          // Filters
          _buildFilters(),
          const SizedBox(height: 16),

          // Policies List
          _buildPoliciesList(),
        ],
      ),
    );
  }

  /// KPI Dashboard with key metrics
  Widget _buildKPIDashboard() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('policies').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final policies = snapshot.data!.docs;
        final activePolicies = policies.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'active';
        }).length;

        final now = DateTime.now();
        final thirtyDaysAgo = now.subtract(const Duration(days: 30));

        final newPolicies = policies.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = _parseDate(data['createdAt']);
          return createdAt != null && createdAt.isAfter(thirtyDaysAgo);
        }).length;

        double mrr = 0;
        for (final doc in policies) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['status'] == 'active') {
            mrr += _monthlyPremium(data);
          }
        }

        final arr = mrr * 12;
        final avgPolicyValue = activePolicies > 0 ? mrr / activePolicies : 0;

        return AdminSectionCard(
          title: 'Policy Metrics',
          icon: Icons.dashboard_outlined,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                AdminKpiCard(
                  label: 'Total policies',
                  value: '${policies.length}',
                  icon: Icons.policy_outlined,
                  color: ClovaraColors.clover,
                ),
                AdminKpiCard(
                  label: 'Active',
                  value: '$activePolicies',
                  icon: Icons.check_circle_outline,
                  color: ClovaraColors.clover,
                  onTap: () {
                    setState(() => _statusFilter = 'active');
                    _scrollToPoliciesTable();
                  },
                ),
                AdminKpiCard(
                  label: 'New (30d)',
                  value: '$newPolicies',
                  icon: Icons.fiber_new_outlined,
                  color: ClovaraColors.sunset,
                  onTap: () {
                    setState(() => _dateFilter = '30');
                    _scrollToPoliciesTable();
                  },
                ),
                AdminKpiCard(
                  label: 'MRR',
                  value: '\$${mrr.toStringAsFixed(0)}',
                  icon: Icons.attach_money,
                  color: Colors.indigo,
                ),
                AdminKpiCard(
                  label: 'ARR',
                  value: '\$${arr.toStringAsFixed(0)}',
                  icon: Icons.trending_up,
                  color: Colors.indigo,
                ),
                AdminKpiCard(
                  label: 'Avg premium',
                  value: '\$${avgPolicyValue.toStringAsFixed(2)}',
                  icon: Icons.calculate_outlined,
                  color: ClovaraColors.forest,
                ),
              ];

              if (constraints.maxWidth >= 1100) {
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: cards
                      .map((c) => SizedBox(width: 320, child: c))
                      .toList(),
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards
                    .map((c) => SizedBox(width: 360, child: c))
                    .toList(),
              );
            },
          ),
        );
      },
    );
  }

  /// Status breakdown chart
  Widget _buildStatusBreakdown() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore.collection('policies').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final policies = snapshot.data!.docs;
        final statusCounts = <String, int>{};

        for (final doc in policies) {
          final data = doc.data() as Map<String, dynamic>;
          final status = data['status'] as String? ?? 'unknown';
          statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        }

        return AdminSectionCard(
          title: 'Policy Status Breakdown',
          icon: Icons.donut_small_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: statusCounts.entries.map((entry) {
                  final color = _getStatusColor(entry.key);
                  final percentage = policies.isNotEmpty
                      ? (entry.value / policies.length * 100)
                      : 0;
                  return InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () {
                      setState(() {
                        _statusFilter = entry.key;
                        _selectedPolicyIds.clear();
                      });
                      _scrollToPoliciesTable();
                    },
                    child: AdminStatusChip(
                      label:
                          '${_formatStatus(entry.key)} • ${entry.value} (${percentage.toStringAsFixed(0)}%)',
                      color: color,
                      icon: Icons.circle,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Conversion funnel visualization
  Widget _buildConversionFunnel() {
    return FutureBuilder<Map<String, int>>(
      future: _getConversionMetrics(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final metrics = snapshot.data!;
        final totalQuotes = metrics['totalQuotes'] ?? 0;
        final eligibleQuotes = metrics['eligibleQuotes'] ?? 0;
        final totalPolicies = metrics['totalPolicies'] ?? 0;
        final activePolicies = metrics['activePolicies'] ?? 0;

        final eligibleRate = totalQuotes > 0
            ? (eligibleQuotes / totalQuotes * 100).toDouble()
            : 0.0;
        final conversionRate = eligibleQuotes > 0
            ? (totalPolicies / eligibleQuotes * 100).toDouble()
            : 0.0;
        final retentionRate = totalPolicies > 0
            ? (activePolicies / totalPolicies * 100).toDouble()
            : 0.0;

        return AdminSectionCard(
          title: 'Conversion Funnel',
          icon: Icons.filter_alt_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFunnelStage(
                'Total Quotes',
                totalQuotes,
                100,
                ClovaraColors.clover,
                null,
              ),
              _buildFunnelArrow(eligibleRate),
              _buildFunnelStage(
                'Eligible Quotes',
                eligibleQuotes,
                eligibleRate,
                ClovaraColors.clover,
                totalQuotes,
              ),
              _buildFunnelArrow(conversionRate),
              _buildFunnelStage(
                'Policies Created',
                totalPolicies,
                conversionRate,
                ClovaraColors.sunset,
                eligibleQuotes,
              ),
              _buildFunnelArrow(retentionRate),
              _buildFunnelStage(
                'Active Policies',
                activePolicies,
                retentionRate,
                ClovaraColors.clover,
                totalPolicies,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFunnelStage(
    String label,
    int count,
    double percentage,
    Color color,
    int? previousCount,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Row(
        children: [
          Icon(Icons.arrow_forward, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (previousCount != null)
                  Text(
                    '${percentage.toStringAsFixed(1)}% conversion',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
          ),
          Text(
            count.toString(),
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

  Widget _buildFunnelArrow(double percentage) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const SizedBox(width: 32),
          Icon(Icons.keyboard_arrow_down, color: Colors.grey[400], size: 24),
          const SizedBox(width: 8),
          Text(
            '${percentage.toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// Filters section
  Widget _buildFilters() {
    final statusOptions = <String, String>{
      'all': 'All Statuses',
      'active': 'Active',
      'pending': 'Pending',
      'expired': 'Expired',
      'cancelled': 'Cancelled',
      'lapsed': 'Lapsed',
      'unknown': 'Unknown',
    };

    if (!statusOptions.containsKey(_statusFilter)) {
      statusOptions[_statusFilter] = _formatStatus(_statusFilter);
    }

    return AdminSectionCard(
      title: 'Filters',
      icon: Icons.tune,
      actions: [
        TextButton.icon(
          onPressed: () => setState(() {
            _statusFilter = 'all';
            _dateFilter = '30';
            _applySort('date_desc');
            _searchQuery = '';
            _selectedPolicyIds.clear();
          }),
          icon: const Icon(Icons.clear_all, size: 18),
          label: const Text('Reset'),
        ),
      ],
      child: Column(
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _statusFilter,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Status',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                    labelStyle: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.70),
                        ),
                  ),
                  isExpanded: true,
                  items: statusOptions.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => _statusFilter = value!),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _dateFilter,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Date Range',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                    labelStyle: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.70),
                        ),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: '7', child: Text('Last 7 days')),
                    DropdownMenuItem(value: '30', child: Text('Last 30 days')),
                    DropdownMenuItem(value: '90', child: Text('Last 90 days')),
                    DropdownMenuItem(value: 'all', child: Text('All time')),
                  ],
                  onChanged: (value) => setState(() => _dateFilter = value!),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  value: _sortBy,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Sort By',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    isDense: true,
                    labelStyle: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.70),
                        ),
                  ),
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(
                      value: 'date_desc',
                      child: Text('Newest First'),
                    ),
                    DropdownMenuItem(
                      value: 'date_asc',
                      child: Text('Oldest First'),
                    ),
                    DropdownMenuItem(
                      value: 'premium_desc',
                      child: Text('Highest Premium'),
                    ),
                    DropdownMenuItem(
                      value: 'premium_asc',
                      child: Text('Lowest Premium'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _applySort(value));
                  },
                ),
              ),
              SizedBox(
                width: 360,
                child: TextField(
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Search',
                    hintText: 'Policy #, pet, owner, plan, policyId…',
                    isDense: true,
                    prefixIcon: Icon(Icons.search),
                    labelStyle: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.70),
                        ),
                  ),
                  onChanged: (v) =>
                      setState(() => _searchQuery = v.trim().toLowerCase()),
                ),
              ),
            ],
          ),
          if (_selectedPolicyIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                AdminStatusChip(
                  label: 'Selected: ${_selectedPolicyIds.length}',
                  color: ClovaraColors.forest,
                  icon: Icons.select_all,
                ),
                const SizedBox(width: 10),
                TextButton.icon(
                  onPressed: () => setState(() => _selectedPolicyIds.clear()),
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('Clear selection'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Policies list
  Widget _buildPoliciesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredPoliciesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading policies: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.policy, size: 64, color: Colors.grey[400]),
                    const SizedBox(height: 16),
                    Text(
                      'No policies found',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // Apply client-side filtering and sorting
        final policies = _filterAndSortPolicies(snapshot.data!.docs);

        // Keep selection consistent with current result set (without mutating during build)
        final visibleIds = policies.map((d) => d.id).toSet();
        final effectiveSelectedIds = _selectedPolicyIds
            .where(visibleIds.contains)
            .toSet();
        if (effectiveSelectedIds.length != _selectedPolicyIds.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() {
              _selectedPolicyIds
                ..clear()
                ..addAll(effectiveSelectedIds);
            });
          });
        }

        if (policies.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.filter_list_off,
                      size: 64,
                      color: Colors.grey[400],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No policies match the selected filters',
                      style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final anySelected = effectiveSelectedIds.isNotEmpty;
        final selectedDocs = anySelected
            ? policies
                  .where((d) => effectiveSelectedIds.contains(d.id))
                  .toList()
            : const <QueryDocumentSnapshot>[];

        return AdminSectionCard(
          title: 'Policies',
          icon: Icons.policy_outlined,
          actions: [
            AdminStatusChip(
              label: '${policies.length} results',
              color: ClovaraColors.slate,
              icon: Icons.list_alt,
            ),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(key: _policiesTableKey),
              AdminBulkActionsBar(
                resultsCount: policies.length,
                selectedCount: effectiveSelectedIds.length,
                onSelectVisible: policies.isEmpty
                    ? null
                    : () => setState(
                        () => _selectedPolicyIds.addAll(
                          policies.map((d) => d.id),
                        ),
                      ),
                onClearSelection: () =>
                    setState(() => _selectedPolicyIds.clear()),
                actions: [
                  TextButton.icon(
                    onPressed: policies.isEmpty
                        ? null
                        : () async {
                            final csv = _buildPoliciesCsv(policies);
                            await Clipboard.setData(ClipboardData(text: csv));
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Copied CSV for ${policies.length} visible policies',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            }
                          },
                    icon: const Icon(Icons.table_view, size: 18),
                    label: const Text('Copy CSV (visible)'),
                  ),
                  if (anySelected)
                    FilledButton.icon(
                      onPressed: () async {
                        final csv = _buildPoliciesCsv(selectedDocs);
                        await Clipboard.setData(ClipboardData(text: csv));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Copied CSV for ${selectedDocs.length} selected policies',
                              ),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.table_view, size: 18),
                      label: const Text('Copy CSV (selected)'),
                    ),
                  if (anySelected)
                    TextButton.icon(
                      onPressed: () async {
                        final ids = effectiveSelectedIds.toList()..sort();
                        await Clipboard.setData(
                          ClipboardData(text: ids.join('\n')),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Copied ${ids.length} policy IDs'),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy, size: 18),
                      label: const Text('Copy IDs'),
                    ),
                  if (anySelected)
                    FilledButton.icon(
                      onPressed: () {
                        final firstId = effectiveSelectedIds.first;
                        final firstDoc = policies.firstWhere(
                          (d) => d.id == firstId,
                          orElse: () => policies.first,
                        );
                        final data = firstDoc.data() as Map<String, dynamic>;
                        _showPolicyDetails(firstDoc.id, data);
                      },
                      icon: const Icon(Icons.open_in_new, size: 18),
                      label: const Text('Open selected'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              AdminSelectableDataTable<QueryDocumentSnapshot>(
                items: policies,
                getId: (d) => d.id,
                selectedIds: _selectedPolicyIds,
                onSelectedIdsChanged: (next) => setState(() {
                  _selectedPolicyIds
                    ..clear()
                    ..addAll(next);
                }),
                sortAscending: _sortAscending,
                sortColumnIndex: _sortColumnIndex,
                columns: [
                  const DataColumn(label: Text('Policy #')),
                  const DataColumn(label: Text('Pet')),
                  const DataColumn(label: Text('Owner')),
                  const DataColumn(label: Text('Status')),
                  DataColumn(
                    label: const Text('Premium'),
                    numeric: true,
                    onSort: (columnIndex, ascending) {
                      setState(
                        () => _applySort(
                          ascending ? 'premium_asc' : 'premium_desc',
                        ),
                      );
                    },
                  ),
                  DataColumn(
                    label: const Text('Created'),
                    onSort: (columnIndex, ascending) {
                      setState(
                        () => _applySort(ascending ? 'date_asc' : 'date_desc'),
                      );
                    },
                  ),
                ],
                buildCells: (context, doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final policyNumber = (data['policyNumber'] as String?) ?? '—';
                  final pet = _map(data['pet']);
                  final owner = _map(data['owner']);
                  final status = (data['status'] as String?) ?? 'unknown';
                  final createdAt = _parseDate(data['createdAt']);
                  final monthlyPremium = _monthlyPremium(data);

                  return [
                    DataCell(
                      Text(policyNumber),
                      onTap: () => _showPolicyDetails(doc.id, data),
                    ),
                    DataCell(
                      Row(
                        children: [
                          Icon(
                            _text(pet, [
                                      'species',
                                      'type',
                                      'petType',
                                    ]).toLowerCase() ==
                                    'dog'
                                ? Icons.pets
                                : Icons.cruelty_free,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withOpacity(0.7),
                          ),
                          const SizedBox(width: 8),
                          Text(_text(pet, ['name'], 'Unknown')),
                        ],
                      ),
                      onTap: () => _showPolicyDetails(doc.id, data),
                    ),
                    DataCell(
                      Text(
                        _ownerName(owner).isEmpty
                            ? 'Unknown'
                            : _ownerName(owner),
                      ),
                      onTap: () => _showPolicyDetails(doc.id, data),
                    ),
                    DataCell(
                      AdminStatusChip(
                        label: _formatStatus(status),
                        color: _getStatusColor(status),
                      ),
                      onTap: () => _showPolicyDetails(doc.id, data),
                    ),
                    DataCell(
                      Text('\$${monthlyPremium.toStringAsFixed(2)}'),
                      onTap: () => _showPolicyDetails(doc.id, data),
                    ),
                    DataCell(
                      Text(createdAt == null ? '—' : _formatDate(createdAt)),
                      onTap: () => _showPolicyDetails(doc.id, data),
                    ),
                  ];
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _applySort(String sortBy) {
    _sortBy = sortBy;

    switch (sortBy) {
      case 'premium_asc':
        _sortColumnIndex = 4;
        _sortAscending = true;
        break;
      case 'premium_desc':
        _sortColumnIndex = 4;
        _sortAscending = false;
        break;
      case 'date_asc':
        _sortColumnIndex = 5;
        _sortAscending = true;
        break;
      case 'date_desc':
      default:
        _sortColumnIndex = 5;
        _sortAscending = false;
        break;
    }
  }

  void _scrollToPoliciesTable() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _policiesTableKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        alignment: 0.1,
      );
    });
  }

  String _buildPoliciesCsv(List<QueryDocumentSnapshot> docs) {
    final rows = <List<String>>[];

    rows.add([
      'policyId',
      'policyNumber',
      'status',
      'createdAt',
      'petName',
      'species',
      'breed',
      'ownerFirstName',
      'ownerLastName',
      'ownerEmail',
      'planName',
      'monthlyPremium',
    ]);

    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>;
      final pet = _map(data['pet']);
      final owner = _map(data['owner']);
      final plan = _map(data['plan']);
      final createdAt = _parseDate(data['createdAt']);
      final monthlyPremium = _monthlyPremium(data);

      rows.add([
        doc.id,
        (data['policyNumber'] ?? '').toString(),
        (data['status'] ?? '').toString(),
        createdAt == null ? '' : createdAt.toIso8601String(),
        _text(pet, ['name']),
        _text(pet, ['species', 'type', 'petType']),
        _text(pet, ['breed']),
        _text(owner, ['firstName']),
        _text(owner, ['lastName']),
        _text(owner, ['email']),
        _text(plan, ['name']),
        monthlyPremium.toStringAsFixed(2),
      ]);
    }

    final b = StringBuffer();
    for (final row in rows) {
      b.writeln(row.map(_csvEscape).join(','));
    }
    return b.toString();
  }

  String _csvEscape(String value) {
    final needsQuotes =
        value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) return value;
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return ClovaraColors.clover;
      case 'pending':
        return ClovaraColors.sunset;
      case 'expired':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      case 'lapsed':
        return Colors.deepOrange;
      default:
        return ClovaraColors.clover;
    }
  }

  String _formatStatus(String status) {
    return status[0].toUpperCase() + status.substring(1).toLowerCase();
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  Stream<QuerySnapshot> _getFilteredPoliciesStream() {
    Query query = _firestore.collection('policies');

    // Apply status filter (server-side for efficiency)
    if (_statusFilter != 'all') {
      query = query.where('status', isEqualTo: _statusFilter);
    }

    // Note: Date filtering and sorting done client-side due to mixed data types
    // (some policies have createdAt as String, some as Timestamp)

    return query.snapshots();
  }

  /// Apply client-side filtering and sorting to handle mixed data types
  List<QueryDocumentSnapshot> _filterAndSortPolicies(
    List<QueryDocumentSnapshot> docs,
  ) {
    var filtered = docs;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final policyNumber = (data['policyNumber'] ?? '')
            .toString()
            .toLowerCase();
        final pet = _map(data['pet']);
        final owner = _map(data['owner']);
        final plan = _map(data['plan']);

        final petName = _text(pet, ['name']).toLowerCase();
        final ownerName = _ownerName(owner).toLowerCase();
        final planName = _text(plan, ['name']).toLowerCase();
        final status = (data['status'] ?? '').toString().toLowerCase();
        final id = doc.id.toLowerCase();

        return policyNumber.contains(_searchQuery) ||
            petName.contains(_searchQuery) ||
            ownerName.contains(_searchQuery) ||
            planName.contains(_searchQuery) ||
            status.contains(_searchQuery) ||
            id.contains(_searchQuery);
      }).toList();
    }

    // Client-side date filtering
    if (_dateFilter != 'all') {
      final days = int.parse(_dateFilter);
      final cutoffDate = DateTime.now().subtract(Duration(days: days));
      filtered = filtered.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final createdAt = _parseDate(data['createdAt']);
        return createdAt != null && createdAt.isAfter(cutoffDate);
      }).toList();
    }

    // Client-side sorting
    if (_sortBy.startsWith('date')) {
      filtered.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aDate = _parseDate(aData['createdAt']);
        final bDate = _parseDate(bData['createdAt']);

        if (aDate == null && bDate == null) return 0;
        if (aDate == null) return 1;
        if (bDate == null) return -1;

        final comparison = aDate.compareTo(bDate);
        return _sortBy == 'date_desc' ? -comparison : comparison;
      });
    } else if (_sortBy.startsWith('premium')) {
      filtered.sort((a, b) {
        final aData = a.data() as Map<String, dynamic>;
        final bData = b.data() as Map<String, dynamic>;
        final aPremium = _monthlyPremium(aData);
        final bPremium = _monthlyPremium(bData);

        final comparison = aPremium.compareTo(bPremium);
        return _sortBy == 'premium_desc' ? -comparison : comparison;
      });
    }

    return filtered;
  }

  Future<Map<String, int>> _getConversionMetrics() async {
    try {
      final quotesSnapshot = await _firestore.collection('quotes').get();
      final eligibleQuotes = quotesSnapshot.docs.where((doc) {
        final data = doc.data();
        return _isEligibleQuote(data);
      }).length;

      final policiesSnapshot = await _firestore.collection('policies').get();
      final activePolicies = policiesSnapshot.docs.where((doc) {
        final data = doc.data();
        return data['status'] == 'active';
      }).length;

      return {
        'totalQuotes': quotesSnapshot.docs.length,
        'eligibleQuotes': eligibleQuotes,
        'totalPolicies': policiesSnapshot.docs.length,
        'activePolicies': activePolicies,
      };
    } catch (e) {
      return {
        'totalQuotes': 0,
        'eligibleQuotes': 0,
        'totalPolicies': 0,
        'activePolicies': 0,
      };
    }
  }

  void _showPolicyDetails(String policyId, Map<String, dynamic> data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Policy #${data['policyNumber']}'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDetailRow(
                'Status',
                _formatStatus(data['status'] ?? 'unknown'),
              ),
              _buildDetailRow(
                'Pet',
                _text(_map(data['pet']), ['name'], 'Unknown'),
              ),
              _buildDetailRow(
                'Species',
                _text(_map(data['pet']), [
                  'species',
                  'type',
                  'petType',
                ], 'Unknown'),
              ),
              _buildDetailRow(
                'Breed',
                _text(_map(data['pet']), ['breed'], 'Unknown'),
              ),
              _buildDetailRow(
                'Owner',
                _ownerName(_map(data['owner'])).isEmpty
                    ? 'Unknown'
                    : _ownerName(_map(data['owner'])),
              ),
              _buildDetailRow(
                'Email',
                _text(_map(data['owner']), ['email'], 'N/A'),
              ),
              _buildDetailRow(
                'Plan',
                _text(_map(data['plan']), ['name'], 'Unknown'),
              ),
              _buildDetailRow(
                'Premium',
                '\$${_monthlyPremium(data).toStringAsFixed(2)}/mo',
              ),
              const SizedBox(height: 12),
              const Text(
                'Policy ID:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SelectableText(
                policyId,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

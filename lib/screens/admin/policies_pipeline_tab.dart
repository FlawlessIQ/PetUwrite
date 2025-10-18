import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Policies Pipeline Tab - Comprehensive policy management and analytics
class PoliciesPipelineTab extends StatefulWidget {
  const PoliciesPipelineTab({super.key});

  @override
  State<PoliciesPipelineTab> createState() => _PoliciesPipelineTabState();
}

class _PoliciesPipelineTabState extends State<PoliciesPipelineTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  String _statusFilter = 'all';
  String _dateFilter = '30'; // days
  String _sortBy = 'date_desc';
  
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
  
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => setState(() {}),
      child: ListView(
        padding: const EdgeInsets.all(16),
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
            final plan = data['plan'] as Map<String, dynamic>?;
            mrr += (plan?['monthlyPremium'] as num?)?.toDouble() ?? 0;
          }
        }
        
        final arr = mrr * 12;
        final avgPolicyValue = activePolicies > 0 ? mrr / activePolicies : 0;

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.dashboard, 
                        color: Theme.of(context).primaryColor, size: 28),
                    const SizedBox(width: 12),
                    const Text(
                      'Policy Metrics',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'Total Policies',
                        policies.length.toString(),
                        Icons.policy,
                        Colors.blue,
                        '${policies.length} total',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Active Policies',
                        activePolicies.toString(),
                        Icons.check_circle,
                        Colors.green,
                        '$activePolicies active',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'New (30d)',
                        newPolicies.toString(),
                        Icons.fiber_new,
                        Colors.orange,
                        'Last 30 days',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMetricCard(
                        'MRR',
                        '\$${mrr.toStringAsFixed(0)}',
                        Icons.attach_money,
                        Colors.purple,
                        'Monthly Recurring',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'ARR',
                        '\$${arr.toStringAsFixed(0)}',
                        Icons.trending_up,
                        Colors.teal,
                        'Annual Recurring',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMetricCard(
                        'Avg Premium',
                        '\$${avgPolicyValue.toStringAsFixed(2)}',
                        Icons.calculate,
                        Colors.indigo,
                        'Per policy/month',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    String subtitle,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
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

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Policy Status Breakdown',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    ...statusCounts.entries.map((entry) {
                      final color = _getStatusColor(entry.key);
                      final percentage = policies.isNotEmpty
                          ? (entry.value / policies.length * 100)
                          : 0;
                      
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Column(
                            children: [
                              Container(
                                height: 100,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: color),
                                ),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        entry.value.toString(),
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: color,
                                        ),
                                      ),
                                      Text(
                                        '${percentage.toStringAsFixed(0)}%',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _formatStatus(entry.key),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ],
            ),
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

        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Conversion Funnel',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                _buildFunnelStage(
                  'Total Quotes',
                  totalQuotes,
                  100,
                  Colors.blue,
                  null,
                ),
                _buildFunnelArrow(eligibleRate),
                _buildFunnelStage(
                  'Eligible Quotes',
                  eligibleQuotes,
                  eligibleRate,
                  Colors.green,
                  totalQuotes,
                ),
                _buildFunnelArrow(conversionRate),
                _buildFunnelStage(
                  'Policies Created',
                  totalPolicies,
                  conversionRate,
                  Colors.orange,
                  eligibleQuotes,
                ),
                _buildFunnelArrow(retentionRate),
                _buildFunnelStage(
                  'Active Policies',
                  activePolicies,
                  retentionRate,
                  Colors.purple,
                  totalPolicies,
                ),
              ],
            ),
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
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
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
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // Status filter
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            value: _statusFilter,
            decoration: const InputDecoration(
              labelText: 'Status',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('All Statuses')),
              DropdownMenuItem(value: 'active', child: Text('Active')),
              DropdownMenuItem(value: 'pending', child: Text('Pending')),
              DropdownMenuItem(value: 'expired', child: Text('Expired')),
              DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
            ],
            onChanged: (value) => setState(() => _statusFilter = value!),
          ),
        ),
        // Date filter
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            value: _dateFilter,
            decoration: const InputDecoration(
              labelText: 'Date Range',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
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
        // Sort
        SizedBox(
          width: 200,
          child: DropdownButtonFormField<String>(
            value: _sortBy,
            decoration: const InputDecoration(
              labelText: 'Sort By',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            isExpanded: true,
            items: const [
              DropdownMenuItem(value: 'date_desc', child: Text('Newest First')),
              DropdownMenuItem(value: 'date_asc', child: Text('Oldest First')),
              DropdownMenuItem(value: 'premium_desc', child: Text('Highest Premium')),
              DropdownMenuItem(value: 'premium_asc', child: Text('Lowest Premium')),
            ],
            onChanged: (value) => setState(() => _sortBy = value!),
          ),
        ),
      ],
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
        
        if (policies.isEmpty) {
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.filter_list_off, size: 64, color: Colors.grey[400]),
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

        return Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text(
                      'Policies',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${policies.length} total',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[900],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: policies.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final doc = policies[index];
                  return _buildPolicyListItem(doc);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPolicyListItem(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final policyNumber = data['policyNumber'] as String? ?? 'N/A';
    final pet = data['pet'] as Map<String, dynamic>?;
    final owner = data['owner'] as Map<String, dynamic>?;
    final plan = data['plan'] as Map<String, dynamic>?;
    final status = data['status'] as String? ?? 'unknown';
    final createdAt = _parseDate(data['createdAt']);
    // final effectiveDate = data['effectiveDate'];
    // final expirationDate = data['expirationDate'];

    final monthlyPremium = (plan?['monthlyPremium'] as num?)?.toDouble() ?? 0;
    final planName = plan?['name'] as String? ?? 'Unknown';
    // effectiveDate and expirationDate available if needed for future features

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        backgroundColor: _getStatusColor(status).withOpacity(0.2),
        child: Icon(
          pet?['species'] == 'Dog' ? Icons.pets : Icons.cruelty_free,
          color: _getStatusColor(status),
        ),
      ),
      title: Row(
        children: [
          Text(
            pet?['name'] ?? 'Unknown Pet',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _getStatusColor(status)),
            ),
            child: Text(
              _formatStatus(status),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: _getStatusColor(status),
              ),
            ),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Policy #$policyNumber • ${owner?['firstName']} ${owner?['lastName']}'),
          Text(
            '$planName - \$${monthlyPremium.toStringAsFixed(2)}/mo',
            style: const TextStyle(fontSize: 12),
          ),
          if (createdAt != null)
            Text(
              'Created ${_formatDate(createdAt)}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.arrow_forward_ios, size: 16),
        onPressed: () => _showPolicyDetails(doc.id, data),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'expired':
        return Colors.grey;
      case 'cancelled':
        return Colors.red;
      case 'lapsed':
        return Colors.deepOrange;
      default:
        return Colors.blue;
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
  List<QueryDocumentSnapshot> _filterAndSortPolicies(List<QueryDocumentSnapshot> docs) {
    var filtered = docs;
    
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
        final aPremium = (aData['plan'] as Map<String, dynamic>?)?['monthlyPremium'] as num? ?? 0;
        final bPremium = (bData['plan'] as Map<String, dynamic>?)?['monthlyPremium'] as num? ?? 0;
        
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
        return data['eligibility']?['eligible'] == true;
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
              _buildDetailRow('Status', _formatStatus(data['status'] ?? 'unknown')),
              _buildDetailRow('Pet', data['pet']?['name'] ?? 'Unknown'),
              _buildDetailRow('Species', data['pet']?['species'] ?? 'Unknown'),
              _buildDetailRow('Breed', data['pet']?['breed'] ?? 'Unknown'),
              _buildDetailRow('Owner', 
                  '${data['owner']?['firstName']} ${data['owner']?['lastName']}'),
              _buildDetailRow('Email', data['owner']?['email'] ?? 'N/A'),
              _buildDetailRow('Plan', data['plan']?['name'] ?? 'Unknown'),
              _buildDetailRow('Premium', 
                  '\$${(data['plan']?['monthlyPremium'] ?? 0).toStringAsFixed(2)}/mo'),
              const SizedBox(height: 12),
              const Text('Policy ID:', style: TextStyle(fontWeight: FontWeight.bold)),
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

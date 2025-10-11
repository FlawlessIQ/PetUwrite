import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../widgets/explainability_chart.dart';
import '../models/explainability_data.dart';
import 'admin_rules_editor_page.dart';
import 'admin/claims_analytics_tab.dart';
import '../widgets/system_health_widget.dart';

/// Admin dashboard for human underwriters to review high-risk quotes
/// Only accessible to users with userRole == 2
class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _selectedFilter = 'all'; // all, pending, overridden
  String _sortBy = 'score_desc'; // score_desc, score_asc, date_desc, date_asc
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: const [
            Tab(icon: Icon(Icons.warning), text: 'High Risk'),
            Tab(icon: Icon(Icons.block), text: 'Ineligible'),
            Tab(icon: Icon(Icons.analytics), text: 'Claims Analytics'),
            Tab(icon: Icon(Icons.edit_note), text: 'Rules Editor'),
            Tab(icon: Icon(Icons.monitor_heart), text: 'System Health'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => setState(() {}),
            tooltip: 'Refresh',
          ),
          if (_tabController.index == 0)
            PopupMenuButton<String>(
              icon: const Icon(Icons.sort),
              tooltip: 'Sort by',
              onSelected: (value) => setState(() => _sortBy = value),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'score_desc',
                  child: Text('Risk Score (High to Low)'),
                ),
                const PopupMenuItem(
                  value: 'score_asc',
                  child: Text('Risk Score (Low to High)'),
                ),
                const PopupMenuItem(
                  value: 'date_desc',
                  child: Text('Date (Newest First)'),
                ),
                const PopupMenuItem(
                  value: 'date_asc',
                  child: Text('Date (Oldest First)'),
                ),
              ],
            ),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // High Risk Tab
          Column(
            children: [
              _buildFilterChips(),
              _buildStatsBar(),
              Expanded(child: _buildQuotesList()),
            ],
          ),
          // Ineligible Tab
          _buildIneligibleQuotesTab(),
          // Claims Analytics Tab
          const ClaimsAnalyticsTab(),
          // Rules Editor Tab
          const AdminRulesEditorPage(),
          // System Health Tab
          _buildSystemHealthTab(),
        ],
      ),
    );
  }

  /// Filter chips for quote status
  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _buildFilterChip('All Quotes', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Pending Review', 'pending'),
          const SizedBox(width: 8),
          _buildFilterChip('Overridden', 'overridden'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) => setState(() => _selectedFilter = value),
      selectedColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
      checkmarkColor: Theme.of(context).colorScheme.primary,
    );
  }

  /// Statistics bar showing counts
  Widget _buildStatsBar() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('quotes')
          .where('riskScore.totalScore', isGreaterThan: 80)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox(height: 60);
        }

        final allQuotes = snapshot.data!.docs;
        final pendingCount = allQuotes
            .where((doc) => !(doc.data() as Map<String, dynamic>)
                .containsKey('humanOverride'))
            .length;
        final overriddenCount = allQuotes
            .where((doc) => (doc.data() as Map<String, dynamic>)
                .containsKey('humanOverride'))
            .length;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatCard(
                'Total High-Risk',
                allQuotes.length.toString(),
                Icons.warning_amber,
                Colors.orange,
              ),
              _buildStatCard(
                'Pending Review',
                pendingCount.toString(),
                Icons.pending_actions,
                Colors.red,
              ),
              _buildStatCard(
                'Overridden',
                overriddenCount.toString(),
                Icons.check_circle,
                Colors.green,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard(
      String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
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
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  /// Main quotes list
  Widget _buildQuotesList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getFilteredQuotesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading quotes: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No high-risk quotes found',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'Quotes with risk score > 80 will appear here',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        var quotes = snapshot.data!.docs;

        // Apply sorting
        quotes.sort((a, b) {
          final dataA = a.data() as Map<String, dynamic>;
          final dataB = b.data() as Map<String, dynamic>;

          switch (_sortBy) {
            case 'score_asc':
              final scoreA = dataA['riskScore']?['totalScore'] ?? 0;
              final scoreB = dataB['riskScore']?['totalScore'] ?? 0;
              return scoreA.compareTo(scoreB);
            case 'score_desc':
              final scoreA = dataA['riskScore']?['totalScore'] ?? 0;
              final scoreB = dataB['riskScore']?['totalScore'] ?? 0;
              return scoreB.compareTo(scoreA);
            case 'date_asc':
              final dateA = (dataA['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime(1970);
              final dateB = (dataB['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime(1970);
              return dateA.compareTo(dateB);
            case 'date_desc':
            default:
              final dateA = (dataA['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime(1970);
              final dateB = (dataB['createdAt'] as Timestamp?)?.toDate() ??
                  DateTime(1970);
              return dateB.compareTo(dateA);
          }
        });

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: quotes.length,
          itemBuilder: (context, index) {
            final doc = quotes[index];
            return _buildQuoteCard(doc);
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getFilteredQuotesStream() {
    Query query = _firestore
        .collection('quotes')
        .where('riskScore.totalScore', isGreaterThan: 80);

    // Note: Additional filtering by humanOverride field is done in _buildQuotesList
    // because Firestore doesn't support complex OR queries efficiently

    return query.snapshots();
  }

  /// Individual quote card
  Widget _buildQuoteCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final hasOverride = data.containsKey('humanOverride');

    // Apply filter
    if (_selectedFilter == 'pending' && hasOverride) return const SizedBox();
    if (_selectedFilter == 'overridden' && !hasOverride) {
      return const SizedBox();
    }

    final riskScoreData = data['riskScore'] as Map<String, dynamic>?;
    final totalScore = riskScoreData?['totalScore'] ?? 0;
    final aiDecision = riskScoreData?['aiAnalysis']?['decision'] ?? 'Unknown';
    final petData = data['pet'] as Map<String, dynamic>?;
    final ownerData = data['owner'] as Map<String, dynamic>?;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showQuoteDetails(doc),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Risk score badge
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: _getRiskColor(totalScore).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getRiskColor(totalScore)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.warning,
                          size: 16,
                          color: _getRiskColor(totalScore),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Risk: $totalScore',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _getRiskColor(totalScore),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Status badge
                  if (hasOverride)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.green),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 16, color: Colors.green),
                          SizedBox(width: 4),
                          Text(
                            'Overridden',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pending, size: 16, color: Colors.orange),
                          SizedBox(width: 4),
                          Text(
                            'Pending Review',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  // Quote ID
                  Text(
                    doc.id.substring(0, 8),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Pet and owner info
              Row(
                children: [
                  // Pet info
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pets,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Pet',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          petData?['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${petData?['breed'] ?? 'Unknown'} • ${petData?['age'] ?? 'N/A'} yrs',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Owner info
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person,
                                size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Owner',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          ownerData?['firstName'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ownerData?['email'] ?? 'No email',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  // Date
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(Icons.calendar_today,
                            size: 16, color: Colors.grey[600]),
                        const SizedBox(height: 4),
                        Text(
                          createdAt != null
                              ? DateFormat('MMM d').format(createdAt)
                              : 'N/A',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                        Text(
                          createdAt != null
                              ? DateFormat('h:mm a').format(createdAt)
                              : '',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // AI Decision
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.psychology, size: 20, color: Colors.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AI Decision',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue,
                            ),
                          ),
                          Text(
                            aiDecision,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.blue),
                  ],
                ),
              ),
              // Override info if exists
              if (hasOverride) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 20, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Human Override',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            Text(
                              data['humanOverride']['decision'] ?? 'N/A',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _getRiskColor(int score) {
    if (score >= 90) return Colors.red[700]!;
    if (score >= 80) return Colors.orange[700]!;
    if (score >= 70) return Colors.amber[700]!;
    return Colors.green[700]!;
  }

  /// Build ineligible quotes tab
  Widget _buildIneligibleQuotesTab() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('quotes')
          .where('eligibility.eligible', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                const SizedBox(height: 16),
                Text('Error loading ineligible quotes: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => setState(() {}),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.green[400]),
                const SizedBox(height: 16),
                Text(
                  'No ineligible quotes',
                  style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                ),
                const SizedBox(height: 8),
                Text(
                  'All quotes passed eligibility checks',
                  style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                ),
              ],
            ),
          );
        }

        final ineligibleQuotes = snapshot.data!.docs;

        return Column(
          children: [
            // Stats bar for ineligible quotes
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[300]!),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatCard(
                    'Total Declined',
                    ineligibleQuotes.length.toString(),
                    Icons.block,
                    Colors.red,
                  ),
                  _buildStatCard(
                    'Pending Review',
                    ineligibleQuotes
                        .where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final eligibility = data['eligibility'] as Map<String, dynamic>?;
                          return eligibility?['status'] == 'review_requested';
                        })
                        .length
                        .toString(),
                    Icons.pending,
                    Colors.orange,
                  ),
                ],
              ),
            ),
            // List of ineligible quotes
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: ineligibleQuotes.length,
                itemBuilder: (context, index) {
                  final doc = ineligibleQuotes[index];
                  return _buildIneligibleQuoteCard(doc);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Build System Health tab with reconciliation monitoring
  Widget _buildSystemHealthTab() {
    return SingleChildScrollView(
      child: Column(
        children: const [
          SystemHealthWidget(),
        ],
      ),
    );
  }

  /// Build card for ineligible quote
  Widget _buildIneligibleQuoteCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final eligibility = data['eligibility'] as Map<String, dynamic>?;
    final petData = data['pet'] as Map<String, dynamic>?;
    final riskScoreData = data['riskScore'] as Map<String, dynamic>?;
    final totalScore = riskScoreData?['totalScore'] ?? 0;
    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final isReviewRequested = eligibility?['status'] == 'review_requested';

    final reason = eligibility?['reason'] ?? 'No reason provided';
    final ruleViolated = eligibility?['ruleViolated'] ?? 'Unknown';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showIneligibleQuoteDetails(doc),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  // Declined badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.red),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.block, size: 16, color: Colors.red),
                        SizedBox(width: 4),
                        Text(
                          'DECLINED',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Review requested badge
                  if (isReviewRequested)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.pending, size: 16, color: Colors.orange),
                          SizedBox(width: 4),
                          Text(
                            'Review Requested',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Spacer(),
                  // Quote ID
                  Text(
                    doc.id.substring(0, 8),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Pet info and risk score
              Row(
                children: [
                  // Pet info
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.pets, size: 16, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Pet',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          petData?['name'] ?? 'Unknown',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          petData?['breed'] ?? 'Unknown',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Risk score
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Risk Score',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getRiskColor(totalScore).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: _getRiskColor(totalScore)),
                          ),
                          child: Text(
                            totalScore.toString(),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: _getRiskColor(totalScore),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Decline reason
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18, color: Colors.red),
                        const SizedBox(width: 6),
                        Text(
                          'Rule Violated: $ruleViolated',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      reason,
                      style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Date and action button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Date
                  if (createdAt != null)
                    Row(
                      children: [
                        Icon(Icons.calendar_today,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          DateFormat('MMM d, yyyy h:mm a').format(createdAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  // Request review button
                  if (!isReviewRequested)
                    TextButton.icon(
                      onPressed: () => _requestReview(doc.id),
                      icon: const Icon(Icons.rate_review, size: 16),
                      label: const Text('Request Review'),
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check, size: 16, color: Colors.orange[700]),
                          const SizedBox(width: 4),
                          Text(
                            'Review Pending',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.orange[700],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Request review for an ineligible quote
  Future<void> _requestReview(String quoteId) async {
    try {
      await _firestore.collection('quotes').doc(quoteId).update({
        'eligibility.status': 'review_requested',
        'eligibility.reviewRequestedAt': Timestamp.now(),
        'eligibility.reviewRequestedBy':
            FirebaseAuth.instance.currentUser?.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review requested successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Show detailed information for ineligible quote
  void _showIneligibleQuoteDetails(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: IneligibleQuoteDetailsView(
              quoteId: doc.id,
              quoteData: data,
              scrollController: scrollController,
              onStatusChange: () {
                Navigator.pop(context);
                setState(() {}); // Refresh list
              },
            ),
          );
        },
      ),
    );
  }

  /// Show detailed quote information modal
  void _showQuoteDetails(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: QuoteDetailsView(
              quoteId: doc.id,
              quoteData: data,
              scrollController: scrollController,
              onOverride: () {
                Navigator.pop(context);
                setState(() {}); // Refresh list
              },
            ),
          );
        },
      ),
    );
  }
}

/// Detailed view of a quote with override capability
class QuoteDetailsView extends StatefulWidget {
  final String quoteId;
  final Map<String, dynamic> quoteData;
  final ScrollController scrollController;
  final VoidCallback onOverride;

  const QuoteDetailsView({
    super.key,
    required this.quoteId,
    required this.quoteData,
    required this.scrollController,
    required this.onOverride,
  });

  @override
  State<QuoteDetailsView> createState() => _QuoteDetailsViewState();
}

class _QuoteDetailsViewState extends State<QuoteDetailsView> {
  final TextEditingController _justificationController =
      TextEditingController();
  String _selectedDecision = 'Approve';
  bool _isSubmitting = false;

  @override
  void dispose() {
    _justificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final riskScoreData =
        widget.quoteData['riskScore'] as Map<String, dynamic>?;
    final totalScore = riskScoreData?['totalScore'] ?? 0;
    final aiAnalysis = riskScoreData?['aiAnalysis'] as Map<String, dynamic>?;
    final petData = widget.quoteData['pet'] as Map<String, dynamic>?;
    final ownerData = widget.quoteData['owner'] as Map<String, dynamic>?;
    final hasOverride = widget.quoteData.containsKey('humanOverride');
    final overrideData =
        widget.quoteData['humanOverride'] as Map<String, dynamic>?;

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        // Handle bar
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Header
        Row(
          children: [
            const Expanded(
              child: Text(
                'Quote Details',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Risk Score Card
        _buildSectionCard(
          title: 'Risk Assessment',
          icon: Icons.assessment,
          color: _getRiskColor(totalScore),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Overall Risk Score',
                    style: TextStyle(fontSize: 16),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getRiskColor(totalScore).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: _getRiskColor(totalScore)),
                    ),
                    child: Text(
                      totalScore.toString(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _getRiskColor(totalScore),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoRow(
                'Risk Level',
                _getRiskLevelText(totalScore),
              ),
              _buildInfoRow(
                'AI Confidence',
                '${aiAnalysis?['confidence'] ?? 'N/A'}%',
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // AI Decision Card
        _buildSectionCard(
          title: 'AI Analysis',
          icon: Icons.psychology,
          color: Colors.blue,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('Decision', aiAnalysis?['decision'] ?? 'Unknown'),
              const SizedBox(height: 12),
              const Text(
                'Reasoning',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Text(
                aiAnalysis?['reasoning'] ?? 'No reasoning provided',
                style: TextStyle(fontSize: 14, color: Colors.grey[700]),
              ),
              if (aiAnalysis?['riskFactors'] != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Risk Factors',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ...(aiAnalysis!['riskFactors'] as List<dynamic>)
                    .map((factor) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(fontSize: 14)),
                              Expanded(
                                child: Text(
                                  factor.toString(),
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey[700]),
                                ),
                              ),
                            ],
                          ),
                        ))
                    ,
              ],
              if (aiAnalysis?['recommendations'] != null) ...[
                const SizedBox(height: 12),
                const Text(
                  'Recommendations',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                ...(aiAnalysis!['recommendations'] as List<dynamic>)
                    .map((rec) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('• ',
                                  style: TextStyle(fontSize: 14)),
                              Expanded(
                                child: Text(
                                  rec.toString(),
                                  style: TextStyle(
                                      fontSize: 14, color: Colors.grey[700]),
                                ),
                              ),
                            ],
                          ),
                        ))
                    ,
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Explainability Chart
        _buildExplainabilitySection(),
        const SizedBox(height: 16),
        // Pet Information Card
        _buildSectionCard(
          title: 'Pet Information',
          icon: Icons.pets,
          color: Colors.purple,
          child: Column(
            children: [
              _buildInfoRow('Name', petData?['name'] ?? 'Unknown'),
              _buildInfoRow('Species', petData?['species'] ?? 'Unknown'),
              _buildInfoRow('Breed', petData?['breed'] ?? 'Unknown'),
              _buildInfoRow('Age', '${petData?['age'] ?? 'N/A'} years'),
              _buildInfoRow('Gender', petData?['gender'] ?? 'Unknown'),
              _buildInfoRow('Weight', '${petData?['weight'] ?? 'N/A'} lbs'),
              if (petData?['medicalConditions'] != null) ...[
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Medical Conditions:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 4),
                ...(petData!['medicalConditions'] as List<dynamic>)
                    .map((condition) => Padding(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '• $condition',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[700]),
                            ),
                          ),
                        ))
                    ,
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Owner Information Card
        _buildSectionCard(
          title: 'Owner Information',
          icon: Icons.person,
          color: Colors.teal,
          child: Column(
            children: [
              _buildInfoRow(
                'Name',
                '${ownerData?['firstName'] ?? ''} ${ownerData?['lastName'] ?? ''}'
                    .trim(),
              ),
              _buildInfoRow('Email', ownerData?['email'] ?? 'N/A'),
              _buildInfoRow('Phone', ownerData?['phone'] ?? 'N/A'),
              _buildInfoRow('State', ownerData?['state'] ?? 'N/A'),
              _buildInfoRow('Zip Code', ownerData?['zipCode'] ?? 'N/A'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // Override Section
        if (hasOverride)
          _buildOverrideDisplay(overrideData!)
        else
          _buildOverrideForm(),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color color,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverrideDisplay(Map<String, dynamic> overrideData) {
    final decision = overrideData['decision'] ?? 'Unknown';
    final justification = overrideData['justification'] ?? 'No justification';
    final underwriterName = overrideData['underwriterName'] ?? 'Unknown';
    final timestamp = (overrideData['timestamp'] as Timestamp?)?.toDate();

    return Card(
      elevation: 2,
      color: Colors.green[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green[700], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Human Override Applied',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Decision', decision),
            _buildInfoRow('Underwriter', underwriterName),
            if (timestamp != null)
              _buildInfoRow(
                'Override Date',
                DateFormat('MMM d, yyyy h:mm a').format(timestamp),
              ),
            const SizedBox(height: 12),
            const Text(
              'Justification:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Text(
                justification,
                style: TextStyle(fontSize: 14, color: Colors.grey[800]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverrideForm() {
    return Card(
      elevation: 2,
      color: Colors.amber[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.rule, color: Colors.amber[900], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Underwriter Override',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Decision',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'Approve',
                  label: Text('Approve'),
                  icon: Icon(Icons.check_circle_outline),
                ),
                ButtonSegment(
                  value: 'Deny',
                  label: Text('Deny'),
                  icon: Icon(Icons.cancel_outlined),
                ),
                ButtonSegment(
                  value: 'Request More Info',
                  label: Text('More Info'),
                  icon: Icon(Icons.info_outline),
                ),
              ],
              selected: {_selectedDecision},
              onSelectionChanged: (Set<String> newSelection) {
                setState(() => _selectedDecision = newSelection.first);
              },
            ),
            const SizedBox(height: 16),
            const Text(
              'Justification (Required)',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _justificationController,
              maxLines: 5,
              decoration: InputDecoration(
                hintText:
                    'Explain your reasoning for overriding the AI decision...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitOverride,
                icon: _isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_isSubmitting ? 'Submitting...' : 'Submit Override'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitOverride() async {
    final justification = _justificationController.text.trim();

    if (justification.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a justification for your decision'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (justification.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Justification must be at least 20 characters'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final now = Timestamp.now();

      // Get user's name from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      final underwriterName =
          '${userData?['firstName'] ?? 'Unknown'} ${userData?['lastName'] ?? ''}';

      // Update quote document with override
      await FirebaseFirestore.instance
          .collection('quotes')
          .doc(widget.quoteId)
          .update({
        'humanOverride': {
          'decision': _selectedDecision,
          'justification': justification,
          'underwriterId': user.uid,
          'underwriterName': underwriterName.trim(),
          'timestamp': now,
        },
        'status': _selectedDecision == 'Approve' ? 'approved' : 'denied',
      });

      // Log to audit_logs collection
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'type': 'quote_override',
        'quoteId': widget.quoteId,
        'underwriterId': user.uid,
        'underwriterName': underwriterName.trim(),
        'decision': _selectedDecision,
        'justification': justification,
        'aiDecision': widget.quoteData['riskScore']?['aiAnalysis']?['decision'],
        'riskScore': widget.quoteData['riskScore']?['totalScore'],
        'timestamp': now,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Override submitted successfully: $_selectedDecision'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onOverride();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting override: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildExplainabilitySection() {
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance
          .collection('quotes')
          .doc(widget.quoteId)
          .collection('explainability')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.orange),
                  const SizedBox(width: 8),
                  Text(
                    'Could not load explainability data',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    'No explainability data available',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          );
        }

        try {
          final explainabilityData = ExplainabilityData.fromJson(
            snapshot.data!.docs.first.data() as Map<String, dynamic>,
          );

          return ExplainabilityChart(
            explainability: explainabilityData,
            maxFeatures: 10,
            showCategories: true,
          );
        } catch (e) {
          return Card(
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber, color: Colors.orange),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error parsing explainability data: $e',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  }

  Color _getRiskColor(int score) {
    if (score >= 90) return Colors.red[700]!;
    if (score >= 80) return Colors.orange[700]!;
    if (score >= 70) return Colors.amber[700]!;
    return Colors.green[700]!;
  }

  String _getRiskLevelText(int score) {
    if (score >= 90) return 'Very High Risk';
    if (score >= 80) return 'High Risk';
    if (score >= 70) return 'Moderate Risk';
    if (score >= 60) return 'Low Risk';
    return 'Very Low Risk';
  }
}

/// Detailed view of an ineligible quote
class IneligibleQuoteDetailsView extends StatefulWidget {
  final String quoteId;
  final Map<String, dynamic> quoteData;
  final ScrollController scrollController;
  final VoidCallback onStatusChange;

  const IneligibleQuoteDetailsView({
    super.key,
    required this.quoteId,
    required this.quoteData,
    required this.scrollController,
    required this.onStatusChange,
  });

  @override
  State<IneligibleQuoteDetailsView> createState() =>
      _IneligibleQuoteDetailsViewState();
}

class _IneligibleQuoteDetailsViewState
    extends State<IneligibleQuoteDetailsView> {
  bool _isUpdating = false;
  final TextEditingController _newRiskScoreController = TextEditingController();
  final TextEditingController _justificationController = TextEditingController();
  String _selectedOverrideDecision = 'Approve';

  @override
  void dispose() {
    _newRiskScoreController.dispose();
    _justificationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final eligibility =
        widget.quoteData['eligibility'] as Map<String, dynamic>?;
    final petData = widget.quoteData['pet'] as Map<String, dynamic>?;
    final ownerData = widget.quoteData['owner'] as Map<String, dynamic>?;
    final riskScoreData =
        widget.quoteData['riskScore'] as Map<String, dynamic>?;
    final totalScore = riskScoreData?['totalScore'] ?? 0;
    final createdAt = (widget.quoteData['createdAt'] as Timestamp?)?.toDate();

    final isReviewRequested = eligibility?['status'] == 'review_requested';
    final reason = eligibility?['reason'] ?? 'No reason provided';
    final ruleViolated = eligibility?['ruleViolated'] ?? 'Unknown';
    final violatedValue = eligibility?['violatedValue'];

    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        // Handle bar
        Center(
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        // Header
        Row(
          children: [
            const Expanded(
              child: Text(
                'Ineligible Quote Details',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Eligibility Status Card
        Card(
          elevation: 2,
          color: Colors.red[50],
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.block, color: Colors.red[700], size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Quote Declined',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Rule Violated', ruleViolated),
                if (violatedValue != null)
                  _buildInfoRow('Violating Value', violatedValue.toString()),
                const SizedBox(height: 12),
                const Text(
                  'Decline Reason:',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Text(
                    reason,
                    style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                  ),
                ),
                if (isReviewRequested) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange[300]!),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.pending, color: Colors.orange[900], size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Review has been requested',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange[900],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Risk Score Card
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assessment,
                        color: _getRiskColor(totalScore), size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Risk Assessment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getRiskColor(totalScore),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Overall Risk Score',
                      style: TextStyle(fontSize: 16),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: _getRiskColor(totalScore).withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _getRiskColor(totalScore)),
                      ),
                      child: Text(
                        totalScore.toString(),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: _getRiskColor(totalScore),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _buildInfoRow('Risk Level', _getRiskLevelText(totalScore)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Pet Information Card
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.pets, color: Colors.purple[700], size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Pet Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.purple[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Name', petData?['name'] ?? 'Unknown'),
                _buildInfoRow('Species', petData?['species'] ?? 'Unknown'),
                _buildInfoRow('Breed', petData?['breed'] ?? 'Unknown'),
                _buildInfoRow('Age', '${petData?['age'] ?? 'N/A'} years'),
                _buildInfoRow('Gender', petData?['gender'] ?? 'Unknown'),
                _buildInfoRow('Weight', '${petData?['weight'] ?? 'N/A'} lbs'),
                if (petData?['medicalConditions'] != null &&
                    (petData!['medicalConditions'] as List).isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Medical Conditions:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  ...(petData['medicalConditions'] as List<dynamic>)
                      .map((condition) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Text(
                              '• $condition',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey[700]),
                            ),
                          )),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Owner Information Card
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.person, color: Colors.teal[700], size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Owner Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow(
                  'Name',
                  '${ownerData?['firstName'] ?? ''} ${ownerData?['lastName'] ?? ''}'
                      .trim(),
                ),
                _buildInfoRow('Email', ownerData?['email'] ?? 'N/A'),
                _buildInfoRow('Phone', ownerData?['phone'] ?? 'N/A'),
                _buildInfoRow('State', ownerData?['state'] ?? 'N/A'),
                _buildInfoRow('Zip Code', ownerData?['zipCode'] ?? 'N/A'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Quote Info Card
        Card(
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'Quote Information',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow('Quote ID', widget.quoteId),
                if (createdAt != null)
                  _buildInfoRow(
                    'Created',
                    DateFormat('MMM d, yyyy h:mm a').format(createdAt),
                  ),
                _buildInfoRow('Status', 'Declined - Ineligible'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Override Eligibility Section
        _buildOverrideEligibilitySection(isReviewRequested),
        const SizedBox(height: 16),
        // Request Review Button
        if (!isReviewRequested)
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isUpdating ? null : _requestReview,
              icon: _isUpdating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.rate_review),
              label: Text(_isUpdating
                  ? 'Requesting Review...'
                  : 'Request Manual Review'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange[300]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.orange[700]),
                const SizedBox(width: 8),
                Text(
                  'Review request is pending',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange[700],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverrideEligibilitySection(bool isReviewRequested) {
    // Check if already overridden
    final hasOverride = widget.quoteData.containsKey('humanOverride');
    
    if (hasOverride) {
      final overrideData = widget.quoteData['humanOverride'] as Map<String, dynamic>;
      final decision = overrideData['decision'] ?? 'Unknown';
      final justification = overrideData['reasoning'] ?? 'No justification provided';
      final underwriterName = overrideData['underwriterName'] ?? 'Unknown';
      final timestamp = (overrideData['timestamp'] as Timestamp?)?.toDate();

      return Card(
        elevation: 2,
        color: Colors.green[50],
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green[700], size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Eligibility Overridden',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Decision', decision),
              _buildInfoRow('Admin', underwriterName),
              if (timestamp != null)
                _buildInfoRow(
                  'Override Date',
                  DateFormat('MMM d, yyyy h:mm a').format(timestamp),
                ),
              const SizedBox(height: 12),
              const Text(
                'Justification:',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green[200]!),
                ),
                child: Text(
                  justification,
                  style: TextStyle(fontSize: 14, color: Colors.grey[800]),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show override button
    return Card(
      elevation: 2,
      color: Colors.amber[50],
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.admin_panel_settings, color: Colors.amber[900], size: 24),
                const SizedBox(width: 8),
                Text(
                  'Admin Override',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'This quote was automatically declined. As an admin, you can override this decision with proper justification.',
              style: TextStyle(fontSize: 14, color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isUpdating ? null : _showOverrideDialog,
                icon: const Icon(Icons.edit_note),
                label: const Text('Override Eligibility'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.amber[700],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOverrideDialog() {
    final riskScoreData = widget.quoteData['riskScore'] as Map<String, dynamic>?;
    final currentRiskScore = riskScoreData?['totalScore'] ?? 0;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings, color: Colors.amber),
            SizedBox(width: 8),
            Text('Override Eligibility'),
          ],
        ),
        content: SingleChildScrollView(
          child: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You are about to override the AI eligibility decision. This action will be logged in the audit trail.',
                    style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 20),
                  // Decision dropdown
                  const Text(
                    'Decision',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedOverrideDecision,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Approve',
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
                            SizedBox(width: 8),
                            Text('Approve'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Deny',
                        child: Row(
                          children: [
                            Icon(Icons.cancel_outlined, size: 20, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Deny'),
                          ],
                        ),
                      ),
                      DropdownMenuItem(
                        value: 'Adjust Premium',
                        child: Row(
                          children: [
                            Icon(Icons.attach_money, size: 20, color: Colors.orange),
                            SizedBox(width: 8),
                            Text('Adjust Premium'),
                          ],
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setDialogState(() {
                        _selectedOverrideDecision = value!;
                      });
                    },
                  ),
                  const SizedBox(height: 16),
                  // New risk score (optional)
                  const Text(
                    'New Risk Score (Optional)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _newRiskScoreController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'Current: $currentRiskScore',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      helperText: 'Enter a value between 0-100, or leave blank to keep current',
                      helperMaxLines: 2,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Manual justification
                  const Text(
                    'Manual Justification (Required)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _justificationController,
                    maxLines: 5,
                    decoration: InputDecoration(
                      hintText: 'e.g., "Condition resolved for >2 years, recent clean checkup"',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                      helperText: 'Explain why you are overriding the AI decision',
                      helperMaxLines: 2,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _newRiskScoreController.clear();
              _justificationController.clear();
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitEligibilityOverride();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber[700],
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit Override'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitEligibilityOverride() async {
    final justification = _justificationController.text.trim();

    // Validation
    if (justification.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a justification for the override'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (justification.length < 20) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Justification must be at least 20 characters'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Validate risk score if provided
    int? newRiskScore;
    final riskScoreText = _newRiskScoreController.text.trim();
    if (riskScoreText.isNotEmpty) {
      newRiskScore = int.tryParse(riskScoreText);
      if (newRiskScore == null || newRiskScore < 0 || newRiskScore > 100) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Risk score must be a number between 0 and 100'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isUpdating = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }

      final now = Timestamp.now();

      // Get user's name from Firestore
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final userData = userDoc.data();
      final adminName =
          '${userData?['firstName'] ?? 'Unknown'} ${userData?['lastName'] ?? ''}'.trim();

      // Prepare update data
      final updateData = <String, dynamic>{
        'humanOverride': {
          'decision': _selectedOverrideDecision,
          'underwriterId': user.uid,
          'underwriterName': adminName,
          'timestamp': now,
          'reasoning': justification,
          'originalStatus': 'declined',
          'originalReason': widget.quoteData['eligibility']?['reason'],
        },
        'eligibility.status': 'overridden',
        'eligibility.overriddenAt': now,
        'eligibility.overriddenBy': user.uid,
      };

      // Update risk score if provided
      if (newRiskScore != null) {
        updateData['riskScore.totalScore'] = newRiskScore;
        updateData['riskScore.overridden'] = true;
        updateData['riskScore.originalScore'] = 
            widget.quoteData['riskScore']?['totalScore'] ?? 0;
        updateData['humanOverride.newRiskScore'] = newRiskScore;
      }

      // Update quote document
      await FirebaseFirestore.instance
          .collection('quotes')
          .doc(widget.quoteId)
          .update(updateData);

      // Log to audit_logs collection
      await FirebaseFirestore.instance.collection('audit_logs').add({
        'type': 'eligibility_override',
        'quoteId': widget.quoteId,
        'adminId': user.uid,
        'adminName': adminName,
        'decision': _selectedOverrideDecision,
        'justification': justification,
        'originalStatus': 'declined',
        'originalReason': widget.quoteData['eligibility']?['reason'],
        'ruleViolated': widget.quoteData['eligibility']?['ruleViolated'],
        'newRiskScore': newRiskScore,
        'originalRiskScore': widget.quoteData['riskScore']?['totalScore'],
        'timestamp': now,
      });

      // Clear form
      _newRiskScoreController.clear();
      _justificationController.clear();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Eligibility override submitted: $_selectedOverrideDecision'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );
        widget.onStatusChange();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting override: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Future<void> _requestReview() async {
    setState(() => _isUpdating = true);

    try {
      await FirebaseFirestore.instance
          .collection('quotes')
          .doc(widget.quoteId)
          .update({
        'eligibility.status': 'review_requested',
        'eligibility.reviewRequestedAt': Timestamp.now(),
        'eligibility.reviewRequestedBy':
            FirebaseAuth.instance.currentUser?.uid,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Review requested successfully'),
            backgroundColor: Colors.green,
          ),
        );
        widget.onStatusChange();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting review: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  Color _getRiskColor(int score) {
    if (score >= 90) return Colors.red[700]!;
    if (score >= 80) return Colors.orange[700]!;
    if (score >= 70) return Colors.amber[700]!;
    return Colors.green[700]!;
  }

  String _getRiskLevelText(int score) {
    if (score >= 90) return 'Very High Risk';
    if (score >= 80) return 'High Risk';
    if (score >= 70) return 'Moderate Risk';
    if (score >= 60) return 'Low Risk';
    return 'Very Low Risk';
  }
}

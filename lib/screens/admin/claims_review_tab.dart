import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:intl/intl.dart';
import '../../models/claim.dart';
import '../../services/claim_document_ai_service.dart';
import '../../admin_console/components/admin_kpi_card.dart';
import '../../admin_console/components/admin_bulk_actions_bar.dart';
import '../../admin_console/components/admin_selectable_data_table.dart';
import '../../admin_console/components/admin_filters_row.dart';
import '../../admin_console/components/admin_section_card.dart';
import '../../theme/clovara_theme.dart';

/// Claims Review tab for admin dashboard
/// Shows claims requiring human review and allows manual decisions
class ClaimsReviewTab extends StatefulWidget {
  const ClaimsReviewTab({super.key});

  @override
  State<ClaimsReviewTab> createState() => _ClaimsReviewTabState();
}

class _ClaimsReviewTabState extends State<ClaimsReviewTab> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final Map<String, String> _petNameCache = <String, String>{};
  final Map<String, Future<String>> _petNameFutures = <String, Future<String>>{};
  final Set<String> _petNamePrewarmed = <String>{};

  String _selectedFilter = 'all';
  String _searchQuery = '';
  final Set<String> _selectedClaimIds = <String>{};

  int _sortColumnIndex = 5; // Date
  bool _sortAscending = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildAnalyticsSummary(),
        const SizedBox(height: 12),
        _buildFiltersBar(),
        const SizedBox(height: 12),
        Expanded(child: _buildClaimsList()),
      ],
    );
  }

  /// Build analytics summary widget
  Widget _buildAnalyticsSummary() {
    final now = DateTime.now();
    final monthStart = DateTime(now.year, now.month, 1);

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('claims')
          .where(
            'createdAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(monthStart),
          )
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final claims = snapshot.data!.docs;
        final totalClaims = claims.length;
        final autoApproved = claims.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'settled' &&
              data['aiConfidenceScore'] != null &&
              (data['aiConfidenceScore'] as num) >= 0.85;
        }).length;
        final humanReviewed = claims.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['humanOverride'] != null;
        }).length;
        final pending = claims.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'processing';
        }).length;

        final processingTimes = claims
            .where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              return data['settledAt'] != null && data['createdAt'] != null;
            })
            .map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final created = (data['createdAt'] as Timestamp).toDate();
              final settled = (data['settledAt'] as Timestamp).toDate();
              return settled.difference(created).inHours;
            })
            .toList();

        final avgProcessingTime = processingTimes.isNotEmpty
            ? processingTimes.reduce((a, b) => a + b) / processingTimes.length
            : 0.0;

        return AdminSectionCard(
          title: 'Claims KPIs (This Month)',
          icon: Icons.query_stats_outlined,
          padding: const EdgeInsets.all(16),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cards = [
                AdminKpiCard(
                  label: 'Total claims',
                  value: '$totalClaims',
                  icon: Icons.folder_open,
                  color: ClovaraColors.forest,
                ),
                AdminKpiCard(
                  label: 'Auto-approved',
                  value: '$autoApproved',
                  delta:
                      '${totalClaims > 0 ? ((autoApproved / totalClaims) * 100).toStringAsFixed(1) : 0}%',
                  icon: Icons.check_circle,
                  color: ClovaraColors.kSuccessMint,
                ),
                AdminKpiCard(
                  label: 'Human reviewed',
                  value: '$humanReviewed',
                  delta:
                      '${totalClaims > 0 ? ((humanReviewed / totalClaims) * 100).toStringAsFixed(1) : 0}%',
                  icon: Icons.person,
                  color: ClovaraColors.clover,
                ),
                AdminKpiCard(
                  label: 'Pending review',
                  value: '$pending',
                  icon: Icons.pending_actions,
                  color: ClovaraColors.kWarning,
                ),
                AdminKpiCard(
                  label: 'Avg processing',
                  value: '${avgProcessingTime.toStringAsFixed(1)}h',
                  icon: Icons.schedule,
                  color: ClovaraColors.kTextGrey,
                ),
              ];

              if (constraints.maxWidth >= 1100) {
                return Row(
                  children: [
                    for (final card in cards) ...[
                      Expanded(child: card),
                      const SizedBox(width: 12),
                    ],
                  ]..removeLast(),
                );
              }

              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards.map((c) => SizedBox(width: 360, child: c)).toList(),
              );
            },
          ),
        );
      },
    );
  }

  /// Build filters bar
  Widget _buildFiltersBar() {
    final theme = Theme.of(context);

    return AdminSectionCard(
      title: 'Filters',
      icon: Icons.tune,
      padding: const EdgeInsets.all(16),
      child: AdminFiltersRow(
        leading: [
          SizedBox(
            width: 240,
            child: DropdownButtonFormField<String>(
              value: _selectedFilter,
              isExpanded: true,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                labelText: 'Queue',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                labelStyle: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: theme.colorScheme.onSurface.withOpacity(0.70),
                ),
              ),
              icon: const Icon(Icons.expand_more, size: 18),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('All Pending')),
                DropdownMenuItem(value: 'escalated', child: Text('AI Escalated')),
                DropdownMenuItem(value: 'high_value', child: Text('High Value')),
                DropdownMenuItem(value: 'low_confidence', child: Text('Low Confidence')),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _selectedFilter = value);
              },
            ),
          ),
        ],
        search: TextField(
          style: theme.textTheme.bodyMedium?.copyWith(fontSize: 13),
          decoration: InputDecoration(
            hintText: 'Search by claim ID, pet name, or policy ID…',
            prefixIcon: const Icon(Icons.search),
            isDense: true,
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value.toLowerCase();
            });
          },
        ),
      ),
    );
  }

  /// Build claims list
  Widget _buildClaimsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getClaimsQuery(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading claims: ${snapshot.error}'),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline,
                    size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No claims requiring review',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        }

        final claims = snapshot.data!.docs
            .map((doc) => Claim.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .where((claim) {
              if (_searchQuery.isEmpty) return true;
              return claim.claimId.toLowerCase().contains(_searchQuery) ||
                  claim.policyId.toLowerCase().contains(_searchQuery) ||
                  claim.petId.toLowerCase().contains(_searchQuery);
            })
            .toList();

        final sortedClaims = [...claims];
        _sortClaims(sortedClaims);

        _prewarmPetNames(sortedClaims.map((c) => c.petId));

        return AdminSectionCard(
          title: 'Claims Inbox',
          icon: Icons.fact_check_outlined,
          expandChild: true,
          child: Column(
            children: [
              AdminBulkActionsBar(
                resultsCount: sortedClaims.length,
                selectedCount: _selectedClaimIds.length,
                onSelectVisible: sortedClaims.isEmpty
                    ? null
                    : () => setState(() => _selectedClaimIds.addAll(sortedClaims.map((c) => c.claimId))),
                onClearSelection: () => setState(() => _selectedClaimIds.clear()),
                actions: [
                  TextButton.icon(
                    onPressed: _selectedClaimIds.isEmpty
                        ? null
                        : () {
                            showDialog<void>(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: const Text('Bulk Actions'),
                                content: const Text(
                                  'Bulk actions are scaffolded for: approve/deny/request-info with a required note and audit logging.\n\n'
                                  'For now, open a claim to review and decide.',
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
                                ],
                              ),
                            );
                          },
                    icon: const Icon(Icons.playlist_add_check, size: 18),
                    label: const Text('Bulk actions'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: AdminSelectableDataTable<Claim>(
                  items: sortedClaims,
            getId: (c) => c.claimId,
            selectedIds: _selectedClaimIds,
            onSelectedIdsChanged: (next) => setState(() {
              _selectedClaimIds
                ..clear()
                ..addAll(next);
            }),
            sortColumnIndex: _sortColumnIndex,
            sortAscending: _sortAscending,
            columns: [
              const DataColumn(label: Text('Pet Name')),
              const DataColumn(label: Text('Claim ID')),
              DataColumn(
                label: const Text('Amount'),
                numeric: true,
                onSort: (index, asc) => setState(() {
                  _sortColumnIndex = index;
                  _sortAscending = asc;
                }),
              ),
              DataColumn(
                label: const Text('AI Confidence'),
                numeric: true,
                onSort: (index, asc) => setState(() {
                  _sortColumnIndex = index;
                  _sortAscending = asc;
                }),
              ),
              const DataColumn(label: Text('Status')),
              DataColumn(
                label: const Text('Date'),
                onSort: (index, asc) => setState(() {
                  _sortColumnIndex = index;
                  _sortAscending = asc;
                }),
              ),
              const DataColumn(label: Text('Actions')),
            ],
            buildCells: (context, claim) {
              final confidence = claim.aiConfidenceScore;
              final confidencePercent = confidence != null ? (confidence * 100).toStringAsFixed(1) : 'N/A';

              return [
                DataCell(
                  FutureBuilder<String>(
                    future: _getPetNameCached(claim.petId),
                    builder: (context, snapshot) {
                      return Text(
                        snapshot.data ?? 'Loading…',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      );
                    },
                  ),
                  onTap: () => _openClaimDetail(claim),
                ),
                DataCell(
                  Text(
                    claim.claimId,
                    style: TextStyle(
                      fontSize: 12,
                      color: ClovaraColors.kTextGrey,
                    ),
                  ),
                  onTap: () => _openClaimDetail(claim),
                ),
                DataCell(
                  Text(
                    '\$${claim.claimAmount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  onTap: () => _openClaimDetail(claim),
                ),
                DataCell(
                  _buildConfidenceBadge(confidencePercent: confidencePercent, confidence: confidence),
                  onTap: () => _openClaimDetail(claim),
                ),
                DataCell(
                  _buildStatusBadge(claim.status),
                  onTap: () => _openClaimDetail(claim),
                ),
                DataCell(
                  Text(
                    DateFormat('MMM d').format(claim.createdAt),
                    style: TextStyle(
                      fontSize: 12,
                      color: ClovaraColors.kTextGrey,
                    ),
                  ),
                  onTap: () => _openClaimDetail(claim),
                ),
                DataCell(
                  ElevatedButton(
                    onPressed: () => _openClaimDetail(claim),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ClovaraColors.clover,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Review', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ];
            },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Get claims query based on filter
  Stream<QuerySnapshot> _getClaimsQuery() {
    Query query = _firestore
        .collection('claims')
        .where('status', whereIn: ['processing', 'submitted'])
        .orderBy('createdAt', descending: true);

    if (_selectedFilter == 'escalated') {
      query = _firestore
          .collection('claims')
          .where('aiDecision', isEqualTo: 'escalate')
          .orderBy('createdAt', descending: true);
    } else if (_selectedFilter == 'high_value') {
      query = _firestore
          .collection('claims')
          .where('status', isEqualTo: 'processing')
          .where('claimAmount', isGreaterThan: 500)
          .orderBy('claimAmount', descending: true);
    } else if (_selectedFilter == 'low_confidence') {
      query = _firestore
          .collection('claims')
          .where('status', isEqualTo: 'processing')
          .where('aiConfidenceScore', isLessThan: 0.7)
          .orderBy('aiConfidenceScore')
          .orderBy('createdAt', descending: true);
    }

    return query.snapshots();
  }

  void _sortClaims(List<Claim> claims) {
    int compareNum(num a, num b) => a.compareTo(b);

    int cmp(Claim a, Claim b) {
      switch (_sortColumnIndex) {
        case 2: // Amount
          return compareNum(a.claimAmount, b.claimAmount);
        case 3: // AI Confidence
          final av = a.aiConfidenceScore ?? -1;
          final bv = b.aiConfidenceScore ?? -1;
          return compareNum(av, bv);
        case 5: // Date
        default:
          return a.createdAt.compareTo(b.createdAt);
      }
    }

    claims.sort((a, b) {
      final result = cmp(a, b);
      return _sortAscending ? result : -result;
    });
  }

  Widget _buildConfidenceBadge({required String confidencePercent, required double? confidence}) {
    Color confidenceColor = ClovaraColors.kTextGrey;
    if (confidence != null) {
      if (confidence >= 0.85) {
        confidenceColor = ClovaraColors.kSuccessMint;
      } else if (confidence >= 0.60) {
        confidenceColor = ClovaraColors.kWarning;
      } else {
        confidenceColor = ClovaraColors.kError;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: confidenceColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: confidenceColor.withOpacity(0.3)),
      ),
      child: Text(
        confidencePercent == 'N/A' ? 'N/A' : '$confidencePercent%',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: confidenceColor,
        ),
      ),
    );
  }



  /// Build status badge
  Widget _buildStatusBadge(ClaimStatus status) {
    Color color;
    String text;

    switch (status) {
      case ClaimStatus.draft:
        color = Colors.grey;
        text = 'Draft';
        break;
      case ClaimStatus.submitted:
        color = ClovaraColors.clover;
        text = 'Submitted';
        break;
      case ClaimStatus.processing:
        color = ClovaraColors.kWarning;
        text = 'Processing';
        break;
      case ClaimStatus.settling:
        color = ClovaraColors.clover;
        text = 'Settling';
        break;
      case ClaimStatus.settled:
        color = ClovaraColors.kSuccessMint;
        text = 'Settled';
        break;
      case ClaimStatus.denied:
        color = ClovaraColors.kError;
        text = 'Denied';
        break;
      case ClaimStatus.cancelled:
        color = Colors.grey;
        text = 'Cancelled';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Future<String> _getPetNameCached(String petId) {
    final cached = _petNameCache[petId];
    if (cached != null) return Future<String>.value(cached);

    final existingFuture = _petNameFutures[petId];
    if (existingFuture != null) return existingFuture;

    final future = _getPetName(petId).whenComplete(() {
      _petNameFutures.remove(petId);
    });
    _petNameFutures[petId] = future;
    return future;
  }

  void _prewarmPetNames(Iterable<String> petIds) {
    // Prewarm a bounded set of visible petIds to reduce per-row FutureBuilder churn.
    // Safe to call every build; it dedupes.
    final ids = petIds.where((id) => id.isNotEmpty).take(75).toList(growable: false);
    if (ids.isEmpty) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final id in ids) {
        if (_petNameCache.containsKey(id)) continue;
        if (_petNamePrewarmed.contains(id)) continue;
        _petNamePrewarmed.add(id);
        _getPetNameCached(id);
      }
    });
  }

  /// Get pet name from Firestore
  Future<String> _getPetName(String petId) async {
    const fallback = 'Unknown Pet';
    try {
      final doc = await _firestore.collection('pets').doc(petId).get();
      if (doc.exists) {
        final name = (doc.data()?['name'] ?? 'Unknown Pet').toString();
        _petNameCache[petId] = name;
        return name;
      }
    } catch (e) {
      debugPrint('Error fetching pet name ($petId): $e');
    }

    _petNameCache[petId] = fallback;
    return fallback;
  }

  /// Open claim detail dialog
  void _openClaimDetail(Claim claim) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => ClaimDetailDialog(claim: claim),
    );
  }
}

/// Claim detail dialog for review and decision
class ClaimDetailDialog extends StatefulWidget {
  final Claim claim;

  const ClaimDetailDialog({super.key, required this.claim});

  @override
  State<ClaimDetailDialog> createState() => _ClaimDetailDialogState();
}

class _ClaimDetailDialogState extends State<ClaimDetailDialog> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ClaimDocumentAIService _docService = ClaimDocumentAIService();
  final TextEditingController _reasonController = TextEditingController();

  bool _isLoading = false;
  String _selectedDecision = 'approve';
  List<ClaimDocumentAnalysis> _documents = [];
  Map<String, dynamic>? _policyData;
  Map<String, dynamic>? _petData;

  @override
  void initState() {
    super.initState();
    _loadClaimData();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadClaimData() async {
    setState(() => _isLoading = true);

    try {
      // Load documents
      _documents = await _docService.getClaimDocuments(widget.claim.claimId);

      // Load policy data
      final policyDoc =
          await _firestore.collection('policies').doc(widget.claim.policyId).get();
      _policyData = policyDoc.data();

      // Load pet data
      final petDoc =
          await _firestore.collection('pets').doc(widget.claim.petId).get();
      _petData = petDoc.data();

      setState(() => _isLoading = false);
    } catch (e) {
      print('Error loading claim data: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: ClovaraColors.forest,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Claim Review',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Claim ID: ${widget.claim.claimId}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildClaimSummary(),
                          const SizedBox(height: 24),
                          _buildAISummary(),
                          const SizedBox(height: 24),
                          _buildDocuments(),
                          const SizedBox(height: 24),
                          _buildPolicyContext(),
                          const SizedBox(height: 24),
                          _buildDecisionSection(),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildClaimSummary() {
    return _buildSection(
      title: 'Claim Summary',
      icon: Icons.description,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Pet Name', _petData?['name'] ?? 'Loading...'),
          _buildInfoRow('Claim Type', widget.claim.claimType.displayName),
          _buildInfoRow('Incident Date',
              DateFormat('MMM d, yyyy').format(widget.claim.incidentDate)),
          _buildInfoRow(
              'Claim Amount', '\$${widget.claim.claimAmount.toStringAsFixed(2)}'),
          _buildInfoRow('Status', widget.claim.status.displayName),
          const SizedBox(height: 12),
          Text(
            'Description:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: ClovaraColors.forest,
            ),
          ),
          const SizedBox(height: 4),
          Text(widget.claim.description),
        ],
      ),
    );
  }

  Widget _buildAISummary() {
    final confidence = widget.claim.aiConfidenceScore;
    final decision = widget.claim.aiDecision;
    final explanation = widget.claim.aiReasoningExplanation;

    return _buildSection(
      title: 'AI Analysis',
      icon: Icons.psychology,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (confidence != null) ...[
            Row(
              children: [
                Text(
                  'Confidence Score: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getConfidenceColor(confidence).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getConfidenceColor(confidence).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '${(confidence * 100).toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getConfidenceColor(confidence),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          if (decision != null) ...[
            _buildInfoRow('AI Decision', decision.displayName),
            const SizedBox(height: 12),
          ],
          if (explanation != null && explanation['explanation'] != null) ...[
            Text(
              'AI Explanation:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ClovaraColors.forest,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(explanation['explanation']),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDocuments() {
    return _buildSection(
      title: 'Uploaded Documents (${_documents.length})',
      icon: Icons.attach_file,
      child: _documents.isEmpty
          ? Text('No documents uploaded', style: TextStyle(color: Colors.grey[600]))
          : Column(
              children: _documents.map((doc) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.description,
                              color: ClovaraColors.clover, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              doc.providerName,
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: doc.isLegitimate
                                  ? ClovaraColors.clover.withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              doc.isLegitimate ? 'Verified' : 'Suspicious',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: doc.isLegitimate ? ClovaraColors.clover : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Total: \$${doc.totalCharge.toStringAsFixed(2)}',
                          style: TextStyle(fontSize: 12)),
                      Text('Treatment: ${doc.treatment}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text(
                          'Confidence: ${(doc.confidenceScore * 100).toStringAsFixed(1)}%',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }

  Widget _buildPolicyContext() {
    return _buildSection(
      title: 'Policy & Risk Profile',
      icon: Icons.shield,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildInfoRow('Policy ID', widget.claim.policyId),
          if (_policyData != null) ...[
            _buildInfoRow('Risk Score',
                (_policyData!['riskScore'] ?? 0.0).toStringAsFixed(1)),
            _buildInfoRow(
                'Premium',
                '\$${(_policyData!['premiumAmount'] ?? 0.0).toStringAsFixed(2)}/month'),
            if (_policyData!['wasManuallyApproved'] == true)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: ClovaraColors.kWarning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning, color: ClovaraColors.kWarning, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'This policy was manually approved (high risk)',
                      style: TextStyle(
                        fontSize: 12,
                        color: ClovaraColors.kWarning,
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

  Widget _buildDecisionSection() {
    return _buildSection(
      title: 'Your Decision',
      icon: Icons.gavel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Decision radio buttons
          Row(
            children: [
              Expanded(
                child: RadioListTile<String>(
                  title: Text('Approve'),
                  value: 'approve',
                  groupValue: _selectedDecision,
                  onChanged: (value) {
                    setState(() => _selectedDecision = value!);
                  },
                  activeColor: ClovaraColors.kSuccessMint,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: Text('Deny'),
                  value: 'deny',
                  groupValue: _selectedDecision,
                  onChanged: (value) {
                    setState(() => _selectedDecision = value!);
                  },
                  activeColor: ClovaraColors.kError,
                ),
              ),
              Expanded(
                child: RadioListTile<String>(
                  title: Text('Request More Info'),
                  value: 'more_info',
                  groupValue: _selectedDecision,
                  onChanged: (value) {
                    setState(() => _selectedDecision = value!);
                  },
                  activeColor: ClovaraColors.kWarning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Reason input
          TextField(
            controller: _reasonController,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: 'Reason (required)',
              hintText: 'Explain your decision...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Submit button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitDecision,
              style: ElevatedButton.styleFrom(
                backgroundColor: _getDecisionColor(),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Text(
                      _getSubmitButtonText(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: ClovaraColors.clover, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ClovaraColors.forest,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
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
            width: 150,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ClovaraColors.kTextGrey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: ClovaraColors.kTextDark),
            ),
          ),
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.85) return ClovaraColors.kSuccessMint;
    if (confidence >= 0.60) return ClovaraColors.kWarning;
    return ClovaraColors.kError;
  }

  Color _getDecisionColor() {
    switch (_selectedDecision) {
      case 'approve':
        return ClovaraColors.kSuccessMint;
      case 'deny':
        return ClovaraColors.kError;
      case 'more_info':
        return ClovaraColors.kWarning;
      default:
        return ClovaraColors.clover;
    }
  }

  String _getSubmitButtonText() {
    switch (_selectedDecision) {
      case 'approve':
        return 'Approve Claim';
      case 'deny':
        return 'Deny Claim';
      case 'more_info':
        return 'Request More Information';
      default:
        return 'Submit Decision';
    }
  }

  Future<void> _submitDecision() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for your decision')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final now = DateTime.now();
      final humanOverride = {
        'overriddenBy': user.uid,
        'overriddenByEmail': user.email ?? 'unknown',
        'originalAIDecision': widget.claim.aiDecision?.value ?? 'none',
        'humanDecision': _selectedDecision,
        'reason': _reasonController.text.trim(),
        'overrideTimestamp': Timestamp.fromDate(now),
      };

      ClaimStatus newStatus;
      switch (_selectedDecision) {
        case 'approve':
          newStatus = ClaimStatus.settling; // Use settling status for payout lock
          break;
        case 'deny':
          newStatus = ClaimStatus.denied;
          break;
        case 'more_info':
          newStatus = ClaimStatus.processing; // Keep processing
          break;
        default:
          newStatus = widget.claim.status;
      }

      // Use optimistic locking with Firestore transaction
      await _firestore.runTransaction((transaction) async {
        // Read current claim state
        final claimRef = _firestore.collection('claims').doc(widget.claim.claimId);
        final currentClaim = await transaction.get(claimRef);
        
        if (!currentClaim.exists) {
          throw Exception('Claim no longer exists');
        }
        
        final currentData = currentClaim.data()!;
        
        // Check if already has humanOverride (someone else reviewed)
        if (currentData['humanOverride'] != null) {
          final existingOverride = currentData['humanOverride'] as Map<String, dynamic>;
          final existingEmail = existingOverride['overriddenByEmail'] as String?;
          throw Exception(
            'Claim was already reviewed by $existingEmail. Please refresh to see the latest decision.'
          );
        }
        
        // Check if status changed (e.g., another admin approved/denied)
        final currentStatus = currentData['status'] as String;
        if (currentStatus != widget.claim.status.value) {
          throw Exception(
            'Claim status has changed to "$currentStatus". Please refresh and try again.'
          );
        }
        
        // Check if claim is locked for payout processing
        if (currentStatus == 'settling') {
          final processingBy = currentData['processingBy'] as String?;
          throw Exception(
            'Claim is currently being processed for payout by $processingBy.'
          );
        }
        
        // Verify claim is in processing status
        if (currentStatus != 'processing') {
          throw Exception(
            'Claim must be in processing status (current: $currentStatus)'
          );
        }
        
        // Safe to update - no conflicts detected
        transaction.update(claimRef, {
          'humanOverride': humanOverride,
          'status': newStatus.value,
          'updatedAt': Timestamp.fromDate(now),
          if (_selectedDecision == 'approve') ...{
            'processingBy': user.uid, // Lock for payout
            'settlingStartedAt': Timestamp.fromDate(now),
          },
          if (_selectedDecision == 'deny')
            'deniedAt': Timestamp.fromDate(now),
        });
        
        // Log to audit trail within transaction
        final auditRef = _firestore
            .collection('claims')
            .doc(widget.claim.claimId)
            .collection('ai_audit_trail')
            .doc(); // Generate ID
        
        transaction.set(auditRef, {
          'claimId': widget.claim.claimId,
          'timestamp': FieldValue.serverTimestamp(),
          'eventType': 'human_override',
          'humanOverride': humanOverride,
          'previousStatus': widget.claim.status.value,
          'newStatus': newStatus.value,
          'transactionId': auditRef.id,
        });
      });

      // If approved, kick off server-side payout processing.
      if (_selectedDecision == 'approve') {
        try {
          final callable = FirebaseFunctions.instance.httpsCallable('processClaimPayout');
          await callable.call({
            'claimId': widget.claim.claimId,
          });
        } catch (e) {
          // Don't block the admin's decision; reconciliation/retries can recover.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Payout initiation failed: $e'),
                backgroundColor: ClovaraColors.sunset,
                duration: const Duration(seconds: 6),
              ),
            );
          }
        }
      }

      setState(() => _isLoading = false);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedDecision == 'approve'
                ? 'Claim approved — payout initiated'
                : 'Decision submitted successfully'),
            backgroundColor: ClovaraColors.kSuccessMint,
          ),
        );
        Navigator.pop(context);
      }
    } on Exception catch (e) {
      // Handle optimistic locking conflicts
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: ClovaraColors.sunset,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'REFRESH',
              textColor: Colors.white,
              onPressed: () {
                Navigator.pop(context); // Close dialog to refresh list
              },
            ),
          ),
        );
      }
    } catch (e) {
      // Handle other errors
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: ClovaraColors.kError,
          ),
        );
      }
    }
  }
}

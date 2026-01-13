import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/underwriting_case.dart';
import '../../theme/clovara_theme.dart';
import 'underwriting_case_review_screen.dart';

class UnderwritingCasesTab extends StatefulWidget {
  const UnderwritingCasesTab({super.key});

  @override
  State<UnderwritingCasesTab> createState() => _UnderwritingCasesTabState();
}

class _UnderwritingCasesTabState extends State<UnderwritingCasesTab> {
  String _filter = 'open';

  static const _openStatuses = ['referred', 'submitted', 'assessed'];
  static const _decidedStatuses = ['approved', 'approved_with_exclusions', 'declined'];

  Query<Map<String, dynamic>> _buildQuery(FirebaseFirestore firestore) {
    final isDecidedFilter = _filter == 'decided' ||
        _filter == 'approved' ||
        _filter == 'approved_with_exclusions' ||
        _filter == 'declined';

    if (isDecidedFilter) {
      return firestore
          .collection('underwriting_cases')
          .where('status', whereIn: _decidedStatuses)
          .orderBy('updatedAt', descending: true);
    }

    return firestore
        .collection('underwriting_cases')
        .where('status', whereIn: _openStatuses)
        .orderBy('updatedAt', descending: true);
  }

  @override
  Widget build(BuildContext context) {
    final firestore = FirebaseFirestore.instance;

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _buildQuery(firestore).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(child: Text('Error loading underwriting cases: ${snapshot.error}'));
        }

        final docs = snapshot.data?.docs ?? const [];
        final allCases = docs.map((d) => UnderwritingCase.fromJson(d.id, d.data())).toList();

        final cases = allCases.where((c) {
          switch (_filter) {
            case 'referred':
              return c.status == UnderwritingCaseStatus.referred;
            case 'submitted':
              return c.status == UnderwritingCaseStatus.submitted;
            case 'assessed':
              return c.status == UnderwritingCaseStatus.assessed;
            case 'decided':
              return c.status == UnderwritingCaseStatus.approved ||
                  c.status == UnderwritingCaseStatus.approvedWithExclusions ||
                  c.status == UnderwritingCaseStatus.declined;
            case 'approved':
              return c.status == UnderwritingCaseStatus.approved;
            case 'approved_with_exclusions':
              return c.status == UnderwritingCaseStatus.approvedWithExclusions;
            case 'declined':
              return c.status == UnderwritingCaseStatus.declined;
            case 'open':
            default:
              return true;
          }
        }).toList();

        if (cases.isEmpty) {
          return Column(
            children: [
              _buildFilters(allCases),
              const Expanded(
                child: Center(child: Text('No underwriting cases matching this filter.')),
              ),
            ],
          );
        }

        return Column(
          children: [
            _buildFilters(allCases),
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: cases.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final c = cases[index];
                  final raw = docs.firstWhere((d) => d.id == c.id).data();

                  final petName = c.petSnapshot?.name ?? 'Pet';
                  final ownerName = c.ownerSnapshot?.fullName ?? 'Owner';
                  final status = underwritingCaseStatusToString(c.status);

                  final decisionOutcome = (raw['decisionOutcome'] ?? '').toString();
                  final decisionDecidedBy = (raw['decisionDecidedBy'] ?? '').toString();
                  final exclusionsCount = (raw['decisionExclusionsCount'] as num?)?.toInt();

                  final decisionLine = decisionOutcome.isEmpty
                      ? 'Decision: (none)'
                      : 'Decision: $decisionOutcome${decisionDecidedBy.isEmpty ? '' : ' • $decisionDecidedBy'}'
                          '${exclusionsCount == null ? '' : ' • exclusions $exclusionsCount'}';

                  return Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      leading: CircleAvatar(
                          backgroundColor: ClovaraColors.clover.withAlpha(38),
                        foregroundColor: ClovaraColors.forest,
                        child: const Icon(Icons.assignment_late),
                      ),
                      title: Text('$petName • $ownerName'),
                      subtitle: Text(
                        'Status: $status\n$decisionLine\nUpdated ${_formatDateTime(c.updatedAt)}',
                      ),
                      isThreeLine: true,
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => UnderwritingCaseReviewScreen(caseId: c.id),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilters(List<UnderwritingCase> allCases) {
    final referredCount = allCases.where((c) => c.status == UnderwritingCaseStatus.referred).length;
    final submittedCount = allCases.where((c) => c.status == UnderwritingCaseStatus.submitted).length;
    final assessedCount = allCases.where((c) => c.status == UnderwritingCaseStatus.assessed).length;
    final approvedCount = allCases.where((c) => c.status == UnderwritingCaseStatus.approved).length;
    final approvedWithExclusionsCount =
        allCases.where((c) => c.status == UnderwritingCaseStatus.approvedWithExclusions).length;
    final declinedCount = allCases.where((c) => c.status == UnderwritingCaseStatus.declined).length;
    final decidedCount = approvedCount + approvedWithExclusionsCount + declinedCount;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _chip('Open (${allCases.length})', 'open'),
          _chip('Referred ($referredCount)', 'referred'),
          _chip('Submitted ($submittedCount)', 'submitted'),
          _chip('Assessed ($assessedCount)', 'assessed'),
          _chip('Decided ($decidedCount)', 'decided'),
          _chip('Approved ($approvedCount)', 'approved'),
          _chip('Approved+Excl ($approvedWithExclusionsCount)', 'approved_with_exclusions'),
          _chip('Declined ($declinedCount)', 'declined'),
        ],
      ),
    );
  }

  Widget _chip(String label, String value) {
    final selected = _filter == value;
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: ClovaraColors.clover.withAlpha(51),
      checkmarkColor: ClovaraColors.clover,
    );
  }

  static String _formatDateTime(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

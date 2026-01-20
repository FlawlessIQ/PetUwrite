import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../admin_console/components/admin_kpi_card.dart';
import '../../admin_console/components/admin_bulk_actions_bar.dart';
import '../../admin_console/components/admin_selectable_data_table.dart';
import '../../admin_console/components/admin_section_card.dart';
import '../../admin_console/components/admin_status_chip.dart';
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
  String _search = '';

  int _sortColumnIndex = 0;
  bool _sortAscending = false;
  final Set<String> _selectedCaseIds = <String>{};

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
        final rows = docs
            .map((d) => _UnderwritingInboxRow(caseDoc: UnderwritingCase.fromJson(d.id, d.data()), raw: d.data()))
            .toList();

        final allCases = rows.map((r) => r.caseDoc).toList();

        final filteredRows = rows.where((r) {
          final c = r.caseDoc;
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
        }).where((r) {
          if (_search.trim().isEmpty) return true;
          final q = _search.trim().toLowerCase();
          final c = r.caseDoc;

          final petName = (c.petSnapshot?.name ?? '').toLowerCase();
          final ownerName = (c.ownerSnapshot?.fullName ?? '').toLowerCase();
          final caseId = c.id.toLowerCase();
          final userId = c.userId.toLowerCase();
          final triggers = c.triggerReasons.join(' ').toLowerCase();
          final decisionOutcome = (r.raw['decisionOutcome'] ?? '').toString().toLowerCase();

          return petName.contains(q) ||
              ownerName.contains(q) ||
              caseId.contains(q) ||
              userId.contains(q) ||
              triggers.contains(q) ||
              decisionOutcome.contains(q);
        }).toList();

        final sortedRows = [...filteredRows];
        _sortRows(sortedRows);

        return ListView(
          children: [
            _buildKpis(allCases),
            const SizedBox(height: 12),
            AdminSectionCard(
              title: 'Underwriting Inbox',
              icon: Icons.rule_folder_outlined,
              child: Column(
                children: [
                  _buildFilters(allCases),
                  const SizedBox(height: 8),
                  _buildSearchAndBulkActions(sortedRows),
                  const SizedBox(height: 12),
                  if (sortedRows.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 28),
                      child: Center(child: Text('No underwriting cases matching this view.')),
                    )
                  else
                    _buildTable(sortedRows),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpis(List<UnderwritingCase> allCases) {
    final openCount = allCases
        .where((c) =>
            c.status == UnderwritingCaseStatus.referred ||
            c.status == UnderwritingCaseStatus.submitted ||
            c.status == UnderwritingCaseStatus.assessed)
        .length;
    final referredCount = allCases.where((c) => c.status == UnderwritingCaseStatus.referred).length;
    final decidedCount = allCases
        .where((c) =>
            c.status == UnderwritingCaseStatus.approved ||
            c.status == UnderwritingCaseStatus.approvedWithExclusions ||
            c.status == UnderwritingCaseStatus.declined)
        .length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;

        final cards = [
          AdminKpiCard(
            label: 'Open queue',
            value: '$openCount',
            icon: Icons.inbox_outlined,
            color: ClovaraColors.clover,
            onTap: () => setState(() => _filter = 'open'),
          ),
          AdminKpiCard(
            label: 'Referred',
            value: '$referredCount',
            icon: Icons.assignment_late_outlined,
            color: ClovaraColors.sunset,
            onTap: () => setState(() => _filter = 'referred'),
          ),
          AdminKpiCard(
            label: 'Decided',
            value: '$decidedCount',
            icon: Icons.verified_outlined,
            color: Colors.indigo,
            onTap: () => setState(() => _filter = 'decided'),
          ),
        ];

        if (isWide) {
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
          children: cards
              .map(
                (c) => SizedBox(
                  width: 360,
                  child: c,
                ),
              )
              .toList(),
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

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
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
    );
  }

  Widget _buildSearchAndBulkActions(List<_UnderwritingInboxRow> rows) {
    final selectedCount = _selectedCaseIds.length;

    return Column(
      children: [
        TextField(
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 13),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Search by caseId, pet, owner, userId, trigger, decision…',
            isDense: true,
          ),
          onChanged: (v) => setState(() => _search = v),
        ),
        const SizedBox(height: 10),
        AdminBulkActionsBar(
          resultsCount: rows.length,
          selectedCount: selectedCount,
          onSelectVisible: rows.isEmpty
              ? null
              : () => setState(() => _selectedCaseIds.addAll(rows.map((r) => r.caseDoc.id))),
          onClearSelection: () => setState(() => _selectedCaseIds.clear()),
          actions: [
            TextButton.icon(
              onPressed: selectedCount == 1
                  ? () {
                      final caseId = _selectedCaseIds.first;
                      _openCase(caseId);
                    }
                  : null,
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Open'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTable(List<_UnderwritingInboxRow> rows) {
    return AdminSelectableDataTable<_UnderwritingInboxRow>(
      items: rows,
      getId: (r) => r.caseDoc.id,
      selectedIds: _selectedCaseIds,
      onSelectedIdsChanged: (next) => setState(() {
        _selectedCaseIds
          ..clear()
          ..addAll(next);
      }),
      sortColumnIndex: _sortColumnIndex,
      sortAscending: _sortAscending,
      columns: [
        DataColumn(
          label: const Text('Updated'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        DataColumn(
          label: const Text('Status'),
          onSort: (i, asc) => setState(() {
            _sortColumnIndex = i;
            _sortAscending = asc;
          }),
        ),
        const DataColumn(label: Text('Pet')),
        const DataColumn(label: Text('Owner')),
        const DataColumn(label: Text('Triggers')),
        const DataColumn(label: Text('Decision')),
        const DataColumn(label: Text('Case ID')),
      ],
      buildCells: (context, r) {
        final c = r.caseDoc;

        final petName = c.petSnapshot?.name ?? '—';
        final ownerName = c.ownerSnapshot?.fullName ?? '—';
        final statusText = underwritingCaseStatusToString(c.status);
        final statusColor = _statusColor(c.status);

        final decisionOutcome = (r.raw['decisionOutcome'] ?? '').toString();
        final decisionDecidedBy = (r.raw['decisionDecidedBy'] ?? '').toString();
        final exclusionsCount = (r.raw['decisionExclusionsCount'] as num?)?.toInt();

        final decisionSummary = decisionOutcome.isEmpty
            ? '—'
            : '$decisionOutcome'
                '${exclusionsCount == null ? '' : ' (excl $exclusionsCount)'}'
                '${decisionDecidedBy.isEmpty ? '' : ' • $decisionDecidedBy'}';

        return [
          DataCell(Text(_formatDateTime(c.updatedAt)), onTap: () => _openCase(c.id)),
          DataCell(
            AdminStatusChip(label: statusText, color: statusColor),
            onTap: () => _openCase(c.id),
          ),
          DataCell(Text(petName), onTap: () => _openCase(c.id)),
          DataCell(Text(ownerName), onTap: () => _openCase(c.id)),
          DataCell(
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                c.triggerReasons.isEmpty ? '—' : c.triggerReasons.join(', '),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            onTap: () => _openCase(c.id),
          ),
          DataCell(
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Text(
                decisionSummary,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            onTap: () => _openCase(c.id),
          ),
          DataCell(
            Text(
              c.id,
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            onTap: () => _openCase(c.id),
          ),
        ];
      },
    );
  }

  void _openCase(String caseId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => UnderwritingCaseReviewScreen(caseId: caseId),
      ),
    );
  }

  void _sortRows(List<_UnderwritingInboxRow> rows) {
    int compareNullable<T extends Comparable>(T? a, T? b) {
      if (a == null && b == null) return 0;
      if (a == null) return -1;
      if (b == null) return 1;
      return a.compareTo(b);
    }

    int cmp(_UnderwritingInboxRow a, _UnderwritingInboxRow b) {
      switch (_sortColumnIndex) {
        case 0: // updated
          return compareNullable<DateTime>(a.caseDoc.updatedAt, b.caseDoc.updatedAt);
        case 1: // status
          return underwritingCaseStatusToString(a.caseDoc.status)
              .compareTo(underwritingCaseStatusToString(b.caseDoc.status));
        default:
          return compareNullable<DateTime>(a.caseDoc.updatedAt, b.caseDoc.updatedAt);
      }
    }

    rows.sort((a, b) {
      final result = cmp(a, b);
      return _sortAscending ? result : -result;
    });
  }

  Color _statusColor(UnderwritingCaseStatus status) {
    switch (status) {
      case UnderwritingCaseStatus.referred:
        return ClovaraColors.sunset;
      case UnderwritingCaseStatus.submitted:
        return Colors.indigo;
      case UnderwritingCaseStatus.assessed:
        return ClovaraColors.forest;
      case UnderwritingCaseStatus.approved:
        return ClovaraColors.clover;
      case UnderwritingCaseStatus.approvedWithExclusions:
        return Colors.teal;
      case UnderwritingCaseStatus.declined:
        return Colors.redAccent;
      case UnderwritingCaseStatus.inProgress:
        return ClovaraColors.slate;
    }
  }

  Widget _chip(String label, String value) {
    final selected = _filter == value;
    return FilterChip(
      selected: selected,
      label: Text(label),
      onSelected: (_) => setState(() => _filter = value),
      selectedColor: ClovaraColors.clover.withAlpha(51),
      checkmarkColor: ClovaraColors.clover,
      labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected ? ClovaraColors.forest : ClovaraColors.slate,
          ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
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

class _UnderwritingInboxRow {
  final UnderwritingCase caseDoc;
  final Map<String, dynamic> raw;

  const _UnderwritingInboxRow({
    required this.caseDoc,
    required this.raw,
  });
}

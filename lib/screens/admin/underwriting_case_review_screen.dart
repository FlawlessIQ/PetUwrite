import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../admin_console/components/admin_section_card.dart';
import '../../admin_console/components/admin_status_chip.dart';
import '../../models/policy_exclusion.dart';
import '../../models/underwriting_case.dart';
import '../../models/underwriting_decision.dart';
import '../../services/underwriting_case_service.dart';
import '../../theme/clovara_theme.dart';

class UnderwritingCaseReviewScreen extends StatefulWidget {
  final String caseId;

  const UnderwritingCaseReviewScreen({super.key, required this.caseId});

  @override
  State<UnderwritingCaseReviewScreen> createState() =>
      _UnderwritingCaseReviewScreenState();
}

class _UnderwritingCaseReviewScreenState
    extends State<UnderwritingCaseReviewScreen> {
  final _service = UnderwritingCaseService();
  final _firestore = FirebaseFirestore.instance;

  late final Future<UnderwritingCase?> _caseFuture;

  bool _saving = false;

  UnderwritingOutcome _outcome = UnderwritingOutcome.approve;
  final TextEditingController _reasonCodesController = TextEditingController();
  final TextEditingController _exclusionsController = TextEditingController();

  UnderwritingDecision? _currentDecision;

  @override
  void initState() {
    super.initState();
    _caseFuture = _loadCase();
  }

  @override
  void dispose() {
    _reasonCodesController.dispose();
    _exclusionsController.dispose();
    super.dispose();
  }

  Future<UnderwritingCase?> _loadCase() async {
    final c = await _service.getCase(widget.caseId);
    _currentDecision = await _service.getCurrentDecision(widget.caseId);

    if (_currentDecision != null) {
      _outcome = _currentDecision!.outcome;
      _reasonCodesController.text = _currentDecision!.reasonCodes.join(', ');
      _exclusionsController.text = _currentDecision!.exclusions
          .map((e) => e.conditionName)
          .join('\n');
    }

    return c;
  }

  Future<void> _saveDecision() async {
    setState(() => _saving = true);

    try {
      final reasonCodes = _reasonCodesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final exclusions = _outcome == UnderwritingOutcome.approveWithExclusions
          ? _exclusionsController.text
                .split('\n')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .map(
                  (condition) => PolicyExclusion(
                    conditionName: condition,
                    scope: 'condition',
                    effectiveDate: DateTime.now(),
                  ),
                )
                .toList()
          : <PolicyExclusion>[];

      final nextVersion = (_currentDecision?.version ?? 0) + 1;

      final decision = UnderwritingDecision(
        outcome: _outcome,
        reasonCodes: reasonCodes,
        exclusions: exclusions,
        pricingAdjustments: UnderwritingPricingAdjustments.defaultAdjustments(),
        decidedAt: DateTime.now(),
        decidedBy: 'admin_override',
        version: nextVersion,
      );

      await _service.saveDecision(widget.caseId, decision);
      await _service.updateStatus(widget.caseId, _statusFromOutcome(_outcome));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Decision saved.')));
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving decision: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  UnderwritingCaseStatus _statusFromOutcome(UnderwritingOutcome outcome) {
    switch (outcome) {
      case UnderwritingOutcome.approve:
        return UnderwritingCaseStatus.approved;
      case UnderwritingOutcome.approveWithExclusions:
        return UnderwritingCaseStatus.approvedWithExclusions;
      case UnderwritingOutcome.decline:
        return UnderwritingCaseStatus.declined;
      case UnderwritingOutcome.refer:
        return UnderwritingCaseStatus.referred;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UnderwritingCase?>(
      future: _caseFuture,
      builder: (context, snapshot) {
        final c = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Decision Case'),
            actions: [
              if (_saving)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Center(
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: _saveDecision,
                  icon: const Icon(Icons.save),
                  label: const Text('Save decision'),
                ),
            ],
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : c == null
              ? const Center(child: Text('Case not found.'))
              : AbsorbPointer(
                  absorbing: _saving,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth >= 1100;

                      final left = ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildCaseHeader(c),
                          const SizedBox(height: 12),
                          _buildDecisionSnapshot(c),
                          const SizedBox(height: 12),
                          _buildAuditTimeline(widget.caseId),
                        ],
                      );

                      final right = ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildDecisionEditor(),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _saveDecision,
                            icon: const Icon(Icons.save),
                            label: const Text('Save exception control'),
                            style: FilledButton.styleFrom(
                              backgroundColor: ClovaraColors.clover,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'All saves are written to the case doc and recorded in the event log.',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurface.withOpacity(0.7),
                                ),
                          ),
                        ],
                      );

                      if (!wide) {
                        return ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            _buildCaseHeader(c),
                            const SizedBox(height: 12),
                            _buildDecisionSnapshot(c),
                            const SizedBox(height: 12),
                            _buildDecisionEditor(),
                            const SizedBox(height: 16),
                            FilledButton.icon(
                              onPressed: _saveDecision,
                              icon: const Icon(Icons.save),
                              label: const Text('Save exception control'),
                              style: FilledButton.styleFrom(
                                backgroundColor: ClovaraColors.clover,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildAuditTimeline(widget.caseId),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(flex: 3, child: left),
                          const VerticalDivider(width: 1),
                          Expanded(flex: 2, child: right),
                        ],
                      );
                    },
                  ),
                ),
        );
      },
    );
  }

  Widget _buildCaseHeader(UnderwritingCase c) {
    final petName = c.petSnapshot?.name ?? 'Pet';
    final ownerName = c.ownerSnapshot?.fullName ?? 'Owner';
    final statusLabel = underwritingCaseStatusToString(c.status);

    return AdminSectionCard(
      title: '$petName • $ownerName',
      icon: Icons.badge_outlined,
      actions: [
        AdminStatusChip(label: statusLabel, color: _statusColor(c.status)),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              _kv('Case ID', c.id),
              _kv('User ID', c.userId),
              _kv('Updated', _formatDateTime(c.updatedAt)),
              if ((c.quoteId ?? '').isNotEmpty) _kv('Quote ID', c.quoteId!),
            ],
          ),
          if (c.triggerReasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Triggers',
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: c.triggerReasons
                  .map(
                    (t) => AdminStatusChip(
                      label: t,
                      color: Theme.of(context).colorScheme.primary,
                      icon: Icons.bolt_outlined,
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDecisionSnapshot(UnderwritingCase c) {
    final decision = _currentDecision;
    final outcome = decision == null
        ? '—'
        : underwritingOutcomeToString(decision.outcome);
    final decidedAt = decision?.decidedAt;
    final decidedBy = (decision?.decidedBy ?? '').isEmpty
        ? '—'
        : decision!.decidedBy;
    final exclusionsCount = decision?.exclusions.length ?? 0;

    return AdminSectionCard(
      title: 'Decision Snapshot',
      icon: Icons.fact_check_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              AdminStatusChip(
                label: 'Outcome: $outcome',
                color: decision == null
                    ? ClovaraColors.slate
                    : ClovaraColors.forest,
              ),
              AdminStatusChip(
                label: 'Decision source: $decidedBy',
                color: ClovaraColors.slate,
                icon: Icons.bolt_outlined,
              ),
              AdminStatusChip(
                label: 'Exclusions: $exclusionsCount',
                color: exclusionsCount > 0 ? Colors.teal : ClovaraColors.slate,
                icon: Icons.do_not_disturb_on_outlined,
              ),
              if (decidedAt != null)
                AdminStatusChip(
                  label: 'Decided at: ${_formatDateTime(decidedAt)}',
                  color: ClovaraColors.slate,
                  icon: Icons.schedule,
                ),
            ],
          ),
          if (decision != null && decision.reasonCodes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Reason codes: ${decision.reasonCodes.join(', ')}'),
          ],
        ],
      ),
    );
  }

  Widget _buildAuditTimeline(String caseId) {
    final eventsQuery = _firestore
        .collection('underwriting_cases')
        .doc(caseId)
        .collection('events')
        .orderBy('createdAt', descending: true)
        .limit(50);

    return AdminSectionCard(
      title: 'Audit Timeline',
      icon: Icons.history,
      actions: [
        TextButton.icon(
          onPressed: () {},
          icon: const Icon(Icons.download_outlined, size: 18),
          label: const Text('Export'),
        ),
      ],
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: eventsQuery.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Text('Error loading events: ${snapshot.error}');
          }

          final docs = snapshot.data?.docs ?? const [];
          if (docs.isEmpty) {
            return const Text('No events recorded yet.');
          }

          return Column(
            children: docs.map((d) {
              final data = d.data();
              final type = (data['eventType'] ?? 'event').toString();
              final actor = (data['actorUserId'] ?? '').toString();
              final ts = data['createdAt'];
              final when = ts is Timestamp ? ts.toDate() : null;
              final payload = data['payload'];

              String payloadSummary() {
                if (payload is Map<String, dynamic>) {
                  if (payload.containsKey('status'))
                    return 'status=${payload['status']}';
                  if (payload.containsKey('outcome'))
                    return 'outcome=${payload['outcome']}';
                  if (payload.containsKey('exclusionsCount'))
                    return 'exclusions=${payload['exclusionsCount']}';
                  if (payload.containsKey('conditionsCount'))
                    return 'conditions=${payload['conditionsCount']}';
                }
                return '';
              }

              final sub = [
                if (when != null) _formatDateTime(when),
                if (actor.isNotEmpty) 'actor=$actor',
                payloadSummary(),
              ].where((s) => s.trim().isNotEmpty).join(' • ');

              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.circle, size: 10),
                title: Text(
                  type,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: sub.isEmpty ? null : Text(sub),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$k: ',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
        Text(v, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
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

  static String _formatDateTime(DateTime value) {
    final y = value.year.toString().padLeft(4, '0');
    final m = value.month.toString().padLeft(2, '0');
    final d = value.day.toString().padLeft(2, '0');
    final hh = value.hour.toString().padLeft(2, '0');
    final mm = value.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  Widget _buildDecisionEditor() {
    return AdminSectionCard(
      title: 'Exception Control',
      icon: Icons.manage_history_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Use only when automation has all required evidence but needs an audited recovery action. The save writes a decision summary onto the case doc and appends an immutable event.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<UnderwritingOutcome>(
            value: _outcome,
            decoration: const InputDecoration(
              labelText: 'Outcome',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(
                value: UnderwritingOutcome.approve,
                child: Text('Approve'),
              ),
              DropdownMenuItem(
                value: UnderwritingOutcome.approveWithExclusions,
                child: Text('Approve with exclusions'),
              ),
              DropdownMenuItem(
                value: UnderwritingOutcome.decline,
                child: Text('Decline'),
              ),
              DropdownMenuItem(
                value: UnderwritingOutcome.refer,
                child: Text('Refer'),
              ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _outcome = value);
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reasonCodesController,
            decoration: const InputDecoration(
              labelText: 'Reason codes (comma-separated)',
              hintText: 'e.g. PRE_EXISTING, ONGOING_TREATMENT',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          if (_outcome == UnderwritingOutcome.approveWithExclusions)
            TextField(
              controller: _exclusionsController,
              minLines: 3,
              maxLines: 8,
              decoration: const InputDecoration(
                labelText: 'Exclusions (one condition per line)',
                hintText: 'e.g. Cruciate ligament\nHip dysplasia',
                border: OutlineInputBorder(),
              ),
            ),
          if (_outcome != UnderwritingOutcome.approveWithExclusions)
            Text(
              'Exclusions apply only to “Approve with exclusions”.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
        ],
      ),
    );
  }
}

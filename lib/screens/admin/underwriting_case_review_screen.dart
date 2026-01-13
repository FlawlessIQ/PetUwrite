import 'package:flutter/material.dart';

import '../../models/policy_exclusion.dart';
import '../../models/underwriting_case.dart';
import '../../models/underwriting_decision.dart';
import '../../services/underwriting_case_service.dart';
import '../../theme/clovara_theme.dart';

class UnderwritingCaseReviewScreen extends StatefulWidget {
  final String caseId;

  const UnderwritingCaseReviewScreen({
    super.key,
    required this.caseId,
  });

  @override
  State<UnderwritingCaseReviewScreen> createState() => _UnderwritingCaseReviewScreenState();
}

class _UnderwritingCaseReviewScreenState extends State<UnderwritingCaseReviewScreen> {
  final _service = UnderwritingCaseService();

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
      _exclusionsController.text = _currentDecision!.exclusions.map((e) => e.conditionName).join('\n');
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
        decidedBy: 'manual',
        version: nextVersion,
      );

      await _service.saveDecision(widget.caseId, decision);
      await _service.updateStatus(widget.caseId, _statusFromOutcome(_outcome));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Decision saved.')),
      );
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
            title: const Text('Underwriting Case Review'),
            backgroundColor: ClovaraColors.forest,
            foregroundColor: Colors.white,
          ),
          body: snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : c == null
                  ? const Center(child: Text('Case not found.'))
                  : AbsorbPointer(
                      absorbing: _saving,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildCaseHeader(c),
                          const SizedBox(height: 16),
                          _buildDecisionEditor(),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _saving ? null : _saveDecision,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.save),
                            label: const Text('Save Manual Decision'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ClovaraColors.clover,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
        );
      },
    );
  }

  Widget _buildCaseHeader(UnderwritingCase c) {
    final petName = c.petSnapshot?.name ?? 'Pet';
    final ownerName = c.ownerSnapshot?.fullName ?? 'Owner';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$petName • $ownerName',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Case ID: ${c.id}'),
            Text('User ID: ${c.userId}'),
            Text('Status: ${underwritingCaseStatusToString(c.status)}'),
            const SizedBox(height: 8),
            if (c.triggerReasons.isNotEmpty)
              Text('Triggers: ${c.triggerReasons.join(', ')}'),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionEditor() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Manual Decision',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
              const Text(
                'Exclusions apply only to “Approve with exclusions”.',
                style: TextStyle(color: Colors.grey),
              ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../screens/underwriting_followup_documents_screen.dart';
import '../../services/draft_service.dart';
import '../../services/user_session_service.dart';
import '../tokens.dart';
import 'buttons.dart';
import 'cards.dart';

class ContinueBanner extends StatefulWidget {
  const ContinueBanner({super.key});

  @override
  State<ContinueBanner> createState() => _ContinueBannerState();
}

class _ContinueBannerState extends State<ContinueBanner> {
  final _codeController = TextEditingController();
  bool _resuming = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _resumeFromKey(String key) async {
    setState(() => _resuming = true);

    // Lightweight blocking progress UI
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: SizedBox(
          height: 72,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Resuming…'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final resolved = await DraftService().resolveAndAdoptDraft(resumeKey: key);

      if (resolved.draftType == 'quote') {
        await UserSessionService().savePendingQuote(resolved.snapshot);
      } else if (resolved.draftType == 'checkout') {
        await UserSessionService().savePendingCheckout(resolved.snapshot);
      } else {
        final caseId = resolved.snapshot['underwritingCaseId']?.toString();
        if (caseId != null && caseId.trim().isNotEmpty) {
          await UserSessionService().savePendingUnderwriting(
            underwritingCaseId: caseId.trim(),
            petName: (resolved.snapshot['petName'] ?? 'your pet').toString(),
            riskScore: resolved.snapshot['riskScore'],
            reason: resolved.snapshot['reason']?.toString(),
            requiredEvidence: (resolved.snapshot['requiredEvidence'] is List)
                ? (resolved.snapshot['requiredEvidence'] as List)
                    .whereType<Map>()
                    .map((e) => e.cast<String, dynamic>())
                    .toList(growable: false)
                : const [],
          );
        }
      }

      if (mounted) Navigator.pop(context);

      if (!mounted) return;

      if (resolved.draftType == 'quote') {
        context.push('/conversational-quote');
        return;
      }

      if (resolved.draftType == 'checkout') {
        final pet = resolved.snapshot['pet'];
        final selectedPlan = resolved.snapshot['selectedPlan'];
        if (pet != null && selectedPlan != null) {
          context.push(
            '/checkout',
            extra: {
              'pet': pet,
              'selectedPlan': selectedPlan,
              'underwritingCaseId': resolved.snapshot['underwritingCaseId']?.toString(),
              'exclusions': resolved.snapshot['exclusions'],
              'underwritingSnapshot': resolved.snapshot['underwritingSnapshot'],
            },
          );
          return;
        }
      }

      final caseId = resolved.snapshot['underwritingCaseId']?.toString();
      if (caseId != null && caseId.trim().isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UnderwritingFollowUpDocumentsScreen(
              underwritingCaseId: caseId.trim(),
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft restored, but nothing to resume.')),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to resume: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

  Future<void> _openCodeDialog() async {
    final controller = TextEditingController(text: _codeController.text);
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Resume with code'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(hintText: 'Paste your resume code'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                final text = (data?.text ?? '').trim();
                if (text.isNotEmpty) controller.text = text;
              },
              child: const Text('Paste'),
            ),
            ElevatedButton(
              onPressed: () {
                final key = controller.text.trim();
                Navigator.pop(context);
                if (key.isNotEmpty) _resumeFromKey(key);
              },
              child: const Text('Resume'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: DraftService().getLocalResumeKey(),
      builder: (context, snapshot) {
        final localKey = snapshot.data;

        return GradientCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(Icons.restore, color: AppColors.deepGreen),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Continue where you left off',
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                            color: AppColors.deepGreen,
                            fontSize: 18,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Resume your quote, checkout, or document upload with one click—or use a resume code from any device.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        PrimaryButton(
                          label: localKey != null ? 'Continue on this device' : 'Enter resume code',
                          icon: localKey != null ? Icons.play_arrow_rounded : Icons.key,
                          isLoading: _resuming,
                          onPressed: _resuming
                              ? null
                              : () {
                                  if (localKey != null) {
                                    _resumeFromKey(localKey);
                                  } else {
                                    _openCodeDialog();
                                  }
                                },
                        ),
                        SecondaryButton(
                          label: 'Paste a code',
                          icon: Icons.content_paste,
                          onPressed: _resuming
                              ? null
                              : () async {
                                  final data = await Clipboard.getData('text/plain');
                                  final text = (data?.text ?? '').trim();
                                  if (text.isNotEmpty) {
                                    _resumeFromKey(text);
                                  } else {
                                    _openCodeDialog();
                                  }
                                },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

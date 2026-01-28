import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/draft_service.dart';

class SaveResumeDialog {
  static Future<void> show(
    BuildContext context, {
    Future<void> Function()? ensureSaved,
    String? title,
    String? body,
    String doneLabel = 'Done',
    String copyLabel = 'Copy',
    IconData icon = Icons.bookmark_add_outlined,
  }) async {
    String? error;

    if (ensureSaved != null) {
      try {
        await _runBlocking(context, ensureSaved);
      } catch (e) {
        error = e.toString().replaceAll('Exception: ', '').trim();
        if (error.isEmpty) error = 'Unable to save right now.';
      }
    }

    if (!context.mounted) return;

    final draftService = DraftService();
    final resumeKey = await draftService.getOrCreateLocalResumeKey();
    final shareable = draftService.encodeForSharing(resumeKey);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Row(
            children: [
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title ?? 'Save & resume later'),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                body ??
                    'Write this down or send it to yourself. You can resume from any device by entering this code on the home page.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.55),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Theme.of(context).dividerColor.withOpacity(0.18),
                  ),
                ),
                child: SelectableText(
                  shareable,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(
                  error,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: shareable),
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Resume code copied.')),
                );
              },
              child: Text(copyLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(doneLabel),
            ),
          ],
        );
      },
    );
  }

  static Future<void> _runBlocking(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    showDialog<void>(
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
                Text('Saving…'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      await action();
    } finally {
      if (context.mounted) Navigator.pop(context);
    }
  }
}

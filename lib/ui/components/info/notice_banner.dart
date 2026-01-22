import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../badges.dart';
import '../premium_card.dart';

enum NoticeTone { info, warning, neutral }

class NoticeBanner extends StatelessWidget {
  const NoticeBanner({
    super.key,
    required this.title,
    required this.body,
    this.tone = NoticeTone.neutral,
    this.icon,
  });

  final String title;
  final String body;
  final NoticeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (bg, fg, defaultIcon) = switch (tone) {
      NoticeTone.info => (
          AppColors.surface2,
          AppColors.deepGreen,
          Icons.info_outline,
        ),
      NoticeTone.warning => (
          const Color(0xFFFFF4EA),
          AppColors.warning,
          Icons.warning_amber_rounded,
        ),
      NoticeTone.neutral => (
          AppColors.surface,
          AppColors.deepGreen,
          Icons.notes_rounded,
        ),
    };

    return PremiumCard(
      showShadow: false,
      backgroundColor: bg,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: icon ?? defaultIcon,
            background: Colors.white.withOpacity(0.70),
            foreground: fg,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepGreen,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: AppColors.textMuted, height: 1.55),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

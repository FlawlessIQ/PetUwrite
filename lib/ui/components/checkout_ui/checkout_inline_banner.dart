import 'package:flutter/material.dart';

import '../../tokens.dart';

enum CheckoutInlineBannerTone { info, warning, success }

class CheckoutInlineBanner extends StatelessWidget {
  const CheckoutInlineBanner({
    super.key,
    required this.title,
    required this.message,
    this.tone = CheckoutInlineBannerTone.info,
    this.trailing,
  });

  final String title;
  final String message;
  final CheckoutInlineBannerTone tone;
  final Widget? trailing;

  Color get _accent {
    switch (tone) {
      case CheckoutInlineBannerTone.success:
        return AppColors.success;
      case CheckoutInlineBannerTone.warning:
        return AppColors.warning;
      case CheckoutInlineBannerTone.info:
        return AppColors.green;
    }
  }

  IconData get _icon {
    switch (tone) {
      case CheckoutInlineBannerTone.success:
        return Icons.check_circle_outline;
      case CheckoutInlineBannerTone.warning:
        return Icons.gpp_maybe_outlined;
      case CheckoutInlineBannerTone.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadii.br16,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.soft,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _accent.withValues(alpha: 0.20)),
            ),
            child: Icon(_icon, color: _accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

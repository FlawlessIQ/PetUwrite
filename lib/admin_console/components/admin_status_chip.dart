import 'package:flutter/material.dart';

import '../admin_theme.dart';

class AdminStatusChip extends StatelessWidget {
  final String label;
  final Color? color;
  final IconData? icon;

  const AdminStatusChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: effectiveColor.withOpacity(0.08),
        border: Border.all(color: effectiveColor.withOpacity(0.24)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: effectiveColor),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: effectiveColor == AdminColors.faint
                  ? AdminColors.muted
                  : effectiveColor,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

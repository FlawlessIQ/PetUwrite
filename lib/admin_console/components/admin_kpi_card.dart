import 'package:flutter/material.dart';

import '../admin_theme.dart';

class AdminKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final String? delta;
  final IconData icon;
  final Color? color;
  final VoidCallback? onTap;

  const AdminKpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.delta,
    this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    final isClickable = onTap != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminRadii.lg),
        mouseCursor: isClickable
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: Ink(
          decoration: BoxDecoration(
            color: AdminColors.surface,
            borderRadius: BorderRadius.circular(AdminRadii.lg),
            border: Border.all(color: AdminColors.border),
            boxShadow: [
              BoxShadow(
                color: AdminColors.text.withOpacity(0.05),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 14,
                bottom: 14,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: c,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: c.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: c.withOpacity(0.18)),
                      ),
                      child: Icon(icon, color: c, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label.toUpperCase(),
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AdminColors.muted,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.8,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    value,
                                    maxLines: 1,
                                    style:
                                        Theme.of(
                                          context,
                                        ).textTheme.headlineMedium?.copyWith(
                                          color: AdminColors.text,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.9,
                                          height: 1.0,
                                        ) ??
                                        const TextStyle(),
                                  ),
                                ),
                              ),
                              if (delta != null &&
                                  delta!.trim().isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 2),
                                  child: Text(
                                    delta!,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelMedium
                                        ?.copyWith(
                                          color: c,
                                          fontWeight: FontWeight.w900,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isClickable) ...[
                      const SizedBox(width: 10),
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.72),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AdminColors.border),
                        ),
                        child: const Icon(
                          Icons.chevron_right,
                          size: 18,
                          color: AdminColors.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

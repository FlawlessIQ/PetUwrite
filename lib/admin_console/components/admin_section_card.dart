import 'package:flutter/material.dart';

import '../admin_theme.dart';

class AdminSectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<Widget>? actions;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool expandChild;

  const AdminSectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.actions,
    this.padding = const EdgeInsets.all(16),
    this.expandChild = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.surface,
        borderRadius: BorderRadius.circular(AdminRadii.lg),
        border: Border.all(color: AdminColors.border, width: 1),
        boxShadow: [
          BoxShadow(
            color: AdminColors.text.withOpacity(0.045),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AdminRadii.lg),
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AdminColors.successSoft,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AdminColors.border),
                      ),
                      child: Icon(
                        icon,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AdminColors.text,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
              const SizedBox(height: 14),
              if (expandChild) Expanded(child: child) else child,
            ],
          ),
        ),
      ),
    );
  }
}

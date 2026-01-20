import 'package:flutter/material.dart';

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
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
            const SizedBox(height: 12),
            if (expandChild)
              Expanded(child: child)
            else
              child,
          ],
        ),
      ),
    );
  }
}

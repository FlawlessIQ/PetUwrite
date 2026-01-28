import 'package:flutter/material.dart';

import '../../tokens.dart';

class CheckoutCard extends StatelessWidget {
  const CheckoutCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.selected = false,
    this.accent,
  });

  final Widget child;
  final EdgeInsets padding;
  final bool selected;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final a = accent ?? AppColors.green;
    final borderColor = selected ? a.withValues(alpha: 0.55) : AppColors.border;
    final borderWidth = selected ? 2.0 : 1.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadii.br20,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: AppShadows.soft,
      ),
      child: child,
    );
  }
}

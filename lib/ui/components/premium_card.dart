import 'package:flutter/material.dart';

import '../tokens.dart';

class PremiumCard extends StatefulWidget {
  const PremiumCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(18),
    this.backgroundColor = AppColors.surface,
    this.radius = AppRadii.br20,
    this.showShadow = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color backgroundColor;
  final BorderRadius radius;
  final bool showShadow;

  @override
  State<PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends State<PremiumCard> {
  bool _hover = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    final interactive = widget.onTap != null;
    final borderColor = _focus
        ? AppColors.green.withOpacity(0.45)
        : (_hover && interactive)
            ? AppColors.borderTint
            : AppColors.border;

    final shadows = !widget.showShadow
        ? const <BoxShadow>[]
        : (_hover && interactive)
            ? AppShadows.hover
            : AppShadows.soft;

    return FocusableActionDetector(
      mouseCursor: interactive ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        scale: (_hover && interactive) ? 1.01 : 1,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            borderRadius: widget.radius,
            border: Border.all(color: borderColor, width: 1),
            boxShadow: shadows,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: widget.radius,
              onTap: widget.onTap,
              child: Padding(
                padding: widget.padding,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../tokens.dart';

class GradientBorder extends StatelessWidget {
  const GradientBorder({
    super.key,
    required this.child,
    this.radius = AppRadii.br24,
    this.thickness = 1.4,
    this.gradient = AppColors.auroraGradient,
    this.innerColor = AppColors.surface,
  });

  final Widget child;
  final BorderRadius radius;
  final double thickness;
  final Gradient gradient;
  final Color innerColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient, borderRadius: radius),
      child: Padding(
        padding: EdgeInsets.all(thickness),
        child: DecoratedBox(
          decoration: BoxDecoration(color: innerColor, borderRadius: radius),
          child: child,
        ),
      ),
    );
  }
}

import 'dart:math';

import 'package:flutter/material.dart';

import '../tokens.dart';

class HeroStage extends StatelessWidget {
  const HeroStage({
    super.key,
    required this.left,
    required this.right,
    this.bottom,
    this.padding = const EdgeInsets.all(18),
    this.radius = AppRadii.br24,
  });

  final Widget left;
  final Widget right;
  final Widget? bottom;
  final EdgeInsets padding;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: radius,
      child: Stack(
        children: [
          const Positioned.fill(child: _AuroraMeshBackground()),
          const _NoiseOverlay(opacity: 0.035),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(color: AppColors.borderTint),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x140B241D),
                    blurRadius: 32,
                    offset: Offset(0, 18),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: padding,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 920;
                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      left,
                      const SizedBox(height: 16),
                      right,
                      if (bottom != null) ...[
                        const SizedBox(height: 16),
                        bottom!,
                      ],
                    ],
                  );
                }

                final row = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 6, child: left),
                    const SizedBox(width: 16),
                    Expanded(flex: 5, child: right),
                  ],
                );

                if (bottom == null) return row;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [row, const SizedBox(height: 16), bottom!],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraMeshBackground extends StatelessWidget {
  const _AuroraMeshBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: AppColors.auroraGradient),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.6, -0.8),
                radius: 1.2,
                colors: [
                  AppColors.deepGreen.withOpacity(0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.9, 0.2),
                radius: 1.0,
                colors: [
                  AppColors.signalBlue.withOpacity(0.10),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.surface.withOpacity(0.78),
            ),
          ),
        ),
      ],
    );
  }
}

class _NoiseOverlay extends StatelessWidget {
  const _NoiseOverlay({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: CustomPaint(painter: _NoisePainter(opacity: opacity)),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  _NoisePainter({required this.opacity});

  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(opacity);
    final rnd = Random(7);

    final count = max(350, (size.width * size.height / 1200).round());
    for (int i = 0; i < count; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final r = rnd.nextDouble() * 0.7 + 0.2;
      canvas.drawCircle(Offset(dx, dy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoisePainter oldDelegate) {
    return oldDelegate.opacity != opacity;
  }
}

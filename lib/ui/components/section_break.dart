import 'package:flutter/material.dart';

class SectionBreak extends StatelessWidget {
  const SectionBreak({
    super.key,
    required this.fromColor,
    required this.toColor,
    this.height = 26,
    this.flip = false,
  });

  final Color fromColor;
  final Color toColor;
  final double height;
  final bool flip;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SectionBreakPainter(
          fromColor: fromColor,
          toColor: toColor,
          flip: flip,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _SectionBreakPainter extends CustomPainter {
  _SectionBreakPainter({
    required this.fromColor,
    required this.toColor,
    required this.flip,
  });

  final Color fromColor;
  final Color toColor;
  final bool flip;

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = toColor;
    canvas.drawRect(Offset.zero & size, bg);

    final paint = Paint()..color = fromColor;

    final path = Path();
    if (!flip) {
      path.moveTo(0, 0);
      path.lineTo(0, size.height * 0.55);
      path.cubicTo(
        size.width * 0.25,
        size.height * 0.95,
        size.width * 0.70,
        size.height * 0.15,
        size.width,
        size.height * 0.65,
      );
      path.lineTo(size.width, 0);
      path.close();
    } else {
      path.moveTo(0, size.height);
      path.lineTo(0, size.height * 0.45);
      path.cubicTo(
        size.width * 0.25,
        size.height * 0.05,
        size.width * 0.70,
        size.height * 0.85,
        size.width,
        size.height * 0.35,
      );
      path.lineTo(size.width, size.height);
      path.close();
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SectionBreakPainter oldDelegate) {
    return oldDelegate.fromColor != fromColor ||
        oldDelegate.toColor != toColor ||
        oldDelegate.flip != flip;
  }
}

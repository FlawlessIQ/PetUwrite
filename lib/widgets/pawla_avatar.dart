import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Pawla - The Empathetic AI Pet Insurance Assistant
/// 
/// An animated avatar that provides emotional support and updates
/// throughout the claims process. Shows different expressions and
/// animations based on context.
class PawlaAvatar extends StatefulWidget {
  final PawlaExpression expression;
  final PawlaState state;
  final double size;
  final String? message;
  final bool animated;
  final bool showGlow;
  
  const PawlaAvatar({
    super.key,
    this.expression = PawlaExpression.happy,
    this.state = PawlaState.idle,
    this.size = 120,
    this.message,
    this.animated = true,
    this.showGlow = false,
  });

  @override
  State<PawlaAvatar> createState() => _PawlaAvatarState();
}

/// Pawla's animation states
enum PawlaState {
  idle,      // Default resting state
  typing,    // When generating a response
  listening, // When waiting for user input
  blinking,  // Subtle blink animation
  nodding,   // Acknowledgment animation
}

class _PawlaAvatarState extends State<PawlaAvatar>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _glowController;
  late AnimationController _blinkController;
  late Animation<double> _floatAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();
    
    // Main animation controller for floating/pulsing
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _floatAnimation = Tween<double>(
      begin: -5,
      end: 5,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    _pulseAnimation = Tween<double>(
      begin: 1.0,
      end: 1.05,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Glow animation for typing state
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _glowAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _glowController,
      curve: Curves.easeInOut,
    ));
    
    // Blink animation
    _blinkController = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _blinkAnimation = Tween<double>(
      begin: 1.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _blinkController,
      curve: Curves.easeInOut,
    ));

    if (widget.animated) {
      _controller.repeat(reverse: true);
    }
    
    if (widget.showGlow || widget.state == PawlaState.typing) {
      _glowController.repeat(reverse: true);
    }
    
    // Trigger periodic blinks
    _startBlinking();
  }
  
  void _startBlinking() {
    Future.delayed(Duration(seconds: 3 + math.Random().nextInt(3)), () {
      if (mounted) {
        _blinkController.forward().then((_) {
          _blinkController.reverse().then((_) {
            _startBlinking();
          });
        });
      }
    });
  }
  
  @override
  void didUpdateWidget(PawlaAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Update glow based on state
    if (widget.state == PawlaState.typing || widget.showGlow) {
      if (!_glowController.isAnimating) {
        _glowController.repeat(reverse: true);
      }
    } else {
      _glowController.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _glowController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: Listenable.merge([_controller, _glowController, _blinkController]),
          builder: (context, child) {
            // Calculate glow intensity
            final glowIntensity = (widget.state == PawlaState.typing || widget.showGlow)
                ? _glowAnimation.value
                : 0.0;
            
            return Transform.translate(
              offset: Offset(0, widget.animated ? _floatAnimation.value : 0),
              child: Transform.scale(
                scale: widget.animated ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: _getGradientColors(),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _getGradientColors()[0].withOpacity(0.3 + (glowIntensity * 0.3)),
                        blurRadius: 20 + (glowIntensity * 10),
                        offset: const Offset(0, 10),
                        spreadRadius: glowIntensity * 5,
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: _PawlaPainter(
                      expression: widget.expression,
                      blinkAmount: _blinkAnimation.value,
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 16),
          _buildMessageBubble(),
        ],
        // Show typing indicator for typing state
        if (widget.state == PawlaState.typing) ...[
          const SizedBox(height: 8),
          _buildTypingIndicator(),
        ],
      ],
    );
  }
  
  Widget _buildTypingIndicator() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildTypingDot(0),
        const SizedBox(width: 4),
        _buildTypingDot(1),
        const SizedBox(width: 4),
        _buildTypingDot(2),
      ],
    );
  }
  
  Widget _buildTypingDot(int index) {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, child) {
        final delay = index * 0.2;
        final animValue = ((_glowAnimation.value + delay) % 1.0);
        final opacity = 0.3 + (animValue * 0.7);
        
        return Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: _getGradientColors()[0].withOpacity(opacity),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }

  List<Color> _getGradientColors() {
    switch (widget.expression) {
      case PawlaExpression.happy:
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
      case PawlaExpression.thinking:
        return [const Color(0xFF4facfe), const Color(0xFF00f2fe)];
      case PawlaExpression.empathetic:
        return [const Color(0xFFf093fb), const Color(0xFFF5576C)];
      case PawlaExpression.celebrating:
        return [const Color(0xFFfa709a), const Color(0xFFfee140)];
      case PawlaExpression.concerned:
        return [const Color(0xFF8e9eab), const Color(0xFFeef2f3)];
      case PawlaExpression.working:
        return [const Color(0xFF667eea), const Color(0xFF764ba2)];
    }
  }

  Widget _buildMessageBubble() {
    return Container(
      constraints: BoxConstraints(maxWidth: widget.size * 2.5),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Text(
        widget.message!,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Color(0xFF333333),
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}

/// Custom painter for Pawla's face
class _PawlaPainter extends CustomPainter {
  final PawlaExpression expression;
  final double blinkAmount;

  _PawlaPainter({
    required this.expression,
    this.blinkAmount = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.white;

    // Draw face features based on expression
    switch (expression) {
      case PawlaExpression.happy:
        _drawHappyFace(canvas, center, size, paint);
        break;
      case PawlaExpression.thinking:
        _drawThinkingFace(canvas, center, size, paint);
        break;
      case PawlaExpression.empathetic:
        _drawEmpatheticFace(canvas, center, size, paint);
        break;
      case PawlaExpression.celebrating:
        _drawCelebratingFace(canvas, center, size, paint);
        break;
      case PawlaExpression.concerned:
        _drawConcernedFace(canvas, center, size, paint);
        break;
      case PawlaExpression.working:
        _drawWorkingFace(canvas, center, size, paint);
        break;
    }
  }

  void _drawHappyFace(Canvas canvas, Offset center, Size size, Paint paint) {
    // Eyes - happy curved eyes
    paint.color = Colors.white;
    final eyeSize = size.width * 0.12;
    final eyeY = center.dy - size.height * 0.1;
    
    // Left eye
    final leftEyePath = Path()
      ..moveTo(center.dx - size.width * 0.2, eyeY)
      ..quadraticBezierTo(
        center.dx - size.width * 0.15,
        eyeY - eyeSize * 0.5,
        center.dx - size.width * 0.1,
        eyeY,
      );
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    canvas.drawPath(leftEyePath, paint);

    // Right eye
    final rightEyePath = Path()
      ..moveTo(center.dx + size.width * 0.1, eyeY)
      ..quadraticBezierTo(
        center.dx + size.width * 0.15,
        eyeY - eyeSize * 0.5,
        center.dx + size.width * 0.2,
        eyeY,
      );
    canvas.drawPath(rightEyePath, paint);

    // Smile
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 4;
    paint.strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(center.dx - size.width * 0.25, center.dy + size.height * 0.05)
      ..quadraticBezierTo(
        center.dx,
        center.dy + size.height * 0.2,
        center.dx + size.width * 0.25,
        center.dy + size.height * 0.05,
      );
    canvas.drawPath(smilePath, paint);

    // Nose - small paw print
    _drawPawNose(canvas, center, size, paint);
  }

  void _drawThinkingFace(Canvas canvas, Offset center, Size size, Paint paint) {
    // Eyes - one slightly squinted
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    final eyeSize = size.width * 0.08;
    final eyeY = center.dy - size.height * 0.1;
    
    // Left eye - normal
    canvas.drawCircle(
      Offset(center.dx - size.width * 0.15, eyeY),
      eyeSize,
      paint,
    );
    
    // Right eye - slightly squinted
    final rightEyeRect = Rect.fromCenter(
      center: Offset(center.dx + size.width * 0.15, eyeY),
      width: eyeSize * 2,
      height: eyeSize * 1.5,
    );
    canvas.drawOval(rightEyeRect, paint);

    // Pupils
    paint.color = const Color(0xFF333333);
    canvas.drawCircle(
      Offset(center.dx - size.width * 0.15, eyeY),
      eyeSize * 0.5,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.15, eyeY),
      eyeSize * 0.4,
      paint,
    );

    // Mouth - slight curve
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    final mouthPath = Path()
      ..moveTo(center.dx - size.width * 0.15, center.dy + size.height * 0.1)
      ..quadraticBezierTo(
        center.dx,
        center.dy + size.height * 0.15,
        center.dx + size.width * 0.15,
        center.dy + size.height * 0.1,
      );
    canvas.drawPath(mouthPath, paint);

    // Thought bubble - three dots
    paint.style = PaintingStyle.fill;
    paint.color = Colors.white.withOpacity(0.8);
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.35, center.dy - size.height * 0.2),
      3,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.4, center.dy - size.height * 0.25),
      4,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.45, center.dy - size.height * 0.3),
      5,
      paint,
    );
  }

  void _drawEmpatheticFace(Canvas canvas, Offset center, Size size, Paint paint) {
    // Soft, caring eyes
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    final eyeSize = size.width * 0.1;
    final eyeY = center.dy - size.height * 0.1;
    
    // Draw soft oval eyes
    final leftEyeRect = Rect.fromCenter(
      center: Offset(center.dx - size.width * 0.15, eyeY),
      width: eyeSize * 1.8,
      height: eyeSize * 2,
    );
    canvas.drawOval(leftEyeRect, paint);
    
    final rightEyeRect = Rect.fromCenter(
      center: Offset(center.dx + size.width * 0.15, eyeY),
      width: eyeSize * 1.8,
      height: eyeSize * 2,
    );
    canvas.drawOval(rightEyeRect, paint);

    // Warm pupils with sparkle
    paint.color = const Color(0xFF764ba2);
    canvas.drawCircle(
      Offset(center.dx - size.width * 0.15, eyeY),
      eyeSize * 0.6,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.15, eyeY),
      eyeSize * 0.6,
      paint,
    );

    // Sparkles in eyes
    paint.color = Colors.white;
    canvas.drawCircle(
      Offset(center.dx - size.width * 0.14, eyeY - 2),
      2,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.16, eyeY - 2),
      2,
      paint,
    );

    // Gentle smile
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    paint.strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(center.dx - size.width * 0.2, center.dy + size.height * 0.08)
      ..quadraticBezierTo(
        center.dx,
        center.dy + size.height * 0.18,
        center.dx + size.width * 0.2,
        center.dy + size.height * 0.08,
      );
    canvas.drawPath(smilePath, paint);

    // Heart accent
    _drawHeart(
      canvas,
      Offset(center.dx + size.width * 0.35, center.dy - size.height * 0.25),
      size.width * 0.08,
      paint,
    );
  }

  void _drawCelebratingFace(Canvas canvas, Offset center, Size size, Paint paint) {
    // Wide happy eyes
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    final eyeSize = size.width * 0.1;
    final eyeY = center.dy - size.height * 0.1;
    
    canvas.drawCircle(
      Offset(center.dx - size.width * 0.15, eyeY),
      eyeSize,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.15, eyeY),
      eyeSize,
      paint,
    );

    // Excited pupils
    paint.color = const Color(0xFF333333);
    canvas.drawCircle(
      Offset(center.dx - size.width * 0.15, eyeY),
      eyeSize * 0.6,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.15, eyeY),
      eyeSize * 0.6,
      paint,
    );

    // Big smile
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 4;
    paint.strokeCap = StrokeCap.round;
    final smilePath = Path()
      ..moveTo(center.dx - size.width * 0.3, center.dy + size.height * 0.05)
      ..quadraticBezierTo(
        center.dx,
        center.dy + size.height * 0.25,
        center.dx + size.width * 0.3,
        center.dy + size.height * 0.05,
      );
    canvas.drawPath(smilePath, paint);

    // Confetti
    paint.style = PaintingStyle.fill;
    final random = math.Random(42); // Fixed seed for consistent confetti
    for (int i = 0; i < 8; i++) {
      final angle = (i / 8) * 2 * math.pi;
      final distance = size.width * 0.4;
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;
      
      paint.color = _getConfettiColor(i);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(random.nextDouble() * math.pi);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: 4, height: 8),
        paint,
      );
      canvas.restore();
    }
  }

  void _drawConcernedFace(Canvas canvas, Offset center, Size size, Paint paint) {
    // Worried eyes
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    final eyeSize = size.width * 0.09;
    final eyeY = center.dy - size.height * 0.1;
    
    canvas.drawCircle(
      Offset(center.dx - size.width * 0.15, eyeY),
      eyeSize,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.15, eyeY),
      eyeSize,
      paint,
    );

    // Pupils
    paint.color = const Color(0xFF555555);
    canvas.drawCircle(
      Offset(center.dx - size.width * 0.15, eyeY + 2),
      eyeSize * 0.5,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.15, eyeY + 2),
      eyeSize * 0.5,
      paint,
    );

    // Worried eyebrows
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    paint.strokeCap = StrokeCap.round;
    
    final leftBrowPath = Path()
      ..moveTo(center.dx - size.width * 0.2, eyeY - eyeSize * 1.5)
      ..lineTo(center.dx - size.width * 0.1, eyeY - eyeSize * 1.8);
    canvas.drawPath(leftBrowPath, paint);
    
    final rightBrowPath = Path()
      ..moveTo(center.dx + size.width * 0.2, eyeY - eyeSize * 1.5)
      ..lineTo(center.dx + size.width * 0.1, eyeY - eyeSize * 1.8);
    canvas.drawPath(rightBrowPath, paint);

    // Concerned mouth
    final mouthPath = Path()
      ..moveTo(center.dx - size.width * 0.15, center.dy + size.height * 0.15)
      ..quadraticBezierTo(
        center.dx,
        center.dy + size.height * 0.12,
        center.dx + size.width * 0.15,
        center.dy + size.height * 0.15,
      );
    canvas.drawPath(mouthPath, paint);
  }

  void _drawWorkingFace(Canvas canvas, Offset center, Size size, Paint paint) {
    // Focused eyes
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    final eyeSize = size.width * 0.09;
    final eyeY = center.dy - size.height * 0.1;
    
    canvas.drawCircle(
      Offset(center.dx - size.width * 0.15, eyeY),
      eyeSize,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.15, eyeY),
      eyeSize,
      paint,
    );

    // Determined pupils
    paint.color = const Color(0xFF667eea);
    canvas.drawCircle(
      Offset(center.dx - size.width * 0.15, eyeY),
      eyeSize * 0.6,
      paint,
    );
    canvas.drawCircle(
      Offset(center.dx + size.width * 0.15, eyeY),
      eyeSize * 0.6,
      paint,
    );

    // Concentrated mouth
    paint.color = Colors.white;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 3;
    canvas.drawLine(
      Offset(center.dx - size.width * 0.15, center.dy + size.height * 0.12),
      Offset(center.dx + size.width * 0.15, center.dy + size.height * 0.12),
      paint,
    );

    // Animated progress indicator
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 2;
    paint.strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCenter(
        center: Offset(center.dx + size.width * 0.35, center.dy),
        width: size.width * 0.15,
        height: size.width * 0.15,
      ),
      -math.pi / 2,
      math.pi * 1.5,
      false,
      paint,
    );
  }

  void _drawPawNose(Canvas canvas, Offset center, Size size, Paint paint) {
    paint.color = Colors.white;
    paint.style = PaintingStyle.fill;
    
    // Main pad
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(center.dx, center.dy + size.height * 0.02),
        width: size.width * 0.08,
        height: size.height * 0.06,
      ),
      paint,
    );
    
    // Three toe beans
    final toeSize = size.width * 0.025;
    final toeY = center.dy - size.height * 0.02;
    
    canvas.drawCircle(Offset(center.dx - size.width * 0.04, toeY), toeSize, paint);
    canvas.drawCircle(Offset(center.dx, toeY - toeSize), toeSize, paint);
    canvas.drawCircle(Offset(center.dx + size.width * 0.04, toeY), toeSize, paint);
  }

  void _drawHeart(Canvas canvas, Offset center, double size, Paint paint) {
    paint.style = PaintingStyle.fill;
    paint.color = Colors.white.withOpacity(0.9);
    
    final path = Path()
      ..moveTo(center.dx, center.dy + size * 0.3)
      ..cubicTo(
        center.dx - size * 0.6,
        center.dy - size * 0.2,
        center.dx - size * 0.8,
        center.dy - size * 0.8,
        center.dx,
        center.dy - size * 0.4,
      )
      ..cubicTo(
        center.dx + size * 0.8,
        center.dy - size * 0.8,
        center.dx + size * 0.6,
        center.dy - size * 0.2,
        center.dx,
        center.dy + size * 0.3,
      );
    
    canvas.drawPath(path, paint);
  }

  Color _getConfettiColor(int index) {
    final colors = [
      const Color(0xFFfa709a),
      const Color(0xFFfee140),
      const Color(0xFF30cfd0),
      const Color(0xFF4facfe),
      const Color(0xFFf093fb),
      const Color(0xFF667eea),
      const Color(0xFF764ba2),
      const Color(0xFFa8edea),
    ];
    return colors[index % colors.length];
  }

  @override
  bool shouldRepaint(covariant _PawlaPainter oldDelegate) {
    return oldDelegate.expression != expression || oldDelegate.blinkAmount != blinkAmount;
  }
}

/// Pawla's expressions for different contexts
enum PawlaExpression {
  happy,         // General positive state
  thinking,      // Processing/analyzing
  empathetic,    // Showing care and understanding
  celebrating,   // Claim approved!
  concerned,     // Issue or denial
  working,       // Actively working on something
}

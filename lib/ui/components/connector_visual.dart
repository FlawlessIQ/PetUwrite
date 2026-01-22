import 'dart:math' as math;
import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../tokens.dart';

class ConnectorVisual extends StatefulWidget {
  const ConnectorVisual({
    super.key,
    this.height = 180,
    this.opacity = 1.0,
    this.borderRadius = 24,
    this.illustrationCandidates = const [
      // User-provided illustration (keep exact filename as added).
      'assets/animations/ChatGPT Image Jan 22, 2026 at 12_30_01 PM.png',
      // Preferred: animated asset (GIF/WebP) exported from design.
      'assets/animations/pets_connector.gif',
      // Fallback: static illustration (PNG) that we can bob/float.
      'assets/images/pets_connector.png',
    ],
  });

  final double height;
  final double opacity;
  final double borderRadius;
  final List<String> illustrationCandidates;

  @override
  State<ConnectorVisual> createState() => _ConnectorVisualState();
}

class _ConnectorVisualState extends State<ConnectorVisual>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  String? _lottieError;
  Future<String?>? _resolvedIllustration;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolvedIllustration ??= _resolveIllustration();
  }

  Future<String?> _resolveIllustration() async {
    final bundle = DefaultAssetBundle.of(context);
    try {
      final manifestRaw = await bundle.loadString('AssetManifest.json');
      final manifest = jsonDecode(manifestRaw);
      if (manifest is! Map) return null;
      final keys = manifest.keys.map((e) => e.toString()).toSet();
      for (final candidate in widget.illustrationCandidates) {
        if (keys.contains(candidate)) return candidate;
      }
      return null;
    } catch (_) {
      // If manifest isn't available for some reason, just don't render an illustration.
      return null;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final floatY = math.sin(_controller.value * math.pi * 2) * 6.0;
    final floatX = math.cos(_controller.value * math.pi * 2) * 4.0;
    final scale = 1.0 + (0.015 * math.sin(_controller.value * math.pi * 2));

    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: AppColors.surface2),
            Opacity(
              opacity: widget.opacity,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _ConnectorPainter(t: _controller.value),
                  );
                },
              ),
            ),

            // Illustration layer (animated GIF preferred; otherwise static PNG with subtle motion).
            Positioned.fill(
              child: FutureBuilder<String?>(
                future: _resolvedIllustration,
                builder: (context, snapshot) {
                  final key = snapshot.data;
                  if (key == null) return const SizedBox.shrink();

                  return Center(
                    child: Transform.translate(
                      offset: Offset(floatX, floatY),
                      child: Transform.scale(
                        scale: scale,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxHeight: widget.height * 0.92,
                            maxWidth: 520,
                          ),
                          child: Image.asset(
                            key,
                            fit: BoxFit.contain,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // If we're not web and Lottie is available, render it as an optional accent behind the illustration.
            if (!kIsWeb)
              Opacity(
                opacity: (widget.opacity * 0.55).clamp(0.0, 1.0),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    AppColors.deepGreen.withOpacity(0.55),
                    BlendMode.srcIn,
                  ),
                  child: Lottie.asset(
                    'assets/animations/clovara_bg_lottie.json',
                    fit: BoxFit.cover,
                    alignment: Alignment.center,
                    controller: _controller,
                    animate: false,
                    frameRate: FrameRate.max,
                    options: LottieOptions(enableMergePaths: true),
                    onLoaded: (composition) {
                      _controller
                        ..duration = composition.duration
                        ..repeat();
                    },
                    errorBuilder: (context, error, stackTrace) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() {
                          _lottieError = error.toString();
                        });
                      });
                      return const SizedBox.shrink();
                    },
                  ),
                ),
              ),

            // Light wash to keep it “insurance-grade” while still visible.
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.white.withOpacity(0.55),
                      Colors.white.withOpacity(0.12),
                      Colors.white.withOpacity(0.42),
                    ],
                    stops: const [0.0, 0.55, 1.0],
                  ),
                ),
              ),
            ),

            if (!kIsWeb && _lottieError != null)
              Center(
                child: Text(
                  'Animation unavailable',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectorPainter extends CustomPainter {
  _ConnectorPainter({required this.t});

  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // Base gradient that slowly shifts.
    final shift = (t * 2.0) - 1.0;
    final shader = LinearGradient(
      begin: Alignment(-1.4 + shift, -1.0),
      end: Alignment(1.2 + shift, 1.0),
      colors: [
        AppColors.deepGreen.withOpacity(0.0),
        AppColors.deepGreen.withOpacity(0.12),
        AppColors.green.withOpacity(0.10),
        AppColors.accentOrange.withOpacity(0.07),
        AppColors.deepGreen.withOpacity(0.0),
      ],
      stops: const [0.0, 0.32, 0.55, 0.72, 1.0],
    ).createShader(rect);

    final paint = Paint()..shader = shader;
    canvas.drawRect(rect, paint);

    // Animated diagonal ribbons.
    final ribbonPaint = Paint()
      ..color = AppColors.deepGreen.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    Path ribbon(double y0, double amp, double thickness) {
      final path = Path();
      final wave = (math.sin((t * math.pi * 2) + (y0 * 0.004)));
      final yBase = y0 + wave * amp;

      path.moveTo(0, yBase);
      path.cubicTo(
        size.width * 0.33,
        yBase - amp * 0.9,
        size.width * 0.66,
        yBase + amp * 0.9,
        size.width,
        yBase,
      );
      path.lineTo(size.width, yBase + thickness);
      path.cubicTo(
        size.width * 0.66,
        yBase + thickness + amp * 0.9,
        size.width * 0.33,
        yBase + thickness - amp * 0.9,
        0,
        yBase + thickness,
      );
      path.close();
      return path;
    }

    canvas.drawPath(
      ribbon(size.height * 0.30, 16, 34),
      ribbonPaint,
    );
    canvas.drawPath(
      ribbon(size.height * 0.62, 14, 28),
      ribbonPaint..color = AppColors.green.withOpacity(0.07),
    );

    // A few moving accent dots to make motion unmistakable.
    final dotPaint = Paint()..color = AppColors.accentOrange.withOpacity(0.18);
    for (var i = 0; i < 6; i++) {
      final p = (t + i * 0.14) % 1.0;
      final x = size.width * p;
      final y = size.height * (0.25 + 0.5 * math.sin((p * math.pi * 2) + i));
      canvas.drawCircle(Offset(x, y), 6, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _ConnectorPainter oldDelegate) {
    return oldDelegate.t != t;
  }
}

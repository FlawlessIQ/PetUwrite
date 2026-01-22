import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../ui/components/connector_visual.dart';

class LottieDebugPage extends StatefulWidget {
  const LottieDebugPage({super.key});

  @override
  State<LottieDebugPage> createState() => _LottieDebugPageState();
}

class _LottieDebugPageState extends State<LottieDebugPage>
    with SingleTickerProviderStateMixin {
  String _status = 'Loading…';
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Lottie Debug')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _status,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'If Lottie is blank on web, we now render an animated fallback connector.\n'
                  'If you want to retry Lottie on web, run with CanvasKit:\n'
                  '  flutter run -d chrome --no-web-resources-cdn --web-renderer canvaskit',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white.withOpacity(0.25)),
                  ),
                  child: AspectRatio(
                    aspectRatio: 3 / 4,
                    child: Lottie.asset(
                      'assets/animations/clovara_bg_lottie.json',
                      fit: BoxFit.contain,
                      controller: _controller,
                      animate: false,
                      frameRate: FrameRate.max,
                      options: LottieOptions(enableMergePaths: true),
                      onLoaded: (composition) {
                        _controller
                          ..duration = composition.duration
                          ..repeat();
                        setState(() {
                          _status =
                              'Loaded + playing. bounds=${composition.bounds} duration=${composition.duration}';
                        });
                      },
                      errorBuilder: (context, error, stackTrace) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          setState(() {
                            _status = 'ERROR: $error';
                          });
                        });
                        return const Center(
                          child: Text(
                            'Lottie failed to render',
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Animated fallback connector (should always move on web):',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                const ConnectorVisual(height: 160),
                const SizedBox(height: 16),
                const Text(
                  'If you see the animation here, the renderer works and the homepage background is just too subtle/covered.\n'
                  'If you still do not see it here, the JSON isn\'t rendering on this platform/renderer and we should switch to a video (WebM/MP4) fallback for web.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

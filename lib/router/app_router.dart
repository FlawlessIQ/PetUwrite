import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_gate.dart';
import '../auth/login_screen.dart';
import '../pages/article_detail_page.dart';
import '../pages/coverage_page.dart';
import '../pages/faq_page.dart';
import '../pages/home_page.dart';
import '../pages/how_it_works_page.dart';
import '../pages/learn_page.dart';
import '../screens/auth_required_checkout.dart';
import '../screens/conversational_quote_flow.dart';
import '../ui/components/app_shell.dart';
import '../ui/tokens.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

GoRouter createAppRouter() {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) {
          // Background layer for all marketing pages
          // Debug controls (handy for environments where the background is too subtle)
          // Examples:
          //  - /?bgDebug=1
          //  - /?bgOpacity=0.6
          //  - /?bgTint=1
          final bgDebug = state.uri.queryParameters['bgDebug'] == '1';
          final bgTint = state.uri.queryParameters['bgTint'] == '1';
          final bgOpacityRaw = state.uri.queryParameters['bgOpacity'];
          // Make the background noticeably present by default.
          final bgOpacity = (double.tryParse(bgOpacityRaw ?? '') ?? 0.8).clamp(
            0.0,
            1.0,
          );
          return AppShell(
            background: _HomeBackdrop(
              debug: bgDebug,
              tint: bgTint,
              opacity: bgOpacity,
            ),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HomePage()),
          ),
          GoRoute(
            path: '/coverage',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: CoveragePage()),
          ),
          GoRoute(
            path: '/how-it-works',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: HowItWorksPage()),
          ),
          GoRoute(
            path: '/learn',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: LearnPage()),
            routes: [
              GoRoute(
                path: ':slug',
                pageBuilder: (context, state) {
                  final slug = state.pathParameters['slug'] ?? 'article';
                  return NoTransitionPage(child: ArticleDetailPage(slug: slug));
                },
              ),
            ],
          ),
          GoRoute(
            path: '/faq',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: FaqPage()),
          ),
        ],
      ),

      // App flows (keep existing screens working)
      GoRoute(
        path: '/conversational-quote',
        builder: (context, state) => const ConversationalQuoteFlow(),
      ),

      // Alias /quote => existing quote start flow
      GoRoute(
        path: '/quote',
        redirect: (context, state) => '/conversational-quote',
      ),

      // Auth
      GoRoute(
        path: '/sign-in',
        builder: (context, state) => const LoginScreen(),
      ),

      // Checkout (needs extra)
      GoRoute(
        path: '/checkout',
        builder: (context, state) {
          final extra = state.extra;
          if (extra is Map<String, dynamic>) {
            if (extra.containsKey('pet') && extra.containsKey('selectedPlan')) {
              return AuthRequiredCheckout(
                pet: extra['pet'],
                selectedPlan: extra['selectedPlan'],
                underwritingCaseId: extra['underwritingCaseId']?.toString(),
                exclusions: extra['exclusions'] is List
                    ? (extra['exclusions'] as List)
                    : null,
                underwritingSnapshot: (extra['underwritingSnapshot'] as Map?)
                    ?.cast<String, dynamic>(),
              );
            }
          }
          return const _MissingCheckoutArgs();
        },
      ),

      // Keep existing AuthGate behavior available (optional deep link)
      GoRoute(path: '/app', builder: (context, state) => const AuthGate()),
    ],
  );
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop({
    required this.debug,
    required this.tint,
    required this.opacity,
  });

  final bool debug;
  final bool tint;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final tintStrength = (tint ? 0.42 : 0.32) * opacity;
    return IgnorePointer(
      child: Stack(
        children: [
          // Base color so the page reads consistently.
          Positioned.fill(
            child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
          ),
          Positioned.fill(
            child: Opacity(
              // Default is subtle; can be overridden via ?bgOpacity=...
              opacity: opacity,
              child: RepaintBoundary(
                child: _Tintable(
                  enabled: tint,
                  color: primary,
                  child: const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: AppColors.auroraGradient,
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Dark green wash (this is the primary "tint" the user wants).
          Positioned.fill(
            child: ColoredBox(
              color: AppColors.deepGreen.withOpacity(
                tintStrength.clamp(0.0, 0.75),
              ),
            ),
          ),

          // Soft glow blobs (helps the background remain noticeable behind white panels).
          Positioned.fill(
            child: Opacity(
              opacity: (opacity * 0.75).clamp(0.0, 1.0),
              child: Stack(
                children: [
                  Positioned(
                    left: -120,
                    top: 80,
                    child: _GlowBlob(
                      size: 420,
                      color: primary.withOpacity(0.10),
                    ),
                  ),
                  Positioned(
                    right: -140,
                    top: 420,
                    child: _GlowBlob(
                      size: 520,
                      color: AppColors.accentOrange.withOpacity(0.08),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Diagonal slabs to make the background read (even without Lottie).
          Positioned.fill(
            child: Opacity(
              opacity: (opacity * 0.75).clamp(0.0, 1.0),
              child: Transform.rotate(
                angle: -0.12,
                child: Align(
                  alignment: Alignment.center,
                  child: FractionallySizedBox(
                    widthFactor: 1.4,
                    child: Column(
                      children: [
                        const Spacer(flex: 2),
                        Expanded(
                          flex: 2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: AppColors.surface3.withOpacity(0.95),
                              borderRadius: BorderRadius.circular(48),
                            ),
                          ),
                        ),
                        const Spacer(flex: 3),
                        Expanded(
                          flex: 2,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: primary.withOpacity(0.085),
                              borderRadius: BorderRadius.circular(48),
                            ),
                          ),
                        ),
                        const Spacer(flex: 2),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Subtle repeating stripes (always on) so the background reads.
          // Kept above slabs so it's still visible around panels.
          Positioned.fill(
            child: Opacity(
              opacity: (opacity * 0.55).clamp(0.0, 1.0),
              child: const _SubtleStripes(),
            ),
          ),

          // Gentle wash to keep it subtle and insurance-grade.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    // Keep this very light; heavier values can completely mask the animation.
                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.18),
                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.04),
                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.18),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          if (debug) const Positioned.fill(child: _BgDebugOverlay()),
        ],
      ),
    );
  }
}

class _Tintable extends StatelessWidget {
  const _Tintable({
    required this.enabled,
    required this.color,
    required this.child,
  });

  final bool enabled;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return ColorFiltered(
      // Soft tint for debugging; should not collapse everything into dark green.
      colorFilter: ColorFilter.mode(
        color.withOpacity(0.28),
        BlendMode.softLight,
      ),
      child: child,
    );
  }
}

class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 90, spreadRadius: 50)],
      ),
    );
  }
}

class _SubtleStripes extends StatelessWidget {
  const _SubtleStripes();

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          tileMode: TileMode.repeated,
          colors: [
            Colors.transparent,
            Colors.transparent,
            primary.withOpacity(0.22),
            primary.withOpacity(0.22),
          ],
          stops: const [0.0, 0.46, 0.46, 0.58],
        ),
      ),
    );
  }
}

class _BgDebugOverlay extends StatelessWidget {
  const _BgDebugOverlay();

  @override
  Widget build(BuildContext context) {
    // Repeated diagonal stripes to prove the background layer is visible.
    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                tileMode: TileMode.repeated,
                colors: [
                  Colors.transparent,
                  Colors.transparent,
                  Theme.of(context).colorScheme.primary.withOpacity(0.12),
                  Theme.of(context).colorScheme.primary.withOpacity(0.12),
                ],
                stops: const [0.0, 0.40, 0.40, 0.55],
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Text(
                  'BG DEBUG ON',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _MissingCheckoutArgs extends StatelessWidget {
  const _MissingCheckoutArgs();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Missing checkout details.')),
    );
  }
}

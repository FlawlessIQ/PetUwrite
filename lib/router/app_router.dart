import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_gate.dart';
import '../auth/login_screen.dart';
import '../pages/article_detail_page.dart';
import '../pages/contact_page.dart';
import '../pages/coverage_page.dart';
import '../pages/faq_page.dart';
import '../pages/home_page.dart';
import '../pages/how_it_works_page.dart';
import '../pages/learn_page.dart';
import '../pages/privacy_page.dart';
import '../pages/terms_page.dart';
import '../screens/auth_required_checkout.dart';
import '../screens/conversational_quote_flow.dart';
import '../ui/components/app_shell.dart';
import '../ui/tokens.dart';
import '../utils/marketing_site_redirect.dart';

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
          final bgOpacityRaw = state.uri.queryParameters['bgOpacity'];
          // Make the background noticeably present by default.
          final bgOpacity = (double.tryParse(bgOpacityRaw ?? '') ?? 0.8).clamp(
            0.0,
            1.0,
          );
          return AppShell(
            background: _HomeBackdrop(debug: bgDebug, opacity: bgOpacity),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                _legacyMarketingPage(const HomePage(), marketingPath: '/'),
          ),
          GoRoute(
            path: '/coverage',
            pageBuilder: (context, state) => _legacyMarketingPage(
              const CoveragePage(),
              marketingPath: '/coverage',
            ),
          ),
          GoRoute(
            path: '/how-it-works',
            pageBuilder: (context, state) => _legacyMarketingPage(
              const HowItWorksPage(),
              marketingPath: '/how-it-works',
            ),
          ),
          GoRoute(
            path: '/learn',
            pageBuilder: (context, state) =>
                _legacyMarketingPage(const LearnPage(), marketingPath: '/'),
            routes: [
              GoRoute(
                path: ':slug',
                pageBuilder: (context, state) {
                  final slug = state.pathParameters['slug'] ?? 'article';
                  return _legacyMarketingPage(
                    ArticleDetailPage(slug: slug),
                    marketingPath: '/',
                  );
                },
              ),
            ],
          ),
          GoRoute(
            path: '/faq',
            pageBuilder: (context, state) =>
                _legacyMarketingPage(const FaqPage(), marketingPath: '/'),
          ),
          GoRoute(
            path: '/privacy',
            pageBuilder: (context, state) => _legacyMarketingPage(
              const PrivacyPage(),
              marketingPath: '/privacy',
            ),
          ),
          GoRoute(
            path: '/terms',
            pageBuilder: (context, state) => _legacyMarketingPage(
              const TermsPage(),
              marketingPath: '/terms',
            ),
          ),
          GoRoute(
            path: '/contact',
            pageBuilder: (context, state) =>
                _legacyMarketingPage(const ContactPage(), marketingPath: '/'),
          ),
        ],
      ),

      // App flows (keep existing screens working)
      GoRoute(
        path: '/conversational-quote',
        builder: (context, state) {
          final extra = state.extra;
          final restorePendingDraft =
              extra is Map<String, dynamic> &&
              extra['restorePendingDraft'] == true;
          return ConversationalQuoteFlow(
            restorePendingDraft: restorePendingDraft,
          );
        },
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
      GoRoute(path: '/admin', builder: (context, state) => const AuthGate()),
      GoRoute(path: '/admin/', builder: (context, state) => const AuthGate()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: '/dashboard/',
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: '/app/admin',
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: '/app/admin/',
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: '/app/dashboard',
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: '/app/dashboard/',
        builder: (context, state) => const AuthGate(),
      ),
      GoRoute(
        path: '/app/sign-in',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/app/sign-in/',
        builder: (context, state) => const LoginScreen(),
      ),
    ],
  );
}

Page<dynamic> _legacyMarketingPage(
  Widget child, {
  required String marketingPath,
}) {
  if (isRunningUnderAppMount()) {
    return NoTransitionPage(child: _MarketingSiteRedirect(path: marketingPath));
  }
  return NoTransitionPage(child: child);
}

class _MarketingSiteRedirect extends StatefulWidget {
  final String path;

  const _MarketingSiteRedirect({required this.path});

  @override
  State<_MarketingSiteRedirect> createState() => _MarketingSiteRedirectState();
}

class _MarketingSiteRedirectState extends State<_MarketingSiteRedirect> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      redirectToMarketingSite(path: widget.path);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}

class _HomeBackdrop extends StatelessWidget {
  const _HomeBackdrop({required this.debug, required this.opacity});

  final bool debug;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: (opacity * 0.7).clamp(0.0, 1.0),
              child: const DecoratedBox(
                decoration: BoxDecoration(gradient: AppColors.auroraGradient),
              ),
            ),
          ),
          Positioned.fill(
            child: Opacity(
              opacity: (opacity * 0.55).clamp(0.0, 1.0),
              child: Stack(
                children: [
                  Positioned(
                    left: -140,
                    top: 10,
                    child: _GlowBlob(
                      size: 360,
                      color: AppColors.signalBlue.withOpacity(0.16),
                    ),
                  ),
                  Positioned(
                    right: -120,
                    top: 260,
                    child: _GlowBlob(
                      size: 340,
                      color: AppColors.accentOrange.withOpacity(0.08),
                    ),
                  ),
                  Positioned(
                    left: 220,
                    top: 560,
                    child: _GlowBlob(
                      size: 300,
                      color: AppColors.mint.withOpacity(0.16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.08),
                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.01),
                    Theme.of(context).scaffoldBackgroundColor.withOpacity(0.10),
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

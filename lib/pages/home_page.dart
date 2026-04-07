// Home page — premium insurance landing
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../services/user_session_service.dart';
import '../ui/components/max_width.dart';
import '../ui/components/buttons.dart';
import '../ui/components/section.dart';
import '../ui/tokens.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── Hero ──
        Section(
          verticalPadding: 20,
          child: const MaxWidth(child: _HeroSection()),
        ),
        // ── Trust bar ──
        Section(
          verticalPadding: 0,
          child: const MaxWidth(child: _TrustBar()),
        ),
        // ── How Clovara removes the confusion ──
        Section(
          verticalPadding: 28,
          child: const MaxWidth(child: _HowItWorksSection()),
        ),
        // ── Why Clovara is different ──
        Section(
          backgroundColor: AppColors.surface4,
          verticalPadding: 32,
          child: const MaxWidth(child: _WhyDifferentSection()),
        ),
        // ── Mid-page CTA ──
        Section(
          verticalPadding: 28,
          child: const MaxWidth(child: _MidCta()),
        ),
        // ── Coverage highlights ──
        Section(
          backgroundColor: AppColors.surface2,
          verticalPadding: 28,
          child: const MaxWidth(child: _CoverageSection()),
        ),
        // ── Trust / credibility ──
        Section(
          verticalPadding: 28,
          child: const MaxWidth(child: _CredibilitySection()),
        ),
        // ── Closing CTA ──
        const Section(
          backgroundColor: AppColors.surface2,
          verticalPadding: 24,
          child: MaxWidth(maxWidth: 1120, child: _ClosingCta()),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HERO
// ─────────────────────────────────────────────────────────────
class _HeroSection extends StatefulWidget {
  const _HeroSection();

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {
  static const _maxHeroWidth = 1120.0;
  bool _hasPendingQuote = false;

  @override
  void initState() {
    super.initState();
    _checkPendingQuote();
  }

  Future<void> _checkPendingQuote() async {
    final pending = await UserSessionService().getPendingQuote();
    if (mounted && pending != null && pending.isNotEmpty) {
      setState(() => _hasPendingQuote = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxHeroWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final isMobile = w < 780;
            final isDesktop = w >= 1040;

            final headingStyle = Theme.of(context).textTheme.displaySmall!
                .copyWith(
                  fontSize: isDesktop ? 52 : (isMobile ? 36 : 44),
                  height: 1.0,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepGreen,
                  letterSpacing: -1.4,
                );

            final bodyStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: AppColors.text,
              height: 1.6,
              fontSize: isDesktop ? 18 : 16,
            );

            final cta = LayoutBuilder(
              builder: (context, c) {
                final fullWidth = c.maxWidth < 520;
                return Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: fullWidth ? double.infinity : null,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: fullWidth ? double.infinity : 240,
                          height: 56,
                          child: PrimaryButton(
                            label: 'See your price',
                            icon: Icons.arrow_forward_rounded,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            onPressed: () => context.go('/quote'),
                          ),
                        ),
                        SizedBox(
                          width: fullWidth ? double.infinity : 220,
                          height: 56,
                          child: SecondaryButton(
                            label: 'How it works',
                            icon: Icons.play_circle_outline_rounded,
                            onPressed: () => context.go('/how-it-works'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );

            final microcopy = Text(
              'Takes 2 minutes · No commitment · Cancel anytime',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            );

            final left = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.green.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'PET INSURANCE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: AppColors.green,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Pet insurance that tells you\nexactly what\u2019s covered.',
                    style: headingStyle,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Transparent pricing, plain-language plans, and fast digital claims. '
                    'See your options in minutes — no phone calls, no fine print.',
                    style: bodyStyle,
                  ),
                  const SizedBox(height: 24),
                  cta,
                  const SizedBox(height: 12),
                  microcopy,
                  if (_hasPendingQuote) ...[                    const SizedBox(height: 14),
                    GestureDetector(
                      onTap: () => context.go('/quote'),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.replay_rounded,
                              size: 16,
                              color: AppColors.green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Continue your quote',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: AppColors.green,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Icons.arrow_forward_rounded,
                              size: 14,
                              color: AppColors.green,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  const _HeroTrustBar(),
                ],
              ),
            );

            final image = ClipRRect(
              borderRadius: AppRadii.br16,
              child: Container(
                color: AppColors.surface2,
                child: AspectRatio(
                  aspectRatio: 16 / 11,
                  child: Image.asset(
                    'assets/images/HOMEPAGE IMAGE.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            );

            final top = isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [left, const SizedBox(height: 28), image],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 11, child: left),
                      const SizedBox(width: 32),
                      Expanded(flex: 9, child: image),
                    ],
                  );

            return Padding(
              padding: EdgeInsets.all(isMobile ? 20 : 0),
              child: top,
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// EYEBROW
// ─────────────────────────────────────────────────────────────
class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall!.copyWith(
        color: AppColors.green,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
        fontSize: 12,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HERO TRUST BAR (inline benefits under CTA)
// ─────────────────────────────────────────────────────────────
class _HeroTrustBar extends StatelessWidget {
  const _HeroTrustBar();

  static const _items = [
    (Icons.verified_outlined, 'Transparent pricing'),
    (Icons.local_hospital_outlined, 'Any licensed vet'),
    (Icons.speed_outlined, 'Claims in minutes'),
    (Icons.shield_outlined, 'No hidden fees'),
  ];

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall!.copyWith(
      color: AppColors.text,
      fontWeight: FontWeight.w700,
      fontSize: 13,
    );
    return Wrap(
      spacing: 20,
      runSpacing: 8,
      children: [
        for (final (icon, label) in _items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.green),
              const SizedBox(width: 6),
              Text(label, style: style),
            ],
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// TRUST BAR (full-width strip below hero)
// ─────────────────────────────────────────────────────────────
class _TrustBar extends StatelessWidget {
  const _TrustBar();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadii.br12,
        border: Border.all(color: AppColors.border),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final items = [
            _TrustBarItem(icon: Icons.pets_rounded, label: 'Dogs & cats'),
            _TrustBarItem(icon: Icons.verified_user_outlined, label: 'Expert-built plans'),
            _TrustBarItem(icon: Icons.access_time_rounded, label: 'Quote in 2 min'),
            _TrustBarItem(icon: Icons.thumb_up_alt_outlined, label: 'No commitments'),
          ];

          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 32,
            runSpacing: 12,
            children: items,
          );
        },
      ),
    );
  }
}

class _TrustBarItem extends StatelessWidget {
  const _TrustBarItem({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 18, color: AppColors.green),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: AppColors.text,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// HOW IT WORKS
// ─────────────────────────────────────────────────────────────
class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionEyebrow(label: 'How it works'),
        const SizedBox(height: 12),
        Text(
          'How Clovara removes the confusion',
          style: Theme.of(context).textTheme.headlineLarge!,
        ),
        const SizedBox(height: 8),
        Text(
          'Three steps. No jargon. Full control.',
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 32),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 760;
            final cards = [
              _HowStep(
                number: '01',
                title: 'See your price instantly',
                body: 'Answer a few questions about your pet. Get a clear quote with no hidden costs — adjust deductible, reimbursement, and limits yourself.',
                icon: Icons.calculate_outlined,
              ),
              _HowStep(
                number: '02',
                title: 'Visit any licensed vet',
                body: 'No networks to navigate. No pre-approvals. Take your pet to the vet you already trust.',
                icon: Icons.local_hospital_outlined,
              ),
              _HowStep(
                number: '03',
                title: 'Submit claims digitally',
                body: 'Upload your invoice online. Track your claim in real time. Get reimbursed fast.',
                icon: Icons.receipt_long_outlined,
              ),
            ];

            if (stacked) {
              return Column(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    cards[i],
                    if (i < cards.length - 1) const SizedBox(height: 16),
                  ],
                ],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i < cards.length - 1) const SizedBox(width: 16),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({
    required this.number,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String number;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadii.br16,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 22, color: AppColors.deepGreen),
              ),
              const Spacer(),
              Text(
                number,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: AppColors.textSubtle,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: AppColors.deepGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// WHY CLOVARA IS DIFFERENT
// ─────────────────────────────────────────────────────────────
class _WhyDifferentSection extends StatelessWidget {
  const _WhyDifferentSection();

  @override
  Widget build(BuildContext context) {
    final headingStyle = Theme.of(context).textTheme.headlineLarge!.copyWith(
      color: AppColors.textOnDark,
    );
    final bodyStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(
      color: AppColors.textOnDark.withOpacity(0.72),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionEyebrow(label: 'Why Clovara'),
        const SizedBox(height: 12),
        Text('Why Clovara is different', style: headingStyle),
        const SizedBox(height: 8),
        Text('Built from scratch to fix what\u2019s broken in pet insurance.', style: bodyStyle),
        const SizedBox(height: 36),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 760;
            final items = [
              _DiffCard(
                icon: Icons.visibility_outlined,
                title: 'Transparent pricing',
                body: 'See exactly what you pay and what you get. No surprise exclusions, no gimmick introductory rates.',
              ),
              _DiffCard(
                icon: Icons.language_outlined,
                title: 'No networks',
                body: 'Visit any licensed vet, specialist, or emergency clinic. Your pet, your choice.',
              ),
              _DiffCard(
                icon: Icons.lightbulb_outline_rounded,
                title: 'Built for clarity',
                body: 'Plain-language policies, real-time claim tracking, and controls you can actually understand.',
              ),
            ];

            if (stacked) {
              return Column(
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    items[i],
                    if (i < items.length - 1) const SizedBox(height: 16),
                  ],
                ],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    Expanded(child: items[i]),
                    if (i < items.length - 1) const SizedBox(width: 16),
                  ],
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _DiffCard extends StatelessWidget {
  const _DiffCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: AppRadii.br16,
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 22, color: AppColors.mint),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: AppColors.textOnDark,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: AppColors.textOnDark.withOpacity(0.68),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MID-PAGE CTA
// ─────────────────────────────────────────────────────────────
class _MidCta extends StatelessWidget {
  const _MidCta();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 32),
      decoration: BoxDecoration(
        gradient: AppColors.ctaGradient,
        borderRadius: AppRadii.br20,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 640;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to see what coverage looks like?',
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Takes 2 minutes. No commitment required.',
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Colors.white.withOpacity(0.78),
                ),
              ),
            ],
          );

          final button = ElevatedButton(
            onPressed: () => context.go('/quote'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.deepGreen,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
              shape: const RoundedRectangleBorder(borderRadius: AppRadii.br12),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
              ),
            ),
            child: const Text('See your price'),
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [copy, const SizedBox(height: 20), button],
            );
          }

          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              button,
            ],
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// COVERAGE HIGHLIGHTS
// ─────────────────────────────────────────────────────────────
class _CoverageSection extends StatelessWidget {
  const _CoverageSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionEyebrow(label: 'Coverage'),
        const SizedBox(height: 12),
        Text(
          'Coverage built around real vet bills',
          style: Theme.of(context).textTheme.headlineLarge!,
        ),
        const SizedBox(height: 8),
        Text(
          'See the major categories before you choose a plan.',
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 760;
            final items = [
              _CoverageTile(
                icon: Icons.medical_services_outlined,
                title: 'Accidents',
                body: 'Broken bones, bite wounds, swallowed objects, and other emergencies.',
              ),
              _CoverageTile(
                icon: Icons.sick_outlined,
                title: 'Illnesses',
                body: 'Infections, chronic conditions, cancer, and more serious diagnoses.',
              ),
              _CoverageTile(
                icon: Icons.local_hospital_outlined,
                title: 'Tests & surgery',
                body: 'Diagnostics, procedures, hospital stays, and follow-up treatment.',
              ),
            ];

            if (stacked) {
              return Column(
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    items[i],
                    if (i < items.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    Expanded(child: items[i]),
                    if (i < items.length - 1) const SizedBox(width: 12),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        SecondaryButton(
          label: 'See full coverage details',
          icon: Icons.arrow_forward_rounded,
          onPressed: () => context.go('/coverage'),
        ),
      ],
    );
  }
}

class _CoverageTile extends StatelessWidget {
  const _CoverageTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadii.br16,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.deepGreen),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: AppColors.deepGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CREDIBILITY / TRUST
// ─────────────────────────────────────────────────────────────
class _CredibilitySection extends StatelessWidget {
  const _CredibilitySection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionEyebrow(label: 'Trust'),
        const SizedBox(height: 12),
        Text(
          'Built by insurance and technology experts',
          style: Theme.of(context).textTheme.headlineLarge!,
        ),
        const SizedBox(height: 8),
        Text(
          'Clovara was designed from the ground up with clarity, fairness, and modern technology at its core.',
          style: Theme.of(context).textTheme.bodyLarge!.copyWith(
            color: AppColors.textMuted,
          ),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 760;
            final items = [
              _CredItem(
                icon: Icons.school_outlined,
                title: 'Expert-built',
                body: 'Designed by insurance professionals who understand underwriting, claims, and compliance.',
              ),
              _CredItem(
                icon: Icons.lock_outline_rounded,
                title: 'Secure & private',
                body: 'Your data is encrypted and never sold. We follow industry-standard security practices.',
              ),
              _CredItem(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Real support',
                body: 'Questions? Our team responds quickly — no chatbots, no runaround.',
              ),
            ];

            if (stacked) {
              return Column(
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    items[i],
                    if (i < items.length - 1) const SizedBox(height: 12),
                  ],
                ],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < items.length; i++) ...[
                    Expanded(child: items[i]),
                    if (i < items.length - 1) const SizedBox(width: 12),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 28),
        // Testimonial placeholder
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: AppRadii.br16,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              const Icon(Icons.format_quote_rounded, size: 32, color: AppColors.textSubtle),
              const SizedBox(height: 12),
              Text(
                '\u201CCustomer testimonials coming soon.\u201D',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: AppColors.textSubtle,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'We\u2019re collecting feedback from early users.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: AppColors.textSubtle,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CredItem extends StatelessWidget {
  const _CredItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadii.br16,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 28, color: AppColors.green),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: AppColors.deepGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: AppColors.textMuted,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// CLOSING CTA
// ─────────────────────────────────────────────────────────────
class _ClosingCta extends StatelessWidget {
  const _ClosingCta();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      decoration: BoxDecoration(
        color: AppColors.deepGreen,
        borderRadius: AppRadii.br24,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 720;
          final copy = Column(
            crossAxisAlignment: stacked ? CrossAxisAlignment.center : CrossAxisAlignment.start,
            children: [
              Text(
                'Get your price in minutes.',
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'See plan options for your dog or cat. No commitment — come back later if you need more time.',
                textAlign: stacked ? TextAlign.center : TextAlign.left,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Colors.white.withOpacity(0.78),
                ),
              ),
            ],
          );

          final actions = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: () => context.go('/quote'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.deepGreen,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 18),
                  shape: const RoundedRectangleBorder(borderRadius: AppRadii.br12),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                ),
                child: const Text('See your price'),
              ),
              const SizedBox(height: 8),
              Text(
                'Takes 2 minutes · No commitment',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Colors.white.withOpacity(0.56),
                  fontSize: 12,
                ),
              ),
            ],
          );

          if (stacked) {
            return Column(
              children: [copy, const SizedBox(height: 20), actions],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              actions,
            ],
          );
        },
      ),
    );
  }
}

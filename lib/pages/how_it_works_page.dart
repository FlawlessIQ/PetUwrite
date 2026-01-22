import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/buttons.dart';
import '../ui/components/gradient_border.dart';
import '../ui/components/badges.dart';
import '../ui/components/max_width.dart';
import '../ui/components/premium_card.dart';
import '../ui/components/section.dart';
import '../ui/components/section_break.dart';
import '../ui/tokens.dart';

class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Section(child: const MaxWidth(child: HowItWorksHero())),

        const SectionBreak(
          fromColor: AppColors.background,
          toColor: AppColors.surface2,
        ),

        Section(
          backgroundColor: AppColors.surface2,
          child: MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The process',
                  style: Theme.of(context).textTheme.headlineSmall!,
                ),
                const SizedBox(height: 8),
                Text(
                  'From getting a quote to receiving reimbursement.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge!.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final columns = w >= 1040 ? 3 : (w >= 760 ? 2 : 1);
                    final gap = 14.0;

                    const quoteCard = ProcessPhaseCard(
                      phaseTitle: 'Quote',
                      steps: [
                        ProcessStepModel(
                          number: 1,
                          title: 'Get a quote',
                          subtitle:
                              'Tell us about your pet and where you live.',
                        ),
                        ProcessStepModel(
                          number: 2,
                          title: 'Choose your plan',
                          subtitle:
                              'Select deductible, reimbursement %, and annual limit.',
                        ),
                      ],
                    );

                    const enrollCard = ProcessPhaseCard(
                      phaseTitle: 'Enroll',
                      steps: [
                        ProcessStepModel(
                          number: 3,
                          title: 'Start coverage',
                          subtitle:
                              'Complete checkout; coverage begins after waiting periods.',
                        ),
                      ],
                    );

                    const claimCard = ProcessPhaseCard(
                      phaseTitle: 'Claim',
                      steps: [
                        ProcessStepModel(
                          number: 4,
                          title: 'Visit any licensed vet',
                          subtitle: 'Pay the vet at time of service.',
                        ),
                        ProcessStepModel(
                          number: 5,
                          title: 'Submit a claim',
                          subtitle:
                              'Upload your invoice and supporting medical notes.',
                        ),
                        ProcessStepModel(
                          number: 6,
                          title: 'Get reimbursed',
                          subtitle:
                              'We review and reimburse according to your plan settings.',
                        ),
                      ],
                    );

                    // Mobile/narrow web: natural-height cards (no empty space).
                    if (columns == 1) {
                      return const Column(
                        children: [
                          ProcessPhaseCard(
                            phaseTitle: 'Quote',
                            compact: true,
                            steps: [
                              ProcessStepModel(
                                number: 1,
                                title: 'Get a quote',
                                subtitle:
                                    'Tell us about your pet and where you live.',
                              ),
                              ProcessStepModel(
                                number: 2,
                                title: 'Choose your plan',
                                subtitle:
                                    'Select deductible, reimbursement %, and annual limit.',
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          ProcessPhaseCard(
                            phaseTitle: 'Enroll',
                            compact: true,
                            steps: [
                              ProcessStepModel(
                                number: 3,
                                title: 'Start coverage',
                                subtitle:
                                    'Complete checkout; coverage begins after waiting periods.',
                              ),
                            ],
                          ),
                          SizedBox(height: 12),
                          ProcessPhaseCard(
                            phaseTitle: 'Claim',
                            compact: true,
                            steps: [
                              ProcessStepModel(
                                number: 4,
                                title: 'Visit any licensed vet',
                                subtitle: 'Pay the vet at time of service.',
                              ),
                              ProcessStepModel(
                                number: 5,
                                title: 'Submit a claim',
                                subtitle:
                                    'Upload your invoice and supporting medical notes.',
                              ),
                              ProcessStepModel(
                                number: 6,
                                title: 'Get reimbursed',
                                subtitle:
                                    'We review and reimburse according to your plan settings.',
                              ),
                            ],
                          ),
                        ],
                      );
                    }

                    // Tablet/desktop: fixed-height cards for perfect alignment.
                    final itemWidth = (w - (gap * (columns - 1))) / columns;
                    final cardHeight = columns == 2 ? 332.0 : 320.0;

                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          height: cardHeight,
                          child: quoteCard,
                        ),
                        SizedBox(
                          width: itemWidth,
                          height: cardHeight,
                          child: enrollCard,
                        ),
                        SizedBox(
                          width: itemWidth,
                          height: cardHeight,
                          child: claimCard,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                const SizedBox(
                  width: double.infinity,
                  child: ClaimRequirementsCard(),
                ),
              ],
            ),
          ),
        ),

        const SectionBreak(
          fromColor: AppColors.surface2,
          toColor: AppColors.background,
          flip: true,
        ),

        Section(
          child: MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Important to know',
                  style: Theme.of(context).textTheme.headlineSmall!,
                ),
                const SizedBox(height: 14),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final w = constraints.maxWidth;
                    final isMobile = w < 720;
                    final columns = w >= 1040 ? 3 : (w >= 760 ? 2 : 1);
                    final gap = 14.0;

                    if (isMobile) {
                      return const Column(
                        children: [
                          _ImportantKnowCard(
                            icon: Icons.schedule,
                            title: 'Reimbursement takes time',
                            body:
                                'Claims are reviewed against policy terms. Processing is typically 3–7 business days.',
                          ),
                          SizedBox(height: 12),
                          _ImportantKnowCard(
                            icon: Icons.fact_check_outlined,
                            title: 'Pre-existing conditions are not covered',
                            body:
                                'Any condition showing signs before coverage begins (or during waiting periods) is considered pre-existing.',
                          ),
                          SizedBox(height: 12),
                          _ImportantKnowCard(
                            icon: Icons.payments_outlined,
                            title: 'You pay the vet directly',
                            body:
                                'Insurance reimburses you after care. There are no provider networks to worry about.',
                          ),
                        ],
                      );
                    }

                    final itemWidth = (w - (gap * (columns - 1))) / columns;
                    final cardHeight = columns == 3 ? 150.0 : 162.0;

                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        SizedBox(
                          width: itemWidth,
                          height: cardHeight,
                          child: const _ImportantKnowCard(
                            icon: Icons.schedule,
                            title: 'Reimbursement takes time',
                            body:
                                'Claims are reviewed against policy terms. Processing is typically 3–7 business days.',
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          height: cardHeight,
                          child: const _ImportantKnowCard(
                            icon: Icons.fact_check_outlined,
                            title: 'Pre-existing conditions are not covered',
                            body:
                                'Any condition showing signs before coverage begins (or during waiting periods) is considered pre-existing.',
                          ),
                        ),
                        SizedBox(
                          width: itemWidth,
                          height: cardHeight,
                          child: const _ImportantKnowCard(
                            icon: Icons.payments_outlined,
                            title: 'You pay the vet directly',
                            body:
                                'Insurance reimburses you after care. There are no provider networks to worry about.',
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 560;

                    final label = Text(
                      'Want more details?',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    );

                    final link = TextLink(
                      label: 'Visit the education hub',
                      onTap: () => context.go('/learn'),
                    );

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [label, const SizedBox(height: 6), link],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: label),
                        link,
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        Section(
          child: MaxWidth(
            child: SizedBox(
              width: double.infinity,
              child: GradientBorder(
                radius: AppRadii.br24,
                child: PremiumCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 28,
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final stacked = constraints.maxWidth < 720;

                      final heading = Text(
                        'Ready to get started?',
                        style: Theme.of(context).textTheme.headlineSmall!,
                      );

                      final body = Text(
                        'Start a quote and we\'ll walk you through plan settings in context—deductible, reimbursement %, and annual limits.',
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: AppColors.textMuted,
                          height: 1.45,
                        ),
                      );

                      final copy = Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [heading, const SizedBox(height: 8), body],
                      );

                      final action = SizedBox(
                        width: stacked ? double.infinity : 240,
                        height: 52,
                        child: PrimaryButton(
                          label: 'Get a quote',
                          icon: Icons.pets,
                          onPressed: () => context.go('/quote'),
                        ),
                      );

                      if (stacked) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [copy, const SizedBox(height: 14), action],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: copy),
                          const SizedBox(width: 16),
                          action,
                        ],
                      );
                    },
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

@immutable
class ProcessStepModel {
  const ProcessStepModel({
    required this.number,
    required this.title,
    required this.subtitle,
  });

  final int number;
  final String title;
  final String subtitle;
}

class ProcessPhaseCard extends StatelessWidget {
  const ProcessPhaseCard({
    super.key,
    required this.phaseTitle,
    required this.steps,
    this.compact = false,
  });

  final String phaseTitle;
  final List<ProcessStepModel> steps;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.w900,
      color: AppColors.deepGreen,
      height: 1.1,
    );

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Icon(
                  Icons.route_outlined,
                  size: 18,
                  color: AppColors.deepGreen,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  phaseTitle,
                  style: titleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (compact)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < steps.length; i++)
                  ProcessStep(step: steps[i], isLast: i == steps.length - 1),
              ],
            )
          else
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < steps.length; i++)
                    ProcessStep(step: steps[i], isLast: i == steps.length - 1),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ProcessStep extends StatelessWidget {
  const ProcessStep({super.key, required this.step, required this.isLast});

  final ProcessStepModel step;
  final bool isLast;

  static const _badgeSize = 26.0;
  static const _gutterWidth = 34.0;
  static const _lineWidth = 2.0;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall!.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.text,
      height: 1.15,
    );

    final subtitleStyle = Theme.of(
      context,
    ).textTheme.bodySmall!.copyWith(color: AppColors.textMuted, height: 1.3);

    final badge = Container(
      height: _badgeSize,
      width: _badgeSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surface3,
        borderRadius: BorderRadius.circular(_badgeSize / 2),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(
        step.number.toString(),
        style: Theme.of(context).textTheme.labelMedium!.copyWith(
          color: AppColors.deepGreen,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Stack(
        children: [
          if (!isLast)
            Positioned(
              left: (_badgeSize / 2) - (_lineWidth / 2),
              top: _badgeSize + 6,
              bottom: 0,
              child: Container(width: _lineWidth, color: AppColors.border),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _gutterWidth,
                child: Align(alignment: Alignment.topLeft, child: badge),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: titleStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      step.subtitle,
                      style: subtitleStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class ClaimRequirementsCard extends StatelessWidget {
  const ClaimRequirementsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.w900,
      color: AppColors.deepGreen,
    );

    final introStyle = Theme.of(
      context,
    ).textTheme.bodySmall!.copyWith(color: AppColors.textMuted, height: 1.45);

    return PremiumCard(
      showShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What you\'ll need for a claim', style: titleStyle),
          const SizedBox(height: 6),
          Text(
            'Depending on the claim, we may request the documents below to review and reimburse.',
            style: introStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          const _ClaimNeedRow(
            icon: Icons.receipt_long_outlined,
            title: 'Itemized invoice',
            body:
                'Shows what procedures/services were performed and what each cost.',
            showDivider: true,
          ),
          const _ClaimNeedRow(
            icon: Icons.folder_open_outlined,
            title: 'Medical records',
            body:
                'Sometimes needed for first-time claims to review pre-existing conditions.',
            showDivider: true,
          ),
          const _ClaimNeedRow(
            icon: Icons.account_balance_outlined,
            title: 'Direct deposit info',
            body: 'Optional, but fastest way to receive reimbursement.',
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _ImportantKnowCard extends StatelessWidget {
  const _ImportantKnowCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall!.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.deepGreen,
      height: 1.15,
    );

    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodySmall!.copyWith(color: AppColors.textMuted, height: 1.45);

    return PremiumCard(
      showShadow: false,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, size: 40),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: titleStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: bodyStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimNeedRow extends StatelessWidget {
  const _ClaimNeedRow({
    required this.icon,
    required this.title,
    required this.body,
    required this.showDivider,
  });

  final IconData icon;
  final String title;
  final String body;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall!.copyWith(
      fontWeight: FontWeight.w800,
      color: AppColors.deepGreen,
    );

    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodySmall!.copyWith(color: AppColors.textMuted, height: 1.45);

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: titleStyle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: bodyStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showDivider)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, thickness: 1, color: AppColors.border),
          ),
      ],
    );
  }
}

class HowItWorksHero extends StatelessWidget {
  const HowItWorksHero({super.key});

  static const _maxHeroWidth = 1200.0;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxHeroWidth),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final isMobile = w < 768;
            final isDesktop = w >= 1024;

            final outerPadding = EdgeInsets.all(isMobile ? 20 : 24);

            final headingStyle = Theme.of(context).textTheme.displaySmall!
                .copyWith(
                  fontSize: isDesktop ? 44 : 40,
                  height: 1.06,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepGreen,
                  letterSpacing: -0.5,
                );

            final bodyStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: AppColors.textMuted,
              height: 1.55,
            );

            final leftText = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('How pet insurance works', style: headingStyle),
                  const SizedBox(height: 12),
                  Text(
                    'See how coverage flows from quote to reimbursement—so you know exactly what to expect before you enroll.',
                    style: bodyStyle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );

            final phases = const _HeroPhaseRow(
              items: [
                _HeroPhase(
                  icon: Icons.tune,
                  title: 'Quote',
                  body: 'Customize plan settings.',
                ),
                _HeroPhase(
                  icon: Icons.verified_user_outlined,
                  title: 'Enroll',
                  body: 'Start coverage after waiting periods.',
                ),
                _HeroPhase(
                  icon: Icons.receipt_long_outlined,
                  title: 'Claim',
                  body: 'Get reimbursed for eligible vet bills.',
                ),
              ],
            );

            final cta = SizedBox(
              width: isMobile ? double.infinity : 260,
              height: 52,
              child: PrimaryButton(
                label: 'Get a quote',
                icon: Icons.pets,
                onPressed: () => context.go('/quote'),
              ),
            );

            final image = ClipRRect(
              borderRadius: AppRadii.br24,
              child: Container(
                color: AppColors.surface,
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.asset(
                    'assets/images/how it works.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            );

            final desktopLeft = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftText,
                const SizedBox(height: 18),
                phases,
                const SizedBox(height: 16),
                cta,
              ],
            );

            final content = isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      leftText,
                      const SizedBox(height: 18),
                      image,
                      const SizedBox(height: 18),
                      phases,
                      const SizedBox(height: 14),
                      cta,
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 11, child: desktopLeft),
                      const SizedBox(width: 24),
                      Expanded(flex: 9, child: image),
                    ],
                  );

            return Container(
              padding: outerPadding,
              decoration: BoxDecoration(
                color: AppColors.surface.withOpacity(0.92),
                borderRadius: AppRadii.br24,
                border: Border.all(color: AppColors.borderTint),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 24,
                    offset: Offset(0, 14),
                  ),
                ],
              ),
              child: content,
            );
          },
        ),
      ),
    );
  }
}

class _HeroPhase {
  const _HeroPhase({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _HeroPhaseRow extends StatelessWidget {
  const _HeroPhaseRow({required this.items});

  final List<_HeroPhase> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wrap = constraints.maxWidth < 520;

        final gap = wrap ? 10.0 : 12.0;
        final childWidth = wrap
            ? (constraints.maxWidth - gap) / 2
            : (constraints.maxWidth - (gap * (items.length - 1))) /
                  items.length;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: wrap ? childWidth : childWidth,
                child: _HeroPhaseChip(item: item),
              ),
          ],
        );
      },
    );
  }
}

class _HeroPhaseChip extends StatelessWidget {
  const _HeroPhaseChip({required this.item});

  final _HeroPhase item;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleSmall!.copyWith(
      color: AppColors.deepGreen,
      fontWeight: FontWeight.w800,
      height: 1.1,
    );

    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodySmall!.copyWith(color: AppColors.textMuted, height: 1.25);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadii.br16,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 32,
            width: 32,
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(item.icon, size: 18, color: AppColors.deepGreen),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: titleStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  item.body,
                  style: bodyStyle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

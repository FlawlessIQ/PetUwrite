import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/buttons.dart';
import '../ui/components/gradient_border.dart';
import '../ui/components/hero_stage.dart';
import '../ui/components/max_width.dart';
import '../ui/components/premium_card.dart';
import '../ui/components/section.dart';
import '../ui/components/section_break.dart';
import '../ui/tokens.dart';

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Section(
          child: MaxWidth(
            child: HeroStage(
              left: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _LegalEyebrow(label: 'Privacy'),
                    const SizedBox(height: 16),
                    Text(
                      'Privacy written for trust, not for loopholes.',
                      style: Theme.of(
                        context,
                      ).textTheme.displaySmall!.copyWith(fontSize: 42),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Clovara collects the information needed to price coverage, underwrite policies, process claims, and support your account. We do not treat privacy as an afterthought.',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              right: const _LegalSummaryCard(
                items: [
                  _LegalSummaryItem(
                    title: 'Why we collect data',
                    body:
                        'To quote, underwrite, bind, service, and review claims.',
                  ),
                  _LegalSummaryItem(
                    title: 'What we collect',
                    body:
                        'Owner details, pet details, billing data, and claim records.',
                  ),
                  _LegalSummaryItem(
                    title: 'How to ask questions',
                    body:
                        'Email legal@clovara.com for privacy or compliance requests.',
                  ),
                ],
              ),
            ),
          ),
        ),
        const SectionBreak(
          fromColor: AppColors.background,
          toColor: AppColors.surface2,
        ),
        Section(
          backgroundColor: AppColors.surface2,
          child: const MaxWidth(
            child: _LegalGrid(
              cards: [
                _LegalCard(
                  title: 'Information we collect',
                  body:
                      'We may collect contact details, policy application data, pet details, payment and billing records, uploaded documents, and claim-related information needed to service your policy.',
                ),
                _LegalCard(
                  title: 'How we use information',
                  body:
                      'We use data to generate quotes, determine eligibility, fulfill policy operations, support claims review, improve product quality, communicate with you, and satisfy legal obligations.',
                ),
                _LegalCard(
                  title: 'How long we keep it',
                  body:
                      'Retention varies based on insurance operations, legal requirements, dispute handling, fraud prevention, and recordkeeping obligations.',
                ),
                _LegalCard(
                  title: 'How to contact us',
                  body:
                      'For privacy questions, access requests, or compliance inquiries, contact legal@clovara.com.',
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
            child: GradientBorder(
              child: PremiumCard(
                showShadow: false,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 760;
                    final copy = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need the full legal context?',
                          style: Theme.of(context).textTheme.headlineSmall!,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'This page is a concise public summary for site visitors. Policyholders may also see additional disclosures during checkout and policy issuance.',
                          style: Theme.of(context).textTheme.bodyMedium!
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
                    );

                    final actions = Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        SecondaryButton(
                          label: 'Contact legal',
                          icon: Icons.gavel_rounded,
                          onPressed: () => context.go('/contact'),
                        ),
                        PrimaryButton(
                          label: 'See coverage',
                          icon: Icons.arrow_outward_rounded,
                          onPressed: () => context.go('/coverage'),
                        ),
                      ],
                    );

                    if (stacked) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [copy, const SizedBox(height: 14), actions],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: copy),
                        const SizedBox(width: 12),
                        actions,
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _LegalEyebrow extends StatelessWidget {
  const _LegalEyebrow({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.borderTint),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: AppColors.deepGreen,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LegalSummaryCard extends StatelessWidget {
  const _LegalSummaryCard({required this.items});

  final List<_LegalSummaryItem> items;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            Text(
              items[i].title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(items[i].body, style: Theme.of(context).textTheme.bodySmall),
            if (i != items.length - 1) const SizedBox(height: 14),
          ],
        ],
      ),
    );
  }
}

class _LegalSummaryItem {
  const _LegalSummaryItem({required this.title, required this.body});

  final String title;
  final String body;
}

class _LegalGrid extends StatelessWidget {
  const _LegalGrid({required this.cards});

  final List<Widget> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;
        if (stacked) {
          return Column(
            children: [
              for (int i = 0; i < cards.length; i++) ...[
                cards[i],
                if (i != cards.length - 1) const SizedBox(height: 14),
              ],
            ],
          );
        }

        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: cards
              .map(
                (card) => SizedBox(
                  width: (constraints.maxWidth - 16) / 2,
                  child: card,
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Text(
            body,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium!.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

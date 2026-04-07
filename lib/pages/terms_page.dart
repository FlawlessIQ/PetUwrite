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

class TermsPage extends StatelessWidget {
  const TermsPage({super.key});

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
                    const _TermsEyebrow(label: 'Terms'),
                    const SizedBox(height: 16),
                    Text(
                      'Clear expectations for using Clovara.',
                      style: Theme.of(
                        context,
                      ).textTheme.displaySmall!.copyWith(fontSize: 42),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'These public-facing terms summarize how Clovara quotes coverage, supports policyholders, handles platform use, and communicates important insurance disclosures.',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              right: const PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TermsItem(
                      title: 'Quotes are not a policy',
                      body:
                          'Coverage is not active until application, underwriting, payment, and policy issuance are complete.',
                    ),
                    SizedBox(height: 12),
                    _TermsItem(
                      title: 'Coverage is subject to policy terms',
                      body:
                          'Benefits, exclusions, waiting periods, and reimbursement are controlled by the issued policy.',
                    ),
                    SizedBox(height: 12),
                    _TermsItem(
                      title: 'Questions should be surfaced early',
                      body:
                          'We want customers to understand plan settings, eligibility, and claims expectations before purchase.',
                    ),
                  ],
                ),
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
          child: const MaxWidth(child: _TermsGrid()),
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
                          'Need help understanding a term before you buy?',
                          style: Theme.of(context).textTheme.headlineSmall!,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'The best investor and customer experiences both come from clarity. If something feels ambiguous, the FAQ, coverage page, and quote flow are the best next steps.',
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
                          label: 'Read FAQ',
                          icon: Icons.help_outline_rounded,
                          onPressed: () => context.go('/faq'),
                        ),
                        PrimaryButton(
                          label: 'Start a quote',
                          icon: Icons.arrow_outward_rounded,
                          onPressed: () => context.go('/quote'),
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

class _TermsEyebrow extends StatelessWidget {
  const _TermsEyebrow({required this.label});

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

class _TermsGrid extends StatelessWidget {
  const _TermsGrid();

  @override
  Widget build(BuildContext context) {
    const items = [
      _TermsItem(
        title: 'Using the platform',
        body:
            'You should provide accurate information when requesting quotes, starting checkout, or submitting claims-related materials.',
      ),
      _TermsItem(
        title: 'Policy and underwriting',
        body:
            'Eligibility, rating, issuance, exclusions, and claims outcomes depend on policy language, underwriting decisions, and available documentation.',
      ),
      _TermsItem(
        title: 'Claims expectations',
        body:
            'Submitting a claim does not guarantee reimbursement. Eligibility depends on timing, policy settings, records, and medical context.',
      ),
      _TermsItem(
        title: 'Changes and updates',
        body:
            'Clovara may evolve product features, site content, or customer experience flows. Material policy changes are handled through the policy and applicable law.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 760;
        if (stacked) {
          return const Column(
            children: [
              PremiumCard(
                child: _TermsItem(
                  title: 'Using the platform',
                  body:
                      'You should provide accurate information when requesting quotes, starting checkout, or submitting claims-related materials.',
                ),
              ),
              SizedBox(height: 14),
              PremiumCard(
                child: _TermsItem(
                  title: 'Policy and underwriting',
                  body:
                      'Eligibility, rating, issuance, exclusions, and claims outcomes depend on policy language, underwriting decisions, and available documentation.',
                ),
              ),
              SizedBox(height: 14),
              PremiumCard(
                child: _TermsItem(
                  title: 'Claims expectations',
                  body:
                      'Submitting a claim does not guarantee reimbursement. Eligibility depends on timing, policy settings, records, and medical context.',
                ),
              ),
              SizedBox(height: 14),
              PremiumCard(
                child: _TermsItem(
                  title: 'Changes and updates',
                  body:
                      'Clovara may evolve product features, site content, or customer experience flows. Material policy changes are handled through the policy and applicable law.',
                ),
              ),
            ],
          );
        }

        final width = (constraints.maxWidth - 16) / 2;
        return Wrap(
          spacing: 16,
          runSpacing: 16,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: PremiumCard(child: item),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }
}

class _TermsItem extends StatelessWidget {
  const _TermsItem({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

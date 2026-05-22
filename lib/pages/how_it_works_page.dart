import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/buttons.dart';
import '../ui/components/max_width.dart';
import '../ui/components/section.dart';
import '../ui/tokens.dart';

class HowItWorksPage extends StatelessWidget {
  const HowItWorksPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Section(verticalPadding: 28, child: MaxWidth(child: _HowHero())),
        Section(
          backgroundColor: AppColors.surface2,
          verticalPadding: 28,
          child: MaxWidth(child: _ThreeSteps()),
        ),
        Section(
          verticalPadding: 28,
          child: MaxWidth(child: _ImportantSection()),
        ),
        Section(
          backgroundColor: AppColors.surface2,
          verticalPadding: 28,
          child: MaxWidth(child: _ClaimDocSection()),
        ),
        Section(verticalPadding: 28, child: MaxWidth(child: _HowClosingCta())),
      ],
    );
  }
}

class _HowHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 780;
        return ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow(label: 'How it works'),
              const SizedBox(height: 14),
              Text(
                'How Clovara removes the confusion',
                style: Theme.of(context).textTheme.displaySmall!.copyWith(
                  fontSize: isMobile ? 36 : 46,
                  height: 1.02,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Three simple steps from quote to claim \u2014 no phone calls, no paperwork confusion.',
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: AppColors.text,
                  fontSize: 18,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'See your price',
                icon: Icons.arrow_forward_rounded,
                onPressed: () => context.go('/quote'),
              ),
              const SizedBox(height: 10),
              Text(
                'Takes 2 minutes \u00B7 No commitment',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ThreeSteps extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow(label: 'Three steps'),
        const SizedBox(height: 12),
        Text(
          'From quote to claim in minutes',
          style: Theme.of(context).textTheme.headlineLarge!,
        ),
        const SizedBox(height: 8),
        Text(
          'No phone trees. No fax machines. No confusion.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge!.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 760;
            final cards = [
              const _StepCard(
                number: '01',
                title: 'Know your cost',
                body:
                    'Answer a few questions about your pet. Choose your deductible, reimbursement rate, and annual limit. See your price instantly.',
                icon: Icons.calculate_outlined,
              ),
              const _StepCard(
                number: '02',
                title: 'Visit any vet',
                body:
                    'See any licensed vet, specialist, or emergency clinic. There\u2019s no network \u2014 go wherever your pet gets the best care.',
                icon: Icons.local_hospital_outlined,
              ),
              const _StepCard(
                number: '03',
                title: 'Submit a claim',
                body:
                    'Upload your invoice and records. Clovara checks the claim quickly and reimburses you directly based on your plan settings.',
                icon: Icons.receipt_long_outlined,
              ),
            ];
            if (stacked) {
              return Column(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    cards[i],
                    if (i < cards.length - 1) const SizedBox(height: 14),
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
                    if (i < cards.length - 1) const SizedBox(width: 14),
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

class _StepCard extends StatelessWidget {
  const _StepCard({
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
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  color: AppColors.green.withValues(alpha: 0.25),
                  fontWeight: FontWeight.w900,
                  fontSize: 36,
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

class _ImportantSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow(label: 'Good to know'),
        const SizedBox(height: 12),
        Text(
          'Important details',
          style: Theme.of(context).textTheme.headlineLarge!,
        ),
        const SizedBox(height: 8),
        Text(
          'A few things to understand before you enroll.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge!.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 28),
        LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 760;
            final cards = [
              const _InfoCard(
                icon: Icons.schedule_outlined,
                title: 'Reimbursement timing',
                body:
                    'Most claims are checked within a few business days. Reimbursement is sent directly to you after approval.',
              ),
              const _InfoCard(
                icon: Icons.block_outlined,
                title: 'Pre-existing conditions',
                body:
                    'Conditions with symptoms before your policy starts aren\u2019t eligible. This is standard across all pet insurers.',
              ),
              const _InfoCard(
                icon: Icons.account_balance_wallet_outlined,
                title: 'You pay the vet directly',
                body:
                    'Pay your vet at the time of visit, then submit a claim. We reimburse you based on your plan settings.',
              ),
            ];
            if (stacked) {
              return Column(
                children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    cards[i],
                    if (i < cards.length - 1) const SizedBox(height: 14),
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
                    if (i < cards.length - 1) const SizedBox(width: 14),
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

class _InfoCard extends StatelessWidget {
  const _InfoCard({
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
        color: AppColors.surface1,
        borderRadius: AppRadii.br16,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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

class _ClaimDocSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Eyebrow(label: 'Claims'),
        const SizedBox(height: 12),
        Text(
          'What you\u2019ll need to file a claim',
          style: Theme.of(context).textTheme.headlineLarge!,
        ),
        const SizedBox(height: 8),
        Text(
          'Keep these documents handy after a vet visit \u2014 they\u2019re all you need.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge!.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 20),
        const _DocRow(
          icon: Icons.receipt_long_outlined,
          title: 'Itemized invoice',
          body: 'A detailed invoice from your vet showing each charge.',
        ),
        const SizedBox(height: 10),
        const _DocRow(
          icon: Icons.description_outlined,
          title: 'Medical records',
          body: 'Notes from the visit including diagnosis and treatment.',
        ),
        const SizedBox(height: 10),
        const _DocRow(
          icon: Icons.history_outlined,
          title: 'Prior records (if new)',
          body:
              'If it\u2019s your first claim, we may ask for prior medical history to verify no pre-existing conditions.',
        ),
      ],
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadii.br12,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
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
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.deepGreen,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: AppColors.textMuted,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HowClosingCta extends StatelessWidget {
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
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to see your price?',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall!.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Answer a few questions. Pick your plan settings. See your price \u2014 no commitment required.',
                textAlign: stacked ? TextAlign.center : TextAlign.left,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: Colors.white.withValues(alpha: 0.78),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 18,
                  ),
                  shape: const RoundedRectangleBorder(
                    borderRadius: AppRadii.br12,
                  ),
                  textStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                child: const Text('See your price'),
              ),
              const SizedBox(height: 8),
              Text(
                'Takes 2 minutes \u00B7 No commitment',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: Colors.white.withValues(alpha: 0.56),
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

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(
    label.toUpperCase(),
    style: Theme.of(context).textTheme.bodySmall!.copyWith(
      color: AppColors.green,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      fontSize: 12,
    ),
  );
}

import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../badges.dart';
import '../premium_card.dart';

class PlanSettingsExplainer extends StatelessWidget {
  const PlanSettingsExplainer({
    super.key,
    this.title = 'How plan settings work',
    this.subtitle,
  });

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      showShadow: false,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final stacked = constraints.maxWidth < 920;

          final left = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 8),
                Text(
                  subtitle!,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: AppColors.textMuted, height: 1.55),
                ),
              ],
              const SizedBox(height: 16),
              const _SettingRow(
                icon: Icons.payments_outlined,
                title: 'Annual deductible',
                body:
                    'What you pay out-of-pocket each year before reimbursements begin. Common options: \$250, \$500, \$1,000.',
              ),
              const SizedBox(height: 12),
              const _SettingRow(
                icon: Icons.percent,
                title: 'Reimbursement %',
                body:
                    'The percentage we reimburse after you\'ve met your deductible. Common options: 70%, 80%, 90%.',
              ),
              const SizedBox(height: 12),
              const _SettingRow(
                icon: Icons.shield_outlined,
                title: 'Annual limit',
                body:
                    'The maximum amount we\'ll reimburse per year. Common options: \$5,000, \$10,000, Unlimited.',
              ),
            ],
          );

          final right = _ExampleMathCard(
            title: 'Example reimbursement',
            invoice: 1200,
            deductibleRemaining: 250,
            reimbursementPercent: 0.8,
          );

          if (stacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                left,
                const SizedBox(height: 16),
                right,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: left),
              const SizedBox(width: 16),
              Expanded(flex: 5, child: right),
            ],
          );
        },
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: AppRadii.br16,
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.deepGreen,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(color: AppColors.textMuted, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExampleMathCard extends StatelessWidget {
  const _ExampleMathCard({
    required this.title,
    required this.invoice,
    required this.deductibleRemaining,
    required this.reimbursementPercent,
  });

  final String title;
  final int invoice;
  final int deductibleRemaining;
  final double reimbursementPercent;

  @override
  Widget build(BuildContext context) {
    final eligibleAfterDeductible = (invoice - deductibleRemaining).clamp(0, invoice);
    final reimbursed = (eligibleAfterDeductible * reimbursementPercent).round();
    final youPay = invoice - reimbursed;

    String dollars(int v) => '\$${v.toString()}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: AppRadii.br20,
        border: Border.all(color: AppColors.borderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: AppColors.deepGreen,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'This is a simplified example. Exact eligibility depends on policy terms, waiting periods, and medical records.',
            style: Theme.of(context)
                .textTheme
                .bodySmall!
                .copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          _Line(label: 'Vet invoice', value: dollars(invoice)),
          _Line(label: 'Deductible remaining', value: '- ${dollars(deductibleRemaining)}'),
          _Line(label: 'Eligible after deductible', value: dollars(eligibleAfterDeductible)),
          _Line(
            label: 'Reimbursement (${(reimbursementPercent * 100).round()}%)',
            value: dollars(reimbursed),
            valueColor: AppColors.success,
          ),
          const Divider(height: 22, thickness: 1, color: AppColors.border),
          _Line(
            label: 'Estimated you pay',
            value: dollars(youPay),
            emphasize: true,
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({
    required this.label,
    required this.value,
    this.emphasize = false,
    this.valueColor,
  });

  final String label;
  final String value;
  final bool emphasize;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.bodySmall!.copyWith(
          color: AppColors.textMuted,
          fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
        );

    final valueStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: valueColor ?? AppColors.deepGreen,
          fontWeight: emphasize ? FontWeight.w900 : FontWeight.w800,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: labelStyle)),
          const SizedBox(width: 10),
          Text(value, style: valueStyle),
        ],
      ),
    );
  }
}

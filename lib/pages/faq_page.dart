import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/accordion.dart';
import '../ui/components/max_width.dart';
import '../ui/components/section.dart';
import '../ui/tokens.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Section(verticalPadding: 28, child: MaxWidth(child: _FaqHero())),
        Section(
          backgroundColor: AppColors.surface2,
          verticalPadding: 28,
          child: MaxWidth(
            child: _FaqGroup(
              eyebrow: 'Pricing & plans',
              headline: 'How pricing works',
              items: [
                AccordionItem(
                  question: 'How is my premium calculated?',
                  answer:
                      'Your monthly price is based on your pet\u2019s species, breed, age, and location \u2014 plus the deductible, reimbursement rate, and annual limit you choose.',
                ),
                AccordionItem(
                  question: 'Can I change my plan settings later?',
                  answer:
                      'You can adjust your deductible, reimbursement percentage, and annual limit at renewal. Changes take effect at the start of your next policy period.',
                ),
                AccordionItem(
                  question: 'Is there a waiting period before coverage starts?',
                  answer:
                      'Yes. Most policies have a short waiting period (typically 14 days for illnesses, 2 days for accidents) before coverage begins. This is standard across pet insurance.',
                ),
                AccordionItem(
                  question: 'Do premiums increase over time?',
                  answer:
                      'Premiums may adjust at renewal based on your pet\u2019s age, claims history, and veterinary cost trends in your area.',
                ),
              ],
            ),
          ),
        ),
        Section(
          verticalPadding: 28,
          child: MaxWidth(
            child: _FaqGroup(
              eyebrow: 'Coverage details',
              headline: 'What\u2019s covered and what\u2019s not',
              items: [
                AccordionItem(
                  question: 'What does Accident & Illness cover?',
                  answer:
                      'Accidents (broken bones, ingestions, bite wounds) plus illnesses (infections, cancer, chronic conditions), diagnostics, surgery, hospitalization, and prescriptions.',
                ),
                AccordionItem(
                  question: 'What does Accident-only cover?',
                  answer:
                      'Physical injuries, swallowed objects, toxic ingestions, and emergency exams related to accidents. Illnesses and chronic conditions are not included.',
                ),
                AccordionItem(
                  question: 'Are pre-existing conditions covered?',
                  answer:
                      'No. Conditions with symptoms before your policy starts are considered pre-existing and are not eligible for coverage. This is standard across all pet insurers.',
                ),
                AccordionItem(
                  question: 'Is routine care covered?',
                  answer:
                      'Standard plans do not cover wellness visits, vaccinations, or preventive care. These are predictable costs best budgeted separately.',
                ),
                AccordionItem(
                  question: 'Can I use any vet?',
                  answer:
                      'Yes. There\u2019s no network. You can visit any licensed veterinarian, specialist, or emergency clinic.',
                ),
              ],
            ),
          ),
        ),
        Section(
          backgroundColor: AppColors.surface2,
          verticalPadding: 28,
          child: MaxWidth(
            child: _FaqGroup(
              eyebrow: 'Claims process',
              headline: 'How claims work',
              items: [
                AccordionItem(
                  question: 'How do I file a claim?',
                  answer:
                      'After your vet visit, upload your itemized invoice and medical records through your account. We handle the rest.',
                ),
                AccordionItem(
                  question: 'How long does reimbursement take?',
                  answer:
                      'Most claims are checked within a few business days. Reimbursement is sent directly to you after approval.',
                ),
                AccordionItem(
                  question: 'Do I pay the vet upfront?',
                  answer:
                      'Yes. You pay your vet at the time of service, then submit a claim for reimbursement based on your plan settings.',
                ),
                AccordionItem(
                  question: 'What documents do I need?',
                  answer:
                      'An itemized invoice and medical records from the visit. For first-time claims, we may also request prior medical history.',
                ),
              ],
            ),
          ),
        ),
        Section(
          verticalPadding: 28,
          child: MaxWidth(
            child: _FaqGroup(
              eyebrow: 'General',
              headline: 'Getting started',
              items: [
                AccordionItem(
                  question: 'How old does my pet need to be?',
                  answer:
                      'Pets must be at least 8 weeks old to enroll. There is no upper age limit for new policies.',
                ),
                AccordionItem(
                  question: 'Can I insure multiple pets?',
                  answer:
                      'Yes. Each pet has its own policy with its own deductible, reimbursement rate, and annual limit.',
                ),
                AccordionItem(
                  question: 'How do I cancel?',
                  answer:
                      'You can cancel anytime through your account. If you cancel within the first 30 days and haven\u2019t filed a claim, you\u2019ll receive a full refund.',
                ),
              ],
            ),
          ),
        ),
        Section(verticalPadding: 28, child: MaxWidth(child: _FaqClosingCta())),
      ],
    );
  }
}

class _FaqHero extends StatelessWidget {
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
              const _Eyebrow(label: 'FAQ'),
              const SizedBox(height: 14),
              Text(
                'Answers without the jargon',
                style: Theme.of(context).textTheme.displaySmall!.copyWith(
                  fontSize: isMobile ? 36 : 46,
                  height: 1.02,
                  letterSpacing: -1.2,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Clear, honest answers to the questions people actually ask about pet insurance.',
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: AppColors.text,
                  fontSize: 18,
                  height: 1.6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FaqGroup extends StatelessWidget {
  const _FaqGroup({
    required this.eyebrow,
    required this.headline,
    required this.items,
  });
  final String eyebrow;
  final String headline;
  final List<AccordionItem> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Eyebrow(label: eyebrow),
        const SizedBox(height: 12),
        Text(headline, style: Theme.of(context).textTheme.headlineLarge!),
        const SizedBox(height: 20),
        Accordion(items: items),
      ],
    );
  }
}

class _FaqClosingCta extends StatelessWidget {
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
                'Still have questions?',
                style: Theme.of(
                  context,
                ).textTheme.headlineSmall!.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'See your price to get started \u2014 or reach out and we\u2019ll walk you through it.',
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
              TextButton(
                onPressed: () => context.go('/contact'),
                child: Text(
                  'Contact us',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w600,
                  ),
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

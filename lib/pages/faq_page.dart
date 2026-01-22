import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/accordion.dart';
import '../ui/components/bento_grid.dart';
import '../ui/components/buttons.dart';
import '../ui/components/gradient_border.dart';
import '../ui/components/hero_stage.dart';
import '../ui/components/max_width.dart';
import '../ui/components/premium_card.dart';
import '../ui/components/section_break.dart';
import '../ui/components/section.dart';
import '../ui/tokens.dart';

class FaqPage extends StatelessWidget {
  const FaqPage({super.key});

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
                    Text(
                      'FAQ: calm answers to common questions.',
                      style: Theme.of(
                        context,
                      ).textTheme.displaySmall!.copyWith(fontSize: 38),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We believe clarity is a feature. Here\'s what most people want to know before they buy.',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              right: BentoGrid(
                primary: ClipRRect(
                  borderRadius: AppRadii.br24,
                  child: Container(
                    color: AppColors.surface,
                    child: AspectRatio(
                      aspectRatio: 1.22,
                      child: Image.asset(
                        'assets/images/faq pic.png',
                        fit: BoxFit.cover,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                ),
                secondary: const [
                  MiniFeatureTile(
                    icon: Icons.lock_outline,
                    title: 'No gotchas',
                    body: 'Simple, clear answers—without the policy overwhelm.',
                  ),
                  MiniFeatureTile(
                    icon: Icons.support_agent,
                    title: 'Designed for humans',
                    body: 'We explain the “why”, not just the “what”.',
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

        _Group(
          title: 'Coverage',
          backgroundColor: AppColors.surface2,
          items: [
            AccordionItem(
              question: 'Do I have to use a specific vet?',
              answer:
                  'No. You can visit any licensed veterinarian. The important part is an itemized invoice and relevant medical notes for claims.',
            ),
            AccordionItem(
              question: 'Are chronic conditions covered?',
              answer:
                  'Chronic conditions may be eligible after waiting periods as long as they are not pre-existing. We\'ll help you understand this during enrollment.',
            ),
            AccordionItem(
              question: 'Is dental covered?',
              answer:
                  'Dental coverage depends on the condition and medical necessity. Routine cleanings are typically wellness unless a specific add-on is offered.',
            ),
          ],
        ),

        const SectionBreak(
          fromColor: AppColors.surface2,
          toColor: AppColors.background,
          flip: true,
        ),

        _Group(
          title: 'Pricing',
          backgroundColor: null,
          items: [
            AccordionItem(
              question: 'What changes my monthly premium?',
              answer:
                  'Your pet\'s age, breed, zip code, and plan settings (deductible, reimbursement %, annual limit) all influence premium.',
            ),
            AccordionItem(
              question: 'Can I change plan settings later?',
              answer:
                  'Some changes may be allowed at renewal. We\'ll be clear about what can change, when it can change, and how it affects coverage.',
            ),
          ],
        ),

        const SectionBreak(
          fromColor: AppColors.background,
          toColor: AppColors.surface2,
        ),

        _Group(
          title: 'Claims',
          backgroundColor: AppColors.surface2,
          items: [
            AccordionItem(
              question: 'How do I submit a claim?',
              answer:
                  'You\'ll upload your invoice and any medical notes. If anything is missing, we\'ll tell you exactly what would help us review faster.',
            ),
            AccordionItem(
              question: 'How long do claims take?',
              answer:
                  'Timelines vary by complexity and documentation. Clean, itemized invoices and clear medical notes are the biggest accelerators.',
            ),
          ],
        ),

        const SectionBreak(
          fromColor: AppColors.surface2,
          toColor: AppColors.background,
          flip: true,
        ),

        _Group(
          title: 'Pre-existing',
          backgroundColor: null,
          items: [
            AccordionItem(
              question: 'What counts as pre-existing?',
              answer:
                  'If symptoms started before coverage begins—even without an official diagnosis—related conditions may be considered pre-existing.',
            ),
            AccordionItem(
              question: 'What if my pet had a minor issue years ago?',
              answer:
                  'It depends on records and symptom timelines. We recommend enrolling early and keeping vet records handy for clarity.',
            ),
          ],
        ),

        const SectionBreak(
          fromColor: AppColors.background,
          toColor: AppColors.surface2,
        ),

        _Group(
          title: 'Account',
          backgroundColor: AppColors.surface2,
          items: [
            AccordionItem(
              question: 'Do I need an account to get a quote?',
              answer:
                  'No. You can start a quote without signing in. You\'ll only be prompted to sign in when it\'s time to purchase or manage your policy.',
            ),
            AccordionItem(
              question: 'Can I resume later?',
              answer:
                  'Yes. We support resume codes and device-based resume. If you lose your place, you can continue without starting over.',
            ),
          ],
        ),

        const SectionBreak(
          fromColor: AppColors.surface2,
          toColor: AppColors.background,
          flip: true,
        ),

        Section(
          child: MaxWidth(
            child: GradientBorder(
              radius: AppRadii.br24,
              child: PremiumCard(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 760;
                    final copy = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Still unsure?',
                          style: Theme.of(context).textTheme.headlineSmall!,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a quote and we\'ll guide you through the details as you go—or sign in to pick up where you left off.',
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
                          label: 'Sign in',
                          icon: Icons.person_outline,
                          onPressed: () => context.go('/sign-in'),
                        ),
                        PrimaryButton(
                          label: 'Get a quote',
                          icon: Icons.pets,
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
                        const SizedBox(width: 14),
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

class _Group extends StatelessWidget {
  const _Group({
    required this.title,
    required this.items,
    required this.backgroundColor,
  });

  final String title;
  final List<AccordionItem> items;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Section(
      backgroundColor: backgroundColor,
      child: MaxWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall!),
            const SizedBox(height: 14),
            Accordion(items: items),
          ],
        ),
      ),
    );
  }
}

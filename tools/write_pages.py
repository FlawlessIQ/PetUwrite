#!/usr/bin/env python3
"""Writes the refactored page files."""
import os

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAGES = os.path.join(BASE, 'lib', 'pages')


def write(name, content):
    path = os.path.join(PAGES, name)
    with open(path, 'w') as f:
        f.write(content)
    print(f'  ✓ {name} ({len(content)} bytes)')


# ── Coverage Page ──────────────────────────────────────────
COVERAGE = r"""import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/buttons.dart';
import '../ui/components/info/coverage_matrix.dart';
import '../ui/components/info/notice_banner.dart';
import '../ui/components/info/plan_settings_explainer.dart';
import '../ui/components/max_width.dart';
import '../ui/components/section.dart';
import '../ui/tokens.dart';

enum CoverageTab { accidentIllness, accidentOnly }

class CoveragePage extends StatefulWidget {
  const CoveragePage({super.key});

  @override
  State<CoveragePage> createState() => _CoveragePageState();
}

class _CoveragePageState extends State<CoveragePage> {
  CoverageTab _selectedTab = CoverageTab.accidentIllness;

  @override
  Widget build(BuildContext context) {
    final rows = _selectedTab == CoverageTab.accidentIllness
        ? const <CoverageMatrixRow>[
            CoverageMatrixRow(
                title: 'Accidents & injuries',
                detail:
                    'Broken bones, bite wounds, swallowed objects, toxic ingestions',
                accidentIllness: CoverageMark.yes,
                accidentOnly: CoverageMark.yes),
            CoverageMatrixRow(
                title: 'Illnesses',
                detail: 'Infections, parasites, ear infections, GI issues',
                accidentIllness: CoverageMark.yes,
                accidentOnly: CoverageMark.no),
            CoverageMatrixRow(
                title: 'Chronic conditions',
                detail: 'Allergies, diabetes, arthritis',
                accidentIllness: CoverageMark.sometimes,
                accidentOnly: CoverageMark.no,
                footnote:
                    'Eligible after waiting periods if not pre-existing.'),
            CoverageMatrixRow(
                title: 'Cancer & serious disease',
                detail: 'Cancer treatment, heart disease, kidney disease',
                accidentIllness: CoverageMark.yes,
                accidentOnly: CoverageMark.no,
                footnote:
                    'Eligibility depends on policy terms and medical records.'),
            CoverageMatrixRow(
                title: 'Hereditary conditions',
                detail: 'Hip dysplasia, breed-specific issues',
                accidentIllness: CoverageMark.sometimes,
                accidentOnly: CoverageMark.no,
                footnote:
                    'Eligible if not pre-existing and after waiting periods.'),
            CoverageMatrixRow(
                title: 'Diagnostics',
                detail: 'X-rays, bloodwork, ultrasounds, MRIs, CT scans',
                accidentIllness: CoverageMark.yes,
                accidentOnly: CoverageMark.sometimes,
                footnote:
                    'Accident-only generally applies when diagnostics relate to an accident.'),
            CoverageMatrixRow(
                title: 'Surgery & hospitalization',
                detail: 'Emergency care, overnight stays, anesthesia',
                accidentIllness: CoverageMark.yes,
                accidentOnly: CoverageMark.sometimes,
                footnote:
                    'Accident-only generally applies for accident-related surgery/care.'),
            CoverageMatrixRow(
                title: 'Prescription medications',
                detail:
                    'Medications prescribed to treat covered conditions',
                accidentIllness: CoverageMark.yes,
                accidentOnly: CoverageMark.sometimes,
                footnote:
                    'Accident-only generally applies for accident-related prescriptions.'),
          ]
        : const <CoverageMatrixRow>[
            CoverageMatrixRow(
                title: 'Physical injuries',
                detail: 'Broken bones, lacerations, bite wounds',
                accidentIllness: CoverageMark.yes,
                accidentOnly: CoverageMark.yes),
            CoverageMatrixRow(
                title: 'Swallowed objects',
                detail: 'Foreign body ingestion requiring treatment',
                accidentIllness: CoverageMark.yes,
                accidentOnly: CoverageMark.yes),
            CoverageMatrixRow(
                title: 'Toxic ingestions',
                detail: 'Poisoning from hazardous substances',
                accidentIllness: CoverageMark.yes,
                accidentOnly: CoverageMark.yes),
            CoverageMatrixRow(
                title: 'Emergency exams',
                detail:
                    'Emergency vet visits for accident-related issues',
                accidentIllness: CoverageMark.yes,
                accidentOnly: CoverageMark.yes),
            CoverageMatrixRow(
                title: 'Illnesses',
                detail:
                    'Infections, parasites, chronic or congenital disease',
                accidentIllness: CoverageMark.yes,
                accidentOnly: CoverageMark.no),
          ];

    return Column(
      children: [
        Section(
            verticalPadding: 28,
            child: MaxWidth(child: _CoverageHero())),
        Section(
            verticalPadding: 28,
            child: MaxWidth(child: _CoverageCategories())),
        Section(
          backgroundColor: AppColors.surface2,
          verticalPadding: 28,
          child: MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Compare coverage levels',
                    style:
                        Theme.of(context).textTheme.headlineLarge!),
                const SizedBox(height: 8),
                Text(
                    'See at a glance what each plan type covers.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyLarge!
                        .copyWith(color: AppColors.textMuted)),
                const SizedBox(height: 20),
                _PremiumSegmentedSwitch(
                  leftLabel: 'Accident & Illness',
                  rightLabel: 'Accident-only',
                  isLeftSelected:
                      _selectedTab == CoverageTab.accidentIllness,
                  onLeft: () => setState(
                      () => _selectedTab = CoverageTab.accidentIllness),
                  onRight: () => setState(
                      () => _selectedTab = CoverageTab.accidentOnly),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedTab == CoverageTab.accidentIllness
                      ? 'Comprehensive protection for accidents, illnesses, diagnostics, and follow-up care.'
                      : 'A simpler option focused on accidental injuries and emergencies.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 20),
                CoverageMatrix(
                  title: _selectedTab == CoverageTab.accidentIllness
                      ? 'Accident & Illness coverage at a glance'
                      : 'Accident-only coverage at a glance',
                  subtitle:
                      'Specific eligibility depends on policy terms.',
                  rows: rows,
                ),
              ],
            ),
          ),
        ),
        Section(
            verticalPadding: 28,
            child: MaxWidth(
                child: PlanSettingsExplainer(
                    subtitle:
                        'Three settings shape your monthly premium and how much you get back when you file a claim.'))),
        Section(
            backgroundColor: AppColors.surface2,
            verticalPadding: 28,
            child: MaxWidth(child: _NotCoveredSection())),
        Section(
            verticalPadding: 28,
            child: MaxWidth(child: _PageClosingCta())),
      ],
    );
  }
}

class _CoverageHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 780;
      final left = ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow(label: 'Coverage'),
              const SizedBox(height: 14),
              Text('Coverage you can actually understand',
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall!
                      .copyWith(
                          fontSize: isMobile ? 36 : 46,
                          height: 1.02,
                          letterSpacing: -1.2)),
              const SizedBox(height: 14),
              Text(
                  'See what\u2019s included before you choose a plan \u2014 no hidden terms, no insurance jargon.',
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: AppColors.text,
                      fontSize: 18,
                      height: 1.6)),
              const SizedBox(height: 24),
              PrimaryButton(
                  label: 'See your price',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => context.go('/quote')),
              const SizedBox(height: 10),
              Text('Takes 2 minutes \u00B7 No commitment',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600)),
            ]),
      );
      final image = ClipRRect(
          borderRadius: AppRadii.br16,
          child: Container(
              color: AppColors.surface2,
              child: AspectRatio(
                  aspectRatio: 1.24,
                  child: Image.asset('assets/images/Cat at vet.png',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium))));
      if (isMobile) {
        return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [left, const SizedBox(height: 28), image]);
      }
      return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 11, child: left),
            const SizedBox(width: 32),
            Expanded(flex: 9, child: image),
          ]);
    });
  }
}

class _CoverageCategories extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow(label: 'What\u2019s covered'),
          const SizedBox(height: 12),
          Text('Three pillars of protection',
              style: Theme.of(context).textTheme.headlineLarge!),
          const SizedBox(height: 8),
          Text(
              'Real coverage for real vet bills \u2014 explained in plain language.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 28),
          LayoutBuilder(builder: (context, constraints) {
            final stacked = constraints.maxWidth < 760;
            final cards = [
              const _CategoryCard(
                  icon: Icons.medical_services_outlined,
                  title: 'Accidents',
                  body:
                      'Broken bones, bite wounds, swallowed objects, and toxic ingestions.',
                  examples:
                      'Example: Your dog swallows a toy and needs emergency surgery.'),
              const _CategoryCard(
                  icon: Icons.sick_outlined,
                  title: 'Illnesses',
                  body:
                      'Infections, chronic conditions, cancer, heart disease, and more.',
                  examples:
                      'Example: Your cat develops kidney disease and needs ongoing treatment.'),
              const _CategoryCard(
                  icon: Icons.biotech_outlined,
                  title: 'Diagnostics & surgery',
                  body:
                      'X-rays, bloodwork, MRIs, surgeries, hospital stays, and follow-up care.',
                  examples:
                      'Example: Your pet needs an MRI and surgery after a back injury.'),
            ];
            if (stacked) {
              return Column(children: [
                for (int i = 0; i < cards.length; i++) ...[
                  cards[i],
                  if (i < cards.length - 1) const SizedBox(height: 14),
                ],
              ]);
            }
            return IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i < cards.length - 1) const SizedBox(width: 14),
                  ],
                ]));
          }),
        ]);
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard(
      {required this.icon,
      required this.title,
      required this.body,
      required this.examples});
  final IconData icon;
  final String title;
  final String body;
  final String examples;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: AppRadii.br16,
          border: Border.all(color: AppColors.border)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14)),
                child:
                    Icon(icon, size: 22, color: AppColors.deepGreen)),
            const SizedBox(height: 20),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(
                        color: AppColors.deepGreen,
                        fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(body,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(
                        color: AppColors.textMuted, height: 1.5)),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: AppRadii.br12),
              child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.lightbulb_outline_rounded,
                        size: 16, color: AppColors.green),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(examples,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall!
                                .copyWith(
                                    color: AppColors.text,
                                    fontWeight: FontWeight.w600,
                                    height: 1.4))),
                  ]),
            ),
          ]),
    );
  }
}

class _NotCoveredSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow(label: 'Transparency'),
          const SizedBox(height: 12),
          Text('What\u2019s typically not covered',
              style: Theme.of(context).textTheme.headlineLarge!),
          const SizedBox(height: 8),
          Text(
              'We believe you should know the exclusions upfront \u2014 not buried in a policy document.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 20),
          const NoticeBanner(
              tone: NoticeTone.info,
              title: 'Pre-existing conditions are not covered',
              body:
                  'If symptoms started before coverage begins \u2014 even without a diagnosis \u2014 related conditions may be considered pre-existing.',
              icon: Icons.fact_check_outlined),
          const SizedBox(height: 16),
          const _ExclusionItem(
              icon: Icons.history_toggle_off,
              title: 'Wellness & routine care',
              body:
                  'Annual exams, vaccinations, flea prevention, and teeth cleaning.'),
          const SizedBox(height: 10),
          const _ExclusionItem(
              icon: Icons.child_friendly_outlined,
              title: 'Breeding & pregnancy',
              body:
                  'Costs related to breeding, pregnancy, or whelping.'),
          const SizedBox(height: 10),
          const _ExclusionItem(
              icon: Icons.face_retouching_off,
              title: 'Cosmetic procedures',
              body:
                  'Tail docking, ear cropping, and similar unless medically necessary.'),
        ]);
  }
}

class _ExclusionItem extends StatelessWidget {
  const _ExclusionItem(
      {required this.icon, required this.title, required this.body});
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
          border: Border.all(color: AppColors.border)),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12)),
                child:
                    Icon(icon, size: 20, color: AppColors.textMuted)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium!
                          .copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepGreen)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(
                              color: AppColors.textMuted,
                              height: 1.45)),
                ])),
          ]),
    );
  }
}

class _PageClosingCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      decoration: BoxDecoration(
          color: AppColors.deepGreen, borderRadius: AppRadii.br24),
      child: LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 720;
        final copy = Column(
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text('See your price based on your pet',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall!
                      .copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                  'Customize your deductible, reimbursement, and annual limit \u2014 then decide on your own time.',
                  textAlign:
                      stacked ? TextAlign.center : TextAlign.left,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(
                          color: Colors.white.withValues(alpha: 0.78))),
            ]);
        final actions = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                  onPressed: () => context.go('/quote'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.deepGreen,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 18),
                      shape: const RoundedRectangleBorder(
                          borderRadius: AppRadii.br12),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  child: const Text('See your price')),
              const SizedBox(height: 8),
              Text('Takes 2 minutes \u00B7 No commitment',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(
                          color:
                              Colors.white.withValues(alpha: 0.56),
                          fontSize: 12)),
            ]);
        if (stacked) {
          return Column(children: [
            copy,
            const SizedBox(height: 20),
            actions,
          ]);
        }
        return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              actions,
            ]);
      }),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: AppColors.green,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          fontSize: 12));
}

class _PremiumSegmentedSwitch extends StatelessWidget {
  const _PremiumSegmentedSwitch(
      {required this.leftLabel,
      required this.rightLabel,
      required this.isLeftSelected,
      required this.onLeft,
      required this.onRight});
  final String leftLabel;
  final String rightLabel;
  final bool isLeftSelected;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Expanded(
              child: _Segment(
                  label: leftLabel,
                  selected: isLeftSelected,
                  onTap: onLeft)),
          Expanded(
              child: _Segment(
                  label: rightLabel,
                  selected: !isLeftSelected,
                  onTap: onRight)),
        ]));
  }
}

class _Segment extends StatelessWidget {
  const _Segment(
      {required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
                color: selected
                    ? AppColors.surface2
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: selected
                        ? AppColors.borderStrong
                        : Colors.transparent)),
            child: Text(label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontWeight:
                        selected ? FontWeight.w800 : FontWeight.w600,
                    color: selected
                        ? AppColors.deepGreen
                        : AppColors.textMuted))));
  }
}
"""


# ── How It Works Page ──────────────────────────────────────
HOW_IT_WORKS = r"""import 'package:flutter/material.dart';
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
            child: MaxWidth(child: _ThreeSteps())),
        Section(
            verticalPadding: 28,
            child: MaxWidth(child: _ImportantSection())),
        Section(
            backgroundColor: AppColors.surface2,
            verticalPadding: 28,
            child: MaxWidth(child: _ClaimDocSection())),
        Section(
            verticalPadding: 28,
            child: MaxWidth(child: _HowClosingCta())),
      ],
    );
  }
}

class _HowHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
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
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall!
                      .copyWith(
                          fontSize: isMobile ? 36 : 46,
                          height: 1.02,
                          letterSpacing: -1.2)),
              const SizedBox(height: 14),
              Text(
                  'Three simple steps from quote to claim \u2014 no phone calls, no paperwork confusion.',
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: AppColors.text,
                      fontSize: 18,
                      height: 1.6)),
              const SizedBox(height: 24),
              PrimaryButton(
                  label: 'See your price',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: () => context.go('/quote')),
              const SizedBox(height: 10),
              Text('Takes 2 minutes \u00B7 No commitment',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600)),
            ]),
      );
    });
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
          Text('From quote to claim in minutes',
              style: Theme.of(context).textTheme.headlineLarge!),
          const SizedBox(height: 8),
          Text('No phone trees. No fax machines. No confusion.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 28),
          LayoutBuilder(builder: (context, constraints) {
            final stacked = constraints.maxWidth < 760;
            final cards = [
              const _StepCard(
                  number: '01',
                  title: 'Know your cost',
                  body:
                      'Answer a few questions about your pet. Choose your deductible, reimbursement rate, and annual limit. See your price instantly.',
                  icon: Icons.calculate_outlined),
              const _StepCard(
                  number: '02',
                  title: 'Visit any vet',
                  body:
                      'See any licensed vet, specialist, or emergency clinic. There\u2019s no network \u2014 go wherever your pet gets the best care.',
                  icon: Icons.local_hospital_outlined),
              const _StepCard(
                  number: '03',
                  title: 'Submit a claim',
                  body:
                      'Upload your invoice and records. We review claims quickly and reimburse you directly based on your plan settings.',
                  icon: Icons.receipt_long_outlined),
            ];
            if (stacked) {
              return Column(children: [
                for (int i = 0; i < cards.length; i++) ...[
                  cards[i],
                  if (i < cards.length - 1)
                    const SizedBox(height: 14),
                ],
              ]);
            }
            return IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i < cards.length - 1)
                      const SizedBox(width: 14),
                  ],
                ]));
          }),
        ]);
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard(
      {required this.number,
      required this.title,
      required this.body,
      required this.icon});
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
          border: Border.all(color: AppColors.border)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                  height: 44,
                  width: 44,
                  decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(icon,
                      size: 22, color: AppColors.deepGreen)),
              const Spacer(),
              Text(number,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall!
                      .copyWith(
                          color: AppColors.green.withValues(alpha: 0.25),
                          fontWeight: FontWeight.w900,
                          fontSize: 36)),
            ]),
            const SizedBox(height: 20),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(
                        color: AppColors.deepGreen,
                        fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(body,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(
                        color: AppColors.textMuted, height: 1.5)),
          ]),
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
          Text('Important details',
              style: Theme.of(context).textTheme.headlineLarge!),
          const SizedBox(height: 8),
          Text(
              'A few things to understand before you enroll.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 28),
          LayoutBuilder(builder: (context, constraints) {
            final stacked = constraints.maxWidth < 760;
            final cards = [
              const _InfoCard(
                  icon: Icons.schedule_outlined,
                  title: 'Reimbursement timing',
                  body:
                      'Most claims are reviewed within a few business days. Reimbursement is sent directly to you after approval.'),
              const _InfoCard(
                  icon: Icons.block_outlined,
                  title: 'Pre-existing conditions',
                  body:
                      'Conditions with symptoms before your policy starts aren\u2019t eligible. This is standard across all pet insurers.'),
              const _InfoCard(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'You pay the vet directly',
                  body:
                      'Pay your vet at the time of visit, then submit a claim. We reimburse you based on your plan settings.'),
            ];
            if (stacked) {
              return Column(children: [
                for (int i = 0; i < cards.length; i++) ...[
                  cards[i],
                  if (i < cards.length - 1)
                    const SizedBox(height: 14),
                ],
              ]);
            }
            return IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  for (int i = 0; i < cards.length; i++) ...[
                    Expanded(child: cards[i]),
                    if (i < cards.length - 1)
                      const SizedBox(width: 14),
                  ],
                ]));
          }),
        ]);
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard(
      {required this.icon,
      required this.title,
      required this.body});
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
          border: Border.all(color: AppColors.border)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14)),
                child:
                    Icon(icon, size: 22, color: AppColors.deepGreen)),
            const SizedBox(height: 20),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(
                        color: AppColors.deepGreen,
                        fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(body,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(
                        color: AppColors.textMuted, height: 1.5)),
          ]),
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
          Text('What you\u2019ll need to file a claim',
              style: Theme.of(context).textTheme.headlineLarge!),
          const SizedBox(height: 8),
          Text(
              'Keep these documents handy after a vet visit \u2014 they\u2019re all you need.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 20),
          const _DocRow(
              icon: Icons.receipt_long_outlined,
              title: 'Itemized invoice',
              body: 'A detailed invoice from your vet showing each charge.'),
          const SizedBox(height: 10),
          const _DocRow(
              icon: Icons.description_outlined,
              title: 'Medical records',
              body:
                  'Notes from the visit including diagnosis and treatment.'),
          const SizedBox(height: 10),
          const _DocRow(
              icon: Icons.history_outlined,
              title: 'Prior records (if new)',
              body:
                  'If it\u2019s your first claim, we may ask for prior medical history to verify no pre-existing conditions.'),
        ]);
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow(
      {required this.icon, required this.title, required this.body});
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
          border: Border.all(color: AppColors.border)),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12)),
                child:
                    Icon(icon, size: 20, color: AppColors.deepGreen)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium!
                          .copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepGreen)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(
                              color: AppColors.textMuted,
                              height: 1.45)),
                ])),
          ]),
    );
  }
}

class _HowClosingCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      decoration: BoxDecoration(
          color: AppColors.deepGreen, borderRadius: AppRadii.br24),
      child: LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 720;
        final copy = Column(
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text('Ready to see your price?',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall!
                      .copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                  'Answer a few questions. Pick your plan settings. See your price \u2014 no commitment required.',
                  textAlign:
                      stacked ? TextAlign.center : TextAlign.left,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(
                          color: Colors.white.withValues(alpha: 0.78))),
            ]);
        final actions = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                  onPressed: () => context.go('/quote'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.deepGreen,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 18),
                      shape: const RoundedRectangleBorder(
                          borderRadius: AppRadii.br12),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  child: const Text('See your price')),
              const SizedBox(height: 8),
              Text('Takes 2 minutes \u00B7 No commitment',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(
                          color:
                              Colors.white.withValues(alpha: 0.56),
                          fontSize: 12)),
            ]);
        if (stacked) {
          return Column(children: [
            copy,
            const SizedBox(height: 20),
            actions,
          ]);
        }
        return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              actions,
            ]);
      }),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: AppColors.green,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          fontSize: 12));
}
"""


# ── FAQ Page ───────────────────────────────────────────────
FAQ = r"""import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/accordion.dart';
import '../ui/components/buttons.dart';
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
                    items: const [
                  AccordionItem(
                      title: 'How is my premium calculated?',
                      body:
                          'Your monthly price is based on your pet\u2019s species, breed, age, and location \u2014 plus the deductible, reimbursement rate, and annual limit you choose.'),
                  AccordionItem(
                      title: 'Can I change my plan settings later?',
                      body:
                          'You can adjust your deductible, reimbursement percentage, and annual limit at renewal. Changes take effect at the start of your next policy period.'),
                  AccordionItem(
                      title: 'Is there a waiting period before coverage starts?',
                      body:
                          'Yes. Most policies have a short waiting period (typically 14 days for illnesses, 2 days for accidents) before coverage begins. This is standard across pet insurance.'),
                  AccordionItem(
                      title: 'Do premiums increase over time?',
                      body:
                          'Premiums may adjust at renewal based on your pet\u2019s age, claims history, and veterinary cost trends in your area.'),
                ]))),
        Section(
            verticalPadding: 28,
            child: MaxWidth(
                child: _FaqGroup(
                    eyebrow: 'Coverage details',
                    headline: 'What\u2019s covered and what\u2019s not',
                    items: const [
                  AccordionItem(
                      title: 'What does Accident & Illness cover?',
                      body:
                          'Accidents (broken bones, ingestions, bite wounds) plus illnesses (infections, cancer, chronic conditions), diagnostics, surgery, hospitalization, and prescriptions.'),
                  AccordionItem(
                      title: 'What does Accident-only cover?',
                      body:
                          'Physical injuries, swallowed objects, toxic ingestions, and emergency exams related to accidents. Illnesses and chronic conditions are not included.'),
                  AccordionItem(
                      title: 'Are pre-existing conditions covered?',
                      body:
                          'No. Conditions with symptoms before your policy starts are considered pre-existing and are not eligible for coverage. This is standard across all pet insurers.'),
                  AccordionItem(
                      title: 'Is routine care covered?',
                      body:
                          'Standard plans do not cover wellness visits, vaccinations, or preventive care. These are predictable costs best budgeted separately.'),
                  AccordionItem(
                      title: 'Can I use any vet?',
                      body:
                          'Yes. There\u2019s no network. You can visit any licensed veterinarian, specialist, or emergency clinic.'),
                ]))),
        Section(
            backgroundColor: AppColors.surface2,
            verticalPadding: 28,
            child: MaxWidth(
                child: _FaqGroup(
                    eyebrow: 'Claims process',
                    headline: 'How claims work',
                    items: const [
                  AccordionItem(
                      title: 'How do I file a claim?',
                      body:
                          'After your vet visit, upload your itemized invoice and medical records through your account. We handle the rest.'),
                  AccordionItem(
                      title: 'How long does reimbursement take?',
                      body:
                          'Most claims are reviewed within a few business days. Reimbursement is sent directly to you after approval.'),
                  AccordionItem(
                      title: 'Do I pay the vet upfront?',
                      body:
                          'Yes. You pay your vet at the time of service, then submit a claim for reimbursement based on your plan settings.'),
                  AccordionItem(
                      title: 'What documents do I need?',
                      body:
                          'An itemized invoice and medical records from the visit. For first-time claims, we may also request prior medical history.'),
                ]))),
        Section(
            verticalPadding: 28,
            child: MaxWidth(
                child: _FaqGroup(
                    eyebrow: 'General',
                    headline: 'Getting started',
                    items: const [
                  AccordionItem(
                      title: 'How old does my pet need to be?',
                      body:
                          'Pets must be at least 8 weeks old to enroll. There is no upper age limit for new policies.'),
                  AccordionItem(
                      title: 'Can I insure multiple pets?',
                      body:
                          'Yes. Each pet has its own policy with its own deductible, reimbursement rate, and annual limit.'),
                  AccordionItem(
                      title: 'How do I cancel?',
                      body:
                          'You can cancel anytime through your account. If you cancel within the first 30 days and haven\u2019t filed a claim, you\u2019ll receive a full refund.'),
                ]))),
        Section(verticalPadding: 28, child: MaxWidth(child: _FaqClosingCta())),
      ],
    );
  }
}

class _FaqHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 780;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow(label: 'FAQ'),
              const SizedBox(height: 14),
              Text('Answers without the jargon',
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall!
                      .copyWith(
                          fontSize: isMobile ? 36 : 46,
                          height: 1.02,
                          letterSpacing: -1.2)),
              const SizedBox(height: 14),
              Text(
                  'Clear, honest answers to the questions people actually ask about pet insurance.',
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: AppColors.text,
                      fontSize: 18,
                      height: 1.6)),
            ]),
      );
    });
  }
}

class _FaqGroup extends StatelessWidget {
  const _FaqGroup(
      {required this.eyebrow,
      required this.headline,
      required this.items});
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
          Text(headline,
              style: Theme.of(context).textTheme.headlineLarge!),
          const SizedBox(height: 20),
          Accordion(items: items),
        ]);
  }
}

class _FaqClosingCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      decoration: BoxDecoration(
          color: AppColors.deepGreen, borderRadius: AppRadii.br24),
      child: LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 720;
        final copy = Column(
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text('Still have questions?',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall!
                      .copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                  'See your price to get started \u2014 or reach out and we\u2019ll walk you through it.',
                  textAlign:
                      stacked ? TextAlign.center : TextAlign.left,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(
                          color: Colors.white.withValues(alpha: 0.78))),
            ]);
        final actions = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                  onPressed: () => context.go('/quote'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.deepGreen,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 18),
                      shape: const RoundedRectangleBorder(
                          borderRadius: AppRadii.br12),
                      textStyle: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16)),
                  child: const Text('See your price')),
              const SizedBox(height: 8),
              TextButton(
                  onPressed: () => context.go('/contact'),
                  child: Text('Contact us',
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontWeight: FontWeight.w600))),
            ]);
        if (stacked) {
          return Column(children: [
            copy,
            const SizedBox(height: 20),
            actions,
          ]);
        }
        return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              actions,
            ]);
      }),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: AppColors.green,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          fontSize: 12));
}
"""


# ── Learn Page ─────────────────────────────────────────────
LEARN = r"""import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/buttons.dart';
import '../ui/components/max_width.dart';
import '../ui/components/section.dart';
import '../ui/tokens.dart';

class _Article {
  const _Article(
      {required this.title,
      required this.summary,
      required this.tags,
      required this.readTime});
  final String title;
  final String summary;
  final List<String> tags;
  final String readTime;
}

const _articles = <_Article>[
  _Article(
      title: 'What does pet insurance actually cover?',
      summary:
          'A plain-language breakdown of accident & illness plans, accident-only plans, and common exclusions.',
      tags: ['Coverage'],
      readTime: '4 min'),
  _Article(
      title: 'How deductibles, reimbursement, and limits work together',
      summary:
          'Understand the three settings that shape your premium and your out-of-pocket costs.',
      tags: ['Pricing'],
      readTime: '5 min'),
  _Article(
      title: 'Pre-existing conditions explained',
      summary:
          'What counts as pre-existing, how insurers evaluate medical history, and what to expect.',
      tags: ['Coverage', 'Pre-existing'],
      readTime: '3 min'),
  _Article(
      title: 'How to file a pet insurance claim',
      summary:
          'Step-by-step: from vet visit to reimbursement \u2014 including what documents you need.',
      tags: ['Claims'],
      readTime: '4 min'),
  _Article(
      title: 'Is pet insurance worth it?',
      summary:
          'A realistic look at when insurance makes sense, what it costs, and how to decide.',
      tags: ['Pricing'],
      readTime: '6 min'),
  _Article(
      title: 'Choosing the right plan for your pet',
      summary:
          'How breed, age, and lifestyle affect your coverage needs \u2014 and what to prioritize.',
      tags: ['Coverage', 'Pricing'],
      readTime: '5 min'),
  _Article(
      title: 'What to expect during the waiting period',
      summary:
          'Why waiting periods exist, how long they last, and what happens if your pet gets sick before they end.',
      tags: ['Coverage'],
      readTime: '3 min'),
  _Article(
      title: 'Understanding wellness vs. insurance coverage',
      summary:
          'Why wellness isn\u2019t included in standard plans and how to budget for routine care.',
      tags: ['Coverage', 'Vet care'],
      readTime: '4 min'),
  _Article(
      title: 'Common claim mistakes and how to avoid them',
      summary:
          'Tips to make the claims process smooth: documentation, timing, and record-keeping.',
      tags: ['Claims'],
      readTime: '3 min'),
  _Article(
      title: 'How Clovara is different from traditional pet insurance',
      summary:
          'Transparency, plain language, and a modern claims experience \u2014 here\u2019s what sets us apart.',
      tags: ['Coverage'],
      readTime: '4 min'),
];

const _allTags = [
  'All',
  'Coverage',
  'Pricing',
  'Claims',
  'Pre-existing',
  'Vet care'
];

class LearnPage extends StatefulWidget {
  const LearnPage({super.key});

  @override
  State<LearnPage> createState() => _LearnPageState();
}

class _LearnPageState extends State<LearnPage> {
  String _selectedTag = 'All';

  List<_Article> get _filtered => _selectedTag == 'All'
      ? _articles
      : _articles.where((a) => a.tags.contains(_selectedTag)).toList();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Section(verticalPadding: 28, child: MaxWidth(child: _LearnHero())),
        Section(
          backgroundColor: AppColors.surface2,
          verticalPadding: 28,
          child: MaxWidth(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Eyebrow(label: 'Topics'),
                  const SizedBox(height: 12),
                  Text('Browse by topic',
                      style:
                          Theme.of(context).textTheme.headlineLarge!),
                  const SizedBox(height: 16),
                  Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final tag in _allTags)
                      _FilterChip(
                          label: tag,
                          selected: _selectedTag == tag,
                          onTap: () =>
                              setState(() => _selectedTag = tag)),
                  ]),
                  const SizedBox(height: 28),
                  ...[
                    for (int i = 0; i < _filtered.length; i++) ...[
                      _ArticleCard(article: _filtered[i]),
                      if (i < _filtered.length - 1)
                        const SizedBox(height: 12),
                    ],
                  ],
                  if (_filtered.isEmpty)
                    Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                            child: Text('No articles for this topic yet.',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge!
                                    .copyWith(
                                        color: AppColors.textMuted)))),
                ]),
          ),
        ),
        Section(
            verticalPadding: 28,
            child: MaxWidth(child: _LearnClosingCta())),
      ],
    );
  }
}

class _LearnHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 780;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow(label: 'Learn'),
              const SizedBox(height: 14),
              Text(
                  'Learn how pet insurance actually works',
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall!
                      .copyWith(
                          fontSize: isMobile ? 36 : 46,
                          height: 1.02,
                          letterSpacing: -1.2)),
              const SizedBox(height: 14),
              Text(
                  'Short, clear guides to help you understand coverage, pricing, and claims \u2014 before you buy.',
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: AppColors.text,
                      fontSize: 18,
                      height: 1.6)),
            ]),
      );
    });
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip(
      {required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
            color: selected ? AppColors.deepGreen : AppColors.surface1,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color:
                    selected ? AppColors.deepGreen : AppColors.border)),
        child: Text(label,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: selected ? Colors.white : AppColors.textMuted,
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _ArticleCard extends StatelessWidget {
  const _ArticleCard({required this.article});
  final _Article article;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: AppRadii.br16,
          border: Border.all(color: AppColors.border)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              for (final tag in article.tags) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text(tag,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(
                              color: AppColors.green,
                              fontWeight: FontWeight.w700,
                              fontSize: 11)),
                ),
                const SizedBox(width: 6),
              ],
              const Spacer(),
              Text(article.readTime,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall!
                      .copyWith(
                          color: AppColors.textSubtle, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            Text(article.title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(
                        color: AppColors.deepGreen,
                        fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(article.summary,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(
                        color: AppColors.textMuted, height: 1.5)),
          ]),
    );
  }
}

class _LearnClosingCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      decoration: BoxDecoration(
          color: AppColors.deepGreen, borderRadius: AppRadii.br24),
      child: LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 720;
        final copy = Column(
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text('Ready to see what it costs?',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall!
                      .copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                  'Get a personalized price for your pet in about two minutes.',
                  textAlign:
                      stacked ? TextAlign.center : TextAlign.left,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(
                          color: Colors.white.withValues(alpha: 0.78))),
            ]);
        final actions = ElevatedButton(
            onPressed: () => context.go('/quote'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.deepGreen,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 18),
                shape: const RoundedRectangleBorder(
                    borderRadius: AppRadii.br12),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            child: const Text('See your price'));
        if (stacked) {
          return Column(children: [
            copy,
            const SizedBox(height: 20),
            actions,
          ]);
        }
        return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              actions,
            ]);
      }),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: AppColors.green,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          fontSize: 12));
}
"""


# ── Contact Page ───────────────────────────────────────────
CONTACT = r"""import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/buttons.dart';
import '../ui/components/max_width.dart';
import '../ui/components/section.dart';
import '../ui/tokens.dart';

class ContactPage extends StatelessWidget {
  const ContactPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Section(
            verticalPadding: 28,
            child: MaxWidth(child: _ContactHero())),
        Section(
            backgroundColor: AppColors.surface2,
            verticalPadding: 28,
            child: MaxWidth(child: _ContactCards())),
        Section(
            verticalPadding: 28,
            child: MaxWidth(child: _ResponseInfo())),
        Section(
            verticalPadding: 28,
            child: MaxWidth(child: _ContactClosingCta())),
      ],
    );
  }
}

class _ContactHero extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final isMobile = constraints.maxWidth < 780;
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const _Eyebrow(label: 'Contact'),
              const SizedBox(height: 14),
              Text('We\u2019re here if you need us',
                  style: Theme.of(context)
                      .textTheme
                      .displaySmall!
                      .copyWith(
                          fontSize: isMobile ? 36 : 46,
                          height: 1.02,
                          letterSpacing: -1.2)),
              const SizedBox(height: 14),
              Text(
                  'Real people. Real answers. No phone trees, no ticket numbers \u2014 just help when you need it.',
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: AppColors.text,
                      fontSize: 18,
                      height: 1.6)),
            ]),
      );
    });
  }
}

class _ContactCards extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow(label: 'Reach us'),
          const SizedBox(height: 12),
          Text('Get in touch',
              style: Theme.of(context).textTheme.headlineLarge!),
          const SizedBox(height: 8),
          Text('Choose the option that works best for you.',
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge!
                  .copyWith(color: AppColors.textMuted)),
          const SizedBox(height: 24),
          LayoutBuilder(builder: (context, constraints) {
            final stacked = constraints.maxWidth < 680;
            final cards = [
              const _ContactCard(
                  icon: Icons.email_outlined,
                  title: 'General support',
                  detail: 'support@clovara.com',
                  description:
                      'Questions about your policy, claims, or account.'),
              const _ContactCard(
                  icon: Icons.gavel_outlined,
                  title: 'Legal & compliance',
                  detail: 'legal@clovara.com',
                  description:
                      'Regulatory questions, legal notices, or compliance inquiries.'),
            ];
            if (stacked) {
              return Column(children: [
                cards[0],
                const SizedBox(height: 14),
                cards[1],
              ]);
            }
            return IntrinsicHeight(
                child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 14),
                  Expanded(child: cards[1]),
                ]));
          }),
        ]);
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard(
      {required this.icon,
      required this.title,
      required this.detail,
      required this.description});
  final IconData icon;
  final String title;
  final String detail;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: AppRadii.br16,
          border: Border.all(color: AppColors.border)),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(14)),
                child:
                    Icon(icon, size: 22, color: AppColors.deepGreen)),
            const SizedBox(height: 20),
            Text(title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium!
                    .copyWith(
                        color: AppColors.deepGreen,
                        fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(detail,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(
                        color: AppColors.green,
                        fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(description,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(
                        color: AppColors.textMuted, height: 1.45)),
          ]),
    );
  }
}

class _ResponseInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Eyebrow(label: 'What to expect'),
          const SizedBox(height: 12),
          Text('How we handle inquiries',
              style: Theme.of(context).textTheme.headlineLarge!),
          const SizedBox(height: 20),
          const _InfoRow(
              icon: Icons.schedule_outlined,
              title: 'Response time',
              body:
                  'We aim to respond to all inquiries within one business day.'),
          const SizedBox(height: 10),
          const _InfoRow(
              icon: Icons.support_agent_outlined,
              title: 'Real people',
              body:
                  'Your message goes to a real person \u2014 not a chatbot or automated queue.'),
          const SizedBox(height: 10),
          const _InfoRow(
              icon: Icons.lock_outline,
              title: 'Secure communication',
              body:
                  'All communications are handled securely. Never share passwords via email.'),
        ]);
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(
      {required this.icon, required this.title, required this.body});
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
          border: Border.all(color: AppColors.border)),
      child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(12)),
                child:
                    Icon(icon, size: 20, color: AppColors.deepGreen)),
            const SizedBox(width: 14),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium!
                          .copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.deepGreen)),
                  const SizedBox(height: 4),
                  Text(body,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall!
                          .copyWith(
                              color: AppColors.textMuted,
                              height: 1.45)),
                ])),
          ]),
    );
  }
}

class _ContactClosingCta extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
      decoration: BoxDecoration(
          color: AppColors.deepGreen, borderRadius: AppRadii.br24),
      child: LayoutBuilder(builder: (context, constraints) {
        final stacked = constraints.maxWidth < 720;
        final copy = Column(
            crossAxisAlignment: stacked
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              Text('Want the fastest path?',
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall!
                      .copyWith(color: Colors.white)),
              const SizedBox(height: 8),
              Text(
                  'Most questions are answered during the quote process. See your price and learn as you go.',
                  textAlign:
                      stacked ? TextAlign.center : TextAlign.left,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(
                          color: Colors.white.withValues(alpha: 0.78))),
            ]);
        final actions = ElevatedButton(
            onPressed: () => context.go('/quote'),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppColors.deepGreen,
                padding: const EdgeInsets.symmetric(
                    horizontal: 32, vertical: 18),
                shape: const RoundedRectangleBorder(
                    borderRadius: AppRadii.br12),
                textStyle: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16)),
            child: const Text('See your price'));
        if (stacked) {
          return Column(children: [
            copy,
            const SizedBox(height: 20),
            actions,
          ]);
        }
        return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: copy),
              const SizedBox(width: 20),
              actions,
            ]);
      }),
    );
  }
}

class _Eyebrow extends StatelessWidget {
  const _Eyebrow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Text(label.toUpperCase(),
      style: Theme.of(context).textTheme.bodySmall!.copyWith(
          color: AppColors.green,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          fontSize: 12));
}
"""


if __name__ == '__main__':
    print('Writing refactored pages...')
    write('coverage_page.dart', COVERAGE)
    write('how_it_works_page.dart', HOW_IT_WORKS)
    write('faq_page.dart', FAQ)
    write('learn_page.dart', LEARN)
    write('contact_page.dart', CONTACT)
    print('Done!')

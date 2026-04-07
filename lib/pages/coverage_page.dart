import 'package:flutter/material.dart';
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

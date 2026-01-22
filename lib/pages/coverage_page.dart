import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/buttons.dart';
import '../ui/components/gradient_border.dart';
import '../ui/components/hero_stage.dart';
import '../ui/components/info/coverage_matrix.dart';
import '../ui/components/info/notice_banner.dart';
import '../ui/components/info/plan_settings_explainer.dart';
import '../ui/components/max_width.dart';
import '../ui/components/premium_card.dart';
import '../ui/components/section.dart';
import '../ui/components/section_break.dart';
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
              detail: 'Broken bones, bite wounds, swallowed objects, toxic ingestions',
              accidentIllness: CoverageMark.yes,
              accidentOnly: CoverageMark.yes,
            ),
            CoverageMatrixRow(
              title: 'Illnesses',
              detail: 'Infections, parasites, ear infections, GI issues',
              accidentIllness: CoverageMark.yes,
              accidentOnly: CoverageMark.no,
            ),
            CoverageMatrixRow(
              title: 'Chronic conditions',
              detail: 'Allergies, diabetes, arthritis',
              accidentIllness: CoverageMark.sometimes,
              accidentOnly: CoverageMark.no,
              footnote: 'Eligible after waiting periods if not pre-existing.',
            ),
            CoverageMatrixRow(
              title: 'Cancer & serious disease',
              detail: 'Cancer treatment, heart disease, kidney disease',
              accidentIllness: CoverageMark.yes,
              accidentOnly: CoverageMark.no,
              footnote: 'Eligibility depends on policy terms and medical records.',
            ),
            CoverageMatrixRow(
              title: 'Hereditary conditions',
              detail: 'Hip dysplasia, breed-specific issues',
              accidentIllness: CoverageMark.sometimes,
              accidentOnly: CoverageMark.no,
              footnote: 'Eligible if not pre-existing and after waiting periods.',
            ),
            CoverageMatrixRow(
              title: 'Diagnostics',
              detail: 'X-rays, bloodwork, ultrasounds, MRIs, CT scans',
              accidentIllness: CoverageMark.yes,
              accidentOnly: CoverageMark.sometimes,
              footnote: 'Accident-only generally applies when diagnostics relate to an accident.',
            ),
            CoverageMatrixRow(
              title: 'Surgery & hospitalization',
              detail: 'Emergency care, overnight stays, anesthesia',
              accidentIllness: CoverageMark.yes,
              accidentOnly: CoverageMark.sometimes,
              footnote: 'Accident-only generally applies for accident-related surgery/care.',
            ),
            CoverageMatrixRow(
              title: 'Prescription medications',
              detail: 'Medications prescribed to treat covered conditions',
              accidentIllness: CoverageMark.yes,
              accidentOnly: CoverageMark.sometimes,
              footnote: 'Accident-only generally applies for accident-related prescriptions.',
            ),
          ]
        : const <CoverageMatrixRow>[
            CoverageMatrixRow(
              title: 'Physical injuries',
              detail: 'Broken bones, lacerations, bite wounds',
              accidentIllness: CoverageMark.yes,
              accidentOnly: CoverageMark.yes,
            ),
            CoverageMatrixRow(
              title: 'Swallowed objects',
              detail: 'Foreign body ingestion requiring treatment',
              accidentIllness: CoverageMark.yes,
              accidentOnly: CoverageMark.yes,
            ),
            CoverageMatrixRow(
              title: 'Toxic ingestions',
              detail: 'Poisoning from hazardous substances',
              accidentIllness: CoverageMark.yes,
              accidentOnly: CoverageMark.yes,
            ),
            CoverageMatrixRow(
              title: 'Emergency exams',
              detail: 'Emergency vet visits for accident-related issues',
              accidentIllness: CoverageMark.yes,
              accidentOnly: CoverageMark.yes,
            ),
            CoverageMatrixRow(
              title: 'Illnesses',
              detail: 'Infections, parasites, chronic or congenital disease',
              accidentIllness: CoverageMark.yes,
              accidentOnly: CoverageMark.no,
            ),
          ];

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
                      'Coverage you can understand',
                      style: Theme.of(context)
                          .textTheme
                          .displaySmall!
                          .copyWith(fontSize: 40),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'We believe transparency builds trust. Here\'s exactly what our plans cover, what they don\'t, and how the settings you choose affect reimbursement.',
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge!
                          .copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              right: ClipRRect(
                borderRadius: AppRadii.br24,
                child: Container(
                  color: AppColors.surface,
                  child: AspectRatio(
                    aspectRatio: 1.24,
                    child: Image.asset(
                      'assets/images/Cat at vet.png',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        const SectionBreak(fromColor: AppColors.background, toColor: AppColors.surface2),

        Section(
          backgroundColor: AppColors.surface2,
          child: MaxWidth(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Choose your coverage level',
                    style: Theme.of(context).textTheme.headlineSmall!),
                const SizedBox(height: 12),
                PremiumCard(
                  showShadow: false,
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PremiumSegmentedSwitch(
                        leftLabel: 'Accident & Illness',
                        rightLabel: 'Accident-only',
                        isLeftSelected: _selectedTab == CoverageTab.accidentIllness,
                        onLeft: () => setState(() => _selectedTab = CoverageTab.accidentIllness),
                        onRight: () => setState(() => _selectedTab = CoverageTab.accidentOnly),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _selectedTab == CoverageTab.accidentIllness
                            ? 'Comprehensive coverage for injuries, illnesses, and breed-specific conditions.'
                            : 'Basic protection focused on injuries and emergencies.',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium!
                            .copyWith(color: AppColors.textMuted),
                      ),
                    ],
                  ),
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
            child: CoverageMatrix(
              title: _selectedTab == CoverageTab.accidentIllness
                  ? 'Accident & Illness coverage at a glance'
                  : 'Accident-only coverage at a glance',
              subtitle: 'A quick comparison view. Specific eligibility depends on policy terms.',
              rows: rows,
            ),
          ),
        ),

        const SectionBreak(fromColor: AppColors.background, toColor: AppColors.surface2),

        Section(
          backgroundColor: AppColors.surface2,
          child: MaxWidth(
            child: const PlanSettingsExplainer(
              subtitle:
                  'Three settings shape your monthly premium and how much you get back when you file a claim.',
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
                Text('What\'s not covered',
                    style: Theme.of(context).textTheme.headlineSmall!),
                const SizedBox(height: 10),
                Text(
                  'These exclusions are standard across the pet insurance industry and help keep premiums affordable.',
                  style: Theme.of(context)
                      .textTheme
                      .bodyLarge!
                      .copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 14),
                const NoticeBanner(
                  tone: NoticeTone.info,
                  title: 'Pre-existing conditions are not covered',
                  body:
                      'If symptoms started before coverage begins—even without a diagnosis—related conditions may be considered pre-existing.',
                  icon: Icons.fact_check_outlined,
                ),
                const SizedBox(height: 12),
                const _ExclusionList(),
              ],
            ),
          ),
        ),

        Section(
          backgroundColor: AppColors.background,
          child: MaxWidth(
            child: GradientBorder(
              radius: AppRadii.br24,
              child: PremiumCard(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 720;
                    final copy = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Build your plan',
                            style: Theme.of(context).textTheme.headlineSmall!),
                        const SizedBox(height: 8),
                        Text(
                          'See pricing based on your pet\'s breed, age, and location.',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium!
                              .copyWith(color: AppColors.textMuted),
                        ),
                      ],
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
                        children: [
                          copy,
                          const SizedBox(height: 14),
                          action,
                        ],
                      );
                    }

                    return Row(
                      children: [
                        Expanded(child: copy),
                        const SizedBox(width: 14),
                        action,
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

class _PremiumSegmentedSwitch extends StatelessWidget {
  const _PremiumSegmentedSwitch({
    required this.leftLabel,
    required this.rightLabel,
    required this.isLeftSelected,
    required this.onLeft,
    required this.onRight,
  });

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
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _Segment(
              label: leftLabel,
              selected: isLeftSelected,
              onTap: onLeft,
            ),
          ),
          Expanded(
            child: _Segment(
              label: rightLabel,
              selected: !isLeftSelected,
              onTap: onRight,
            ),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

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
          color: selected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.borderStrong : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                color: selected ? AppColors.deepGreen : AppColors.textMuted,
              ),
        ),
      ),
    );
  }
}

class _ExclusionList extends StatelessWidget {
  const _ExclusionList();

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      showShadow: false,
      padding: EdgeInsets.zero,
      child: Column(
        children: const [
          _ExclusionRow(
            icon: Icons.history_toggle_off,
            title: 'Wellness & routine care',
            body:
                'Annual exams, vaccinations, flea prevention, and teeth cleaning (unless a wellness rider is offered).',
          ),
          Divider(height: 1, thickness: 1, color: AppColors.border),
          _ExclusionRow(
            icon: Icons.child_friendly_outlined,
            title: 'Breeding & pregnancy',
            body: 'Costs related to breeding, pregnancy, or whelping.',
          ),
          Divider(height: 1, thickness: 1, color: AppColors.border),
          _ExclusionRow(
            icon: Icons.face_retouching_off,
            title: 'Cosmetic procedures',
            body:
                'Tail docking, ear cropping, and similar procedures unless medically necessary.',
          ),
        ],
      ),
    );
  }
}

class _ExclusionRow extends StatelessWidget {
  const _ExclusionRow({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, size: 20, color: AppColors.textMuted),
          ),
          const SizedBox(width: 12),
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

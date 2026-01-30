// Home page
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../ui/components/gradient_border.dart';
import '../ui/components/max_width.dart';
import '../ui/components/premium_card.dart';
import '../ui/components/buttons.dart';
import '../ui/components/clovara_logo.dart';
import '../ui/components/section.dart';
import '../ui/components/section_break.dart';
import '../ui/tokens.dart';

import '../screens/underwriting_followup_documents_screen.dart';
import '../services/draft_service.dart';
import '../services/user_session_service.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Section(
          verticalPadding: 28,
          child: const MaxWidth(child: _HeroSection()),
        ),

        const SectionBreak(
          fromColor: AppColors.background,
          toColor: AppColors.surface2,
        ),

        Section(
          backgroundColor: AppColors.surface2,
          child: MaxWidth(child: const _ContinuationHub()),
        ),

        const SectionBreak(
          fromColor: AppColors.surface2,
          toColor: AppColors.background,
          flip: true,
        ),

        Section(
          child: MaxWidth(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 980;

                final headingStyle = Theme.of(
                  context,
                ).textTheme.headlineSmall!.copyWith(color: AppColors.deepGreen);

                final bodyStyle = Theme.of(context).textTheme.bodyLarge!
                    .copyWith(color: AppColors.textMuted, height: 1.5);

                final microStyle = Theme.of(context).textTheme.bodySmall!
                    .copyWith(
                      color: AppColors.textMuted,
                      height: 1.35,
                      fontWeight: FontWeight.w600,
                    );

                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('How Clovara works', style: headingStyle),
                    const SizedBox(height: 10),
                    Text(
                      'A few simple steps from quote to reimbursement. No jargon, no surprise rules.',
                      style: bodyStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),
                    SecondaryButton(
                      label: 'See the full process',
                      icon: Icons.arrow_forward,
                      onPressed: () => context.go('/how-it-works'),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We walk you through each step inside the quote flow.',
                      style: microStyle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );

                final timeline = const _HowClovaraWorksMiniCard();

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [copy, const SizedBox(height: 16), timeline],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 4, child: copy),
                    const SizedBox(width: 18),
                    Expanded(flex: 8, child: timeline),
                  ],
                );
              },
            ),
          ),
        ),

        const SectionBreak(
          fromColor: AppColors.background,
          toColor: AppColors.surface2,
        ),

        Section(
          backgroundColor: AppColors.surface2,
          child: MaxWidth(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked = constraints.maxWidth < 920;
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'What Accident & Illness covers',
                      style: Theme.of(context).textTheme.headlineSmall!,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Our standard plan is designed for the unexpected vet bills that matter most.',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 14),
                    SecondaryButton(
                      label: 'View coverage details',
                      icon: Icons.arrow_forward,
                      onPressed: () => context.go('/coverage'),
                    ),
                  ],
                );

                final list = _CoverageHighlightsGrid(
                  items: const [
                    _CoverageHighlight(
                      icon: Icons.medical_services_outlined,
                      title: 'Accidents & injuries',
                      body:
                          'Broken bones, bite wounds, swallowed objects, toxic ingestions.',
                    ),
                    _CoverageHighlight(
                      icon: Icons.sick_outlined,
                      title: 'Illnesses',
                      body:
                          'Infections, cancer, heart disease, chronic conditions.',
                    ),
                    _CoverageHighlight(
                      icon: Icons.biotech_outlined,
                      title: 'Diagnostics',
                      body: 'X-rays, bloodwork, ultrasounds, MRIs, CT scans.',
                    ),
                    _CoverageHighlight(
                      icon: Icons.local_hospital_outlined,
                      title: 'Surgery & hospitalization',
                      body:
                          'Emergency surgery, overnight stays, and intensive care.',
                    ),
                  ],
                );

                if (stacked) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [copy, const SizedBox(height: 16), list],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: copy),
                    const SizedBox(width: 18),
                    Expanded(flex: 7, child: list),
                  ],
                );
              },
            ),
          ),
        ),

        const SectionBreak(
          fromColor: AppColors.surface2,
          toColor: AppColors.background,
          flip: true,
        ),

        Section(
          verticalPadding: 24,
          child: MaxWidth(
            maxWidth: 1200,
            child: GradientBorder(
              radius: AppRadii.br24,
              child: PremiumCard(
                showShadow: false,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 22,
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final stacked = constraints.maxWidth < 720;
                    final copy = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ready to protect your pet?',
                          style: Theme.of(context).textTheme.headlineSmall!,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start a quote and customize your coverage in a few simple steps.',
                          style: Theme.of(context).textTheme.bodyMedium!
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
                        children: [copy, const SizedBox(height: 14), action],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
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

class _HeroSection extends StatelessWidget {
  const _HeroSection();

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
            const innerGap = 24.0;

            final headingStyle = Theme.of(context).textTheme.displaySmall!
                .copyWith(
                  fontSize: isDesktop ? 44 : 38,
                  height: 1.06,
                  fontWeight: FontWeight.w800,
                  color: AppColors.deepGreen,
                  letterSpacing: -0.6,
                );

            final bodyStyle = Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: AppColors.textMuted,
              height: 1.6,
              fontSize: isDesktop ? 19 : (isMobile ? 17 : 18),
            );

            final helperStyle = Theme.of(context).textTheme.bodySmall!.copyWith(
              color: AppColors.textMuted,
              height: 1.35,
              fontWeight: FontWeight.w600,
              fontSize: isMobile ? 15 : 15.5,
            );

            final cta = LayoutBuilder(
              builder: (context, c) {
                final fullWidth = c.maxWidth < 520;
                final buttonWidth = fullWidth ? double.infinity : 320.0;

                return Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: buttonWidth,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          height: 56,
                          child: PrimaryButton(
                            label: 'Get a quote',
                            icon: Icons.pets,
                            textStyle: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                            onPressed: () => context.go('/quote'),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Takes about 2 minutes. No phone calls, no spam.',
                          style: helperStyle,
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );

            final left = ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ClovaraLogoLockup(
                    compact: true,
                    boxedMark: false,
                    markSize: 22,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Pet insurance that actually makes sense.',
                    style: headingStyle,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'See what\'s covered, what you\'ll pay, and how claims work—before you enroll. Straightforward coverage for your dog or cat.',
                    style: bodyStyle,
                  ),
                  const SizedBox(height: 20),
                  cta,
                ],
              ),
            );

            final image = ClipRRect(
              borderRadius: AppRadii.br24,
              child: Container(
                color: AppColors.surface,
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.asset(
                    'assets/images/HOMEPAGE IMAGE.png',
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
              ),
            );

            final features = const _HeroFeatureRow(
              items: [
                _HeroFeature(
                  icon: Icons.pets,
                  title: 'Dogs & cats',
                  body: 'Plans built around real-world vet bills.',
                ),
                _HeroFeature(
                  icon: Icons.verified_rounded,
                  title: 'Any licensed vet',
                  body: 'Use your favorite clinic—no networks.',
                ),
                _HeroFeature(
                  icon: Icons.receipt_long_rounded,
                  title: 'Clear reimbursements',
                  body: 'Know your deductible and % before you enroll.',
                ),
                _HeroFeature(
                  icon: Icons.pause_circle_outline,
                  title: 'Pause anytime',
                  body: 'Adjust or pause without starting over.',
                ),
              ],
            );

            final top = isMobile
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [left, const SizedBox(height: 24), image],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(flex: 11, child: left),
                      const SizedBox(width: innerGap),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [top, const SizedBox(height: 24), features],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ContinuationHub extends StatefulWidget {
  const _ContinuationHub();

  @override
  State<_ContinuationHub> createState() => _ContinuationHubState();
}

class _ContinuationHubState extends State<_ContinuationHub> {
  bool _resuming = false;

  Future<void> _resumeFromKey(String key) async {
    setState(() => _resuming = true);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: SizedBox(
          height: 72,
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Text('Resuming…'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final resolved = await DraftService().resolveAndAdoptDraft(
        resumeKey: key,
      );

      if (resolved.draftType == 'quote') {
        await UserSessionService().savePendingQuote(resolved.snapshot);
      } else if (resolved.draftType == 'checkout') {
        await UserSessionService().savePendingCheckout(resolved.snapshot);
      } else {
        final caseId = resolved.snapshot['underwritingCaseId']?.toString();
        if (caseId != null && caseId.trim().isNotEmpty) {
          await UserSessionService().savePendingUnderwriting(
            underwritingCaseId: caseId.trim(),
            petName: (resolved.snapshot['petName'] ?? 'your pet').toString(),
            riskScore: resolved.snapshot['riskScore'],
            reason: resolved.snapshot['reason']?.toString(),
            requiredEvidence: (resolved.snapshot['requiredEvidence'] is List)
                ? (resolved.snapshot['requiredEvidence'] as List)
                      .whereType<Map>()
                      .map((e) => e.cast<String, dynamic>())
                      .toList(growable: false)
                : const [],
          );
        }
      }

      if (mounted) Navigator.pop(context);
      if (!mounted) return;

      if (resolved.draftType == 'quote') {
        context.push('/conversational-quote');
        return;
      }

      if (resolved.draftType == 'checkout') {
        final pet = resolved.snapshot['pet'];
        final selectedPlan = resolved.snapshot['selectedPlan'];
        if (pet != null && selectedPlan != null) {
          context.push(
            '/checkout',
            extra: {
              'pet': pet,
              'selectedPlan': selectedPlan,
              'underwritingCaseId': resolved.snapshot['underwritingCaseId']
                  ?.toString(),
              'exclusions': resolved.snapshot['exclusions'],
              'underwritingSnapshot': resolved.snapshot['underwritingSnapshot'],
            },
          );
          return;
        }
      }

      final caseId = resolved.snapshot['underwritingCaseId']?.toString();
      if (caseId != null && caseId.trim().isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UnderwritingFollowUpDocumentsScreen(
              underwritingCaseId: caseId.trim(),
            ),
          ),
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Draft restored, but nothing to resume.')),
      );
    } catch (e) {
      if (mounted) Navigator.pop(context);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to resume: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _resuming = false);
    }
  }

  Future<void> _openCodeDialog() async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Resume with code'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Paste your resume code',
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final data = await Clipboard.getData('text/plain');
                final text = (data?.text ?? '').trim();
                if (text.isNotEmpty) controller.text = text;
              },
              child: const Text('Paste'),
            ),
            ElevatedButton(
              onPressed: () {
                final key = controller.text.trim();
                Navigator.pop(context);
                if (key.isNotEmpty) _resumeFromKey(key);
              },
              child: const Text('Resume'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final eyebrowStyle = Theme.of(context).textTheme.labelLarge!.copyWith(
      color: AppColors.textMuted,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.2,
    );

    final headingStyle = Theme.of(context).textTheme.headlineSmall!.copyWith(
      color: AppColors.deepGreen,
      fontWeight: FontWeight.w800,
    );

    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodyMedium!.copyWith(color: AppColors.textMuted, height: 1.5);

    return FutureBuilder<String?>(
      future: DraftService().getLocalResumeKey(),
      builder: (context, snapshot) {
        final localKey = snapshot.data;

        return LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 1024;
            final containerPadding = EdgeInsets.symmetric(
              vertical: 24,
              horizontal: isDesktop ? 32 : 20,
            );

            final left = _ContinuationColumn(
              eyebrow: 'Already started?',
              heading: 'Pick up where you left off.',
              body: 'Resume a quote or manage your policy from any device.',
              eyebrowStyle: eyebrowStyle,
              headingStyle: headingStyle,
              bodyStyle: bodyStyle,
              child: _ResumeButtons(
                isDesktop: isDesktop,
                isLoading: _resuming,
                onEnterResumeCode: _resuming
                    ? null
                    : () {
                        if (localKey != null) {
                          _resumeFromKey(localKey);
                        } else {
                          _openCodeDialog();
                        }
                      },
                onPasteCode: _resuming
                    ? null
                    : () async {
                        final data = await Clipboard.getData('text/plain');
                        final text = (data?.text ?? '').trim();
                        if (text.isNotEmpty) {
                          _resumeFromKey(text);
                        } else {
                          _openCodeDialog();
                        }
                      },
              ),
            );

            final right = _ContinuationColumn(
              eyebrow: 'New here?',
              heading: 'Start fresh in a few minutes.',
              body:
                  'Get a new quote, learn how claims work, or sign in to your account.',
              eyebrowStyle: eyebrowStyle,
              headingStyle: headingStyle,
              bodyStyle: bodyStyle,
              child: Column(
                children: [
                  _ContinuationActionRow(
                    icon: Icons.pets,
                    title: 'Get a quote',
                    description:
                        'Answer a few questions, see pricing, and customize your plan.',
                    onTap: () => context.go('/quote'),
                    isPrimary: true,
                  ),
                  const SizedBox(height: 10),
                  _ContinuationActionRow(
                    icon: Icons.receipt_long_outlined,
                    title: 'Claims basics',
                    description:
                        'Know what to submit and how reimbursements work.',
                    onTap: () => context.go('/learn/claims-basics'),
                  ),
                  const SizedBox(height: 10),
                  _ContinuationActionRow(
                    icon: Icons.person_outline,
                    title: 'Sign in',
                    description:
                        'Manage your policy, billing, and claims in one place.',
                    onTap: () => context.go('/sign-in'),
                  ),
                ],
              ),
            );

            return SizedBox(
              width: double.infinity,
              child: PremiumCard(
                padding: containerPadding,
                backgroundColor: AppColors.surface,
                child: isDesktop
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 24),
                              child: left,
                            ),
                          ),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.only(left: 24),
                              decoration: BoxDecoration(
                                border: Border(
                                  left: BorderSide(color: AppColors.borderTint),
                                ),
                              ),
                              child: right,
                            ),
                          ),
                        ],
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          left,
                          const SizedBox(height: 28),
                          Divider(height: 1, color: AppColors.borderTint),
                          const SizedBox(height: 28),
                          right,
                        ],
                      ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ContinuationColumn extends StatelessWidget {
  const _ContinuationColumn({
    required this.eyebrow,
    required this.heading,
    required this.body,
    required this.eyebrowStyle,
    required this.headingStyle,
    required this.bodyStyle,
    required this.child,
  });

  final String eyebrow;
  final String heading;
  final String body;
  final TextStyle eyebrowStyle;
  final TextStyle headingStyle;
  final TextStyle bodyStyle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(eyebrow, style: eyebrowStyle),
        const SizedBox(height: 10),
        Text(heading, style: headingStyle),
        const SizedBox(height: 10),
        Text(body, style: bodyStyle),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _ResumeButtons extends StatelessWidget {
  const _ResumeButtons({
    required this.isDesktop,
    required this.isLoading,
    required this.onEnterResumeCode,
    required this.onPasteCode,
  });

  final bool isDesktop;
  final bool isLoading;
  final VoidCallback? onEnterResumeCode;
  final VoidCallback? onPasteCode;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = !isDesktop || constraints.maxWidth < 420;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 52,
                child: PrimaryButton(
                  label: 'Enter resume code',
                  icon: Icons.key,
                  isLoading: isLoading,
                  onPressed: onEnterResumeCode,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 52,
                child: SecondaryButton(
                  label: 'Paste a code',
                  icon: Icons.content_paste,
                  onPressed: onPasteCode,
                ),
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: PrimaryButton(
                  label: 'Enter resume code',
                  icon: Icons.key,
                  isLoading: isLoading,
                  onPressed: onEnterResumeCode,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: SecondaryButton(
                  label: 'Paste a code',
                  icon: Icons.content_paste,
                  onPressed: onPasteCode,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ContinuationActionRow extends StatefulWidget {
  const _ContinuationActionRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;
  final bool isPrimary;

  @override
  State<_ContinuationActionRow> createState() => _ContinuationActionRowState();
}

class _ContinuationActionRowState extends State<_ContinuationActionRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium!.copyWith(
      color: AppColors.deepGreen,
      fontWeight: FontWeight.w800,
    );

    final descStyle = Theme.of(
      context,
    ).textTheme.bodySmall!.copyWith(color: AppColors.textMuted, height: 1.35);

    final bg = _hovered ? AppColors.surface3 : AppColors.surface2;
    final border = _hovered ? AppColors.border : AppColors.borderTint;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: AppRadii.br16,
        border: Border.all(color: border),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: AppRadii.br16,
          onTap: widget.onTap,
          onHover: (v) => setState(() => _hovered = v),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.borderTint),
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.isPrimary
                        ? AppColors.deepGreen
                        : AppColors.deepGreen.withOpacity(0.85),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: titleStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.description,
                        style: descStyle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HowClovaraWorksMiniCard extends StatelessWidget {
  const _HowClovaraWorksMiniCard();

  @override
  Widget build(BuildContext context) {
    final groupTitleStyle = Theme.of(context).textTheme.titleMedium!.copyWith(
      color: AppColors.deepGreen,
      fontWeight: FontWeight.w800,
    );

    final stepTitleStyle = Theme.of(context).textTheme.bodyMedium!.copyWith(
      color: AppColors.deepGreen,
      fontWeight: FontWeight.w800,
      height: 1.25,
    );

    final stepDescStyle = Theme.of(
      context,
    ).textTheme.bodySmall!.copyWith(color: AppColors.textMuted, height: 1.25);

    return PremiumCard(
      padding: const EdgeInsets.all(18),
      backgroundColor: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _MiniProcessGroup(
            icon: Icons.calculate_outlined,
            title: 'Quote',
            titleStyle: groupTitleStyle,
            steps: [
              _MiniProcessStep(
                number: 1,
                title: 'Get a quote',
                description: 'Tell us about your pet and where you live.',
              ),
              _MiniProcessStep(
                number: 2,
                title: 'Choose your plan',
                description:
                    'Pick your deductible, reimbursement %, and annual limit.',
              ),
            ],
            stepTitleStyle: stepTitleStyle,
            stepDescStyle: stepDescStyle,
          ),
          const SizedBox(height: 14),
          _MiniProcessGroup(
            icon: Icons.verified_user_outlined,
            title: 'Enroll',
            titleStyle: groupTitleStyle,
            steps: [
              _MiniProcessStep(
                number: 3,
                title: 'Start coverage',
                description:
                    'Complete checkout; coverage begins after waiting periods.',
              ),
            ],
            stepTitleStyle: stepTitleStyle,
            stepDescStyle: stepDescStyle,
          ),
          const SizedBox(height: 14),
          _MiniProcessGroup(
            icon: Icons.health_and_safety_outlined,
            title: 'Use your plan',
            titleStyle: groupTitleStyle,
            steps: [
              _MiniProcessStep(
                number: 4,
                title: 'Visit any vet',
                description: 'Go to any licensed vet and pay at checkout.',
              ),
              _MiniProcessStep(
                number: 5,
                title: 'Submit a claim',
                description: 'Upload your invoice and medical notes online.',
              ),
              _MiniProcessStep(
                number: 6,
                title: 'Get reimbursed',
                description:
                    'We review your claim and send your reimbursement.',
              ),
            ],
            stepTitleStyle: stepTitleStyle,
            stepDescStyle: stepDescStyle,
          ),
        ],
      ),
    );
  }
}

class _MiniProcessStep {
  const _MiniProcessStep({
    required this.number,
    required this.title,
    required this.description,
  });

  final int number;
  final String title;
  final String description;
}

class _MiniProcessGroup extends StatelessWidget {
  const _MiniProcessGroup({
    required this.icon,
    required this.title,
    required this.titleStyle,
    required this.steps,
    required this.stepTitleStyle,
    required this.stepDescStyle,
  });

  final IconData icon;
  final String title;
  final TextStyle titleStyle;
  final List<_MiniProcessStep> steps;
  final TextStyle stepTitleStyle;
  final TextStyle stepDescStyle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                color: AppColors.surface3,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderTint),
              ),
              child: Icon(icon, size: 16, color: AppColors.deepGreen),
            ),
            const SizedBox(width: 10),
            Text(title, style: titleStyle),
          ],
        ),
        const SizedBox(height: 10),
        for (int i = 0; i < steps.length; i++) ...[
          _MiniProcessStepRow(
            step: steps[i],
            isFirst: i == 0,
            isLast: i == steps.length - 1,
            titleStyle: stepTitleStyle,
            descStyle: stepDescStyle,
          ),
        ],
      ],
    );
  }
}

class _MiniProcessStepRow extends StatelessWidget {
  const _MiniProcessStepRow({
    required this.step,
    required this.isFirst,
    required this.isLast,
    required this.titleStyle,
    required this.descStyle,
  });

  final _MiniProcessStep step;
  final bool isFirst;
  final bool isLast;
  final TextStyle titleStyle;
  final TextStyle descStyle;

  @override
  Widget build(BuildContext context) {
    const badgeSize = 22.0;
    const gutterWidth = 28.0;
    const lineWidth = 1.0;
    const gapToPrevious = 10.0;
    const gapToNext = 10.0;

    final lineColor = AppColors.borderTint;
    final badgeBorder = AppColors.border;

    final badge = Container(
      height: badgeSize,
      width: badgeSize,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: badgeBorder),
      ),
      child: Center(
        child: Text(
          '${step.number}',
          style: Theme.of(context).textTheme.labelMedium!.copyWith(
            color: AppColors.deepGreen,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );

    return Stack(
      children: [
        if (!isFirst)
          Positioned(
            left: (badgeSize / 2) - (lineWidth / 2),
            top: 0,
            height: gapToPrevious,
            child: Container(width: lineWidth, color: lineColor),
          ),
        if (!isLast)
          Positioned(
            left: (badgeSize / 2) - (lineWidth / 2),
            top: badgeSize + 4,
            bottom: 0,
            child: Container(width: lineWidth, color: lineColor),
          ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: gutterWidth,
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
                    step.description,
                    style: descStyle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (!isLast) const SizedBox(height: gapToNext),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _HeroFeature {
  const _HeroFeature({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _HeroFeatureRow extends StatelessWidget {
  const _HeroFeatureRow({required this.items});

  final List<_HeroFeature> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final cols = w >= 1024
            ? 4
            : w >= 768
            ? 2
            : 1;

        const gap = 12.0;
        // Ensure enough vertical room for icon + 2-line title + 2-line body
        // across common web font scaling.
        final tileMinHeight = cols == 4 ? 192.0 : 148.0;
        final centerText = cols == 1;

        if (cols == 4) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (int i = 0; i < items.length; i++) ...[
                Expanded(
                  child: _HeroFeatureCard(
                    item: items[i],
                    minHeight: tileMinHeight,
                    centerText: centerText,
                  ),
                ),
                if (i != items.length - 1) const SizedBox(width: gap),
              ],
            ],
          );
        }

        if (cols == 2) {
          Widget rowFor(int i0, int i1) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _HeroFeatureCard(
                    item: items[i0],
                    minHeight: tileMinHeight,
                    centerText: centerText,
                  ),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: _HeroFeatureCard(
                    item: items[i1],
                    minHeight: tileMinHeight,
                    centerText: centerText,
                  ),
                ),
              ],
            );
          }

          return Column(
            children: [
              rowFor(0, 1),
              const SizedBox(height: gap),
              rowFor(2, 3),
            ],
          );
        }

        return Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              _HeroFeatureCard(
                item: items[i],
                minHeight: tileMinHeight,
                centerText: centerText,
              ),
              if (i != items.length - 1) const SizedBox(height: gap),
            ],
          ],
        );
      },
    );
  }
}

class _HeroFeatureCard extends StatelessWidget {
  const _HeroFeatureCard({
    required this.item,
    required this.minHeight,
    required this.centerText,
  });

  final _HeroFeature item;
  final double minHeight;
  final bool centerText;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTightHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight <= 152;
        final effectiveMinHeight =
            (constraints.maxHeight.isFinite &&
                constraints.maxHeight < minHeight)
            ? 0.0
            : minHeight;

        final titleStyle = Theme.of(context).textTheme.titleMedium!.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.deepGreen,
          height: 1.15,
          fontSize: isTightHeight ? 14.5 : null,
        );

        final bodyStyle = Theme.of(context).textTheme.bodySmall!.copyWith(
          color: AppColors.textMuted,
          height: 1.35,
          fontSize: isTightHeight ? 12.5 : null,
        );

        final iconBox = isTightHeight ? 48.0 : 56.0;
        final iconSize = isTightHeight ? 24.0 : 28.0;
        final pad = isTightHeight ? 14.0 : 16.0;
        final titleLines = isTightHeight ? 1 : 2;
        final bodyLines = isTightHeight ? 1 : 2;

        return ConstrainedBox(
          constraints: BoxConstraints(minHeight: effectiveMinHeight),
          child: Container(
            padding: EdgeInsets.all(pad),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppRadii.br16,
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: centerText
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Container(
                    height: iconBox,
                    width: iconBox,
                    decoration: BoxDecoration(
                      color: AppColors.surface3,
                      borderRadius: BorderRadius.circular(
                        isTightHeight ? 16 : 18,
                      ),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Icon(
                      item.icon,
                      size: iconSize,
                      color: AppColors.deepGreen,
                    ),
                  ),
                ),
                SizedBox(height: isTightHeight ? 10 : 12),
                Text(
                  item.title,
                  style: titleStyle,
                  textAlign: centerText ? TextAlign.center : TextAlign.start,
                  maxLines: titleLines,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
                SizedBox(height: isTightHeight ? 6 : 8),
                Text(
                  item.body,
                  style: bodyStyle,
                  textAlign: centerText ? TextAlign.center : TextAlign.start,
                  maxLines: bodyLines,
                  overflow: TextOverflow.ellipsis,
                  softWrap: true,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CoverageHighlight {
  const _CoverageHighlight({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _CoverageHighlightsGrid extends StatelessWidget {
  const _CoverageHighlightsGrid({required this.items});

  final List<_CoverageHighlight> items;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      showShadow: false,
      padding: const EdgeInsets.all(18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final cols = w >= 560 ? 2 : 1;
          const gap = 12.0;

          // Desktop/tablet: fixed-height 2x2 grid for perfect alignment.
          // Mobile: natural-height tiles to avoid extra empty space.
          if (cols == 1) {
            return Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  _CoverageTile(item: items[i], expand: false),
                  if (i != items.length - 1) const SizedBox(height: gap),
                ],
              ],
            );
          }

          // Slightly taller to avoid web overflows with the refined copy.
          const tileHeight = 184.0;

          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: gap,
              crossAxisSpacing: gap,
              mainAxisExtent: tileHeight,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              return _CoverageTile(item: items[index], expand: true);
            },
          );
        },
      ),
    );
  }
}

class _CoverageTile extends StatelessWidget {
  const _CoverageTile({required this.item, required this.expand});

  final _CoverageHighlight item;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final titleStyle = Theme.of(context).textTheme.titleMedium!.copyWith(
      color: AppColors.deepGreen,
      fontWeight: FontWeight.w800,
      height: 1.1,
    );

    final bodyStyle = Theme.of(
      context,
    ).textTheme.bodySmall!.copyWith(color: AppColors.textMuted, height: 1.35);

    final tile = Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadii.br16,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(item.icon, size: 19, color: AppColors.deepGreen),
          ),
          const SizedBox(height: 8),
          Text(
            item.title,
            style: titleStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            item.body,
            style: bodyStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );

    return expand ? SizedBox.expand(child: tile) : tile;
  }
}

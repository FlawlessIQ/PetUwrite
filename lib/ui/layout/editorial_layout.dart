import 'package:flutter/material.dart';
import '../tokens.dart';

/// A full-width section with optional background color.
/// Used to create the rhythm of alternating surfaces.
class EditorialSection extends StatelessWidget {
  const EditorialSection({
    super.key,
    required this.child,
    this.backgroundColor,
    this.padding = const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
    this.innerMaxWidth = 1200,
  });

  final Widget child;
  final Color? backgroundColor;
  final EdgeInsets padding;
  final double innerMaxWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: backgroundColor,
      child: Padding(
        padding: padding,
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: innerMaxWidth),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// A full-width editorial hero with confident typography and image bleed.
/// The image can be placed on the right or work as a background accent.
class EditorialHero extends StatelessWidget {
  const EditorialHero({
    super.key,
    required this.title,
    required this.subtitle,
    required this.primaryCta,
    this.secondaryCta,
    this.image,
    this.backgroundColor = AppColors.surface2,
  });

  final String title;
  final String subtitle;
  final Widget primaryCta;
  final Widget? secondaryCta;
  final Widget? image;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    // Determine if we are on mobile or desktop based on constraints
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth > 900;
        final theme = Theme.of(context);

        if (!isDesktop) {
          // Mobile Layout: Vertical stack
          return Container(
            color: backgroundColor,
            padding: const EdgeInsets.fromLTRB(24, 60, 24, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 42,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  subtitle,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    primaryCta,
                    if (secondaryCta != null) secondaryCta!,
                  ],
                ),
                if (image != null) ...[const SizedBox(height: 48), image!],
              ],
            ),
          );
        }

        // Desktop Layout: Side by side with bleed
        // We use a Stack-like approach or Row depending on the bleed effect wanted.
        return Container(
          color: backgroundColor,
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 600),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              // Content Left (constrained width)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1200),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 80,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: theme.textTheme.displaySmall?.copyWith(
                                  fontSize: 64, // Larger, more confident
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.5,
                                  height: 1.05,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                subtitle,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w400,
                                  color: AppColors.textMuted,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 40),
                              Row(
                                children: [
                                  primaryCta,
                                  if (secondaryCta != null) ...[
                                    const SizedBox(width: 16),
                                    secondaryCta!,
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      // Spacer for the right side image
                      const Expanded(flex: 5, child: SizedBox()),
                    ],
                  ),
                ),
              ),

              // Image Right (Bleed to edge)
              if (image != null)
                Positioned(
                  top: 0,
                  bottom: 0,
                  right: 0,
                  width:
                      MediaQuery.of(context).size.width *
                      0.45, // approx 45% width
                  child: ClipRect(
                    child: Transform.translate(
                      offset: const Offset(40, 0), // Slight push
                      child: image!,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// A 2-column layout for editorial content lists (e.g. "What's Covered").
class EditorialSplitList extends StatelessWidget {
  const EditorialSplitList({
    super.key,
    required this.heading,
    required this.description,
    required this.items,
  });

  final String heading;
  final String description;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 800) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(heading, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 16),
              Text(
                description,
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 40),
              ...items.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: e,
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    heading,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 18,
                      color: AppColors.textMuted,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 64),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                // Use slightly tighter comfortable dense spacing for the list items
                children: items
                    .map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: 32),
                        child: e,
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Use this for items inside EditorialSplitList
class EditorialListItem extends StatelessWidget {
  const EditorialListItem({
    super.key,
    required this.title,
    required this.body,
    this.icon,
  });

  final String title;
  final String body;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.deepGreen, size: 20),
          ),
          const SizedBox(width: 16),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.textSubtle),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A vertical timeline without boxes.
class EditorialTimeline extends StatelessWidget {
  const EditorialTimeline({super.key, required this.steps});

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: steps.asMap().entries.map((entry) {
        final index = entry.key;
        final step = entry.value;
        final isLast = index == steps.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Timeline line
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surface1,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.deepGreen,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.deepGreen,
                          ),
                        ),
                      ),
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(width: 2, color: AppColors.borderTint),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 64),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        step.description,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class TimelineStep {
  final String title;
  final String description;

  const TimelineStep({required this.title, required this.description});
}

class EditorialComparisonRow extends StatelessWidget {
  const EditorialComparisonRow({super.key, required this.plans});

  final List<ComparisonPlan> plans;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            children: plans
                .map(
                  (p) => Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: _PlanPanel(plan: p),
                  ),
                )
                .toList(),
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: plans
              .map(
                (p) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _PlanPanel(plan: p),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class ComparisonPlan {
  final String title;
  final String price;
  final String description;
  final List<String> features;
  final bool isRecommended;

  const ComparisonPlan({
    required this.title,
    required this.price,
    required this.description,
    required this.features,
    this.isRecommended = false,
  });
}

class _PlanPanel extends StatelessWidget {
  const _PlanPanel({required this.plan});

  final ComparisonPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: plan.isRecommended ? AppColors.surface1 : Colors.transparent,
        border: Border.all(
          color: plan.isRecommended ? AppColors.green : AppColors.border,
          width: plan.isRecommended ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: plan.isRecommended ? AppShadows.soft : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (plan.isRecommended) ...[
            Text(
              'MOST POPULAR',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.green,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            plan.title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            plan.price,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Text(
            plan.description,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textMuted,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          ...plan.features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check, size: 18, color: AppColors.green),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      f,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

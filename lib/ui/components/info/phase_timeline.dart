import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../badges.dart';
import '../premium_card.dart';

class PhaseTimelineStep {
  const PhaseTimelineStep({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;
}

class PhaseTimelinePhase {
  const PhaseTimelinePhase({
    required this.label,
    required this.steps,
  });

  final String label;
  final List<PhaseTimelineStep> steps;
}

class PhaseTimeline extends StatelessWidget {
  const PhaseTimeline({
    super.key,
    required this.phases,
  }) : assert(phases.length > 0);

  final List<PhaseTimelinePhase> phases;

  @override
  Widget build(BuildContext context) {
    int stepNumber = 0;

    return PremiumCard(
      showShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int p = 0; p < phases.length; p++) ...[
            if (p != 0) const SizedBox(height: 14),
            Text(
              phases[p].label,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w900,
                    color: AppColors.deepGreen,
                  ),
            ),
            const SizedBox(height: 10),
            for (int s = 0; s < phases[p].steps.length; s++) ...[
              _PhaseStepRow(
                number: ++stepNumber,
                step: phases[p].steps[s],
                showConnector: !(p == phases.length - 1 &&
                    s == phases[p].steps.length - 1),
              ),
              if (!(p == phases.length - 1 && s == phases[p].steps.length - 1))
                const SizedBox(height: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _PhaseStepRow extends StatelessWidget {
  const _PhaseStepRow({
    required this.number,
    required this.step,
    required this.showConnector,
  });

  final int number;
  final PhaseTimelineStep step;
  final bool showConnector;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              height: 30,
              width: 30,
              decoration: BoxDecoration(
                color: AppColors.deepGreen,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  number.toString(),
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
            ),
            if (showConnector)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 10),
                width: 2,
                height: 26,
                color: AppColors.borderStrong,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(icon: step.icon, size: 38),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step.title,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.deepGreen,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                step.description,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(color: AppColors.textMuted, height: 1.55),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

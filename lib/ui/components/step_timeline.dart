import 'package:flutter/material.dart';

import '../tokens.dart';
import 'badges.dart';
import 'premium_card.dart';

class TimelineStep {
  TimelineStep({
    required this.title,
    required this.description,
    required this.icon,
    this.imageSlotLabel,
  });

  final String title;
  final String description;
  final IconData icon;
  final String? imageSlotLabel;
}

class StepTimeline extends StatelessWidget {
  const StepTimeline({
    super.key,
    required this.steps,
  });

  final List<TimelineStep> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < steps.length; i++) ...[
          _StepRow(step: steps[i], index: i + 1, isLast: i == steps.length - 1),
          if (i != steps.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({required this.step, required this.index, required this.isLast});

  final TimelineStep step;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                height: 34,
                width: 34,
                decoration: BoxDecoration(
                  color: AppColors.deepGreen,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    index.toString(),
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium!
                        .copyWith(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
              if (!isLast)
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 2,
                  height: 40,
                  color: AppColors.borderStrong,
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconBadge(icon: step.icon, size: 40),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.title,
                            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                                  fontSize: 18,
                                  color: AppColors.deepGreen,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            step.description,
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
                if (step.imageSlotLabel != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: AppRadii.br16,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Center(
                      child: Text(
                        step.imageSlotLabel!,
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                              color: AppColors.textSubtle,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

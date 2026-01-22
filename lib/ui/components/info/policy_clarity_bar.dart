import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../badges.dart';
import '../premium_card.dart';

class PolicyClarityItem {
  const PolicyClarityItem({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class PolicyClarityBar extends StatelessWidget {
  const PolicyClarityBar({
    super.key,
    required this.items,
  }) : assert(items.length > 0);

  final List<PolicyClarityItem> items;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      showShadow: false,
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final cols = w >= 980
              ? 4
              : w >= 720
                  ? 2
                  : 1;

          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final item in items)
                SizedBox(
                  width: cols == 1
                      ? w
                      : (w - (14 * (cols - 1))) / cols,
                  child: _ClarityTile(item: item),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ClarityTile extends StatelessWidget {
  const _ClarityTile({required this.item});

  final PolicyClarityItem item;

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
          IconBadge(icon: item.icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.deepGreen,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.body,
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

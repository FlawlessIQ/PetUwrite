import 'package:flutter/material.dart';

import '../../tokens.dart';
import '../badges.dart';
import '../premium_card.dart';

class ChecklistItem {
  const ChecklistItem({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;
}

class ChecklistPanel extends StatelessWidget {
  const ChecklistPanel({
    super.key,
    required this.title,
    required this.items,
  });

  final String title;
  final List<ChecklistItem> items;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      showShadow: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.deepGreen,
                ),
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < items.length; i++) ...[
            _Row(item: items[i]),
            if (i != items.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Divider(height: 1, thickness: 1, color: AppColors.border),
              ),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.item});

  final ChecklistItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
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
    );
  }
}

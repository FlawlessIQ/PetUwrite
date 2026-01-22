import 'package:flutter/material.dart';

import '../tokens.dart';
import 'badges.dart';
import 'buttons.dart';
import 'premium_card.dart';

class QuickActionCard extends StatelessWidget {
  const QuickActionCard({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.ctaLabel,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final String ctaLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon),
          const SizedBox(height: 12),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  fontSize: 18,
                  color: AppColors.deepGreen,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Align(
            alignment: Alignment.centerLeft,
            child: SecondaryButton(label: ctaLabel, onPressed: onTap),
          ),
        ],
      ),
    );
  }
}

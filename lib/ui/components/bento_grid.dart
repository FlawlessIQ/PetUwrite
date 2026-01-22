import 'package:flutter/material.dart';

import '../tokens.dart';
import 'premium_card.dart';

class BentoGrid extends StatelessWidget {
  const BentoGrid({
    super.key,
    required this.primary,
    required this.secondary,
    this.gap = 12,
  });

  final Widget primary;
  final List<Widget> secondary;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;

        if (w < 640) {
          return Column(
            children: [
              primary,
              SizedBox(height: gap),
              for (int i = 0; i < secondary.length; i++) ...[
                secondary[i],
                if (i != secondary.length - 1) SizedBox(height: gap),
              ],
            ],
          );
        }

        if (w < 980) {
          final tiles = <Widget>[primary, ...secondary];
          final colWidth = (w - gap) / 2;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final tile in tiles) SizedBox(width: colWidth, child: tile),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 7, child: primary),
            SizedBox(width: gap),
            Expanded(
              flex: 5,
              child: Column(
                children: [
                  for (int i = 0; i < secondary.length; i++) ...[
                    secondary[i],
                    if (i != secondary.length - 1) SizedBox(height: gap),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class MiniFeatureTile extends StatelessWidget {
  const MiniFeatureTile({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Icon(icon, color: AppColors.deepGreen, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: AppColors.deepGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class StatChipTile extends StatelessWidget {
  const StatChipTile({
    super.key,
    required this.label,
    this.icon = Icons.auto_awesome,
    this.supporting,
  });

  final String label;
  final String? supporting;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: AppColors.deepGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    color: AppColors.deepGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (supporting != null) ...[
            const SizedBox(height: 8),
            Text(
              supporting!,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: AppColors.textMuted),
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface3,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'Comfort-first coverage clarity',
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: AppColors.textMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

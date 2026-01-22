import 'package:flutter/material.dart';

import '../tokens.dart';
import 'premium_card.dart';

class ArticleTile extends StatelessWidget {
  const ArticleTile({
    super.key,
    required this.title,
    required this.excerpt,
    required this.readTime,
    this.category,
    this.onTap,
  });

  final String title;
  final String excerpt;
  final String readTime;
  final String? category;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (category != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                category!,
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.deepGreen,
                    ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  fontSize: 18,
                  height: 1.25,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            excerpt,
            style: Theme.of(context)
                .textTheme
                .bodyMedium!
                .copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: AppColors.textSubtle),
              const SizedBox(width: 6),
              Text(
                readTime,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium!
                    .copyWith(fontSize: 14, color: AppColors.textSubtle),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward, size: 18, color: AppColors.deepGreen),
            ],
          ),
        ],
      ),
    );
  }
}

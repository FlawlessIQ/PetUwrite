import 'package:flutter/material.dart';

import '../tokens.dart';

class ImageSlot extends StatelessWidget {
  const ImageSlot._({
    required this.label,
    required this.aspectRatio,
    this.height,
  });

  final String label;
  final double aspectRatio;
  final double? height;

  factory ImageSlot.hero({String label = 'Hero image here'}) =>
      ImageSlot._(label: label, aspectRatio: 16 / 10);

  factory ImageSlot.card({String label = 'Card image here'}) =>
      ImageSlot._(label: label, aspectRatio: 16 / 11);

  factory ImageSlot.inline({String label = 'Inline image here'}) =>
      ImageSlot._(label: label, aspectRatio: 16 / 9, height: 180);

  @override
  Widget build(BuildContext context) {
    final content = Container(
      decoration: BoxDecoration(
        borderRadius: AppRadii.br24,
        border: Border.all(color: AppColors.border),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.surface2,
            AppColors.surface2.withOpacity(0.65),
          ],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.image_outlined, color: AppColors.textSubtle.withOpacity(0.9), size: 34),
            const SizedBox(height: 8),
            Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: AppColors.textSubtle,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
      ),
    );

    if (height != null) {
      return SizedBox(height: height, child: ClipRRect(borderRadius: AppRadii.br24, child: content));
    }

    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(borderRadius: AppRadii.br24, child: content),
    );
  }
}

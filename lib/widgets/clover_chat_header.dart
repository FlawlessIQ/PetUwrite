import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../theme/clovara_theme.dart';

/// Clover Chat Header Widget
/// 
/// Brand-consistent chat header showing Clover as the active assistant
class CloverChatHeader extends StatelessWidget {
  const CloverChatHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: ClovaraColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Clover avatar using SVG mark
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: ClovaraColors.mist,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: ClovaraColors.clover.withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: SvgPicture.asset(
              'assets/images/clovara_mark_refined.svg',
              width: 28,
              height: 28,
            ),
          ),
          const SizedBox(width: 12),
          // Clover name
          Text(
            'Clover',
            style: ClovaraTypography.h3.copyWith(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          // Online status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: ClovaraColors.clover.withOpacity(0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.bolt,
                  size: 16,
                  color: ClovaraColors.clover,
                ),
                const SizedBox(width: 6),
                Text(
                  'Online',
                  style: ClovaraTypography.bodySmall.copyWith(
                    color: ClovaraColors.clover,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../tokens.dart';

const String _clovaraMarkAsset = 'assets/images/clovara_mark_refined.svg';

class ClovaraMark extends StatelessWidget {
  const ClovaraMark({
    super.key,
    this.size = 28,
    this.color,
    this.fit = BoxFit.contain,
  });

  final double size;
  final Color? color;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      _clovaraMarkAsset,
      width: size,
      height: size,
      fit: fit,
      colorFilter: color == null
          ? null
          : ColorFilter.mode(color!, BlendMode.srcIn),
    );
  }
}

class ClovaraLogoLockup extends StatelessWidget {
  const ClovaraLogoLockup({
    super.key,
    this.markSize = 40,
    this.textSize,
    this.compact = false,
    this.boxedMark = true,
    this.markColor,
    this.textColor,
  });

  final double markSize;
  final double? textSize;
  final bool compact;
  final bool boxedMark;
  final Color? markColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? AppColors.deepGreen;

    final style = Theme.of(context).textTheme.headlineLarge?.copyWith(
          color: effectiveTextColor,
          fontSize: textSize ?? (compact ? 18 : 40),
          fontWeight: FontWeight.w800,
          letterSpacing: -1,
        );

    final mark = boxedMark
        ? Container(
            padding: EdgeInsets.all(compact ? 8 : 12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(compact ? 14 : 16),
              border: Border.all(
                color: AppColors.borderStrong,
                width: 2,
              ),
            ),
            child: ClovaraMark(
              size: markSize,
              color: markColor,
            ),
          )
        : ClovaraMark(
            size: markSize,
            color: markColor,
          );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(width: compact ? 10 : 16),
        Text('Clovara', style: style),
      ],
    );
  }
}

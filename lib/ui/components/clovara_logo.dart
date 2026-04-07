import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../tokens.dart';

const String _clovaraMarkAsset = 'assets/images/clovara_mark_refined.svg';

// ---------------------------------------------------------------------------
// ClovaraMark – renders ONLY the SVG logo mark (no text).
// ---------------------------------------------------------------------------
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

// ---------------------------------------------------------------------------
// ClovaraLogo – the canonical logo component for all UI surfaces.
//
//   [ LOGO MARK ]  Clovara
//
// Props:
//   • size          – small | medium | large (controls mark + text sizing)
//   • showText      – false for icon-only contexts (compact nav, avatar, etc.)
//   • color         – optional tint applied to both mark and text
// ---------------------------------------------------------------------------
enum ClovaraLogoSize { small, medium, large }

class ClovaraLogo extends StatelessWidget {
  const ClovaraLogo({
    super.key,
    this.size = ClovaraLogoSize.medium,
    this.showText = true,
    this.color,
  });

  final ClovaraLogoSize size;
  final bool showText;
  final Color? color;

  double get _markSize {
    switch (size) {
      case ClovaraLogoSize.small:
        return 20;
      case ClovaraLogoSize.medium:
        return 26;
      case ClovaraLogoSize.large:
        return 40;
    }
  }

  double get _textSize {
    switch (size) {
      case ClovaraLogoSize.small:
        return 16;
      case ClovaraLogoSize.medium:
        return 20;
      case ClovaraLogoSize.large:
        return 34;
    }
  }

  double get _spacing {
    switch (size) {
      case ClovaraLogoSize.small:
        return 8;
      case ClovaraLogoSize.medium:
        return 10;
      case ClovaraLogoSize.large:
        return 14;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? AppColors.deepGreen;

    final mark = ClovaraMark(size: _markSize);

    if (!showText) return mark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        mark,
        SizedBox(width: _spacing),
        Text(
          'Clovara',
          style: TextStyle(
            fontFamily: 'Public Sans',
            fontSize: _textSize,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: effectiveColor,
            height: 1.0,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Backwards-compatible alias – delegates to ClovaraLogo.
// Deprecated: migrate all call-sites to ClovaraLogo.
// ---------------------------------------------------------------------------
@Deprecated('Use ClovaraLogo instead')
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

  ClovaraLogoSize get _mappedSize {
    if (markSize <= 22) return ClovaraLogoSize.small;
    if (markSize <= 30) return ClovaraLogoSize.medium;
    return ClovaraLogoSize.large;
  }

  @override
  Widget build(BuildContext context) {
    return ClovaraLogo(
      size: _mappedSize,
      showText: true,
      color: textColor ?? markColor,
    );
  }
}

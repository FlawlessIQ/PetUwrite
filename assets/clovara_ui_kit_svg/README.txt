# Clovara UI Kit (SVG)
Minimal outlined icons aligned to Clovara brand.

Palette:
{
  "clover": "#16A34A",
  "sunset": "#F97316",
  "forest": "#0B3D2E",
  "mist": "#F7FAF8",
  "slate": "#334155"
}

## Usage in Flutter
1) Add dependency:
   flutter pub add flutter_svg

2) Add to pubspec.yaml:
flutter:
  assets:
    - assets/ui_kit_clovara/

3) In code:
import 'package:flutter_svg/flutter_svg.dart';

SvgPicture.asset(
  'assets/ui_kit_clovara/icon_paw.svg',
  width: 24, height: 24,
  colorFilter: const ColorFilter.mode(Color(0xFF0B3D2E), BlendMode.srcIn), // optional tint
);

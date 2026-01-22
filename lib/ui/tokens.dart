import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Surfaces
  // Keep “comfortable dense” layouts readable by using subtle layer shifts.
  static const background = Color(0xFFF7FAF8);
  static const surface1 = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF1F6F3);
  static const surface3 = Color(0xFFEAF1ED);

  // Back-compat aliases (older components/pages)
  static const offWhite = background;
  static const surface = surface1;

  // Brand
  static const deepGreen = Color(0xFF0F3D2E);
  static const green = Color(0xFF1E7A4E);
  static const greenDark = Color(0xFF0B2B20);

  // Accent (used sparingly)
  static const accentOrange = Color(0xFFF08A4B);
  static const accentAmber = Color(0xFFF6B15A);

  // Text
  static const text = Color(0xFF0E1B14);
  static const textMuted = Color(0xFF41564C);
  static const textSubtle = Color(0xFF6A8076);

  // Borders
  static const border = Color(0xFFE3ECE7);
  static const borderStrong = Color(0xFFCADAD2);
  static const borderTint = Color(0xFFD3E6DC);

  // Status
  static const danger = Color(0xFFB3261E);
  static const warning = Color(0xFFB56A00);
  static const success = Color(0xFF0D7A4D);

  static const shadow = Color(0x1A0E1B14);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF0F3D2E),
      Color(0xFF1E7A4E),
    ],
  );

  // Background aurora (NOT the CTA/button gradient)
  static const auroraGradient = LinearGradient(
    begin: Alignment(-1.0, -1.0),
    end: Alignment(1.0, 1.0),
    stops: [0.0, 0.55, 1.0],
    colors: [
      Color(0xFFDAF6E8), // mint glow
      Color(0xFFEAF0FF), // soft blue glow
      Color(0xFFFFF1E6), // warm peach glow
    ],
  );

  static const ctaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF1E7A4E),
      Color(0xFFF08A4B),
    ],
  );
}

class AppRadii {
  static const r8 = Radius.circular(8);
  static const r12 = Radius.circular(12);
  static const r16 = Radius.circular(16);
  static const r20 = Radius.circular(20);
  static const r24 = Radius.circular(24);

  static const br12 = BorderRadius.all(r12);
  static const br16 = BorderRadius.all(r16);
  static const br20 = BorderRadius.all(r20);
  static const br24 = BorderRadius.all(r24);
}

class AppShadows {
  static List<BoxShadow> get soft => const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 18,
          offset: Offset(0, 8),
        ),
      ];

  static List<BoxShadow> get hover => const [
        BoxShadow(
          color: AppColors.shadow,
          blurRadius: 26,
          offset: Offset(0, 14),
        ),
      ];
}

class AppSpace {
  // Comfortable-dense rhythm
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s48 = 48;
  static const double s56 = 56;
}

class AppText {
  static TextTheme textTheme(BuildContext context) {
    // Minimum 16px body for accessibility
    final base = Theme.of(context).textTheme;

    TextStyle safe(TextStyle? style) => style ?? const TextStyle();

    return base.copyWith(
      displaySmall: GoogleFonts.poppins(
        textStyle: safe(base.displaySmall),
        fontWeight: FontWeight.w700,
        fontSize: 42,
        height: 1.06,
        letterSpacing: -0.6,
        color: AppColors.deepGreen,
      ),
      headlineLarge: GoogleFonts.poppins(
        textStyle: safe(base.headlineLarge),
        fontWeight: FontWeight.w700,
        fontSize: 34,
        height: 1.12,
        letterSpacing: -0.3,
        color: AppColors.deepGreen,
      ),
      headlineMedium: GoogleFonts.poppins(
        textStyle: safe(base.headlineMedium),
        fontWeight: FontWeight.w700,
        fontSize: 28,
        height: 1.16,
        color: AppColors.deepGreen,
      ),
      headlineSmall: GoogleFonts.poppins(
        textStyle: safe(base.headlineSmall),
        fontWeight: FontWeight.w700,
        fontSize: 22,
        height: 1.22,
        color: AppColors.deepGreen,
      ),
      bodyMedium: GoogleFonts.inter(
        textStyle: safe(base.bodyMedium),
        fontSize: 16,
        height: 1.5,
        color: AppColors.text,
      ),
      bodyLarge: GoogleFonts.inter(
        textStyle: safe(base.bodyLarge),
        fontSize: 16,
        height: 1.55,
        color: AppColors.text,
      ),
      bodySmall: GoogleFonts.inter(
        textStyle: safe(base.bodySmall),
        fontSize: 14,
        height: 1.45,
        color: AppColors.textMuted,
      ),
      labelLarge: GoogleFonts.inter(
        textStyle: safe(base.labelLarge),
        fontWeight: FontWeight.w600,
      ),
      titleMedium: GoogleFonts.inter(
        textStyle: safe(base.titleMedium),
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
      titleLarge: GoogleFonts.poppins(
        textStyle: safe(base.titleLarge),
        fontWeight: FontWeight.w600,
        color: AppColors.text,
      ),
    );
  }
}

class AppTheme {
  static ThemeData build(ThemeData base, BuildContext context) {
    final textTheme = AppText.textTheme(context);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.deepGreen,
        secondary: AppColors.green,
        surface: AppColors.surface,
        onSurface: AppColors.text,
      ),
      textTheme: textTheme,
      dividerColor: AppColors.border,
      focusColor: AppColors.green.withOpacity(0.18),
      hoverColor: AppColors.green.withOpacity(0.06),
    );
  }
}

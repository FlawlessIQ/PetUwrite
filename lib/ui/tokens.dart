import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Surfaces
  // Keep “comfortable dense” layouts readable by using subtle layer shifts.
  static const background = Color(0xFFFAFAF8);
  static const surface1 = Color(0xFFFFFFFF);
  static const surface2 = Color(0xFFF4F5F4);
  static const surface3 = Color(0xFFE6ECE7);
  static const surface4 = Color(0xFF0F1F1B);
  static const navSurface = Color(0xFFFFFFFF);

  // Back-compat aliases (older components/pages)
  static const offWhite = background;
  static const surface = surface1;

  // Brand
  static const deepGreen = Color(0xFF0B241D);
  static const green = Color(0xFF126B4D);
  static const greenDark = Color(0xFF082019);
  static const sage = Color(0xFF5D8B79);
  static const mint = Color(0xFFB9E4D1);
  static const signalBlue = Color(0xFF8DB8D7);

  // Accent (used sparingly)
  static const accentOrange = Color(0xFFD38342);
  static const accentAmber = Color(0xFFE7B15B);
  static const accentGold = Color(0xFFF0DAB0);

  // Text
  static const text = Color(0xFF0D1B16);
  static const textMuted = Color(0xFF3A5549);
  static const textSubtle = Color(0xFF5C756B);
  static const textOnDark = Color(0xFFEAF4EF);

  // Borders
  static const border = Color(0xFFDDE5E0);
  static const borderStrong = Color(0xFFC9D6CF);
  static const borderTint = Color(0xFFD5E1DB);

  // Status
  static const danger = Color(0xFFB3261E);
  static const warning = Color(0xFFB56A00);
  static const success = Color(0xFF0D7A4D);

  static const shadow = Color(0x1F102019);

  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B241D), Color(0xFF154B39), Color(0xFF1A6B4E)],
  );

  // Background aurora (NOT the CTA/button gradient)
  static const auroraGradient = LinearGradient(
    begin: Alignment(-1.0, -1.0),
    end: Alignment(1.0, 1.0),
    stops: [0.0, 0.55, 1.0],
    colors: [Color(0xFFF7F4EE), Color(0xFFE8F1F7), Color(0xFFF7EFE3)],
  );

  static const ctaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B241D), Color(0xFF126B4D)],
  );

  static const trustGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0B241D), Color(0xFF12382D)],
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
    BoxShadow(color: AppColors.shadow, blurRadius: 18, offset: Offset(0, 8)),
  ];

  static List<BoxShadow> get hover => const [
    BoxShadow(color: AppColors.shadow, blurRadius: 26, offset: Offset(0, 14)),
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
      displaySmall: GoogleFonts.publicSans(
        textStyle: safe(base.displaySmall),
        fontWeight: FontWeight.w800,
        fontSize: 40,
        height: 1.02,
        letterSpacing: -1.0,
        color: AppColors.deepGreen,
      ),
      headlineLarge: GoogleFonts.publicSans(
        textStyle: safe(base.headlineLarge),
        fontWeight: FontWeight.w700,
        fontSize: 28,
        height: 1.12,
        letterSpacing: -0.45,
        color: AppColors.deepGreen,
      ),
      headlineMedium: GoogleFonts.publicSans(
        textStyle: safe(base.headlineMedium),
        fontWeight: FontWeight.w700,
        fontSize: 24,
        height: 1.16,
        letterSpacing: -0.25,
        color: AppColors.deepGreen,
      ),
      headlineSmall: GoogleFonts.publicSans(
        textStyle: safe(base.headlineSmall),
        fontWeight: FontWeight.w700,
        fontSize: 20,
        height: 1.2,
        color: AppColors.deepGreen,
      ),
      bodyMedium: GoogleFonts.publicSans(
        textStyle: safe(base.bodyMedium),
        fontSize: 16,
        height: 1.55,
        color: AppColors.text,
      ),
      bodyLarge: GoogleFonts.publicSans(
        textStyle: safe(base.bodyLarge),
        fontSize: 16,
        height: 1.6,
        color: AppColors.text,
      ),
      bodySmall: GoogleFonts.publicSans(
        textStyle: safe(base.bodySmall),
        fontSize: 14,
        height: 1.45,
        color: AppColors.textMuted,
      ),
      labelLarge: GoogleFonts.publicSans(
        textStyle: safe(base.labelLarge),
        fontWeight: FontWeight.w700,
        fontSize: 15,
        letterSpacing: 0.2,
      ),
      titleMedium: GoogleFonts.publicSans(
        textStyle: safe(base.titleMedium),
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: AppColors.text,
      ),
      titleLarge: GoogleFonts.publicSans(
        textStyle: safe(base.titleLarge),
        fontWeight: FontWeight.w700,
        fontSize: 20,
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

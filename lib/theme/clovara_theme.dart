import 'package:flutter/material.dart';

/// ---------- Brand Tokens ----------
class ClovaraColors {
  // Brand
  static const clover = Color(0xFF16A34A); // Primary
  static const forest = Color(0xFF0B3D2E); // Headings / strong text
  static const sunset = Color(0xFFF97316); // Accent
  static const gold   = Color(0xFFF59E0B); // Support accent

  // Neutrals
  static const mist   = Color(0xFFF7FAF8); // App background
  static const white  = Color(0xFFFFFFFF);
  static const slate  = Color(0xFF334155); // Body text
  static const border = Color(0xFFE2E8F0);

  // Semantics
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error   = Color(0xFFEF4444);
  static const info    = Color(0xFF3B82F6);

  // Legacy aliases for backwards compatibility
  static const kSuccessMint = success;
  static const kWarmCoral = sunset;
  static const kWarning = warning;
  static const kError = error;
  static const kTextGrey = slate;
  static const kTextDark = forest;

  static const gradient = LinearGradient(
    colors: [clover, sunset],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const brandGradient = LinearGradient(
    colors: [clover, sunset],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const brandGradientSoft = LinearGradient(
    colors: [clover, sunset],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class ClovaraTypography {
  static const poppins = 'Poppins';
  static const inter   = 'Inter';

  static const TextStyle h1 = TextStyle(
    fontFamily: poppins, fontWeight: FontWeight.w600, fontSize: 34, height: 1.2, letterSpacing: -0.5,
    color: ClovaraColors.forest,
  );
  static const TextStyle h2 = TextStyle(
    fontFamily: poppins, fontWeight: FontWeight.w600, fontSize: 28, height: 1.25, letterSpacing: -0.25,
    color: ClovaraColors.forest,
  );
  static const TextStyle h3 = TextStyle(
    fontFamily: poppins, fontWeight: FontWeight.w600, fontSize: 22, height: 1.3,
    color: ClovaraColors.forest,
  );

  static const TextStyle body = TextStyle(
    fontFamily: inter, fontWeight: FontWeight.w400, fontSize: 16, height: 1.55, color: ClovaraColors.slate,
  );
  static const TextStyle bodySmall = TextStyle(
    fontFamily: inter, fontWeight: FontWeight.w400, fontSize: 14, height: 1.45, color: ClovaraColors.slate,
  );
  static const TextStyle label = TextStyle(
    fontFamily: inter, fontWeight: FontWeight.w500, fontSize: 14, letterSpacing: 0.2, color: ClovaraColors.slate,
  );
  static const TextStyle button = TextStyle(
    fontFamily: inter, fontWeight: FontWeight.w600, fontSize: 16, letterSpacing: 0.2, color: Colors.white,
  );
}

class ClovaraTheme {
  /// Primary (light) theme — world-class, calm, generous spacing
  static ThemeData get light {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.light);

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: ClovaraColors.clover,
        secondary: ClovaraColors.sunset,
        surface: ClovaraColors.white,
        background: ClovaraColors.mist,
        error: ClovaraColors.error,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: ClovaraColors.forest,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: ClovaraColors.mist,

      appBarTheme: const AppBarTheme(
        backgroundColor: ClovaraColors.white,
        foregroundColor: ClovaraColors.forest,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: ClovaraTypography.h3,
        toolbarHeight: 64,
      ),

      textTheme: const TextTheme(
        displayLarge: ClovaraTypography.h1,
        displayMedium: ClovaraTypography.h2,
        titleMedium: ClovaraTypography.h3,
        bodyLarge: ClovaraTypography.body,
        bodyMedium: ClovaraTypography.bodySmall,
        labelLarge: ClovaraTypography.label,
      ),

      cardTheme: CardThemeData(
        color: ClovaraColors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      dividerTheme: const DividerThemeData(
        color: ClovaraColors.border, thickness: 1, space: 24,
      ),

      iconTheme: const IconThemeData(
        color: ClovaraColors.forest, size: 22,
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: ClovaraTypography.bodySmall.copyWith(color: ClovaraColors.slate.withOpacity(.7)),
        labelStyle: ClovaraTypography.label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ClovaraColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ClovaraColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ClovaraColors.clover, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: ClovaraColors.error),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: ClovaraColors.clover,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: ClovaraTypography.button,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: ClovaraColors.clover,
          side: const BorderSide(color: ClovaraColors.clover, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: ClovaraTypography.button.copyWith(color: ClovaraColors.clover),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ClovaraColors.forest,
          textStyle: ClovaraTypography.button.copyWith(color: ClovaraColors.forest, fontSize: 16),
        ),
      ),

      chipTheme: ChipThemeData(
        backgroundColor: ClovaraColors.white,
        selectedColor: ClovaraColors.clover.withOpacity(.12),
        labelStyle: ClovaraTypography.bodySmall,
        secondaryLabelStyle: ClovaraTypography.bodySmall.copyWith(color: ClovaraColors.clover),
        side: const BorderSide(color: ClovaraColors.border),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        checkmarkColor: ClovaraColors.clover,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: ClovaraColors.white,
        selectedItemColor: ClovaraColors.clover,
        unselectedItemColor: ClovaraColors.slate,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      snackBarTheme: SnackBarThemeData(
        backgroundColor: ClovaraColors.forest,
        contentTextStyle: ClovaraTypography.body.copyWith(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ClovaraColors.clover,
        linearTrackColor: ClovaraColors.border,
      ),
    );
  }

  /// Optional dark stub — keep light as first-class for now
  static ThemeData get dark =>
      ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: const ColorScheme.dark(primary: ClovaraColors.clover),
      );
}

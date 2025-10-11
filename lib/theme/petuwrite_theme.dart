import 'package:flutter/material.dart';

/// PetUwrite Brand Colors
/// Trust powered by intelligence
class PetUwriteColors {
  // Primary brand colors
  static const Color kPrimaryNavy = Color(0xFF0A2647); // Deep trust blue
  static const Color kSecondaryTeal = Color(0xFF00C2CB); // Smart teal accent
  static const Color kAccentSky = Color(0xFFA8E6E8); // Soft sky tone
  
  // Background colors
  static const Color kBackgroundLight = Color(0xFFF8FAFB);
  static const Color kBackgroundDark = Color(0xFF061122);
  
  // Semantic colors
  static const Color kSuccessMint = Color(0xFF4CE1A5);
  static const Color kWarmCoral = Color(0xFFFF6F61);
  static const Color kError = Color(0xFFFF5252);
  static const Color kWarning = Color(0xFFFFB74D);
  
  // Text colors
  static const Color kTextLight = Color(0xFFFFFFFF);
  static const Color kTextDark = Color(0xFF0A2647);
  static const Color kTextGrey = Color(0xFF6B7280);
  static const Color kTextMuted = Color(0xFF9CA3AF);
  
  // Brand gradient
  static const LinearGradient brandGradient = LinearGradient(
    colors: [kSecondaryTeal, kPrimaryNavy],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  // Soft gradient variants
  static const LinearGradient brandGradientSoft = LinearGradient(
    colors: [kAccentSky, kSecondaryTeal],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient darkGradient = LinearGradient(
    colors: [kPrimaryNavy, kBackgroundDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

/// PetUwrite Typography
class PetUwriteTypography {
  // Font families
  static const String poppins = 'Poppins';
  static const String inter = 'Inter';
  static const String nunitoSans = 'Nunito Sans';
  
  // Heading styles (Poppins SemiBold)
  static const TextStyle h1 = TextStyle(
    fontFamily: poppins,
    fontWeight: FontWeight.w600,
    fontSize: 32,
    height: 1.2,
    letterSpacing: -0.5,
  );
  
  static const TextStyle h2 = TextStyle(
    fontFamily: poppins,
    fontWeight: FontWeight.w600,
    fontSize: 24,
    height: 1.3,
    letterSpacing: -0.3,
  );
  
  static const TextStyle h3 = TextStyle(
    fontFamily: poppins,
    fontWeight: FontWeight.w600,
    fontSize: 20,
    height: 1.4,
  );
  
  static const TextStyle h4 = TextStyle(
    fontFamily: poppins,
    fontWeight: FontWeight.w600,
    fontSize: 18,
    height: 1.4,
  );
  
  // Body text styles (Inter Regular)
  static const TextStyle bodyLarge = TextStyle(
    fontFamily: inter,
    fontWeight: FontWeight.w400,
    fontSize: 16,
    height: 1.5,
  );
  
  static const TextStyle body = TextStyle(
    fontFamily: inter,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    height: 1.5,
  );
  
  static const TextStyle bodySmall = TextStyle(
    fontFamily: inter,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.4,
  );
  
  // Button text
  static const TextStyle button = TextStyle(
    fontFamily: inter,
    fontWeight: FontWeight.w600,
    fontSize: 14,
    letterSpacing: 0.5,
  );
  
  static const TextStyle buttonLarge = TextStyle(
    fontFamily: inter,
    fontWeight: FontWeight.w600,
    fontSize: 16,
    letterSpacing: 0.5,
  );
  
  // Caption and labels
  static const TextStyle caption = TextStyle(
    fontFamily: inter,
    fontWeight: FontWeight.w400,
    fontSize: 12,
    height: 1.3,
  );
  
  static const TextStyle label = TextStyle(
    fontFamily: inter,
    fontWeight: FontWeight.w500,
    fontSize: 14,
    letterSpacing: 0.1,
  );
  
  // Tagline
  static const TextStyle tagline = TextStyle(
    fontFamily: inter,
    fontWeight: FontWeight.w400,
    fontSize: 14,
    fontStyle: FontStyle.italic,
    letterSpacing: 0.5,
  );
}

/// PetUwrite Theme Configuration
class PetUwriteTheme {
  /// Light theme (for daytime use)
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      
      // Color scheme
      colorScheme: ColorScheme.light(
        primary: PetUwriteColors.kPrimaryNavy,
        secondary: PetUwriteColors.kSecondaryTeal,
        tertiary: PetUwriteColors.kAccentSky,
        surface: Colors.white,
        error: PetUwriteColors.kError,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: PetUwriteColors.kTextDark,
        onError: Colors.white,
      ),
      
      // Scaffold
      scaffoldBackgroundColor: PetUwriteColors.kBackgroundLight,
      
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: PetUwriteColors.kPrimaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: PetUwriteTypography.h3.copyWith(
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      
      // Card
      cardTheme: CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: Colors.white,
      ),
      
      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PetUwriteColors.kSecondaryTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: PetUwriteTypography.button,
        ),
      ),
      
      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PetUwriteColors.kSecondaryTeal,
          side: const BorderSide(color: PetUwriteColors.kSecondaryTeal, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: PetUwriteTypography.button,
        ),
      ),
      
      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PetUwriteColors.kSecondaryTeal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: PetUwriteTypography.button,
        ),
      ),
      
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PetUwriteColors.kSecondaryTeal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PetUwriteColors.kError, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: PetUwriteTypography.label.copyWith(
          color: PetUwriteColors.kTextGrey,
        ),
        hintStyle: PetUwriteTypography.body.copyWith(
          color: PetUwriteColors.kTextMuted,
        ),
      ),
      
      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: PetUwriteColors.kAccentSky.withOpacity(0.3),
        selectedColor: PetUwriteColors.kSecondaryTeal,
        labelStyle: PetUwriteTypography.caption,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      
      // Dialog
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 8,
      ),
      
      // Bottom sheet
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        backgroundColor: Colors.white,
      ),
      
      // Floating action button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: PetUwriteColors.kSecondaryTeal,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      
      // Text theme
      textTheme: TextTheme(
        displayLarge: PetUwriteTypography.h1,
        displayMedium: PetUwriteTypography.h2,
        displaySmall: PetUwriteTypography.h3,
        headlineMedium: PetUwriteTypography.h4,
        bodyLarge: PetUwriteTypography.bodyLarge,
        bodyMedium: PetUwriteTypography.body,
        bodySmall: PetUwriteTypography.bodySmall,
        labelLarge: PetUwriteTypography.button,
        labelSmall: PetUwriteTypography.caption,
      ),
      
      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PetUwriteColors.kSecondaryTeal,
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: Colors.grey.shade200,
        thickness: 1,
        space: 16,
      ),
    );
  }
  
  /// Dark theme (for admin/underwriter interface)
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      
      // Color scheme
      colorScheme: ColorScheme.dark(
        primary: PetUwriteColors.kSecondaryTeal,
        secondary: PetUwriteColors.kAccentSky,
        tertiary: PetUwriteColors.kSuccessMint,
        surface: PetUwriteColors.kPrimaryNavy,
        error: PetUwriteColors.kError,
        onPrimary: Colors.white,
        onSecondary: PetUwriteColors.kPrimaryNavy,
        onSurface: Colors.white,
        onError: Colors.white,
      ),
      
      // Scaffold
      scaffoldBackgroundColor: PetUwriteColors.kBackgroundDark,
      
      // AppBar
      appBarTheme: AppBarTheme(
        backgroundColor: PetUwriteColors.kPrimaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: PetUwriteTypography.h3.copyWith(
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      
      // Card
      cardTheme: CardThemeData(
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: PetUwriteColors.kPrimaryNavy,
      ),
      
      // Elevated button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: PetUwriteColors.kSecondaryTeal,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: PetUwriteTypography.button,
        ),
      ),
      
      // Outlined button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: PetUwriteColors.kSecondaryTeal,
          side: const BorderSide(color: PetUwriteColors.kSecondaryTeal, width: 2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: PetUwriteTypography.button,
        ),
      ),
      
      // Text button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: PetUwriteColors.kAccentSky,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: PetUwriteTypography.button,
        ),
      ),
      
      // Input decoration
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: PetUwriteColors.kPrimaryNavy,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PetUwriteColors.kSecondaryTeal),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: PetUwriteColors.kSecondaryTeal.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PetUwriteColors.kSecondaryTeal, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: PetUwriteColors.kError, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: PetUwriteTypography.label.copyWith(
          color: PetUwriteColors.kAccentSky,
        ),
        hintStyle: PetUwriteTypography.body.copyWith(
          color: PetUwriteColors.kTextMuted,
        ),
      ),
      
      // Text theme
      textTheme: TextTheme(
        displayLarge: PetUwriteTypography.h1.copyWith(color: Colors.white),
        displayMedium: PetUwriteTypography.h2.copyWith(color: Colors.white),
        displaySmall: PetUwriteTypography.h3.copyWith(color: Colors.white),
        headlineMedium: PetUwriteTypography.h4.copyWith(color: Colors.white),
        bodyLarge: PetUwriteTypography.bodyLarge.copyWith(color: Colors.white),
        bodyMedium: PetUwriteTypography.body.copyWith(color: Colors.white),
        bodySmall: PetUwriteTypography.bodySmall.copyWith(color: PetUwriteColors.kTextMuted),
        labelLarge: PetUwriteTypography.button,
        labelSmall: PetUwriteTypography.caption.copyWith(color: PetUwriteColors.kTextMuted),
      ),
      
      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: PetUwriteColors.kSecondaryTeal,
      ),
      
      // Divider
      dividerTheme: DividerThemeData(
        color: PetUwriteColors.kSecondaryTeal.withOpacity(0.2),
        thickness: 1,
        space: 16,
      ),
    );
  }
}

/// Asset paths and app constants
class PetUwriteAssets {
  // Logo paths (using SVG placeholders until PNG logos are added)
  static const String logoNavyBackground = 'assets/petuwrite_logo_navy.svg';
  static const String logoTransparent = 'assets/petuwrite_logo_transparent.svg';
  
  // App identity
  static const String appName = 'PetUwrite';
  static const String tagline = 'Trust powered by intelligence';
  static const String copyright = '© 2025 FlawlessIQ LLC';
}

/// Helper widget for brand gradient backgrounds
class BrandGradientBackground extends StatelessWidget {
  final Widget child;
  final Gradient? gradient;
  
  const BrandGradientBackground({
    super.key,
    required this.child,
    this.gradient,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: gradient ?? PetUwriteColors.brandGradient,
      ),
      child: child,
    );
  }
}

/// Helper widget for brand gradient cards
class BrandGradientCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Gradient? gradient;
  
  const BrandGradientCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.gradient,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: gradient ?? PetUwriteColors.brandGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: PetUwriteColors.kSecondaryTeal.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}

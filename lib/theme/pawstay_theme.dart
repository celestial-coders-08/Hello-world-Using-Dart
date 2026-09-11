import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PawStayTheme {
  // Theme state notifier
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);

  // Brand Color Palette
  static const Color primary = Color(0xFF99462A); // Terracotta
  static const Color primaryContainer = Color(0xFFD97757);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color onPrimaryContainer = Color(0xFF541400);

  static const Color secondary = Color(0xFF506447); // Sage Green
  static const Color secondaryContainer = Color(0xFFD0E7C2);
  static const Color onSecondary = Color(0xFFFFFFFF);
  static const Color onSecondaryContainer = Color(0xFF54684B);

  static const Color tertiary = Color(0xFF605E5B); // Warm Cream/Gray
  static const Color tertiaryContainer = Color(0xFF94928E);
  static const Color onTertiary = Color(0xFFFFFFFF);
  static const Color onTertiaryContainer = Color(0xFF2C2B28);

  static const Color background = Color(0xFFFFF8F4); // Warm Cream
  static const Color onBackground = Color(0xFF1F1B17); // Charcoal Brown

  static const Color surface = Color(0xFFFFF8F4);
  static const Color surfaceDim = Color(0xFFE2D8D1);
  static const Color surfaceBright = Color(0xFFFFF8F4);
  static const Color onSurface = Color(0xFF1F1B17);
  static const Color onSurfaceVariant = Color(0xFF55433D);

  static const Color surfaceContainerLowest = Color(0xFFFFFFFF);
  static const Color surfaceContainerLow = Color(0xFFFCF2EA);
  static const Color surfaceContainer = Color(0xFFF6ECE5);
  static const Color surfaceContainerHigh = Color(0xFFF1E6DF);
  static const Color surfaceContainerHighest = Color(0xFFEBE1DA);

  static const Color outline = Color(0xFF88726C);
  static const Color outlineVariant = Color(0xFFDBC1B9);

  static const Color error = Color(0xFFBA1A1A);
  static const Color errorContainer = Color(0xFFFFDAD6);
  static const Color onError = Color(0xFFFFFFFF);
  static const Color onErrorContainer = Color(0xFF93000A);

  // Border Radii
  static const double radiusSm = 4.0;
  static const double radiusDefault = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 24.0;

  // Spacing
  static const double unit = 8.0;
  static const double marginMobile = 16.0;
  static const double marginDesktop = 40.0;
  static const double gutter = 24.0;

  // Ambient Shadows
  static List<BoxShadow> get ambientShadow1 => [
    BoxShadow(
      color: const Color(0xFF4A443F).withValues(alpha: 0.06),
      offset: const Offset(0, 4),
      blurRadius: 20,
    ),
  ];

  static List<BoxShadow> get ambientShadow2 => [
    BoxShadow(
      color: const Color(0xFF4A443F).withValues(alpha: 0.10),
      offset: const Offset(0, 8),
      blurRadius: 30,
    ),
  ];

  // Custom Text Theme Setup
  static TextTheme get textTheme {
    return TextTheme(
      displayLarge: GoogleFonts.plusJakartaSans(
        fontSize: 48,
        fontWeight: FontWeight.bold,
        height: 56 / 48,
        letterSpacing: -0.02 * 48,
        color: onBackground,
      ),
      headlineLarge: GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        height: 40 / 32,
        color: onBackground,
      ),
      headlineMedium: GoogleFonts.plusJakartaSans(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        color: onBackground,
      ),
      bodyLarge: GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.normal,
        height: 28 / 18,
        color: onBackground,
      ),
      bodyMedium: GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        height: 24 / 16,
        color: onBackground,
      ),
      labelLarge: GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        height: 20 / 14,
        letterSpacing: 0.01 * 14,
        color: onBackground,
      ),
      labelMedium: GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 16 / 12,
        color: onBackground,
      ),
    );
  }

  // ThemeData Export
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primary,
      colorScheme: const ColorScheme(
        brightness: Brightness.light,
        primary: primary,
        onPrimary: onPrimary,
        primaryContainer: primaryContainer,
        onPrimaryContainer: onPrimaryContainer,
        secondary: secondary,
        onSecondary: onSecondary,
        secondaryContainer: secondaryContainer,
        onSecondaryContainer: onSecondaryContainer,
        tertiary: tertiary,
        onTertiary: onTertiary,
        tertiaryContainer: tertiaryContainer,
        onTertiaryContainer: onTertiaryContainer,
        error: error,
        onError: onError,
        errorContainer: errorContainer,
        onErrorContainer: onErrorContainer,
        surface: surface,
        onSurface: onSurface,
        surfaceContainerHighest: surfaceContainerHighest,
        onSurfaceVariant: onSurfaceVariant,
        outline: outline,
        outlineVariant: outlineVariant,
      ),
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: primary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: outlineVariant, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: outlineVariant, width: 1.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          color: onSurfaceVariant,
          fontSize: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 2,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusDefault),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

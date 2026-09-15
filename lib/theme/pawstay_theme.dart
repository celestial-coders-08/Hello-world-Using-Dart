import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PawStayTheme {
  // Theme state notifier
  static final ValueNotifier<ThemeMode> themeNotifier =
      ValueNotifier<ThemeMode>(ThemeMode.light);
  static bool _providerLightMode = false;
  static ThemeMode? _modeBeforeProvider;
  static bool _providerDarkMode = false;

  static void enterProviderLightMode() {
    if (_providerLightMode) return;
    _modeBeforeProvider = themeNotifier.value;
    _providerLightMode = true;
    _providerDarkMode = false;
    if (themeNotifier.value != ThemeMode.light) {
      themeNotifier.value = ThemeMode.light;
    }
  }

  static void exitProviderLightMode() {
    if (!_providerLightMode) return;
    _providerLightMode = false;
    _providerDarkMode = false;
    final previousMode = _modeBeforeProvider;
    _modeBeforeProvider = null;
    if (previousMode != null && themeNotifier.value != previousMode) {
      themeNotifier.value = previousMode;
    }
  }

  static bool get isProviderDarkMode => _providerDarkMode;

  static void setProviderDarkMode(bool enabled) {
    if (!_providerLightMode || _providerDarkMode == enabled) return;
    _providerDarkMode = enabled;
    themeNotifier.value = enabled ? ThemeMode.dark : ThemeMode.light;
  }

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

  static bool get isDark => _providerLightMode
      ? _providerDarkMode
      : themeNotifier.value == ThemeMode.dark;

  static Color get background =>
      isDark ? const Color(0xFF171412) : const Color(0xFFFFF8F4);
  static Color get onBackground =>
      isDark ? const Color(0xFFF3E9E3) : const Color(0xFF1F1B17);

  static Color get surface =>
      isDark ? const Color(0xFF211B19) : const Color(0xFFFFF8F4);
  static Color get surfaceDim =>
      isDark ? const Color(0xFF3A302D) : const Color(0xFFE2D8D1);
  static Color get surfaceBright =>
      isDark ? const Color(0xFF2C2421) : const Color(0xFFFFF8F4);
  static Color get onSurface =>
      isDark ? const Color(0xFFF3E9E3) : const Color(0xFF1F1B17);
  static Color get onSurfaceVariant =>
      isDark ? const Color(0xFFD8C5BC) : const Color(0xFF55433D);

  static Color get surfaceContainerLowest =>
      isDark ? const Color(0xFF1B1614) : const Color(0xFFFFFFFF);
  static Color get surfaceContainerLow =>
      isDark ? const Color(0xFF271F1D) : const Color(0xFFFCF2EA);
  static Color get surfaceContainer =>
      isDark ? const Color(0xFF2E2522) : const Color(0xFFF6ECE5);
  static Color get surfaceContainerHigh =>
      isDark ? const Color(0xFF392E2A) : const Color(0xFFF1E6DF);
  static Color get surfaceContainerHighest =>
      isDark ? const Color(0xFF443832) : const Color(0xFFEBE1DA);

  static Color get outline =>
      isDark ? const Color(0xFFBBA69C) : const Color(0xFF88726C);
  static Color get outlineVariant =>
      isDark ? const Color(0xFF5A4841) : const Color(0xFFDBC1B9);

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
      colorScheme: ColorScheme(
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
          borderSide: BorderSide(color: outlineVariant, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: BorderSide(color: outlineVariant, width: 1.0),
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

  static ThemeData get providerTheme =>
      isProviderDarkMode ? darkTheme : lightTheme;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primary,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: background,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: onSurface,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: BorderSide(color: outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusDefault),
          borderSide: BorderSide(color: outlineVariant),
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
    );
  }
}

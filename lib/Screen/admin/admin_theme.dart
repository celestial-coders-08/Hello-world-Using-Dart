import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AdminTheme {
  // Global theme switcher for Admin Panel
  static final ValueNotifier<bool> isDarkMode = ValueNotifier<bool>(true);

  // Toggle mode
  static void toggleTheme() {
    isDarkMode.value = !isDarkMode.value;
  }

  // --- DARK THEME (Sleek Slate Enterprise) ---
  static const Color darkBg = Color(0xFF0F172A); // Slate 900
  static const Color darkCard = Color(0xFF1E293B); // Slate 800
  static const Color darkCardSoft = Color(0xFF243247);
  static const Color darkBorder = Color(0xFF334155); // Slate 700
  static const Color darkBorderLight = Color(0xFF475569);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);

  // --- LIGHT THEME (PawStay Warm Luxury) ---
  static const Color lightBg = Color(0xFFFFF8F4); // Warm Cream
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightCardSoft = Color(0xFFFAF3EE);
  static const Color lightBorder = Color(0xFFEADBCE);
  static const Color lightBorderLight = Color(0xFFF1E5DB);
  static const Color lightTextPrimary = Color(0xFF231815);
  static const Color lightTextSecondary = Color(0xFF6B5851);
  static const Color lightTextMuted = Color(0xFF9C877F);

  // Brand Accents
  static const Color primary = Color(0xFF99462A); // PawStay Terracotta
  static const Color primaryLight = Color(0xFFD97757);
  static const Color primaryContainerDark = Color(0x3399462A);
  static const Color primaryContainerLight = Color(0xFFFBECE6);

  static const Color secondary = Color(0xFF506447); // Sage Green
  static const Color secondaryLight = Color(0xFF758E6A);
  static const Color secondaryContainerDark = Color(0x33506447);
  static const Color secondaryContainerLight = Color(0xFFE9F2E4);

  static const Color accentBlue = Color(0xFF38BDF8); // Sky Blue
  static const Color accentPurple = Color(0xFFA78BFA); // Violet
  static const Color accentAmber = Color(0xFFF59E0B); // Amber

  // Dynamic getters based on current isDarkMode state
  static Color get background => isDarkMode.value ? darkBg : lightBg;
  static Color get cardBg => isDarkMode.value ? darkCard : lightCard;
  static Color get cardBgSoft => isDarkMode.value ? darkCardSoft : lightCardSoft;
  static Color get border => isDarkMode.value ? darkBorder : lightBorder;
  static Color get borderLight => isDarkMode.value ? darkBorderLight : lightBorderLight;

  static Color get textPrimary => isDarkMode.value ? darkTextPrimary : lightTextPrimary;
  static Color get textSecondary => isDarkMode.value ? darkTextSecondary : lightTextSecondary;
  static Color get textMuted => isDarkMode.value ? darkTextMuted : lightTextMuted;

  static Color get primaryContainer => isDarkMode.value ? primaryContainerDark : primaryContainerLight;
  static Color get secondaryContainer => isDarkMode.value ? secondaryContainerDark : secondaryContainerLight;

  // Status Colors
  static const Color statusSuccess = Color(0xFF10B981);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusDanger = Color(0xFFEF4444);
  static const Color statusInfo = Color(0xFF0EA5E9);

  static Color get statusSuccessBg => isDarkMode.value ? const Color(0x2210B981) : const Color(0xFFE8F5E9);
  static Color get statusWarningBg => isDarkMode.value ? const Color(0x22F59E0B) : const Color(0xFFFFF3E0);
  static Color get statusDangerBg => isDarkMode.value ? const Color(0x22EF4444) : const Color(0xFFFFEBEE);
  static Color get statusInfoBg => isDarkMode.value ? const Color(0x220EA5E9) : const Color(0xFFE3F2FD);

  // Dynamic Card Decoration
  static BoxDecoration cardDecoration({Color? customBg, Color? customBorder, Color? borderColor}) => BoxDecoration(
    color: customBg ?? cardBg,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: borderColor ?? customBorder ?? border, width: 1),
    boxShadow: [
      BoxShadow(
        color: isDarkMode.value
            ? Colors.black.withValues(alpha: 0.3)
            : const Color(0xFF7A4A33).withValues(alpha: 0.06),
        blurRadius: 14,
        offset: const Offset(0, 4),
      ),
    ],
  );

  static TextStyle heading(double size, {FontWeight weight = FontWeight.bold, Color? color}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? textPrimary,
      letterSpacing: -0.3,
    );
  }

  static TextStyle body(double size, {FontWeight weight = FontWeight.normal, Color? color}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? textSecondary,
    );
  }
}

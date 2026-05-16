// lib/app/theme/premium_theme.dart
//
// ResumePilot PremiumTheme — Material 3 with deep purple/indigo brand palette.
// Dark mode is the primary (default) mode.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PremiumTheme {
  PremiumTheme._();

  // ── Brand palette ─────────────────────────────────────────────────────────

  static const Color primary = Color(0xFF7C3AED);       // Deep purple
  static const Color primaryDark = Color(0xFF4F46E5);   // Indigo
  static const Color accent = Color(0xFFA78BFA);        // Soft violet
  static const Color accentPink = Color(0xFFEC4899);    // Hot pink

  // Status
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color error = Color(0xFFEF4444);
  static const Color info = Color(0xFF3B82F6);

  // ── Dark mode tokens ──────────────────────────────────────────────────────

  static const Color darkBg = Color(0xFF0F0F14);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF1E1E35);
  static const Color darkCardAlt = Color(0xFF252540);
  static const Color darkBorder = Color(0xFF2D2D4A);
  static const Color darkBorderFocus = Color(0xFF7C3AED);
  static const Color darkTextPrimary = Color(0xFFE2E8F0);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextTertiary = Color(0xFF64748B);

  // ── Light mode tokens ─────────────────────────────────────────────────────

  static const Color lightBg = Color(0xFFF8F7FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFF1EFFE);
  static const Color lightBorder = Color(0xFFDDD6FE);
  static const Color lightTextPrimary = Color(0xFF1E1B4B);
  static const Color lightTextSecondary = Color(0xFF5B21B6);
  static const Color lightTextTertiary = Color(0xFF7C3AED);

  // ── Spec-aligned aliases (used by new screens) ────────────────────────────
  // Mirror the prompt's naming: bgPrimary = darkBg, textPrimary = darkTextPrimary, etc.
  static const Color bgPrimary     = darkBg;
  static const Color bgSecondary   = darkSurface;
  static const Color bgCard        = darkCard;
  static const Color textPrimary   = darkTextPrimary;
  static const Color textSecondary = darkTextSecondary;
  static const Color textMuted     = darkTextTertiary;

  // ── Gradients ─────────────────────────────────────────────────────────────


  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF0F0F14), Color(0xFF1A1A2E), Color(0xFF1E1535)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E1E35), Color(0xFF252545)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ── Text styles (Outfit font) ─────────────────────────────────────────────

  static TextStyle headline1(Color color) => GoogleFonts.outfit(
        fontSize: 32, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.5);

  static TextStyle headline2(Color color) => GoogleFonts.outfit(
        fontSize: 24, fontWeight: FontWeight.w700, color: color);

  static TextStyle headline3(Color color) => GoogleFonts.outfit(
        fontSize: 20, fontWeight: FontWeight.w600, color: color);

  static TextStyle body(Color color) => GoogleFonts.outfit(
        fontSize: 15, fontWeight: FontWeight.w400, color: color);

  static TextStyle bodySmall(Color color) => GoogleFonts.outfit(
        fontSize: 13, fontWeight: FontWeight.w400, color: color);

  static TextStyle label(Color color) => GoogleFonts.outfit(
        fontSize: 12, fontWeight: FontWeight.w600, color: color, letterSpacing: 0.4);

  static TextStyle caption(Color color) => GoogleFonts.outfit(
        fontSize: 11, fontWeight: FontWeight.w400, color: color);

  // ── Dark ThemeData ────────────────────────────────────────────────────────

  static ThemeData get darkMode {
    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.dark(
        primary: primary,
        onPrimary: Colors.white,
        secondary: accent,
        onSecondary: Colors.white,
        surface: darkSurface,
        onSurface: darkTextPrimary,
        error: error,
        outline: darkBorder,
        outlineVariant: darkBorder,
      ),
      scaffoldBackgroundColor: darkBg,
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, color: darkTextPrimary),
        headlineMedium: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, color: darkTextPrimary),
        titleLarge: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: darkTextPrimary),
        bodyLarge: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w400, color: darkTextPrimary),
        bodyMedium: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w400, color: darkTextSecondary),
        labelLarge: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w600, color: darkTextPrimary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: darkTextPrimary),
        titleTextStyle: GoogleFonts.outfit(
          color: darkTextPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardTheme(
        color: darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: darkCard,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: darkBorder)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: darkBorder)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: primary, width: 2)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: error, width: 2)),
        hintStyle: GoogleFonts.outfit(color: darkTextTertiary, fontSize: 15),
        labelStyle: GoogleFonts.outfit(color: darkTextSecondary, fontSize: 15),
        prefixIconColor: darkTextSecondary,
        suffixIconColor: darkTextSecondary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: darkBorder,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: darkBorder),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          textStyle: GoogleFonts.outfit(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: primary.withOpacity(0.15),
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.outfit(
                color: accent, fontSize: 11, fontWeight: FontWeight.w600);
          }
          return GoogleFonts.outfit(
              color: darkTextTertiary, fontSize: 11, fontWeight: FontWeight.w400);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: accent, size: 22);
          }
          return const IconThemeData(color: darkTextTertiary, size: 22);
        }),
      ),
      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: darkCardAlt,
        labelStyle: GoogleFonts.outfit(color: darkTextSecondary, fontSize: 13),
        side: const BorderSide(color: darkBorder),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: darkSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
    );
  }

  // ── Light ThemeData ───────────────────────────────────────────────────────

  static ThemeData get lightMode {
    final base = ThemeData.light(useMaterial3: true);
    return base.copyWith(
      colorScheme: ColorScheme.light(
        primary: primary,
        onPrimary: Colors.white,
        secondary: primaryDark,
        onSecondary: Colors.white,
        surface: lightSurface,
        onSurface: lightTextPrimary,
        error: error,
        outline: lightBorder,
      ),
      scaffoldBackgroundColor: lightBg,
      textTheme: GoogleFonts.outfitTextTheme(base.textTheme).copyWith(
        displayLarge: GoogleFonts.outfit(fontSize: 32, fontWeight: FontWeight.w700, color: lightTextPrimary),
        headlineMedium: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w600, color: lightTextPrimary),
        titleLarge: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.w600, color: lightTextPrimary),
        bodyLarge: GoogleFonts.outfit(fontSize: 16, color: lightTextPrimary),
        bodyMedium: GoogleFonts.outfit(fontSize: 14, color: lightTextSecondary),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: lightTextPrimary),
        titleTextStyle: GoogleFonts.outfit(
          color: lightTextPrimary, fontSize: 18, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardTheme(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: lightBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: lightSurface,
        indicatorColor: primary.withOpacity(0.12),
        height: 64,
      ),
    );
  }
}

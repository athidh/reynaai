// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── New Palette Tokens ──────────────────────────────────────────────────────
  // Primary:   #6A49FA (vivid indigo)
  // Deep:      #453284 (deep purple)
  // Sky:       #C6E6FF (soft sky blue)
  // Blush:     #FEDADA (blush pink)

  static const Color surface = Color(0xFF0D0B1A);
  static const Color surfaceDim = Color(0xFF0D0B1A);
  static const Color surfaceContainerLow = Color(0xFF11101F);
  static const Color surfaceContainer = Color(0xFF171526);
  static const Color surfaceContainerHigh = Color(0xFF1D1A2E);
  static const Color surfaceContainerHighest = Color(0xFF242136);
  static const Color surfaceBright = Color(0xFF2A273E);

  static const Color primary = Color(0xFF6A49FA);
  static const Color primaryContainer = Color(0xFF453284);
  static const Color primaryDim = Color(0xFF5A3CE0);
  static const Color onPrimary = Color(0xFFFFFFFF);

  static const Color secondary = Color(0xFFC6E6FF);
  static const Color secondaryContainer = Color(0xFF2A4060);
  static const Color onSecondary = Color(0xFF0A1A2F);

  static const Color tertiary = Color(0xFFFEDADA);
  static const Color tertiaryContainer = Color(0xFFF9A8A8);
  static const Color onTertiary = Color(0xFF3D1010);

  static const Color outline = Color(0xFF7A7890);
  static const Color outlineVariant = Color(0xFF4A4860);
  static const Color onSurface = Color(0xFFF0EEF6);
  static const Color onSurfaceVariant = Color(0xFFABA9C0);

  static const Color error = Color(0xFFFF6E84);
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: const ColorScheme.dark(
        surface: AppColors.surface,
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        tertiary: AppColors.tertiary,
        onTertiary: AppColors.onTertiary,
        error: AppColors.error,
        onSurface: AppColors.onSurface,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        outline: AppColors.outline,
        outlineVariant: AppColors.outlineVariant,
      ),
      textTheme: TextTheme(
        // Space Grotesk - Headlines/Labels
        displayLarge: GoogleFonts.spaceGrotesk(
          color: AppColors.onSurface,
          fontSize: 80,
          fontWeight: FontWeight.w900,
          letterSpacing: -2,
        ),
        displayMedium: GoogleFonts.spaceGrotesk(
          color: AppColors.onSurface,
          fontSize: 56,
          fontWeight: FontWeight.w900,
          letterSpacing: -2,
        ),
        headlineLarge: GoogleFonts.spaceGrotesk(
          color: AppColors.onSurface,
          fontSize: 36,
          fontWeight: FontWeight.w900,
          letterSpacing: -1,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          color: AppColors.onSurface,
          fontSize: 28,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.spaceGrotesk(
          color: AppColors.onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        labelLarge: GoogleFonts.spaceGrotesk(
          color: AppColors.onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 2.0,
        ),
        labelSmall: GoogleFonts.spaceGrotesk(
          color: AppColors.onSurfaceVariant,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.5,
        ),
        // Manrope - Body
        bodyLarge: GoogleFonts.manrope(
          color: AppColors.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w400,
        ),
        bodyMedium: GoogleFonts.manrope(
          color: AppColors.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w400,
        ),
        bodySmall: GoogleFonts.manrope(
          color: AppColors.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w300,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerHigh,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.primaryContainer, width: 1),
        ),
        hintStyle: GoogleFonts.spaceGrotesk(
          color: AppColors.outlineVariant,
          fontSize: 14,
          letterSpacing: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xCC0D0B1A),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.outlineVariant,
        elevation: 0,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}

// ─── Shared Decorations ─────────────────────────────────────────────────────

class AppDecorations {
  /// Glassmorphism card (modals, overlays)
  static BoxDecoration glassCard({double opacity = 0.4}) => BoxDecoration(
        color: AppColors.surfaceContainerHighest.withOpacity(opacity),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryContainer, width: 1.5),
      );

  /// Soft edge border
  static BoxDecoration razorEdge({Color? color}) => BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: color ?? AppColors.primaryContainer, width: 1.5),
      );

  /// Left accent border (tactical panel)
  static BoxDecoration leftAccentBorder({Color? color}) => BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          left: BorderSide(color: color ?? AppColors.primary, width: 4),
        ),
      );

  /// Soul Orb wrapper - glowing container
  static BoxDecoration soulOrb({double glowRadius = 60}) => BoxDecoration(
        color: AppColors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: glowRadius,
            spreadRadius: 8,
          ),
        ],
      );
}

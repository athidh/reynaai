// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Empress Protocol Color Tokens
  static const Color surface = Color(0xFF0B0E14);
  static const Color surfaceDim = Color(0xFF0B0E14);
  static const Color surfaceContainerLow = Color(0xFF10131A);
  static const Color surfaceContainer = Color(0xFF161A21);
  static const Color surfaceContainerHigh = Color(0xFF1C2028);
  static const Color surfaceContainerHighest = Color(0xFF22262F);
  static const Color surfaceBright = Color(0xFF282C36);

  static const Color primary = Color(0xFFDF8EFF);
  static const Color primaryContainer = Color(0xFFD67AFC);
  static const Color primaryDim = Color(0xFFD378F9);
  static const Color onPrimary = Color(0xFF4F006D);

  static const Color secondary = Color(0xFFB889FF);
  static const Color secondaryContainer = Color(0xFF5A2A9C);
  static const Color onSecondary = Color(0xFF320067);

  static const Color tertiary = Color(0xFFFF6D8D);
  static const Color tertiaryContainer = Color(0xFFFC306F);
  static const Color onTertiary = Color(0xFF480018);

  static const Color outline = Color(0xFF73757D);
  static const Color outlineVariant = Color(0xFF45484F);
  static const Color onSurface = Color(0xFFECEDF6);
  static const Color onSurfaceVariant = Color(0xFFA9ABB3);

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
        // Space Grotesk - Headlines/Labels (Command voice)
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
        // Manrope - Body (Supportive voice)
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
      // 0px border radius - No roundness rule
      cardTheme: const CardThemeData(
        color: AppColors.surfaceContainerHigh,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerHigh,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.zero,
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
        backgroundColor: Color(0xCC0B0E14),
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
        border: Border.all(color: AppColors.primaryContainer, width: 1.5),
      );

  /// Razor edge border only
  static BoxDecoration razorEdge({Color? color}) => BoxDecoration(
        border: Border.all(
            color: color ?? AppColors.primaryContainer, width: 1.5),
      );

  /// Left accent border (tactical panel)
  static BoxDecoration leftAccentBorder({Color? color}) => BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        border: Border(
          left: BorderSide(color: color ?? AppColors.primary, width: 4),
        ),
      );

  /// Soul Orb wrapper - rotated diamond glow
  static BoxDecoration soulOrb({double glowRadius = 60}) => BoxDecoration(
        color: AppColors.surfaceContainerHighest,
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

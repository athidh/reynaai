// lib/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // ── New Palette Tokens ──────────────────────────────────────────────────────
  // Primary:   #6A49FA (vivid indigo)
  // Deep:      #453284 (deep purple)
  // Sky:       #C6E6FF (soft sky blue)
  // Blush:     #FEDADA (blush pink)

  static bool isDark = false;

  // ── Core Brand Palette ─────────────────────────────────────────
  static Color get primary          => const Color(0xFF6A49FA);
  static Color get primaryContainer => isDark ? const Color(0xFF3B2890) : const Color(0xFFEBE6FF);
  static Color get primaryDim       => isDark ? const Color(0xFF5A3CE0) : const Color(0xFF866BFB);
  static Color get onPrimary        => const Color(0xFFFFFFFF);

  static Color get secondary        => const Color(0xFFC6E6FF);
  static Color get secondaryContainer => isDark ? const Color(0xFF233656) : const Color(0xFFE0F0FF);
  static Color get onSecondary      => isDark ? const Color(0xFFE0F0FF) : const Color(0xFF0A1A2F);

  static Color get tertiary         => const Color(0xFFFEDADA);
  static Color get tertiaryContainer => isDark ? const Color(0xFF904242) : const Color(0xFFFFEDED);
  static Color get onTertiary       => isDark ? const Color(0xFFFFEDED) : const Color(0xFF4A1A1A);

  // ── Premium Background & Surfaces (High Contrast) ──────────────
  static Color get background              => isDark ? const Color(0xFF090812) : const Color(0xFFF4F6F9);
  static Color get surface                 => isDark ? const Color(0xFF100E1C) : const Color(0xFFFFFFFF);
  static Color get surfaceContainerLow     => isDark ? const Color(0xFF151325) : const Color(0xFFF8F9FA);
  static Color get surfaceContainer        => isDark ? const Color(0xFF1B1830) : const Color(0xFFF1F3F5);
  static Color get surfaceContainerHigh    => isDark ? const Color(0xFF231F3D) : const Color(0xFFE9ECEF);
  static Color get surfaceContainerHighest => isDark ? const Color(0xFF2D284D) : const Color(0xFFDEE2E6);
  static Color get surfaceBright           => isDark ? const Color(0xFF2A273E) : const Color(0xFFFFFFFF);
  static Color get surfaceDim              => isDark ? const Color(0xFF090812) : const Color(0xFFF8F9FA);

  // ── Typography (Max Legibility) ────────────────────────────────
  static Color get onBackground     => isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0F172A);
  static Color get onSurface        => isDark ? const Color(0xFFF8FAFC) : const Color(0xFF1E293B);
  static Color get onSurfaceVariant => isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

  // ── Dividers & Borders & Faint Text ────────────────────────────
  // Previously low contrast, now 'outline' is prominent enough for text,
  // while 'outlineVariant' is subtle enough for borders.
  static Color get outline        => isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
  static Color get outlineVariant => isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1);

  // ── Status ─────────────────────────────────────────────────────
  static Color get error   => isDark ? const Color(0xFFFF5273) : const Color(0xFFE03131);
  static Color get onError => const Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: ColorScheme.light(
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
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
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

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.surface,
      colorScheme: ColorScheme.dark(
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
      textTheme: lightTheme.textTheme,
      cardTheme: lightTheme.cardTheme,
      inputDecorationTheme: lightTheme.inputDecorationTheme,
      bottomNavigationBarTheme: lightTheme.bottomNavigationBarTheme,
      pageTransitionsTheme: lightTheme.pageTransitionsTheme,
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

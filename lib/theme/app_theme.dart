import 'package:flutter/material.dart';

/// LoadOut visual identity. Brass + gunmetal palette — see `ROADMAP.md`
/// "Design language" section. Dark theme is the default (matches the
/// app icon and sign-in screen and most users' system preference); a
/// matching light theme exists for users who flip system appearance.
class AppTheme {
  // Brand palette — keep these the canonical reference for any new UI.
  static const Color brass = Color(0xFFC5A572);
  static const Color brassHighlight = Color(0xFFEBBF74);
  static const Color brassDeep = Color(0xFF8A6F3F);
  static const Color gunmetal = Color(0xFF1F2937);
  static const Color gunmetalDeep = Color(0xFF161F2B);
  static const Color gunmetalSurface = Color(0xFF2A3441);
  static const Color gunmetalSurfaceHigh = Color(0xFF394656);
  static const Color parchment = Color(0xFFFAF7F0);
  static const Color parchmentSurface = Color(0xFFFFFFFF);
  static const Color ink = Color(0xFF1F2937);
  static const Color oxblood = Color(0xFF7B2D2D);

  // ─────────────────────────── Dark (default) ───────────────────────────

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: brass,
      brightness: Brightness.dark,
      primary: brass,
      onPrimary: gunmetalDeep,
      secondary: brassHighlight,
      onSecondary: gunmetalDeep,
      surface: gunmetal,
      onSurface: const Color(0xFFF5F5F5),
      surfaceContainer: gunmetalSurface,
      surfaceContainerHigh: gunmetalSurfaceHigh,
      error: const Color(0xFFE57373),
      onError: gunmetalDeep,
      outline: const Color(0xFF4A5566),
    );
    return _buildTheme(scheme);
  }

  // ─────────────────────────── Light (opt-in) ───────────────────────────

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: brass,
      brightness: Brightness.light,
      primary: brassDeep,
      onPrimary: Colors.white,
      secondary: gunmetal,
      onSecondary: Colors.white,
      surface: parchment,
      onSurface: ink,
      surfaceContainer: parchmentSurface,
      error: oxblood,
      onError: Colors.white,
    );
    return _buildTheme(scheme);
  }

  // ─────────────────────────── Shared component overrides ───────────────────────────

  static ThemeData _buildTheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      textTheme: _textTheme(scheme),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _serif,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: scheme.onSurface,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.3)),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: BorderSide(color: scheme.outline.withValues(alpha: 0.6)),
          textStyle: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: scheme.primary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark
            ? scheme.surfaceContainer
            : scheme.surfaceContainer.withValues(alpha: 0.6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.4)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.75)),
        helperStyle: TextStyle(color: scheme.onSurface.withValues(alpha: 0.55)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.18),
        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: scheme.onSurface,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? scheme.primary : scheme.onSurface.withValues(alpha: 0.7),
          );
        }),
        height: 72,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outline.withValues(alpha: 0.25),
        thickness: 1,
        space: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: scheme.onSurface.withValues(alpha: 0.7),
        titleTextStyle: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: scheme.onSurface,
        ),
        subtitleTextStyle: TextStyle(
          fontSize: 13,
          color: scheme.onSurface.withValues(alpha: 0.65),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        contentTextStyle: TextStyle(color: scheme.onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  // System serif for display/heading text. iOS: New York / Times.
  // Android: Noto Serif (or platform default serif).
  static const String _serif = 'serif';

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = ThemeData(brightness: scheme.brightness).textTheme;
    final onSurface = scheme.onSurface;
    return base.copyWith(
      // Display + headline use serif for editorial weight on hero text.
      displayLarge: base.displayLarge?.copyWith(
        fontFamily: _serif,
        fontWeight: FontWeight.w400,
        color: onSurface,
        letterSpacing: -0.5,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontFamily: _serif,
        fontWeight: FontWeight.w400,
        color: onSurface,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontFamily: _serif,
        fontWeight: FontWeight.w500,
        color: onSurface,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontFamily: _serif,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontFamily: _serif,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontFamily: _serif,
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      // Title sizes stay sans for UI density readability.
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: onSurface,
      ),
      // Body uses sans (system default) for density.
      bodyLarge: base.bodyLarge?.copyWith(color: onSurface),
      bodyMedium: base.bodyMedium?.copyWith(
        color: onSurface.withValues(alpha: 0.85),
      ),
      bodySmall: base.bodySmall?.copyWith(
        color: onSurface.withValues(alpha: 0.65),
      ),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

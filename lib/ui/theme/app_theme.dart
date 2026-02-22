import 'package:flutter/material.dart';

/// KINGTRUX design system constants and theme definitions.
///
/// Provides consistent Material 3 light and dark themes with truck-industry
/// inspired deep-orange accent colors, a harmonious typography scale,
/// uniform shape constants, and spacing helpers.
abstract final class AppTheme {
  // ---------------------------------------------------------------------------
  // Seed / brand color
  // ---------------------------------------------------------------------------
  static const Color seed = Color(0xFFE65100); // deep-orange (truck-amber)

  // ---------------------------------------------------------------------------
  // Spacing scale (8-dp grid)
  // ---------------------------------------------------------------------------
  static const double spaceXS = 4.0;
  static const double spaceSM = 8.0;
  static const double spaceMD = 16.0;
  static const double spaceLG = 24.0;
  static const double spaceXL = 32.0;

  // ---------------------------------------------------------------------------
  // Border-radius tokens
  // ---------------------------------------------------------------------------
  static const double radiusSM = 8.0;
  static const double radiusMD = 12.0;
  static const double radiusLG = 16.0;
  static const double radiusXL = 24.0;

  // ---------------------------------------------------------------------------
  // Elevation
  // ---------------------------------------------------------------------------
  static const double elevationCard = 2.0;
  static const double elevationSheet = 4.0;

  // ---------------------------------------------------------------------------
  // Typography
  // ---------------------------------------------------------------------------
  static const TextTheme _textTheme = TextTheme(
    headlineSmall: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15),
    titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.5),
    bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.25),
    bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.4),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
  );

  // ---------------------------------------------------------------------------
  // Shared component themes
  // ---------------------------------------------------------------------------
  static AppBarTheme _appBarTheme(ColorScheme cs) => AppBarTheme(
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: false,
        titleTextStyle: _textTheme.titleLarge?.copyWith(color: cs.onSurface),
      );

  static CardTheme _cardTheme(ColorScheme cs) => CardTheme(
        elevation: elevationCard,
        color: cs.surfaceContainerLow,
        margin: const EdgeInsets.all(spaceMD),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLG),
        ),
      );

  static BottomSheetThemeData _bottomSheetTheme(ColorScheme cs) =>
      BottomSheetThemeData(
        backgroundColor: cs.surfaceContainerLow,
        modalBackgroundColor: cs.surfaceContainerLow,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(radiusXL),
          ),
        ),
        showDragHandle: true,
      );

  static FloatingActionButtonThemeData _fabTheme(ColorScheme cs) =>
      FloatingActionButtonThemeData(
        backgroundColor: cs.primaryContainer,
        foregroundColor: cs.onPrimaryContainer,
        elevation: elevationSheet,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
      );

  static ElevatedButtonThemeData _elevatedButtonTheme(ColorScheme cs) =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          padding: const EdgeInsets.symmetric(
            horizontal: spaceLG,
            vertical: spaceSM + spaceXS,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusMD),
          ),
        ),
      );

  static SnackBarThemeData _snackBarTheme(ColorScheme cs) => SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMD),
        ),
        backgroundColor: cs.inverseSurface,
        contentTextStyle: TextStyle(color: cs.onInverseSurface),
      );

  // ---------------------------------------------------------------------------
  // Light theme
  // ---------------------------------------------------------------------------
  static ThemeData get light {
    final cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    );
    return _buildTheme(cs);
  }

  // ---------------------------------------------------------------------------
  // Dark theme
  // ---------------------------------------------------------------------------
  static ThemeData get dark {
    final cs = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return _buildTheme(cs);
  }

  // ---------------------------------------------------------------------------
  // Build ThemeData from a ColorScheme
  // ---------------------------------------------------------------------------
  static ThemeData _buildTheme(ColorScheme cs) => ThemeData(
        useMaterial3: true,
        colorScheme: cs,
        textTheme: _textTheme,
        appBarTheme: _appBarTheme(cs),
        cardTheme: _cardTheme(cs),
        bottomSheetTheme: _bottomSheetTheme(cs),
        floatingActionButtonTheme: _fabTheme(cs),
        elevatedButtonTheme: _elevatedButtonTheme(cs),
        snackBarTheme: _snackBarTheme(cs),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? cs.primary : null,
          ),
          trackColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? cs.primaryContainer : null,
          ),
        ),
        dividerTheme: DividerThemeData(
          color: cs.outlineVariant,
          thickness: 1,
          space: spaceMD,
        ),
      );
}

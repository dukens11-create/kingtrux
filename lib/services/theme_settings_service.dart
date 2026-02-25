import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preset color themes available in the KINGTRUX app.
enum ThemeOption {
  /// Default deep-orange truck-amber accent (original KINGTRUX brand colors).
  classic,

  /// High-contrast yellow accent for improved visibility.
  highContrast,

  /// Deep-blue accent.
  blue,

  /// Forest-green accent.
  green,

  /// Deep-red accent.
  red,

  /// Driver-defined custom accent color.
  custom,
}

/// Persists the driver's chosen [ThemeOption] and optional custom accent color
/// to device storage via [SharedPreferences].
class ThemeSettingsService {
  static const _keyOption = 'theme_option';
  static const _keyCustomAccent = 'theme_custom_accent';

  // ---------------------------------------------------------------------------
  // Default / preset seed colors
  // ---------------------------------------------------------------------------

  /// The factory-default seed color (Classic theme).
  static const Color defaultSeedColor = Color(0xFFE65100);

  /// Seed colors for every preset [ThemeOption].
  ///
  /// The [ThemeOption.custom] entry is the fallback used when no custom color
  /// has been saved yet.
  static const Map<ThemeOption, Color> presetSeedColors = {
    ThemeOption.classic: Color(0xFFE65100),      // deep-orange
    ThemeOption.highContrast: Color(0xFFFFD600), // high-contrast yellow
    ThemeOption.blue: Color(0xFF1565C0),         // deep-blue
    ThemeOption.green: Color(0xFF2E7D32),        // forest-green
    ThemeOption.red: Color(0xFFC62828),          // deep-red
    ThemeOption.custom: Color(0xFFE65100),       // fallback = classic
  };

  /// Human-readable display names for each [ThemeOption].
  static const Map<ThemeOption, String> optionLabels = {
    ThemeOption.classic: 'Classic',
    ThemeOption.highContrast: 'High Contrast',
    ThemeOption.blue: 'Blue',
    ThemeOption.green: 'Green',
    ThemeOption.red: 'Red',
    ThemeOption.custom: 'Custom',
  };

  // ---------------------------------------------------------------------------
  // Palette of selectable custom accent colors
  // ---------------------------------------------------------------------------

  /// Ordered list of Material accent colors offered for custom selection.
  static const List<Color> customPalette = [
    Color(0xFFE65100), // deep-orange (classic)
    Color(0xFFC62828), // deep-red
    Color(0xFFAD1457), // pink
    Color(0xFF6A1B9A), // deep-purple
    Color(0xFF283593), // indigo
    Color(0xFF1565C0), // deep-blue
    Color(0xFF00695C), // teal
    Color(0xFF2E7D32), // forest-green
    Color(0xFF33691E), // light-green dark
    Color(0xFF827717), // lime dark
    Color(0xFFF57F17), // amber dark
    Color(0xFFBF360C), // deep-orange dark
    Color(0xFF37474F), // blue-grey (neutral dark)
    Color(0xFF424242), // grey dark
    Color(0xFF4A148C), // purple
    Color(0xFF880E4F), // deep-pink
    Color(0xFF006064), // cyan dark
    Color(0xFF01579B), // light-blue dark
  ];

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  /// Load the persisted [ThemeOption].
  ///
  /// Returns [ThemeOption.classic] when nothing has been saved yet or on error.
  Future<ThemeOption> loadOption() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyOption);
      return ThemeOption.values.firstWhere(
        (o) => o.name == raw,
        orElse: () => ThemeOption.classic,
      );
    } catch (_) {
      return ThemeOption.classic;
    }
  }

  /// Persist [option] to device storage.
  Future<void> saveOption(ThemeOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOption, option.name);
  }

  /// Load the custom accent [Color] (used when [ThemeOption.custom] is active).
  ///
  /// Returns [defaultSeedColor] when nothing has been saved yet or on error.
  Future<Color> loadCustomAccent() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getInt(_keyCustomAccent);
      if (raw == null) return defaultSeedColor;
      return Color(raw);
    } catch (_) {
      return defaultSeedColor;
    }
  }

  /// Persist [color] as the custom accent color.
  Future<void> saveCustomAccent(Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyCustomAccent, color.value);
  }
}

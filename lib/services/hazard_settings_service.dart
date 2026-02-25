import 'package:shared_preferences/shared_preferences.dart';

/// In-navigation hazard alert settings.
class HazardSettings {
  const HazardSettings({
    this.enableLowBridgeWarnings = true,
    this.enableSharpCurveWarnings = true,
    this.enableDowngradeHillWarnings = true,
    this.enableHazardTts = true,
  });

  /// Whether to show alerts for low bridges / height restrictions.
  final bool enableLowBridgeWarnings;

  /// Whether to show alerts for sharp curves.
  final bool enableSharpCurveWarnings;

  /// Whether to show alerts for steep downgrade hills.
  final bool enableDowngradeHillWarnings;

  /// Whether hazard alerts should be spoken aloud.
  ///
  /// Both this flag **and** the global voice-guidance toggle must be true for
  /// TTS to fire.
  final bool enableHazardTts;

  /// Return a copy with the specified fields overridden.
  HazardSettings copyWith({
    bool? enableLowBridgeWarnings,
    bool? enableSharpCurveWarnings,
    bool? enableDowngradeHillWarnings,
    bool? enableHazardTts,
  }) {
    return HazardSettings(
      enableLowBridgeWarnings:
          enableLowBridgeWarnings ?? this.enableLowBridgeWarnings,
      enableSharpCurveWarnings:
          enableSharpCurveWarnings ?? this.enableSharpCurveWarnings,
      enableDowngradeHillWarnings:
          enableDowngradeHillWarnings ?? this.enableDowngradeHillWarnings,
      enableHazardTts: enableHazardTts ?? this.enableHazardTts,
    );
  }
}

/// Persists [HazardSettings] to device storage via [SharedPreferences].
class HazardSettingsService {
  static const _keyLowBridge = 'hazard_enable_low_bridge';
  static const _keySharpCurve = 'hazard_enable_sharp_curve';
  static const _keyDowngradeHill = 'hazard_enable_downgrade_hill';
  static const _keyHazardTts = 'hazard_enable_tts';

  /// Load persisted hazard settings.
  ///
  /// Returns all-defaults ([HazardSettings()]) when no saved values are found
  /// or on error.
  Future<HazardSettings> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return HazardSettings(
        enableLowBridgeWarnings: prefs.getBool(_keyLowBridge) ?? true,
        enableSharpCurveWarnings: prefs.getBool(_keySharpCurve) ?? true,
        enableDowngradeHillWarnings: prefs.getBool(_keyDowngradeHill) ?? true,
        enableHazardTts: prefs.getBool(_keyHazardTts) ?? true,
      );
    } catch (_) {
      return const HazardSettings();
    }
  }

  /// Persist [settings] to device storage.
  Future<void> save(HazardSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyLowBridge, settings.enableLowBridgeWarnings);
    await prefs.setBool(_keySharpCurve, settings.enableSharpCurveWarnings);
    await prefs.setBool(_keyDowngradeHill, settings.enableDowngradeHillWarnings);
    await prefs.setBool(_keyHazardTts, settings.enableHazardTts);
  }
}

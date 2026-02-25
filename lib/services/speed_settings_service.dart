import 'package:shared_preferences/shared_preferences.dart';
import '../models/commercial_speed_settings.dart';

/// Persists speed-alert settings to device storage via [SharedPreferences].
class SpeedSettingsService {
  static const _keyUnderspeedThreshold = 'speed_underspeed_threshold_mph';

  // Commercial speed settings keys
  static const _keyCommercialEnabled = 'commercial_speed_enabled';
  static const _keyCommercialMaxSpeedMs = 'commercial_max_speed_ms';
  static const _keyCommercialUnit = 'commercial_speed_unit';
  static const _keyCommercialStateLimits = 'commercial_state_limits_enabled';

  /// Default underspeed threshold in mph.
  static const double defaultUnderspeedThresholdMph = 10.0;

  /// Load persisted speed settings.
  ///
  /// Returns [defaultUnderspeedThresholdMph] when no saved value is found.
  Future<double> loadUnderspeedThreshold() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getDouble(_keyUnderspeedThreshold) ??
          defaultUnderspeedThresholdMph;
    } catch (_) {
      return defaultUnderspeedThresholdMph;
    }
  }

  /// Persist the underspeed threshold in mph.
  Future<void> saveUnderspeedThreshold(double thresholdMph) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyUnderspeedThreshold, thresholdMph);
  }

  /// Load persisted commercial/truck max-speed settings.
  ///
  /// Returns [CommercialSpeedSettings.defaults()] when no saved value is found.
  Future<CommercialSpeedSettings> loadCommercialSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final defaults = CommercialSpeedSettings.defaults();
      final enabled = prefs.getBool(_keyCommercialEnabled) ?? defaults.enabled;
      final maxSpeedMs =
          prefs.getDouble(_keyCommercialMaxSpeedMs) ?? defaults.maxSpeedMs;
      final unitIndex = prefs.getInt(_keyCommercialUnit) ??
          SpeedUnit.values.indexOf(defaults.unit);
      final unit = SpeedUnit.values[unitIndex.clamp(0, SpeedUnit.values.length - 1)];
      final enableStateLimits =
          prefs.getBool(_keyCommercialStateLimits) ?? defaults.enableStateLimits;
      return CommercialSpeedSettings(
        enabled: enabled,
        maxSpeedMs: maxSpeedMs,
        unit: unit,
        enableStateLimits: enableStateLimits,
      );
    } catch (_) {
      return CommercialSpeedSettings.defaults();
    }
  }

  /// Persist [settings] to device storage.
  Future<void> saveCommercialSettings(CommercialSpeedSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyCommercialEnabled, settings.enabled);
    await prefs.setDouble(_keyCommercialMaxSpeedMs, settings.maxSpeedMs);
    await prefs.setInt(_keyCommercialUnit, SpeedUnit.values.indexOf(settings.unit));
    await prefs.setBool(_keyCommercialStateLimits, settings.enableStateLimits);
  }
}

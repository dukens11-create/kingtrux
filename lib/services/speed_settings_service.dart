import 'package:shared_preferences/shared_preferences.dart';

/// Persists speed-alert settings to device storage via [SharedPreferences].
class SpeedSettingsService {
  static const _keyUnderspeedThreshold = 'speed_underspeed_threshold_mph';

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
}

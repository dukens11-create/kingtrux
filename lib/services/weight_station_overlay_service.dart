import 'package:shared_preferences/shared_preferences.dart';

/// Persists the weight-station overlay visibility preference to device
/// storage via [SharedPreferences].
///
/// The overlay is **hidden by default** so drivers who do not use it are
/// not affected.  Users can enable it through the Map Overlays section in
/// Route Options settings.
class WeightStationOverlayService {
  static const _key = 'show_weight_station_overlay';

  /// Load the persisted preference.
  ///
  /// Returns `false` (hidden) when no value has been saved yet or on error.
  Future<bool> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Persist [value] as the weight-station overlay visibility preference.
  Future<void> save(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

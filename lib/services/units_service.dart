import 'package:shared_preferences/shared_preferences.dart';

/// Persists the driver's distance / speed units preference.
///
/// SharedPreferences key: `use_metric_units`
/// - `true` → kilometres / km/h
/// - `false` → miles / mph (default)
class UnitsService {
  static const _key = 'use_metric_units';

  /// Load the persisted units preference; defaults to `false` (imperial).
  Future<bool> load() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  /// Persist [useMetric] to device storage.
  Future<void> save(bool useMetric) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, useMetric);
  }
}

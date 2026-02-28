import 'package:shared_preferences/shared_preferences.dart';

/// Persists extra route-avoidance options (avoid ferries, avoid unpaved) to
/// device storage via [SharedPreferences].
///
/// Note: toll avoidance is persisted separately by [TollPreferenceService].
class RouteOptionsService {
  static const _keyAvoidFerries = 'route_opt_avoid_ferries';
  static const _keyAvoidUnpaved = 'route_opt_avoid_unpaved';

  /// Load [avoidFerries] from device storage. Returns `false` when no value
  /// has been saved yet or on error.
  Future<bool> loadAvoidFerries() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyAvoidFerries) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Persist [value] as the avoid-ferries preference.
  Future<void> saveAvoidFerries(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAvoidFerries, value);
  }

  /// Load [avoidUnpaved] from device storage. Returns `false` when no value
  /// has been saved yet or on error.
  Future<bool> loadAvoidUnpaved() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyAvoidUnpaved) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Persist [value] as the avoid-unpaved-roads preference.
  Future<void> saveAvoidUnpaved(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAvoidUnpaved, value);
  }
}

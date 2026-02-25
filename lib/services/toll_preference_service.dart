import 'package:shared_preferences/shared_preferences.dart';
import '../models/toll_preference.dart';

/// Persists the driver's toll preference to device storage via
/// [SharedPreferences].
class TollPreferenceService {
  static const _key = 'toll_preference';

  /// Load the persisted [TollPreference].
  ///
  /// Returns [TollPreference.any] when no value has been saved yet or on error.
  Future<TollPreference> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_key);
      return value == TollPreference.tollFree.name
          ? TollPreference.tollFree
          : TollPreference.any;
    } catch (_) {
      return TollPreference.any;
    }
  }

  /// Persist [preference] to device storage.
  Future<void> save(TollPreference preference) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, preference.name);
  }
}

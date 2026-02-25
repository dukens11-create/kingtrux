import 'package:shared_preferences/shared_preferences.dart';
import '../models/truck_stop_brand.dart';

/// Persists the set of enabled [TruckStopBrand] filters via [SharedPreferences].
///
/// When no value is stored (first launch), all brands are considered enabled.
class TruckStopBrandSettingsService {
  static const _key = 'truck_stop_enabled_brands';

  /// Load the set of enabled brands.
  ///
  /// Returns all brands when nothing has been persisted yet or on any error.
  Future<Set<TruckStopBrand>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_key);
      if (stored == null) return Set.of(TruckStopBrand.values);
      final result = <TruckStopBrand>{};
      for (final name in stored) {
        final match = TruckStopBrand.values
            .where((b) => b.name == name)
            .firstOrNull;
        if (match != null) result.add(match);
      }
      return result;
    } catch (_) {
      return Set.of(TruckStopBrand.values);
    }
  }

  /// Persist [brands] to device storage.
  Future<void> save(Set<TruckStopBrand> brands) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, brands.map((b) => b.name).toList());
  }
}

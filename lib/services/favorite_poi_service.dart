import 'package:shared_preferences/shared_preferences.dart';

/// Persists favourite POI IDs to device storage via [SharedPreferences].
class FavoritePoiService {
  static const _key = 'favorite_poi_ids';

  /// Load the set of favourite POI IDs.
  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(_key) ?? []).toSet();
  }

  /// Persist [ids] to device storage.
  Future<void> save(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, ids.toList());
  }
}

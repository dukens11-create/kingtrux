import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the set of favorite POI IDs to device storage via SharedPreferences.
class FavoritesService {
  static const _key = 'poi_favorites';

  /// Load the saved favorite POI IDs, or return an empty set if none.
  Future<Set<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.cast<String>().toSet();
    } catch (_) {
      return {};
    }
  }

  /// Persist [favorites] to device storage.
  Future<void> save(Set<String> favorites) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(favorites.toList()));
  }
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/poi.dart';

/// Persists and retrieves favourite [Poi] items using [SharedPreferences].
///
/// Favourites are stored as a JSON-encoded list of [Poi] maps under the key
/// [_key].  Only the fields required to reconstruct a [Poi] are saved.
class PoiFavoritesService {
  static const _key = 'poi_favorites';

  /// Load the full list of favourite POIs from device storage.
  ///
  /// Returns an empty list when no favourites have been saved yet or if the
  /// stored data cannot be parsed.
  Future<List<Poi>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => _poiFromJson(e as Map<String, dynamic>))
          .whereType<Poi>()
          .toList();
    } catch (e) {
      debugPrint('PoiFavoritesService.load error: $e');
      return [];
    }
  }

  /// Persist [favorites] to device storage, replacing any previously saved list.
  Future<void> save(List<Poi> favorites) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(favorites.map(_poiToJson).toList());
      await prefs.setString(_key, encoded);
    } catch (e) {
      debugPrint('PoiFavoritesService.save error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Serialization helpers
  // ---------------------------------------------------------------------------

  Map<String, dynamic> _poiToJson(Poi poi) => {
        'id': poi.id,
        'type': poi.type.name,
        'name': poi.name,
        'lat': poi.lat,
        'lng': poi.lng,
        'tags': poi.tags,
      };

  Poi? _poiFromJson(Map<String, dynamic> json) {
    try {
      final typeStr = json['type'] as String?;
      final type = PoiType.values.firstWhere(
        (t) => t.name == typeStr,
        orElse: () => PoiType.fuel,
      );
      return Poi(
        id: json['id'] as String,
        type: type,
        name: json['name'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        tags: Map<String, dynamic>.from(
          json['tags'] as Map<dynamic, dynamic>? ?? {},
        ),
      );
    } catch (e) {
      debugPrint('PoiFavoritesService: failed to parse POI: $e');
      return null;
    }
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_stop.dart';

/// Persists the last-set route destination across app sessions.
///
/// SharedPreferences keys:
/// - `dest_lat` – single-destination latitude (legacy / long-press map).
/// - `dest_lng` – single-destination longitude.
/// - `route_stops` – JSON-encoded list of [TripStop] objects for the
///   multi-stop "Where to?" flow.
class DestinationPersistenceService {
  static const _keyLat = 'dest_lat';
  static const _keyLng = 'dest_lng';
  static const _keyStops = 'route_stops';

  /// Persist [lat] / [lng] to device storage.
  Future<void> save(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_keyLat, lat);
    await prefs.setDouble(_keyLng, lng);
  }

  /// Load the last-saved destination, or `null` if none is persisted.
  Future<({double lat, double lng})?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_keyLat);
    final lng = prefs.getDouble(_keyLng);
    if (lat == null || lng == null) return null;
    return (lat: lat, lng: lng);
  }

  /// Remove any persisted single destination (e.g. after the user clears the
  /// route).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLat);
    await prefs.remove(_keyLng);
  }

  // ---------------------------------------------------------------------------
  // Multi-stop route persistence
  // ---------------------------------------------------------------------------

  /// Persist [stops] as a JSON-encoded list.
  Future<void> saveStops(List<TripStop> stops) async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(stops.map((s) => s.toJson()).toList());
    await prefs.setString(_keyStops, encoded);
  }

  /// Load the previously-saved stop list.  Returns an empty list if nothing
  /// has been persisted yet.
  Future<List<TripStop>> loadStops() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keyStops);
    if (jsonStr == null) return [];
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return list
        .map((e) => TripStop.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Remove any persisted multi-stop list.
  Future<void> clearStops() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyStops);
  }
}

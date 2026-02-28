import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last-set route destination across app sessions.
///
/// SharedPreferences keys:
/// - `dest_lat` – destination latitude as a double string.
/// - `dest_lng` – destination longitude as a double string.
class DestinationPersistenceService {
  static const _keyLat = 'dest_lat';
  static const _keyLng = 'dest_lng';

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

  /// Remove any persisted destination (e.g. after the user clears the route).
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyLat);
    await prefs.remove(_keyLng);
  }
}

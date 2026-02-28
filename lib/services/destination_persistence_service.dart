import 'package:shared_preferences/shared_preferences.dart';

/// Persists the last used destination (lat/lng) to device storage so that the
/// app can auto-rebuild the route on the next launch.
class DestinationPersistenceService {
  static const _latKey = 'dest_lat';
  static const _lngKey = 'dest_lng';

  /// Load the persisted destination.
  ///
  /// Returns a record `(lat, lng)` when a destination has previously been
  /// saved, or `null` when no destination is stored or on error.
  Future<({double lat, double lng})?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_latKey);
      final lng = prefs.getDouble(_lngKey);
      if (lat != null && lng != null) return (lat: lat, lng: lng);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Persist [lat] / [lng] as the current destination.
  Future<void> save(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_latKey, lat);
    await prefs.setDouble(_lngKey, lng);
  }

  /// Remove any previously stored destination.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_latKey);
    await prefs.remove(_lngKey);
  }
}

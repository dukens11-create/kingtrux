import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists map-specific user preferences (map type, onboarding dismissal)
/// to device storage via [SharedPreferences].
class MapPreferencesService {
  static const _keyMapType = 'map_type';
  static const _keyOnboardingDismissed = 'map_onboarding_dismissed';

  // ---------------------------------------------------------------------------
  // Map type
  // ---------------------------------------------------------------------------

  /// Load the persisted [MapType].
  ///
  /// Returns [MapType.normal] when nothing has been saved yet or on error.
  Future<MapType> loadMapType() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyMapType);
      switch (raw) {
        case 'satellite':
          return MapType.satellite;
        default:
          return MapType.normal;
      }
    } catch (_) {
      return MapType.normal;
    }
  }

  /// Persist [mapType] to device storage.
  Future<void> saveMapType(MapType mapType) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = mapType == MapType.satellite ? 'satellite' : 'normal';
    await prefs.setString(_keyMapType, raw);
  }

  // ---------------------------------------------------------------------------
  // Onboarding dismissal
  // ---------------------------------------------------------------------------

  /// Returns `true` when the user has dismissed the onboarding overlay.
  Future<bool> loadOnboardingDismissed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyOnboardingDismissed) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Persist that the user has dismissed the onboarding overlay.
  Future<void> saveOnboardingDismissed() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyOnboardingDismissed, true);
  }
}

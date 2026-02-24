import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/truck_profile.dart';

/// Persists [TruckProfile] to device storage via SharedPreferences.
class TruckProfileService {
  static const _key = 'truck_profile';

  /// Load the saved profile, or return [TruckProfile.defaultProfile] if none.
  Future<TruckProfile> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return TruckProfile.defaultProfile();
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return TruckProfile.fromJson(map);
    } catch (_) {
      return TruckProfile.defaultProfile();
    }
  }

  /// Persist [profile] to device storage.
  Future<void> save(TruckProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(profile.toJson()));
  }
}

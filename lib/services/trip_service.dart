import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';

/// Persists the active trip to device storage via SharedPreferences.
class TripService {
  static const _activeKey = 'active_trip';

  /// Load the last active trip, or return `null` if none is saved.
  Future<Trip?> loadActiveTrip() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_activeKey);
    if (raw == null) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return Trip.fromJson(map);
    } catch (_) {
      return null;
    }
  }

  /// Persist [trip] as the active trip.
  Future<void> saveActiveTrip(Trip trip) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeKey, jsonEncode(trip.toJson()));
  }

  /// Remove the persisted active trip.
  Future<void> clearActiveTrip() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeKey);
  }
}

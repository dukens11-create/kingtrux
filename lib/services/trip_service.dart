import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip.dart';

/// Persists [Trip] objects to device storage using [SharedPreferences].
///
/// Trips are stored as a JSON-encoded list under [_key].  The structure is
/// designed to be forward-compatible with a future Firebase/cloud sync layer:
/// each trip carries a stable [Trip.id] that can serve as the Firestore
/// document ID.
class TripService {
  static const _key = 'saved_trips';

  /// Load all saved trips from device storage.
  ///
  /// Returns an empty list when no trips have been saved or if the stored
  /// data cannot be parsed.
  Future<List<Trip>> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Trip.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('TripService.load error: $e');
      return [];
    }
  }

  /// Persist [trips] to device storage, replacing any previously saved list.
  Future<void> save(List<Trip> trips) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode(trips.map((t) => t.toJson()).toList()),
      );
    } catch (e) {
      debugPrint('TripService.save error: $e');
    }
  }
}

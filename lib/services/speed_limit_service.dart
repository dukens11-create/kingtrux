import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

/// Queries OpenStreetMap via the Overpass API to find the posted road speed
/// limit nearest to a given GPS coordinate.
///
/// Results are cached: a new Overpass request is only made after the driver
/// has moved more than [requeryDistanceMeters] from the position of the last
/// successful query.
class SpeedLimitService {
  /// Minimum distance (metres) the driver must travel before a new Overpass
  /// query is issued.
  static const double requeryDistanceMeters = 200.0;

  /// Search radius (metres) around the driver's position.
  static const double searchRadiusMeters = 50.0;

  double? _lastQueryLat;
  double? _lastQueryLng;
  double? _cachedLimitMph;
  bool _queryInProgress = false;

  /// Returns the cached speed limit in mph, or `null` if unknown.
  double? get cachedLimitMph => _cachedLimitMph;

  /// Query the road speed limit at [lat]/[lng].
  ///
  /// Returns the speed limit in mph, or `null` if no `maxspeed` tag is found
  /// or if the query fails. Skips the network request if the driver has not
  /// moved [requeryDistanceMeters] since the last successful query.
  Future<double?> queryLimit(double lat, double lng) async {
    if (_queryInProgress) return _cachedLimitMph;

    // Skip if close to previous query position.
    if (_lastQueryLat != null && _lastQueryLng != null) {
      final dist = _haversine(lat, lng, _lastQueryLat!, _lastQueryLng!);
      if (dist < requeryDistanceMeters) return _cachedLimitMph;
    }

    _queryInProgress = true;
    try {
      final query =
          '[out:json][timeout:10];way[maxspeed](around:${searchRadiusMeters.toInt()},$lat,$lng);out tags;';
      final response = await http.post(
        Uri.parse(Config.overpassApiUrl),
        body: query,
      ).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint(
          'SpeedLimitService: Overpass error ${response.statusCode}',
        );
        return _cachedLimitMph;
      }

      final limit = _parseResponse(response.body);
      _cachedLimitMph = limit;
      _lastQueryLat = lat;
      _lastQueryLng = lng;
      return limit;
    } catch (e) {
      debugPrint('SpeedLimitService: query failed: $e');
      return _cachedLimitMph;
    } finally {
      _queryInProgress = false;
    }
  }

  /// Force the next [queryLimit] call to issue a new Overpass request.
  void reset() {
    _lastQueryLat = null;
    _lastQueryLng = null;
    _cachedLimitMph = null;
    _queryInProgress = false;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  double? _parseResponse(String body) {
    try {
      final data = json.decode(body) as Map<String, dynamic>;
      final elements = data['elements'] as List? ?? [];
      final speeds = <double>[];
      for (final el in elements) {
        final tags = (el['tags'] as Map?)?.cast<String, dynamic>() ?? {};
        final raw = tags['maxspeed'] as String?;
        if (raw == null) continue;
        final mph = _parseMph(raw);
        if (mph != null) speeds.add(mph);
      }
      if (speeds.isEmpty) return null;
      // Return the most common value; ties resolved by first occurrence.
      final freq = <double, int>{};
      for (final s in speeds) {
        freq[s] = (freq[s] ?? 0) + 1;
      }
      return freq.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    } catch (e) {
      debugPrint('SpeedLimitService: parse error: $e');
      return null;
    }
  }

  /// Parse an OSM `maxspeed` tag value to mph.
  ///
  /// Handles: `"55"`, `"55 mph"`, `"90 km/h"`.
  /// Returns `null` for non-numeric values (e.g., `"national"`, `"urban"`).
  double? _parseMph(String value) {
    final v = value.trim().toLowerCase();
    if (v.endsWith('km/h')) {
      final n = double.tryParse(v.replaceAll(RegExp(r'\s*km/h'), '').trim());
      return n != null ? n * 0.621371 : null;
    }
    if (v.endsWith('mph')) {
      return double.tryParse(v.replaceAll(RegExp(r'\s*mph'), '').trim());
    }
    // No unit – assume mph (North American default in OSM).
    return double.tryParse(v);
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final phi1 = lat1 * math.pi / 180;
    final phi2 = lat2 * math.pi / 180;
    final dPhi = (lat2 - lat1) * math.pi / 180;
    final dLambda = (lng2 - lng1) * math.pi / 180;
    final sinDPhi = math.sin(dPhi / 2);
    final sinDLambda = math.sin(dLambda / 2);
    final a = sinDPhi * sinDPhi +
        math.cos(phi1) * math.cos(phi2) * sinDLambda * sinDLambda;
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }
}

import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/poi.dart';
import 'overpass_poi_service.dart';

// ---------------------------------------------------------------------------
// Geometry helpers (pure functions, package-level for easy unit testing)
// ---------------------------------------------------------------------------

/// Haversine distance in metres between two WGS-84 coordinates.
double weighStationHaversine(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const r = 6371000.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dPhi = (lat2 - lat1) * math.pi / 180;
  final dLambda = (lng2 - lng1) * math.pi / 180;
  final a = _sq(math.sin(dPhi / 2)) +
      math.cos(phi1) * math.cos(phi2) * _sq(math.sin(dLambda / 2));
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

double _sq(double x) => x * x;

/// Initial bearing from (lat1, lng1) → (lat2, lng2) in degrees [0, 360).
double weighStationBearing(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dLambda = (lng2 - lng1) * math.pi / 180;
  final y = math.sin(dLambda) * math.cos(phi2);
  final x = math.cos(phi1) * math.sin(phi2) -
      math.sin(phi1) * math.cos(phi2) * math.cos(dLambda);
  final theta = math.atan2(y, x);
  return (theta * 180 / math.pi + 360) % 360;
}

/// Minimum unsigned angular difference between two bearings, in [0, 180].
double weighStationAngularDiff(double b1, double b2) {
  final diff = ((b1 - b2) % 360 + 360) % 360;
  return diff <= 180 ? diff : 360 - diff;
}

/// Returns `true` if the target (toLat, toLng) is "ahead" of a driver at
/// (fromLat, fromLng) moving with [headingDeg], using a ±[maxDiffDeg] cone.
bool isAheadByHeading(
  double fromLat,
  double fromLng,
  double toLat,
  double toLng,
  double headingDeg, {
  double maxDiffDeg = 60.0,
}) {
  final bearing = weighStationBearing(fromLat, fromLng, toLat, toLng);
  return weighStationAngularDiff(bearing, headingDeg) <= maxDiffDeg;
}

/// Returns the index of the polyline point in [polyline] that is closest to
/// (lat, lng).
///
/// [polyline] is a list of `[lat, lng]` pairs.
int closestPolylineIndex(
  double lat,
  double lng,
  List<List<double>> polyline,
) {
  var bestIdx = 0;
  var bestDist = double.infinity;
  for (var i = 0; i < polyline.length; i++) {
    final d = weighStationHaversine(lat, lng, polyline[i][0], polyline[i][1]);
    if (d < bestDist) {
      bestDist = d;
      bestIdx = i;
    }
  }
  return bestIdx;
}

/// Returns `true` when the target is "ahead" of the driver along the route
/// polyline, meaning its closest polyline index is strictly greater than the
/// driver's closest polyline index.
///
/// Also checks that the target is within [corridorMeters] of the polyline so
/// that off-road POIs are not incorrectly classified.
bool isAheadOnRoute(
  double driverLat,
  double driverLng,
  double targetLat,
  double targetLng,
  List<List<double>> polyline, {
  double corridorMeters = 5000.0,
}) {
  if (polyline.isEmpty) return false;

  // Ensure target is within the corridor around the polyline.
  var minTargetDist = double.infinity;
  for (final pt in polyline) {
    final d = weighStationHaversine(targetLat, targetLng, pt[0], pt[1]);
    if (d < minTargetDist) minTargetDist = d;
  }
  if (minTargetDist > corridorMeters) return false;

  final driverIdx = closestPolylineIndex(driverLat, driverLng, polyline);
  final targetIdx = closestPolylineIndex(targetLat, targetLng, polyline);
  return targetIdx > driverIdx;
}

// ---------------------------------------------------------------------------
// WeighStationAheadService
// ---------------------------------------------------------------------------

/// Continuously tracks the nearest weigh station (scale) to the driver,
/// in any direction, using a locally cached Overpass result set.
///
/// Call [update] on each GPS position update.  Results are derived from a
/// locally cached Overpass response; the cache is refreshed at most once per
/// [cacheTtl] and only when the driver has moved at least
/// [cacheMovementThresholdMeters] from the last fetch location.
///
/// "Passed" detection uses a two-step distance hysteresis:
///  1. Distance to the selected scale drops below [passedNearThresholdMeters].
///  2. Distance then rises above [passedFarHysteresisMeters].
/// At that point the scale is marked as passed and the next closest
/// scale is selected.
///
/// [onCacheRefreshed] is called after a background fetch succeeds so the
/// caller (e.g. AppState) can re-invoke [update] with the latest position to
/// immediately pick the best scale from fresh data.
class WeighStationAheadService {
  WeighStationAheadService(this._poiService);

  final OverpassPoiService _poiService;

  // ── Configuration ─────────────────────────────────────────────────────────

  /// Overpass search radius: 100 miles in metres.
  static const double searchRadiusMeters = 160934.0;

  /// How long cached scale data remains valid.
  static const Duration cacheTtl = Duration(minutes: 15);

  /// Minimum driver movement before the cache is considered stale by location
  /// (5 miles in metres).
  static const double cacheMovementThresholdMeters = 8046.72;

  /// Distance at which the driver is considered "near" the selected scale
  /// (0.5 miles in metres).
  static const double passedNearThresholdMeters = 804.672;

  /// After being near, if distance grows beyond this value the driver has
  /// passed the scale (1.5 miles in metres).
  static const double passedFarHysteresisMeters = 2413.72;

  // ── Cache ──────────────────────────────────────────────────────────────────

  List<Poi> _cachedScales = [];
  DateTime? _cacheTime;
  double? _cacheLat;
  double? _cacheLng;
  bool _isFetching = false;

  // ── Selection state ────────────────────────────────────────────────────────

  Poi? _selectedScale;
  bool _wasNear = false;
  final Set<String> _passedScaleIds = {};

  // ── Public API ─────────────────────────────────────────────────────────────

  /// Called after a background Overpass fetch completes successfully so the
  /// owner can re-invoke [update] to incorporate fresh data immediately.
  void Function()? onCacheRefreshed;

  /// Called when the driver passes (crosses) the currently selected scale.
  ///
  /// The passed [Poi] is the scale that was just crossed.  Use this to prompt
  /// the driver to report the scale's status.
  void Function(Poi passedScale)? onScalePassed;

  /// Returns the currently tracked scale (null if none found).
  Poi? get selectedScale => _selectedScale;

  /// Synchronously recomputes the closest scale from the cached data and
  /// returns it together with its distance in metres.
  ///
  /// When the cache is missing or stale, a background fetch is started
  /// automatically; [onCacheRefreshed] will fire once new data is available.
  (Poi?, double?) update({
    required double lat,
    required double lng,
  }) {
    // Trigger a background cache refresh if the data is missing or stale.
    if (_shouldRefreshCache(lat, lng) && !_isFetching) {
      _fetchInBackground(lat, lng);
    }

    return _recompute(lat, lng);
  }

  /// Reset all selection state (call when a new route or session starts).
  void reset() {
    _selectedScale = null;
    _wasNear = false;
    _passedScaleIds.clear();
  }

  // ── Test helpers ───────────────────────────────────────────────────────────

  /// Directly inject cached scales, bypassing the Overpass fetch.
  ///
  /// This is intended for unit tests only; do not call in production code.
  @visibleForTesting
  void injectCacheForTesting(List<Poi> scales) {
    _cachedScales = List.of(scales);
    _cacheTime = DateTime.now();
    _cacheLat = 0.0;
    _cacheLng = 0.0;
  }

  // ── Private helpers ────────────────────────────────────────────────────────

  (Poi?, double?) _recompute(double lat, double lng) {
    // Check whether the currently selected scale has been passed.
    if (_selectedScale != null) {
      final dist = weighStationHaversine(
        lat,
        lng,
        _selectedScale!.lat,
        _selectedScale!.lng,
      );
      if (dist <= passedNearThresholdMeters) {
        _wasNear = true;
      }
      if (_wasNear && dist > passedFarHysteresisMeters) {
        // Driver has crossed the scale — mark it passed and clear selection.
        final passed = _selectedScale!;
        _passedScaleIds.add(passed.id);
        _selectedScale = null;
        _wasNear = false;
        onScalePassed?.call(passed);
      }
    }

    // If no current selection, find the closest scale in any direction.
    if (_selectedScale == null) {
      _selectedScale = _findClosest(lat, lng);
      _wasNear = false;
    }

    if (_selectedScale == null) return (null, null);

    final dist = weighStationHaversine(
      lat,
      lng,
      _selectedScale!.lat,
      _selectedScale!.lng,
    );
    return (_selectedScale, dist);
  }

  Poi? _findClosest(double lat, double lng) {
    Poi? best;
    var bestDist = double.infinity;

    for (final poi in _cachedScales) {
      if (_passedScaleIds.contains(poi.id)) continue;

      final dist = weighStationHaversine(lat, lng, poi.lat, poi.lng);
      if (dist < bestDist) {
        bestDist = dist;
        best = poi;
      }
    }

    return best;
  }

  bool _shouldRefreshCache(double lat, double lng) {
    final fetchTime = _cacheTime;
    if (fetchTime == null) return true;
    if (DateTime.now().difference(fetchTime) > cacheTtl) return true;
    final cacheLat = _cacheLat;
    final cacheLng = _cacheLng;
    if (cacheLat == null || cacheLng == null) return true;
    final moved = weighStationHaversine(lat, lng, cacheLat, cacheLng);
    return moved > cacheMovementThresholdMeters;
  }

  void _fetchInBackground(double lat, double lng) {
    _isFetching = true;
    _poiService
        .fetchPois(
          centerLat: lat,
          centerLng: lng,
          enabledTypes: {PoiType.scale},
          radiusMeters: searchRadiusMeters,
        )
        .then((pois) {
          _cachedScales = pois;
          _cacheTime = DateTime.now();
          _cacheLat = lat;
          _cacheLng = lng;
          _isFetching = false;
          onCacheRefreshed?.call();
        })
        .catchError((Object e) {
          _isFetching = false;
          debugPrint('WeighStationAheadService: Overpass fetch error: $e');
        });
  }
}

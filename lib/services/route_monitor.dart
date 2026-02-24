import 'dart:math' as math;
import '../models/trip_stop.dart';

/// Callback fired when the driver approaches a trip stop.
typedef ApproachingStopCallback = void Function(TripStop stop);

/// Callback fired when the driver drifts off the planned route.
typedef OffRouteMonitorCallback = void Function(double distanceMeters);

/// Callback fired when the driver returns to the planned route.
typedef BackOnRouteCallback = void Function();

/// Monitors geofence conditions for an active route and trip.
///
/// Call [update] on each GPS position update to evaluate:
///   - Distance to the active route polyline (off-route / back-on-route)
///   - Distance to each upcoming trip stop (approaching-stop)
///
/// Off-route and back-on-route events are debounced: the condition must
/// persist for [offRouteDebounceCount] consecutive position updates before
/// the corresponding callback fires.  Approaching-stop alerts fire at most
/// once per stop (tracked by stop ID).
///
/// This service has no GPS subscription of its own; position updates are
/// supplied by the caller (e.g., [AppState]).
class RouteMonitor {
  // ---------------------------------------------------------------------------
  // Thresholds
  // ---------------------------------------------------------------------------

  /// Distance in metres at which an "approaching stop" alert is emitted.
  static const double approachingStopDistanceMeters = 5000.0; // 5 km

  /// Distance in metres from the route beyond which the driver is off-route.
  static const double offRouteThresholdMeters = 500.0;

  /// Consecutive position updates required before off-route / back-on-route
  /// callbacks fire (debounce).
  static const int offRouteDebounceCount = 3;

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------

  /// Fired once per stop when the driver comes within
  /// [approachingStopDistanceMeters] of that stop.
  ApproachingStopCallback? onApproachingStop;

  /// Fired when the driver is considered off-route (after debounce).
  OffRouteMonitorCallback? onOffRoute;

  /// Fired when the driver returns to the route (after debounce).
  BackOnRouteCallback? onBackOnRoute;

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  final Set<String> _announcedStopIds = {};
  int _offRouteCount = 0;
  int _onRouteCount = 0;
  bool _currentlyOffRoute = false;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Process a new GPS position against the active route and stops.
  ///
  /// [lat] / [lng] — current device coordinates.
  /// [routePolyline] — list of `[lat, lng]` pairs describing the active route.
  /// [stops] — trip stops to monitor (typically all stops not yet visited).
  void update({
    required double lat,
    required double lng,
    required List<List<double>> routePolyline,
    required List<TripStop> stops,
  }) {
    if (routePolyline.isEmpty) return;

    // ── Off-route / back-on-route ─────────────────────────────────────────
    final distToRoute = _distanceToPolyline(lat, lng, routePolyline);

    if (distToRoute > offRouteThresholdMeters) {
      _onRouteCount = 0;
      _offRouteCount++;
      if (!_currentlyOffRoute && _offRouteCount >= offRouteDebounceCount) {
        _currentlyOffRoute = true;
        onOffRoute?.call(distToRoute);
      }
    } else {
      _offRouteCount = 0;
      if (_currentlyOffRoute) {
        _onRouteCount++;
        if (_onRouteCount >= offRouteDebounceCount) {
          _currentlyOffRoute = false;
          _onRouteCount = 0;
          onBackOnRoute?.call();
        }
      }
    }

    // ── Approaching stops ─────────────────────────────────────────────────
    for (final stop in stops) {
      if (_announcedStopIds.contains(stop.id)) continue;
      final distToStop = _haversine(lat, lng, stop.lat, stop.lng);
      if (distToStop <= approachingStopDistanceMeters) {
        _announcedStopIds.add(stop.id);
        onApproachingStop?.call(stop);
      }
    }
  }

  /// Reset all internal state (call when a new route or trip is activated).
  void reset() {
    _announcedStopIds.clear();
    _offRouteCount = 0;
    _onRouteCount = 0;
    _currentlyOffRoute = false;
  }

  // ---------------------------------------------------------------------------
  // Geometry helpers
  // ---------------------------------------------------------------------------

  double _distanceToPolyline(
    double lat,
    double lng,
    List<List<double>> poly,
  ) {
    if (poly.length == 1) return _haversine(lat, lng, poly[0][0], poly[0][1]);
    var minDist = double.infinity;
    for (var i = 0; i < poly.length - 1; i++) {
      final d = _distanceToSegment(
        lat,
        lng,
        poly[i][0],
        poly[i][1],
        poly[i + 1][0],
        poly[i + 1][1],
      );
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  double _distanceToSegment(
    double pLat,
    double pLng,
    double aLat,
    double aLng,
    double bLat,
    double bLng,
  ) {
    final abLat = bLat - aLat;
    final abLng = bLng - aLng;
    final ab2 = abLat * abLat + abLng * abLng;
    if (ab2 == 0) return _haversine(pLat, pLng, aLat, aLng);
    final t =
        (((pLat - aLat) * abLat + (pLng - aLng) * abLng) / ab2)
            .clamp(0.0, 1.0);
    return _haversine(pLat, pLng, aLat + t * abLat, aLng + t * abLng);
  }

  /// Haversine distance in metres between two WGS-84 coordinates.
  double _haversine(double lat1, double lng1, double lat2, double lng2) {
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
}

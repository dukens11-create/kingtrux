import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/route_result.dart';
import '../models/navigation_maneuver.dart';

/// Callback invoked when the active maneuver changes.
typedef ManeuverCallback = void Function(
    NavigationManeuver maneuver, int index);

/// Callback invoked when the user has drifted off the planned route.
typedef OffRouteCallback = void Function(double distanceMeters);

/// Callback invoked when the destination is reached.
typedef ArrivalCallback = void Function();

/// Callback invoked when a spoken voice prompt should be played.
typedef VoiceCallback = void Function(String text);

/// Manages an active turn-by-turn navigation session.
///
/// This service provides the **foundation layer** for HERE Navigate SDK
/// integration. It uses:
///   - Maneuver steps from the HERE Routing REST API v8 ([RouteResult.maneuvers])
///   - Device GPS via [Geolocator] for position tracking
///   - Haversine geometry for off-route detection and maneuver advancement
///
/// Upgrade path: When the native HERE Navigate SDK is wired in (see
/// `HERE_NAVIGATE_SETUP.md`), replace the [Geolocator] position stream in
/// [start] with the SDK's `NavigatorInterface` callbacks while keeping the
/// same public API.
class NavigationSessionService {
  // ---------------------------------------------------------------------------
  // Thresholds
  // ---------------------------------------------------------------------------

  /// Distance in metres beyond which the user is considered off-route.
  static const double offRouteThresholdMeters = 50.0;

  /// Distance in metres before a maneuver at which to announce it.
  static const double announceBeforeMeters = 300.0;

  /// Distance in metres within which we consider the user to have reached a
  /// maneuver waypoint and advance to the next step.
  static const double waypointReachedMeters = 30.0;

  // ---------------------------------------------------------------------------
  // Event callbacks
  // ---------------------------------------------------------------------------

  /// Fired when the active (next) maneuver changes.
  ManeuverCallback? onManeuverUpdate;

  /// Fired when the user appears to have drifted off the planned route.
  OffRouteCallback? onOffRoute;

  /// Fired once when the final destination is reached.
  ArrivalCallback? onArrival;

  /// Fired when a voice prompt should be spoken.
  ///
  /// Hook this up to a TTS engine (e.g., `flutter_tts`) to produce audio
  /// guidance. Respects the caller-controlled [voiceGuidanceEnabled] flag.
  VoiceCallback? onVoicePrompt;

  // ---------------------------------------------------------------------------
  // State
  // ---------------------------------------------------------------------------

  RouteResult? _route;
  int _maneuverIndex = 0;
  StreamSubscription<Position>? _positionSub;
  bool _arrived = false;
  bool _announcedCurrentManeuver = false;

  /// Whether the session is currently running.
  bool get isActive => _positionSub != null;

  /// The maneuver step the user should execute next.
  NavigationManeuver? get currentManeuver {
    final route = _route;
    if (route == null || route.maneuvers.isEmpty) return null;
    if (_maneuverIndex >= route.maneuvers.length) return null;
    return route.maneuvers[_maneuverIndex];
  }

  /// All maneuver steps from the current step to the destination.
  List<NavigationManeuver> get remainingManeuvers {
    final route = _route;
    if (route == null || route.maneuvers.isEmpty) return const [];
    if (_maneuverIndex >= route.maneuvers.length) return const [];
    return route.maneuvers.sublist(_maneuverIndex);
  }

  /// Sum of [NavigationManeuver.distanceMeters] for all remaining steps.
  double get remainingDistanceMeters {
    return remainingManeuvers.fold(0.0, (sum, m) => sum + m.distanceMeters);
  }

  /// Sum of [NavigationManeuver.durationSeconds] for all remaining steps.
  int get remainingDurationSeconds {
    return remainingManeuvers.fold(0, (sum, m) => sum + m.durationSeconds);
  }

  // ---------------------------------------------------------------------------
  // Session lifecycle
  // ---------------------------------------------------------------------------

  /// Start a navigation session for [route].
  ///
  /// Any previously active session is stopped first. Announces the first
  /// maneuver immediately and then subscribes to the GPS stream.
  Future<void> start(RouteResult route) async {
    await stop();
    _route = route;
    _maneuverIndex = 0;
    _arrived = false;
    _announcedCurrentManeuver = false;

    // Announce the departure maneuver straight away.
    _tryAnnounce(currentManeuver);

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5, // metres between position updates
    );

    _positionSub = Geolocator.getPositionStream(locationSettings: settings)
        .listen(
          _onPosition,
          onError: (Object e) =>
              debugPrint('NavigationSessionService: GPS error: $e'),
        );
  }

  /// Stop the active session and reset all state.
  Future<void> stop() async {
    await _positionSub?.cancel();
    _positionSub = null;
    _route = null;
    _maneuverIndex = 0;
    _arrived = false;
    _announcedCurrentManeuver = false;
  }

  // ---------------------------------------------------------------------------
  // Internal position handler
  // ---------------------------------------------------------------------------

  void _onPosition(Position pos) {
    final route = _route;
    if (route == null || _arrived) return;

    final userLat = pos.latitude;
    final userLng = pos.longitude;

    // Off-route check.
    final distFromRoute = _distanceToPolyline(
      userLat,
      userLng,
      route.polylinePoints
          .map((p) => [p.latitude, p.longitude])
          .toList(),
    );

    if (distFromRoute > offRouteThresholdMeters) {
      onOffRoute?.call(distFromRoute);
      return;
    }

    _advanceManeuver(userLat, userLng, route);
  }

  void _advanceManeuver(double userLat, double userLng, RouteResult route) {
    if (route.maneuvers.isEmpty) return;
    if (_maneuverIndex >= route.maneuvers.length) return;

    final current = route.maneuvers[_maneuverIndex];
    final distToNext =
        _haversine(userLat, userLng, current.lat, current.lng);

    // Pre-announce upcoming maneuver.
    if (!_announcedCurrentManeuver && distToNext <= announceBeforeMeters) {
      _tryAnnounce(current);
      _announcedCurrentManeuver = true;
    }

    // Advance past the maneuver waypoint when within threshold.
    if (distToNext < waypointReachedMeters) {
      final next = _maneuverIndex + 1;
      if (next >= route.maneuvers.length) {
        _arrived = true;
        onVoicePrompt?.call('You have arrived at your destination.');
        onArrival?.call();
      } else {
        _maneuverIndex = next;
        _announcedCurrentManeuver = false;
        onManeuverUpdate?.call(route.maneuvers[_maneuverIndex], _maneuverIndex);
        _tryAnnounce(route.maneuvers[_maneuverIndex]);
      }
    }
  }

  void _tryAnnounce(NavigationManeuver? m) {
    if (m != null && m.instruction.isNotEmpty) {
      onVoicePrompt?.call(m.instruction);
    }
  }

  // ---------------------------------------------------------------------------
  // Geometry helpers
  // ---------------------------------------------------------------------------

  /// Returns the minimum distance in metres from [lat]/[lng] to the nearest
  /// segment of the decoded [polyline].
  double _distanceToPolyline(
    double lat,
    double lng,
    List<List<double>> polyline,
  ) {
    if (polyline.isEmpty) return double.infinity;
    if (polyline.length == 1) {
      return _haversine(lat, lng, polyline[0][0], polyline[0][1]);
    }
    var minDist = double.infinity;
    for (var i = 0; i < polyline.length - 1; i++) {
      final d = _distanceToSegment(
        lat, lng,
        polyline[i][0], polyline[i][1],
        polyline[i + 1][0], polyline[i + 1][1],
      );
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  /// Approximate perpendicular distance from point P to segment A→B.
  ///
  /// Works accurately for the short road segments encountered in navigation.
  double _distanceToSegment(
    double pLat, double pLng,
    double aLat, double aLng,
    double bLat, double bLng,
  ) {
    final abLat = bLat - aLat;
    final abLng = bLng - aLng;
    final ab2 = abLat * abLat + abLng * abLng;
    if (ab2 == 0) return _haversine(pLat, pLng, aLat, aLng);

    final t = (((pLat - aLat) * abLat + (pLng - aLng) * abLng) / ab2)
        .clamp(0.0, 1.0);
    return _haversine(
      pLat, pLng,
      aLat + t * abLat,
      aLng + t * abLng,
    );
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

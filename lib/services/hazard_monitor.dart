import 'dart:math' as math;
import '../models/hazard.dart';

/// Callback fired when the driver is approaching a hazard.
typedef HazardAlertCallback = void Function(
  Hazard hazard,
  double distanceMeters,
);

/// Monitors proximity to hazards along the active route and fires
/// [onHazardApproaching] when the driver comes within the alert threshold for
/// each hazard type.
///
/// Alert thresholds:
/// - Low bridges: [lowBridgeThresholdMeters] (~2 miles)
/// - Sharp curves: [sharpCurveThresholdMeters] (~1 mile)
/// - Downgrade hills: [downgradeHillThresholdMeters] (~2 miles)
/// - Work zones: [workZoneThresholdMeters] (~1 mile)
///
/// Spam prevention: each hazard has an individual cooldown tracked by
/// [Hazard.id].  Once an alert fires it will not fire again until
/// [cooldownSeconds] have elapsed.
///
/// Position updates are supplied by the caller; this service has no GPS
/// subscription of its own.
class HazardMonitor {
  // ---------------------------------------------------------------------------
  // Thresholds
  // ---------------------------------------------------------------------------

  /// Distance in metres at which a low-bridge alert fires (~2 miles).
  static const double lowBridgeThresholdMeters = 3218.7;

  /// Distance in metres at which a sharp-curve alert fires (~1 mile).
  static const double sharpCurveThresholdMeters = 1609.3;

  /// Distance in metres at which a downgrade-hill alert fires (~2 miles).
  static const double downgradeHillThresholdMeters = 3218.7;

  /// Distance in metres at which a work-zone alert fires (~1 mile).
  static const double workZoneThresholdMeters = 1609.3;

  /// Minimum seconds between repeated alerts for the same hazard instance.
  static const int cooldownSeconds = 300;

  // ---------------------------------------------------------------------------
  // Callback
  // ---------------------------------------------------------------------------

  /// Called when the driver approaches a hazard whose cooldown has expired.
  HazardAlertCallback? onHazardApproaching;

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  /// Tracks when each hazard was last announced, keyed by [Hazard.id].
  final Map<String, DateTime> _lastAlertTimes = {};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Evaluate the driver position against [hazards], firing
  /// [onHazardApproaching] for any hazard within its threshold whose cooldown
  /// has expired.
  ///
  /// Per-type enable flags ([enableLowBridge], [enableSharpCurve],
  /// [enableDowngradeHill], [enableWorkZone]) suppress alerts for disabled
  /// categories without resetting cooldown state.
  void update({
    required double lat,
    required double lng,
    required List<Hazard> hazards,
    bool enableLowBridge = true,
    bool enableSharpCurve = true,
    bool enableDowngradeHill = true,
    bool enableWorkZone = true,
  }) {
    final now = DateTime.now();
    for (final hazard in hazards) {
      // Honour per-type enable flags.
      final enabled = switch (hazard.type) {
        HazardType.lowBridge => enableLowBridge,
        HazardType.sharpCurve => enableSharpCurve,
        HazardType.downgradeHill => enableDowngradeHill,
        HazardType.workZone => enableWorkZone,
      };
      if (!enabled) continue;

      // Per-hazard cooldown check.
      final last = _lastAlertTimes[hazard.id];
      if (last != null &&
          now.difference(last).inSeconds < cooldownSeconds) {
        continue;
      }

      final threshold = _thresholdForType(hazard.type);
      final dist = _haversine(lat, lng, hazard.lat, hazard.lng);
      if (dist <= threshold) {
        _lastAlertTimes[hazard.id] = now;
        onHazardApproaching?.call(hazard, dist);
      }
    }
  }

  /// Reset all cooldown state (call when a new route or session starts).
  void reset() {
    _lastAlertTimes.clear();
  }

  // ---------------------------------------------------------------------------
  // Polyline-based hazard detection
  // ---------------------------------------------------------------------------

  /// Analyse [polylinePoints] (list of `[lat, lng]` pairs) and return a list
  /// of [Hazard] objects marking sharp-curve locations.
  ///
  /// A curve is considered "sharp" when the bearing change between two
  /// consecutive segments exceeds [angleDegThreshold] degrees (default 30°).
  /// Segments shorter than [minSegmentLengthMeters] (default 20 m) are skipped
  /// to avoid false positives from densely-packed GPS points.  Adjacent
  /// detections within [minGapMeters] (default 200 m) of each other are
  /// de-duplicated so a single bend does not produce multiple alerts.
  ///
  /// Returns an empty list when [polylinePoints] has fewer than 3 points.
  static List<Hazard> detectSharpCurves(
    List<List<double>> polylinePoints, {
    double angleDegThreshold = 30.0,
    double minSegmentLengthMeters = 20.0,
    double minGapMeters = 200.0,
  }) {
    if (polylinePoints.length < 3) return const [];

    final hazards = <Hazard>[];
    double? lastHazardLat;
    double? lastHazardLng;
    int curveIndex = 0;

    for (var i = 1; i < polylinePoints.length - 1; i++) {
      final prev = polylinePoints[i - 1];
      final curr = polylinePoints[i];
      final next = polylinePoints[i + 1];

      final segA = _staticHaversine(prev[0], prev[1], curr[0], curr[1]);
      final segB = _staticHaversine(curr[0], curr[1], next[0], next[1]);

      // Skip points that are too close together (GPS noise).
      if (segA < minSegmentLengthMeters || segB < minSegmentLengthMeters) {
        continue;
      }

      final bearingIn = _bearing(prev[0], prev[1], curr[0], curr[1]);
      final bearingOut = _bearing(curr[0], curr[1], next[0], next[1]);
      final angle = _angleDiff(bearingIn, bearingOut);

      if (angle >= angleDegThreshold) {
        // De-duplicate: skip if too close to the previous detected curve.
        if (lastHazardLat != null && lastHazardLng != null) {
          final gap = _staticHaversine(
            lastHazardLat,
            lastHazardLng,
            curr[0],
            curr[1],
          );
          if (gap < minGapMeters) continue;
        }

        hazards.add(Hazard(
          id: 'sharp_curve_$curveIndex',
          type: HazardType.sharpCurve,
          lat: curr[0],
          lng: curr[1],
        ));
        lastHazardLat = curr[0];
        lastHazardLng = curr[1];
        curveIndex++;
      }
    }

    return hazards;
  }

  // ---------------------------------------------------------------------------
  // Geometry helpers
  // ---------------------------------------------------------------------------

  double _thresholdForType(HazardType type) {
    switch (type) {
      case HazardType.lowBridge:
        return lowBridgeThresholdMeters;
      case HazardType.sharpCurve:
        return sharpCurveThresholdMeters;
      case HazardType.downgradeHill:
        return downgradeHillThresholdMeters;
      case HazardType.workZone:
        return workZoneThresholdMeters;
    }
  }

  double _haversine(double lat1, double lng1, double lat2, double lng2) =>
      _staticHaversine(lat1, lng1, lat2, lng2);

  static double _staticHaversine(
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

  /// Initial bearing from (lat1,lng1) to (lat2,lng2) in degrees [0, 360).
  static double _bearing(
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
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Absolute difference between two bearings in degrees, normalised to
  /// [0, 180].
  static double _angleDiff(double a, double b) {
    var diff = (b - a + 360) % 360;
    if (diff > 180) diff = 360 - diff;
    return diff;
  }

  static double _sq(double x) => x * x;
}

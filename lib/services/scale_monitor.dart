import 'dart:math' as math;
import '../models/scale_report.dart';

/// Callback fired when the driver approaches a scale with a known status.
typedef NearbyScaleCallback = void Function(
  ScaleReport report,
  double distanceMeters,
);

/// Monitors proximity to weigh scales that have driver-submitted status
/// reports, firing [onNearbyScale] when the driver comes within
/// [nearbyThresholdMeters].
///
/// Each scale alert fires at most once per report (tracked by POI ID +
/// reportedAt timestamp). Call [reset] when a new route or session starts.
///
/// Position updates are supplied by the caller; this service has no GPS
/// subscription of its own.
class ScaleMonitor {
  // ---------------------------------------------------------------------------
  // Threshold
  // ---------------------------------------------------------------------------

  /// Distance in metres at which a scale alert is emitted.
  static const double nearbyThresholdMeters = 5000.0; // 5 km

  // ---------------------------------------------------------------------------
  // Callback
  // ---------------------------------------------------------------------------

  /// Called once per scale report when the driver comes within
  /// [nearbyThresholdMeters] of that scale.
  NearbyScaleCallback? onNearbyScale;

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  /// Tracks which reports have already fired (poiId + reportedAt ISO string).
  final Set<String> _announcedKeys = {};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Evaluate the driver position against [reports] and fire [onNearbyScale]
  /// for any scale within [nearbyThresholdMeters] that has not yet been
  /// announced in this session.
  void update({
    required double lat,
    required double lng,
    required List<ScaleReport> reports,
  }) {
    for (final report in reports) {
      final key = '${report.poiId}_${report.reportedAt.toIso8601String()}';
      if (_announcedKeys.contains(key)) continue;
      final dist = _haversine(lat, lng, report.lat, report.lng);
      if (dist <= nearbyThresholdMeters) {
        _announcedKeys.add(key);
        onNearbyScale?.call(report, dist);
      }
    }
  }

  /// Reset all announced state (call when a new route or trip is activated).
  void reset() {
    _announcedKeys.clear();
  }

  // ---------------------------------------------------------------------------
  // Geometry helper
  // ---------------------------------------------------------------------------

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

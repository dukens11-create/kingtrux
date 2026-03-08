import 'dart:math' as math;
import '../models/weigh_station.dart';

/// Callback fired when the driver approaches a weigh station.
typedef WeighStationAlertCallback = void Function(
  WeighStation station,
  double distanceMeters,
);

// =============================================================================
// WeighStationMonitor
// =============================================================================

/// Monitors driver proximity to weigh stations and fires
/// [onNearbyStation] when the driver comes within [thresholdMeters] of a
/// station that has not already been announced in this session.
///
/// Alert behaviour by status:
/// - [WeighStationStatus.open]    – alert fires (station is enforcing).
/// - [WeighStationStatus.closed]  – no alert (station is bypassed).
/// - [WeighStationStatus.unknown] – alert fires when [alertOnUnknown] is
///   `true` (default), so drivers are always notified when status is
///   unavailable.
///
/// Spam prevention: each station alert fires at most once per session.
/// Call [reset] when a new route or navigation session starts.
///
/// Position updates are supplied by the caller; this monitor has no GPS
/// subscription of its own.
class WeighStationMonitor {
  // ---------------------------------------------------------------------------
  // Threshold
  // ---------------------------------------------------------------------------

  /// Default proximity threshold in metres (~1 mile).
  static const double defaultThresholdMeters = 1609.3;

  // ---------------------------------------------------------------------------
  // Callback
  // ---------------------------------------------------------------------------

  /// Called when the driver approaches a qualifying weigh station.
  WeighStationAlertCallback? onNearbyStation;

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Distance in metres at which the proximity alert fires.
  ///
  /// Configurable by the driver via [WeighStationSettings.alertDistanceMeters].
  double thresholdMeters;

  /// Whether to fire alerts for stations with [WeighStationStatus.unknown]
  /// status.
  ///
  /// When `true` (default) the driver is notified even when the enforcement
  /// status cannot be determined.  When `false`, alerts only fire for
  /// explicitly [WeighStationStatus.open] stations.
  bool alertOnUnknown;

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  /// Station IDs that have already been announced in the current session.
  final Set<String> _announcedIds = {};

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  WeighStationMonitor({
    this.thresholdMeters = defaultThresholdMeters,
    this.alertOnUnknown = true,
  });

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Evaluate the driver position against [stations] and fire
  /// [onNearbyStation] for any qualifying station within [thresholdMeters]
  /// that has not yet been announced this session.
  ///
  /// Pass `enabled: false` to suppress all alerts (e.g. when the driver
  /// has disabled weigh-station notifications in settings).
  void update({
    required double lat,
    required double lng,
    required List<WeighStation> stations,
    bool enabled = true,
  }) {
    if (!enabled) return;

    for (final station in stations) {
      if (_announcedIds.contains(station.id)) continue;

      // Apply status-based filtering.
      final shouldAlert = switch (station.status) {
        WeighStationStatus.open => true,
        WeighStationStatus.closed => false,
        WeighStationStatus.unknown => alertOnUnknown,
      };
      if (!shouldAlert) continue;

      final dist = _haversine(lat, lng, station.lat, station.lng);
      if (dist <= thresholdMeters) {
        _announcedIds.add(station.id);
        onNearbyStation?.call(station, dist);
      }
    }
  }

  /// Reset all announced state (call when a new route or session starts).
  void reset() => _announcedIds.clear();

  // ---------------------------------------------------------------------------
  // Geometry helper
  // ---------------------------------------------------------------------------

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

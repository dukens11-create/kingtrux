import 'dart:math' as math;
import '../models/weigh_station.dart';

/// Callback fired when the driver is approaching a weigh station.
typedef WeighStationAlertCallback = void Function(
  WeighStation station,
  double distanceMeters,
);

/// Monitors the driver's position against a list of [WeighStation] objects
/// and fires [onApproaching] when the driver comes within
/// [thresholdMeters] of a station.
///
/// **Spam prevention**: each station-alert fires at most once per session
/// (tracked by station id).  Call [reset] to clear state when a new trip
/// starts or when the station list is replaced.
///
/// Position updates are supplied by the caller; this service has no GPS
/// subscription of its own.
class WeighStationMonitor {
  // ---------------------------------------------------------------------------
  // Threshold
  // ---------------------------------------------------------------------------

  /// Default proximity threshold in metres (~3 miles / ~5 km).
  static const double defaultThresholdMeters = 4828.0;

  /// Minimum seconds between re-alerts for the same station.
  static const int cooldownSeconds = 300;

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Distance in metres at which an alert is emitted for approaching stations.
  ///
  /// Configurable so the settings UI can expose this as a preference.
  double thresholdMeters;

  // ---------------------------------------------------------------------------
  // Callback
  // ---------------------------------------------------------------------------

  /// Called when the driver approaches a weigh station whose cooldown has
  /// expired.
  WeighStationAlertCallback? onApproaching;

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  /// Tracks when each station was last announced, keyed by [WeighStation.id].
  final Map<String, DateTime> _lastAlertTimes = {};

  // ---------------------------------------------------------------------------
  // Constructor
  // ---------------------------------------------------------------------------

  WeighStationMonitor({double? thresholdMeters})
      : thresholdMeters = thresholdMeters ?? defaultThresholdMeters;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Evaluate the driver position against [stations], firing [onApproaching]
  /// for any station within [thresholdMeters] whose cooldown has expired.
  ///
  /// Set [enabled] to `false` to suppress all alerts without resetting
  /// cooldown state (mirrors the user's "Weigh Station Alerts" toggle).
  void update({
    required double lat,
    required double lng,
    required List<WeighStation> stations,
    bool enabled = true,
  }) {
    if (!enabled) return;
    final now = DateTime.now();
    for (final station in stations) {
      final last = _lastAlertTimes[station.id];
      if (last != null &&
          now.difference(last).inSeconds < cooldownSeconds) {
        continue;
      }
      final dist = _haversine(lat, lng, station.lat, station.lng);
      if (dist <= thresholdMeters) {
        _lastAlertTimes[station.id] = now;
        onApproaching?.call(station, dist);
      }
    }
  }

  /// Reset all cooldown state (call when a new trip or session starts).
  void reset() {
    _lastAlertTimes.clear();
  }

  // ---------------------------------------------------------------------------
  // Geometry helpers
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

  static double _sq(double x) => x * x;
}

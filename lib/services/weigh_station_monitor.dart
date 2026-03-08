import 'dart:math' as math;
import '../models/weigh_station.dart';

/// Callback fired when the driver approaches a weigh station for an alert.
typedef WeighStationAlertCallback = void Function(
  WeighStation station,
  double distanceMeters,
);

/// Callback fired when the driver is within the crowdsourcing submission
/// radius of a station.  The UI should show a prompt for the driver to
/// report the current status.
typedef WeighStationSubmissionCallback = void Function(
  WeighStation station,
);

// =============================================================================
// WeighStationMonitor
// =============================================================================

/// Monitors driver proximity to weigh stations and fires
/// [onNearbyStation] when the driver comes within [thresholdMeters] of a
/// station that has not already been announced in this session.
///
/// Additionally fires [onSubmissionPrompt] when the driver is within
/// [submissionProximityMeters] (150 ft ≈ 45.72 m) of a station for which
/// a crowdsourcing prompt has not yet been shown this session.
///
/// Alert behaviour by status:
/// - [WeighStationStatus.openBypass]       – alert fires (active enforcement).
/// - [WeighStationStatus.openGoingThrough] – alert fires (active enforcement).
/// - [WeighStationStatus.monitoring]       – alert fires.
/// - [WeighStationStatus.closed]           – no alert.
/// - [WeighStationStatus.unknown]          – alert fires when [alertOnUnknown]
///   is `true` (default).
///
/// Spam prevention: each alert fires at most once per session.
/// Call [reset] when a new route or navigation session starts.
///
/// Position updates are supplied by the caller; this monitor has no GPS
/// subscription of its own.
class WeighStationMonitor {
  // ---------------------------------------------------------------------------
  // Thresholds
  // ---------------------------------------------------------------------------

  /// Default proximity threshold in metres (~1 mile) for the alert banner.
  static const double defaultThresholdMeters = 1609.3;

  /// Radius in metres at which the crowdsourcing submission prompt appears.
  ///
  /// 150 feet = 45.72 metres, per requirements spec.
  static const double submissionProximityMeters = 45.72;

  // ---------------------------------------------------------------------------
  // Callbacks
  // ---------------------------------------------------------------------------

  /// Called when the driver approaches a qualifying weigh station.
  WeighStationAlertCallback? onNearbyStation;

  /// Called when the driver is within [submissionProximityMeters] of a station
  /// and has not yet been prompted to submit a status report this session.
  WeighStationSubmissionCallback? onSubmissionPrompt;

  // ---------------------------------------------------------------------------
  // Configuration
  // ---------------------------------------------------------------------------

  /// Distance in metres at which the proximity alert fires.
  ///
  /// Configurable by the driver via [WeighStationSettings.alertDistanceMeters].
  double thresholdMeters;

  /// Whether to fire alerts for stations with [WeighStationStatus.unknown]
  /// effective status.
  ///
  /// When `true` (default) the driver is notified even when the enforcement
  /// status cannot be determined.  When `false`, alerts only fire for
  /// explicitly active stations.
  bool alertOnUnknown;

  // ---------------------------------------------------------------------------
  // Internal state
  // ---------------------------------------------------------------------------

  /// Station IDs for which the alert has already been announced this session.
  final Set<String> _announcedIds = {};

  /// Station IDs for which the submission prompt has already been shown.
  final Set<String> _promptedIds = {};

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
  /// Also fires [onSubmissionPrompt] for stations within
  /// [submissionProximityMeters] when [submissionEnabled] is `true`.
  ///
  /// Pass `enabled: false` to suppress all alerts (e.g. when the driver
  /// has disabled weigh-station notifications in settings).
  void update({
    required double lat,
    required double lng,
    required List<WeighStation> stations,
    bool enabled = true,
    bool submissionEnabled = true,
  }) {
    for (final station in stations) {
      final dist = _haversine(lat, lng, station.lat, station.lng);

      // ── Crowdsourcing prompt (150-foot radius) ───────────────────────────
      if (submissionEnabled &&
          !_promptedIds.contains(station.id) &&
          dist <= submissionProximityMeters) {
        _promptedIds.add(station.id);
        onSubmissionPrompt?.call(station);
      }

      // ── Proximity alert ──────────────────────────────────────────────────
      if (!enabled) continue;
      if (_announcedIds.contains(station.id)) continue;

      final shouldAlert = switch (station.effectiveStatus) {
        WeighStationStatus.openBypass => true,
        WeighStationStatus.openGoingThrough => true,
        WeighStationStatus.monitoring => true,
        WeighStationStatus.closed => false,
        WeighStationStatus.unknown => alertOnUnknown,
      };
      if (!shouldAlert) continue;

      if (dist <= thresholdMeters) {
        _announcedIds.add(station.id);
        onNearbyStation?.call(station, dist);
      }
    }
  }

  /// Reset all announced / prompted state (call when a new route or session
  /// starts).
  void reset() {
    _announcedIds.clear();
    _promptedIds.clear();
  }

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

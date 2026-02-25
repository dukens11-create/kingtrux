/// Category of a route hazard.
enum HazardType { lowBridge, sharpCurve, downgradeHill }

/// A hazard point along the active route that the driver should be warned about.
///
/// Instances are typically built either from provider data (e.g., HERE routing
/// warnings) or from heuristic analysis of the route polyline (e.g., sharp
/// curves derived from bearing changes).
class Hazard {
  const Hazard({
    required this.id,
    required this.type,
    required this.lat,
    required this.lng,
    this.maxHeightMeters,
    this.gradePercent,
    this.recommendedSpeedMph,
  });

  /// Unique identifier for this hazard instance (used for cooldown tracking).
  final String id;

  /// Category of this hazard.
  final HazardType type;

  /// WGS-84 latitude of the hazard location.
  final double lat;

  /// WGS-84 longitude of the hazard location.
  final double lng;

  /// Vertical clearance in metres — present only for [HazardType.lowBridge].
  final double? maxHeightMeters;

  /// Downgrade grade in percent — present only for [HazardType.downgradeHill].
  final double? gradePercent;

  /// Advisory speed in mph — optionally set for [HazardType.sharpCurve].
  final double? recommendedSpeedMph;
}

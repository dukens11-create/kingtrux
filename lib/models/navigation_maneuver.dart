import 'package:google_maps_flutter/google_maps_flutter.dart';

/// A single turn-by-turn maneuver step returned by the HERE Routing API v8.
class NavigationManeuver {
  /// Human-readable text instruction (e.g., "Turn right onto Main St").
  final String instruction;

  /// Distance in meters for this maneuver leg.
  final double distanceMeters;

  /// Travel duration in seconds for this maneuver leg.
  final int durationSeconds;

  /// Action type as returned by the HERE API
  /// (e.g., "depart", "arrive", "turn", "keep", "merge", "uTurn").
  final String action;

  /// Optional direction hint (e.g., "left", "right", "straight").
  final String? direction;

  /// Name of the road the driver enters after this maneuver (e.g., "Main St").
  ///
  /// Parsed from the HERE Routing API v8 `nextRoad.name` field.
  final String? roadName;

  /// Route number of the road entered after this maneuver (e.g., "I-95 N").
  ///
  /// Parsed from the HERE Routing API v8 `nextRoad.number` field.
  final String? routeNumber;

  /// Latitude of the maneuver waypoint.
  final double lat;

  /// Longitude of the maneuver waypoint.
  final double lng;

  const NavigationManeuver({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.action,
    required this.lat,
    required this.lng,
    this.direction,
    this.roadName,
    this.routeNumber,
  });

  /// Build from a single entry in the HERE Routing API v8 `actions` array.
  ///
  /// [polylinePoints] is the decoded polyline for the section; the action's
  /// `offset` field is used as an index into that list to obtain the
  /// maneuver's geographic position.
  factory NavigationManeuver.fromHereAction(
    Map<String, dynamic> json,
    List<LatLng> polylinePoints,
  ) {
    final offset = (json['offset'] as num?)?.toInt() ?? 0;
    final clamped = polylinePoints.isEmpty
        ? null
        : polylinePoints[offset.clamp(0, polylinePoints.length - 1)];

    // Parse road name and route number from HERE API `nextRoad` field.
    final nextRoad = json['nextRoad'] as Map<String, dynamic>?;
    final roadName = _parseFirstName(nextRoad?['name']);
    final routeNumber = _parseFirstName(nextRoad?['number']);

    return NavigationManeuver(
      instruction: json['instruction'] as String? ?? '',
      distanceMeters: (json['length'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
      action: json['action'] as String? ?? 'depart',
      direction: json['direction'] as String?,
      roadName: roadName,
      routeNumber: routeNumber,
      lat: clamped?.latitude ?? 0.0,
      lng: clamped?.longitude ?? 0.0,
    );
  }

  /// Extract the first name value from a HERE API name array.
  ///
  /// HERE returns names as `[{"value": "...", "language": "en"}, ...]`.
  static String? _parseFirstName(dynamic nameList) {
    if (nameList == null) return null;
    final list = nameList as List?;
    if (list == null || list.isEmpty) return null;
    final first = list.first as Map<String, dynamic>?;
    final value = first?['value'] as String?;
    return (value != null && value.isNotEmpty) ? value : null;
  }
}

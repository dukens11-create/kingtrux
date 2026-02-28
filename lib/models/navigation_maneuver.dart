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

  /// Latitude of the maneuver waypoint.
  final double lat;

  /// Longitude of the maneuver waypoint.
  final double lng;

  /// Road name at the maneuver point (e.g., "Main Street").
  ///
  /// Parsed from [nextRoad.name] in the HERE Routing API v8 action object
  /// when available; falls back to [currentRoad.name].
  final String? roadName;

  /// Route number at the maneuver point (e.g., "I-95", "US-1").
  ///
  /// Parsed from [nextRoad.number] in the HERE Routing API v8 action object
  /// when available; falls back to [currentRoad.number].
  final String? roadNumber;

  const NavigationManeuver({
    required this.instruction,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.action,
    required this.lat,
    required this.lng,
    this.direction,
    this.roadName,
    this.roadNumber,
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

    // Road name/number: prefer nextRoad (road being turned onto) over
    // currentRoad (road being left).
    final nextRoadObj = json['nextRoad'] as Map<String, dynamic>?;
    final currRoadObj = json['currentRoad'] as Map<String, dynamic>?;
    final roadName = _firstRoadString(nextRoadObj, 'name') ??
        _firstRoadString(currRoadObj, 'name');
    final roadNumber = _firstRoadString(nextRoadObj, 'number') ??
        _firstRoadString(currRoadObj, 'number');

    return NavigationManeuver(
      instruction: json['instruction'] as String? ?? '',
      distanceMeters: (json['length'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['duration'] as num?)?.toInt() ?? 0,
      action: json['action'] as String? ?? 'depart',
      direction: json['direction'] as String?,
      lat: clamped?.latitude ?? 0.0,
      lng: clamped?.longitude ?? 0.0,
      roadName: roadName,
      roadNumber: roadNumber,
    );
  }

  /// Extracts the first value string from a HERE road object's named list.
  ///
  /// HERE road objects look like: `{"name": [{"value": "...", "language": "en"}]}`
  static String? _firstRoadString(
    Map<String, dynamic>? road,
    String key,
  ) {
    if (road == null) return null;
    final list = road[key] as List?;
    if (list == null || list.isEmpty) return null;
    return (list.first as Map<String, dynamic>?)?.['value'] as String?;
  }
}

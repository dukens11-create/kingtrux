import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'navigation_maneuver.dart';

/// Route result from HERE routing service
class RouteResult {
  /// Polyline points (lat/lng)
  final List<LatLng> polylinePoints;
  
  /// Route length in meters
  final double lengthMeters;
  
  /// Route duration in seconds
  final int durationSeconds;

  /// Turn-by-turn maneuver steps parsed from HERE Routing API v8 `actions`.
  final List<NavigationManeuver> maneuvers;

  /// Whether toll roads were avoided when calculating this route.
  final bool avoidedTolls;

  /// Estimated total toll cost in USD, or `null` if tolls were avoided or
  /// no cost data was returned by the routing API.
  final double? estimatedTollCostUsd;

  const RouteResult({
    required this.polylinePoints,
    required this.lengthMeters,
    required this.durationSeconds,
    this.maneuvers = const [],
    this.avoidedTolls = false,
    this.estimatedTollCostUsd,
  });
}

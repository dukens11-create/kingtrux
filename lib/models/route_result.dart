import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Route result from HERE routing service
class RouteResult {
  /// Polyline points (lat/lng)
  final List<LatLng> polylinePoints;
  
  /// Route length in meters
  final double lengthMeters;
  
  /// Route duration in seconds
  final int durationSeconds;

  const RouteResult({
    required this.polylinePoints,
    required this.lengthMeters,
    required this.durationSeconds,
  });
}

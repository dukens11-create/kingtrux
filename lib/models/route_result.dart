import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Route result from routing service
class RouteResult {
  final List<LatLng> polylinePoints;
  final double lengthMeters;
  final int durationSeconds;

  const RouteResult({
    required this.polylinePoints,
    required this.lengthMeters,
    required this.durationSeconds,
  });
}

import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/route_result.dart';
import '../models/navigation_maneuver.dart';
import '../models/trip_stop.dart';
import '../models/truck_profile.dart';
import 'here_routing_service.dart';

/// Builds a single combined [RouteResult] for a multi-stop trip by stitching
/// together per-leg routes from [HereRoutingService].
///
/// Strategy: one request per consecutive stop pair, then concatenate
/// polylines (deduplicating the shared join point) and sum
/// length/duration/maneuvers.
class TripRoutingService {
  final HereRoutingService _routing;

  TripRoutingService({HereRoutingService? routing})
      : _routing = routing ?? HereRoutingService();

  /// Calculate a combined route for [stops] using [truckProfile].
  ///
  /// Set [avoidTolls] to `true` to request toll-free routing for every leg.
  /// Throws if there are fewer than 2 stops, or if any leg fails.
  Future<RouteResult> buildTripRoute({
    required List<TripStop> stops,
    required TruckProfile truckProfile,
    bool avoidTolls = false,
  }) async {
    if (stops.length < 2) {
      throw Exception('A trip requires at least 2 stops (origin + destination).');
    }

    final List<LatLng> allPoints = [];
    double totalLength = 0;
    int totalDuration = 0;
    final List<NavigationManeuver> allManeuvers = [];
    double? totalTollCost;

    for (int i = 0; i < stops.length - 1; i++) {
      final from = stops[i];
      final to = stops[i + 1];

      final leg = await _routing.getTruckRoute(
        originLat: from.lat,
        originLng: from.lng,
        destLat: to.lat,
        destLng: to.lng,
        truckProfile: truckProfile,
        avoidTolls: avoidTolls,
      );

      // Concatenate polyline — skip the first point of every leg after the
      // first to avoid duplicate join points.
      if (allPoints.isEmpty) {
        allPoints.addAll(leg.polylinePoints);
      } else if (leg.polylinePoints.isNotEmpty) {
        allPoints.addAll(leg.polylinePoints.sublist(1));
      }

      totalLength += leg.lengthMeters;
      totalDuration += leg.durationSeconds;
      allManeuvers.addAll(leg.maneuvers);

      // Accumulate toll cost estimates across legs.
      if (leg.estimatedTollCostUsd != null) {
        totalTollCost = (totalTollCost ?? 0) + leg.estimatedTollCostUsd!;
      }
    }

    return RouteResult(
      polylinePoints: allPoints,
      lengthMeters: totalLength,
      durationSeconds: totalDuration,
      maneuvers: allManeuvers,
      avoidedTolls: avoidTolls,
      estimatedTollCostUsd: totalTollCost,
    );
  }
}

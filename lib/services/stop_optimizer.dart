import 'dart:math' as math;
import '../models/trip_stop.dart';

/// Optimizes the order of intermediate trip stops to minimize total travel
/// distance, using a nearest-neighbour greedy pass followed by 2-opt refinement.
///
/// The first stop (origin) and the last stop (final destination) are always
/// kept in place; only the intermediate stops are reordered.
class StopOptimizer {
  /// Returns a reordered copy of [stops] that minimises total route distance.
  ///
  /// If [stops] has fewer than 3 elements there is nothing to optimise and
  /// the original list is returned unchanged.
  static List<TripStop> optimize(List<TripStop> stops) {
    if (stops.length < 3) return List.of(stops);

    final origin = stops.first;
    final destination = stops.last;
    final intermediates = stops.sublist(1, stops.length - 1);

    if (intermediates.isEmpty) return List.of(stops);

    // Nearest-neighbour pass over intermediates
    final ordered = _nearestNeighbour(origin, intermediates, destination);

    // 2-opt refinement over intermediates only
    final refined = _twoOpt(ordered);

    return [origin, ...refined, destination];
  }

  // ---------------------------------------------------------------------------
  // Nearest-neighbour heuristic
  // ---------------------------------------------------------------------------

  static List<TripStop> _nearestNeighbour(
    TripStop origin,
    List<TripStop> intermediates,
    TripStop destination,
  ) {
    final unvisited = List<TripStop>.of(intermediates);
    final result = <TripStop>[];
    TripStop current = origin;

    while (unvisited.isNotEmpty) {
      double best = double.infinity;
      int bestIdx = 0;
      for (int i = 0; i < unvisited.length; i++) {
        final d = _dist(current, unvisited[i]);
        if (d < best) {
          best = d;
          bestIdx = i;
        }
      }
      current = unvisited[bestIdx];
      result.add(current);
      unvisited.removeAt(bestIdx);
    }

    return result;
  }

  // ---------------------------------------------------------------------------
  // 2-opt improvement
  // ---------------------------------------------------------------------------

  static List<TripStop> _twoOpt(List<TripStop> route) {
    if (route.length < 2) return List.of(route);
    var best = List<TripStop>.of(route);
    bool improved = true;
    while (improved) {
      improved = false;
      for (int i = 0; i < best.length - 1; i++) {
        for (int j = i + 1; j < best.length; j++) {
          final candidate = _reverse(best, i, j);
          if (_totalDistance(candidate) < _totalDistance(best)) {
            best = candidate;
            improved = true;
          }
        }
      }
    }
    return best;
  }

  /// Reverse the sub-sequence [i..j] (inclusive) of [route].
  static List<TripStop> _reverse(List<TripStop> route, int i, int j) {
    final result = List<TripStop>.of(route);
    while (i < j) {
      final tmp = result[i];
      result[i] = result[j];
      result[j] = tmp;
      i++;
      j--;
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Distance helpers (Euclidean on lat/lng — accurate enough for ordering)
  // ---------------------------------------------------------------------------

  /// Approximate great-circle distance in degrees² (sufficient for ordering).
  static double _dist(TripStop a, TripStop b) {
    final dLat = a.lat - b.lat;
    final dLng = a.lng - b.lng;
    return math.sqrt(dLat * dLat + dLng * dLng);
  }

  static double _totalDistance(List<TripStop> stops) {
    double total = 0;
    for (int i = 0; i < stops.length - 1; i++) {
      total += _dist(stops[i], stops[i + 1]);
    }
    return total;
  }
}

import 'dart:math' as math;
import '../models/poi.dart';

typedef ScalePassedCallback = void Function(Poi poi, double distanceMeters);

/// Detects when a driver passes a weigh-station (scale) POI and fires
/// [onScalePassed] once per pass, with a per-POI cooldown to prevent
/// repeated prompts from circling or slow traffic.
///
/// State machine per POI:
///   idle → armed (on entering [armRadiusMeters])
///   armed → passed (on leaving [exitRadiusMeters] after being armed)
///   passed → cooldown (fires callback; no further triggers for [cooldownDuration])
///   cooldown expires → idle
///
/// This class has no platform dependencies and is unit-testable.
class ScalePassMonitor {
  ScalePassMonitor({
    this.armRadiusMeters = 300.0,
    this.exitRadiusMeters = 700.0,
    this.cooldownDuration = const Duration(minutes: 45),
  });

  /// Distance at which a POI becomes "armed" (driver approaching).
  final double armRadiusMeters;

  /// Distance beyond which a previously-armed POI is considered "passed".
  final double exitRadiusMeters;

  /// Minimum time between consecutive prompts for the same POI.
  final Duration cooldownDuration;

  /// Callback fired when the driver passes a scale POI.
  ScalePassedCallback? onScalePassed;

  final Map<String, _PoiState> _states = {};

  /// Update the monitor with the driver's current GPS position and the list
  /// of scale POIs. Call this from every GPS position update.
  void update({
    required double lat,
    required double lng,
    required List<Poi> scalePois,
    DateTime? now,
  }) {
    final currentTime = now ?? DateTime.now();
    for (final poi in scalePois) {
      final dist = _haversine(lat, lng, poi.lat, poi.lng);
      final state = _states[poi.id] ?? _PoiState();

      if (state.cooldownUntil != null &&
          currentTime.isBefore(state.cooldownUntil!)) {
        // Still in cooldown — skip.
        _states[poi.id] = state;
        continue;
      }

      if (!state.armed) {
        if (dist <= armRadiusMeters) {
          // Driver entered the arm radius — arm this POI.
          _states[poi.id] = _PoiState(armed: true);
        } else {
          _states[poi.id] = state;
        }
      } else {
        // Currently armed.
        if (dist > exitRadiusMeters) {
          // Driver has exited the exit radius after being armed — passed!
          final cooldownUntil = currentTime.add(cooldownDuration);
          _states[poi.id] = _PoiState(armed: false, cooldownUntil: cooldownUntil);
          onScalePassed?.call(poi, dist);
        } else {
          _states[poi.id] = state;
        }
      }
    }
  }

  /// Reset all internal state (e.g., when starting a new session).
  void reset() {
    _states.clear();
  }

  static double _haversine(
      double lat1, double lng1, double lat2, double lng2) {
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

class _PoiState {
  _PoiState({this.armed = false, this.cooldownUntil});
  final bool armed;
  final DateTime? cooldownUntil;
}

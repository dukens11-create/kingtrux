import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/trip_stop.dart';
import 'package:kingtrux/services/route_monitor.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Straight north-south polyline from (0,0) to (1,0) (≈111 km long).
final _straightPolyline = [
  [0.0, 0.0],
  [0.5, 0.0],
  [1.0, 0.0],
];

TripStop _stop(String id, double lat, double lng, {String? label}) => TripStop(
      id: id,
      label: label,
      lat: lat,
      lng: lng,
      createdAt: DateTime(2025),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── 1. Approaching stop ───────────────────────────────────────────────────
  group('RouteMonitor — approaching stop', () {
    test('fires callback when within 5 km of a stop', () {
      final monitor = RouteMonitor();
      final stop = _stop('s1', 0.5, 0.0); // on the route midpoint
      TripStop? announced;
      monitor.onApproachingStop = (s) => announced = s;

      // Position very close to the stop (same coords → distance ≈ 0)
      monitor.update(
        lat: 0.5,
        lng: 0.0,
        routePolyline: _straightPolyline,
        stops: [stop],
      );

      expect(announced, isNotNull);
      expect(announced!.id, 's1');
    });

    test('does NOT fire when more than 5 km from a stop', () {
      final monitor = RouteMonitor();
      // Stop is at (10, 0), position at (0, 0) → ≈1111 km away
      final stop = _stop('s2', 10.0, 0.0);
      TripStop? announced;
      monitor.onApproachingStop = (s) => announced = s;

      monitor.update(
        lat: 0.0,
        lng: 0.0,
        routePolyline: _straightPolyline,
        stops: [stop],
      );

      expect(announced, isNull);
    });

    test('fires exactly once per stop even with multiple updates', () {
      final monitor = RouteMonitor();
      final stop = _stop('s3', 0.5, 0.0);
      var count = 0;
      monitor.onApproachingStop = (_) => count++;

      for (var i = 0; i < 5; i++) {
        monitor.update(
          lat: 0.5,
          lng: 0.0,
          routePolyline: _straightPolyline,
          stops: [stop],
        );
      }

      expect(count, 1);
    });

    test('fires for each stop independently', () {
      final monitor = RouteMonitor();
      final stop1 = _stop('a', 0.5, 0.0);
      final stop2 = _stop('b', 0.5, 0.0);
      final announced = <String>[];
      monitor.onApproachingStop = (s) => announced.add(s.id);

      monitor.update(
        lat: 0.5,
        lng: 0.0,
        routePolyline: _straightPolyline,
        stops: [stop1, stop2],
      );

      expect(announced, containsAll(['a', 'b']));
    });

    test('reset clears announced stop set so alert can fire again', () {
      final monitor = RouteMonitor();
      final stop = _stop('s4', 0.5, 0.0);
      var count = 0;
      monitor.onApproachingStop = (_) => count++;

      monitor.update(
        lat: 0.5,
        lng: 0.0,
        routePolyline: _straightPolyline,
        stops: [stop],
      );
      expect(count, 1);

      monitor.reset();

      monitor.update(
        lat: 0.5,
        lng: 0.0,
        routePolyline: _straightPolyline,
        stops: [stop],
      );
      expect(count, 2);
    });
  });

  // ── 2. Off-route detection ────────────────────────────────────────────────
  group('RouteMonitor — off-route', () {
    test('fires onOffRoute after debounce count of consecutive off-route updates',
        () {
      final monitor = RouteMonitor();
      // Position far east of the polyline (≫ 500 m)
      const farLat = 0.5;
      const farLng = 1.0; // ≈111 km east

      var offRouteCount = 0;
      monitor.onOffRoute = (_) => offRouteCount++;

      // Send debounceCount - 1 updates: should NOT fire yet
      for (var i = 0; i < RouteMonitor.offRouteDebounceCount - 1; i++) {
        monitor.update(
          lat: farLat,
          lng: farLng,
          routePolyline: _straightPolyline,
          stops: const [],
        );
      }
      expect(offRouteCount, 0);

      // One more update reaches the debounce threshold → fires
      monitor.update(
        lat: farLat,
        lng: farLng,
        routePolyline: _straightPolyline,
        stops: const [],
      );
      expect(offRouteCount, 1);
    });

    test('fires onOffRoute only once while continuously off-route', () {
      final monitor = RouteMonitor();
      var offRouteCount = 0;
      monitor.onOffRoute = (_) => offRouteCount++;

      for (var i = 0; i < RouteMonitor.offRouteDebounceCount + 5; i++) {
        monitor.update(
          lat: 0.5,
          lng: 1.0,
          routePolyline: _straightPolyline,
          stops: const [],
        );
      }

      expect(offRouteCount, 1);
    });

    test('does NOT fire when position is on the route', () {
      final monitor = RouteMonitor();
      var offRouteCount = 0;
      monitor.onOffRoute = (_) => offRouteCount++;

      for (var i = 0; i < RouteMonitor.offRouteDebounceCount + 2; i++) {
        // On the polyline
        monitor.update(
          lat: 0.5,
          lng: 0.0,
          routePolyline: _straightPolyline,
          stops: const [],
        );
      }

      expect(offRouteCount, 0);
    });
  });

  // ── 3. Back-on-route detection ────────────────────────────────────────────
  group('RouteMonitor — back on route', () {
    test('fires onBackOnRoute after returning to route (debounced)', () {
      final monitor = RouteMonitor();
      var offCount = 0;
      var backCount = 0;
      monitor.onOffRoute = (_) => offCount++;
      monitor.onBackOnRoute = () => backCount++;

      // Go off-route
      for (var i = 0; i < RouteMonitor.offRouteDebounceCount; i++) {
        monitor.update(
          lat: 0.5,
          lng: 1.0,
          routePolyline: _straightPolyline,
          stops: const [],
        );
      }
      expect(offCount, 1);
      expect(backCount, 0);

      // Return to route — needs debounceCount consecutive on-route updates
      for (var i = 0; i < RouteMonitor.offRouteDebounceCount - 1; i++) {
        monitor.update(
          lat: 0.5,
          lng: 0.0,
          routePolyline: _straightPolyline,
          stops: const [],
        );
      }
      expect(backCount, 0); // not yet

      monitor.update(
        lat: 0.5,
        lng: 0.0,
        routePolyline: _straightPolyline,
        stops: const [],
      );
      expect(backCount, 1);
    });

    test('onBackOnRoute fires at most once per off-route episode', () {
      final monitor = RouteMonitor();
      var backCount = 0;
      monitor.onBackOnRoute = () => backCount++;

      // Go off-route
      for (var i = 0; i < RouteMonitor.offRouteDebounceCount; i++) {
        monitor.update(
          lat: 0.5,
          lng: 1.0,
          routePolyline: _straightPolyline,
          stops: const [],
        );
      }

      // Return to route with many updates
      for (var i = 0; i < RouteMonitor.offRouteDebounceCount + 10; i++) {
        monitor.update(
          lat: 0.5,
          lng: 0.0,
          routePolyline: _straightPolyline,
          stops: const [],
        );
      }

      expect(backCount, 1);
    });
  });

  // ── 4. No crash on empty inputs ───────────────────────────────────────────
  group('RouteMonitor — edge cases', () {
    test('update with empty polyline is a no-op', () {
      final monitor = RouteMonitor();
      var called = false;
      monitor.onOffRoute = (_) => called = true;

      expect(
        () => monitor.update(
          lat: 0.0,
          lng: 0.0,
          routePolyline: const [],
          stops: const [],
        ),
        returnsNormally,
      );
      expect(called, isFalse);
    });

    test('update with single-point polyline does not throw', () {
      final monitor = RouteMonitor();
      expect(
        () => monitor.update(
          lat: 0.0,
          lng: 0.0,
          routePolyline: [
            [0.0, 0.0],
          ],
          stops: const [],
        ),
        returnsNormally,
      );
    });

    test('reset clears off-route state', () {
      final monitor = RouteMonitor();
      var offCount = 0;
      monitor.onOffRoute = (_) => offCount++;

      // Trigger off-route
      for (var i = 0; i < RouteMonitor.offRouteDebounceCount; i++) {
        monitor.update(
          lat: 0.5,
          lng: 1.0,
          routePolyline: _straightPolyline,
          stops: const [],
        );
      }
      expect(offCount, 1);

      monitor.reset();

      // Off-route again after reset — should fire again
      for (var i = 0; i < RouteMonitor.offRouteDebounceCount; i++) {
        monitor.update(
          lat: 0.5,
          lng: 1.0,
          routePolyline: _straightPolyline,
          stops: const [],
        );
      }
      expect(offCount, 2);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kingtrux/models/navigation_maneuver.dart';
import 'package:kingtrux/models/route_result.dart';
import 'package:kingtrux/services/navigation_session_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // NavigationManeuver model
  // ---------------------------------------------------------------------------
  group('NavigationManeuver', () {
    test('fromHereAction parses fields correctly', () {
      final points = [
        const LatLng(43.0, -79.0),
        const LatLng(43.1, -79.1),
        const LatLng(43.2, -79.2),
      ];

      final json = {
        'action': 'turn',
        'direction': 'right',
        'instruction': 'Turn right onto Main St',
        'length': 450.0,
        'duration': 38,
        'offset': 1,
      };

      final m = NavigationManeuver.fromHereAction(json, points);

      expect(m.action, 'turn');
      expect(m.direction, 'right');
      expect(m.instruction, 'Turn right onto Main St');
      expect(m.distanceMeters, 450.0);
      expect(m.durationSeconds, 38);
      expect(m.lat, 43.1);
      expect(m.lng, -79.1);
    });

    test('fromHereAction clamps offset beyond polyline length', () {
      final points = [const LatLng(10.0, 20.0)];
      final json = {'action': 'arrive', 'offset': 99};
      final m = NavigationManeuver.fromHereAction(json, points);
      expect(m.lat, 10.0);
      expect(m.lng, 20.0);
    });

    test('fromHereAction handles empty polyline gracefully', () {
      final m = NavigationManeuver.fromHereAction({'action': 'depart'}, []);
      expect(m.lat, 0.0);
      expect(m.lng, 0.0);
      expect(m.instruction, '');
    });

    test('action defaults to depart when missing', () {
      final m = NavigationManeuver.fromHereAction({}, []);
      expect(m.action, 'depart');
    });
  });

  // ---------------------------------------------------------------------------
  // RouteResult with maneuvers
  // ---------------------------------------------------------------------------
  group('RouteResult', () {
    test('maneuvers default to empty list', () {
      const result = RouteResult(
        polylinePoints: [],
        lengthMeters: 1000,
        durationSeconds: 60,
      );
      expect(result.maneuvers, isEmpty);
    });

    test('stores provided maneuvers', () {
      const m = NavigationManeuver(
        instruction: 'Head north',
        distanceMeters: 200,
        durationSeconds: 15,
        action: 'depart',
        lat: 0,
        lng: 0,
      );
      const result = RouteResult(
        polylinePoints: [],
        lengthMeters: 1000,
        durationSeconds: 60,
        maneuvers: [m],
      );
      expect(result.maneuvers.length, 1);
      expect(result.maneuvers.first.instruction, 'Head north');
    });
  });

  // ---------------------------------------------------------------------------
  // NavigationSessionService state machine
  // ---------------------------------------------------------------------------
  group('NavigationSessionService', () {
    test('is not active before start()', () {
      expect(NavigationSessionService().isActive, isFalse);
    });

    test('currentManeuver is null before start()', () {
      expect(NavigationSessionService().currentManeuver, isNull);
    });

    test('remainingManeuvers is empty before start()', () {
      expect(NavigationSessionService().remainingManeuvers, isEmpty);
    });

    test('stop() can be called on idle service without error', () async {
      final svc = NavigationSessionService();
      await expectLater(svc.stop(), completes);
    });
  });
}

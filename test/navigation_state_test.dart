import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kingtrux/models/navigation_maneuver.dart';
import 'package:kingtrux/models/route_result.dart';
import 'package:kingtrux/services/navigation_session_service.dart';
import 'package:kingtrux/state/app_state.dart';

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

    test('fromHereAction parses nextRoad name and route number', () {
      final json = {
        'action': 'turn',
        'direction': 'right',
        'instruction': 'Take I-95 N',
        'length': 1200.0,
        'duration': 60,
        'nextRoad': {
          'name': [
            {'value': 'Interstate 95', 'language': 'en'},
          ],
          'number': [
            {'value': 'I-95 N'},
          ],
        },
      };
      final m = NavigationManeuver.fromHereAction(json, []);
      expect(m.roadName, 'Interstate 95');
      expect(m.routeNumber, 'I-95 N');
    });

    test('fromHereAction returns null roadName and routeNumber when nextRoad absent', () {
      final json = {'action': 'turn', 'direction': 'left', 'instruction': 'Turn left'};
      final m = NavigationManeuver.fromHereAction(json, []);
      expect(m.roadName, isNull);
      expect(m.routeNumber, isNull);
    });

    test('fromHereAction ignores empty nextRoad name/number arrays', () {
      final json = {
        'action': 'keep',
        'nextRoad': {'name': <dynamic>[], 'number': <dynamic>[]},
      };
      final m = NavigationManeuver.fromHereAction(json, []);
      expect(m.roadName, isNull);
      expect(m.routeNumber, isNull);
    });

    test('fromHereAction handles nextRoad with only road name', () {
      final json = {
        'action': 'turn',
        'direction': 'left',
        'nextRoad': {
          'name': [{'value': 'Main Street', 'language': 'en'}],
        },
      };
      final m = NavigationManeuver.fromHereAction(json, []);
      expect(m.roadName, 'Main Street');
      expect(m.routeNumber, isNull);
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

    test('remainingDistanceMeters is 0 before start()', () {
      expect(NavigationSessionService().remainingDistanceMeters, 0.0);
    });

    test('remainingDurationSeconds is 0 before start()', () {
      expect(NavigationSessionService().remainingDurationSeconds, 0);
    });

    test('stop() resets active state and returns without error', () async {
      final svc = NavigationSessionService();
      await expectLater(svc.stop(), completes);
      expect(svc.isActive, isFalse);
      expect(svc.currentManeuver, isNull);
      expect(svc.remainingManeuvers, isEmpty);
      expect(svc.remainingDistanceMeters, 0.0);
      expect(svc.remainingDurationSeconds, 0);
    });
  });

  // ---------------------------------------------------------------------------
  // Remaining distance / duration helpers
  // ---------------------------------------------------------------------------
  group('NavigationSessionService remaining totals', () {
    // Helper: build a RouteResult from a list of (distance, duration) pairs.
    RouteResult _buildRoute(List<({double dist, int dur})> legs) {
      final maneuvers = legs
          .map(
            (l) => NavigationManeuver(
              instruction: '',
              distanceMeters: l.dist,
              durationSeconds: l.dur,
              action: 'turn',
              lat: 0,
              lng: 0,
            ),
          )
          .toList();
      return RouteResult(
        polylinePoints: const [],
        lengthMeters: legs.fold(0.0, (s, l) => s + l.dist),
        durationSeconds: legs.fold(0, (s, l) => s + l.dur),
        maneuvers: maneuvers,
      );
    }

    // The live-GPS path (start()) cannot be unit-tested without a real device;
    // these tests verify the fold logic that the getters depend on.
    test('service getters return 0 when no route is loaded', () {
      final svc = NavigationSessionService();
      expect(svc.remainingDistanceMeters, 0.0);
      expect(svc.remainingDurationSeconds, 0);
    });

    test('RouteResult maneuver fold produces correct distance and duration', () {
      final route = _buildRoute([
        (dist: 500, dur: 30),
        (dist: 1000, dur: 60),
        (dist: 200, dur: 15),
      ]);

      final totalDist =
          route.maneuvers.fold(0.0, (s, m) => s + m.distanceMeters);
      final totalDur =
          route.maneuvers.fold(0, (s, m) => s + m.durationSeconds);
      expect(totalDist, closeTo(1700, 0.01));
      expect(totalDur, 105);
    });
  });

  // ---------------------------------------------------------------------------
  // AppState voice language architecture
  // ---------------------------------------------------------------------------
  group('AppState voice language', () {
    test('supportedVoiceLanguages contains required locales', () {
      expect(AppState.supportedVoiceLanguages, containsAll([
        'en-US',
        'en-CA',
        'fr-CA',
        'es-US',
      ]));
    });

    test('default voiceLanguage is en-US', () {
      final state = AppState();
      expect(state.voiceLanguage, 'en-US');
      state.dispose();
    });

    test('setVoiceLanguage updates voiceLanguage for valid tag', () {
      final state = AppState();
      state.setVoiceLanguage('fr-CA');
      expect(state.voiceLanguage, 'fr-CA');
      state.dispose();
    });

    test('setVoiceLanguage ignores unknown tags', () {
      final state = AppState();
      state.setVoiceLanguage('de-DE');
      expect(state.voiceLanguage, 'en-US'); // unchanged
      state.dispose();
    });
  });
}

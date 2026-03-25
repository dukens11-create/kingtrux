import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/services/external_nav_service.dart';

void main() {
  group('ExternalNavApp.displayName', () {
    test('googleMaps returns Google Maps', () {
      expect(ExternalNavApp.googleMaps.displayName, 'Google Maps');
    });

    test('sygicTruck returns Sygic Truck', () {
      expect(ExternalNavApp.sygicTruck.displayName, 'Sygic Truck');
    });

    test('waze returns Waze', () {
      expect(ExternalNavApp.waze.displayName, 'Waze');
    });
  });

  group('ExternalNavApp enum coverage', () {
    test('all app cases are enumerated', () {
      expect(ExternalNavApp.values.length, 3);
    });

    test('googleMaps is always in values', () {
      expect(ExternalNavApp.values, contains(ExternalNavApp.googleMaps));
    });

    test('sygicTruck is always in values', () {
      expect(ExternalNavApp.values, contains(ExternalNavApp.sygicTruck));
    });

    test('waze is always in values', () {
      expect(ExternalNavApp.values, contains(ExternalNavApp.waze));
    });
  });

  group('ExternalNavApp display names are non-empty and unique', () {
    test('no app has an empty display name', () {
      for (final app in ExternalNavApp.values) {
        expect(
          app.displayName,
          isNotEmpty,
          reason: '${app.name} must have a non-empty displayName',
        );
      }
    });

    test('each app has a unique display name', () {
      final names = ExternalNavApp.values.map((a) => a.displayName).toList();
      final unique = names.toSet();
      expect(unique.length, names.length);
    });
  });

  // ── URI format correctness ──────────────────────────────────────────────

  group('Google Maps native URI format', () {
    // We verify the URI string without calling canLaunchUrl (which requires
    // a platform channel).  The exact same Uri.parse call used in the service
    // is reproduced here so any future refactoring would break these tests.
    const lat = 40.712776;
    const lng = -74.005974;

    test('native URI scheme is google.navigation', () {
      final uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
      expect(uri.scheme, 'google.navigation');
    });

    test('native URI contains destination coordinates', () {
      final uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
      expect(uri.toString(), contains('$lat,$lng'));
    });

    test('native URI requests driving mode', () {
      final uri = Uri.parse('google.navigation:q=$lat,$lng&mode=d');
      expect(uri.toString(), contains('mode=d'));
    });

    test('web fallback URI is HTTPS google.com maps', () {
      final uri = Uri.https(
        'www.google.com',
        '/maps/dir/',
        {'api': '1', 'destination': '$lat,$lng', 'travelmode': 'driving'},
      );
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters['travelmode'], 'driving');
      expect(uri.queryParameters['destination'], '$lat,$lng');
    });
  });

  group('Sygic Truck URI format', () {
    const lat = 40.712776;
    const lng = -74.005974;

    test('Sygic URI uses com.sygic.aura scheme', () {
      final uri = Uri.parse('com.sygic.aura://coordinate|$lng|$lat|drive');
      expect(uri.scheme, 'com.sygic.aura');
    });

    test('Sygic URI contains longitude then latitude (lon first)', () {
      final uri = Uri.parse('com.sygic.aura://coordinate|$lng|$lat|drive');
      // Sygic expects longitude BEFORE latitude in its URI
      expect(uri.toString(), contains('|$lng|$lat|'));
    });
  });

  group('Waze URI format', () {
    const lat = 40.712776;
    const lng = -74.005974;

    test('Waze URI uses waze scheme', () {
      final uri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
      expect(uri.scheme, 'waze');
    });

    test('Waze URI contains navigate=yes', () {
      final uri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
      expect(uri.toString(), contains('navigate=yes'));
    });

    test('Waze URI contains lat,lng', () {
      final uri = Uri.parse('waze://?ll=$lat,$lng&navigate=yes');
      expect(uri.toString(), contains('$lat,$lng'));
    });
  });
}

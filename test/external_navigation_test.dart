import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/utils/external_navigation.dart';

void main() {
  // ── ExternalNavigationUrl.googleMaps ─────────────────────────────────────

  group('ExternalNavigationUrl.googleMaps – destination only', () {
    const lat = 40.712776;
    const lng = -74.005974;

    test('uses HTTPS scheme', () {
      final uri = ExternalNavigationUrl.googleMaps(destLat: lat, destLng: lng);
      expect(uri.scheme, 'https');
    });

    test('uses www.google.com host', () {
      final uri = ExternalNavigationUrl.googleMaps(destLat: lat, destLng: lng);
      expect(uri.host, 'www.google.com');
    });

    test('path is /maps/dir/', () {
      final uri = ExternalNavigationUrl.googleMaps(destLat: lat, destLng: lng);
      expect(uri.path, '/maps/dir/');
    });

    test('destination query param contains coordinates', () {
      final uri = ExternalNavigationUrl.googleMaps(destLat: lat, destLng: lng);
      expect(uri.queryParameters['destination'], '$lat,$lng');
    });

    test('travelmode is driving', () {
      final uri = ExternalNavigationUrl.googleMaps(destLat: lat, destLng: lng);
      expect(uri.queryParameters['travelmode'], 'driving');
    });

    test('no waypoints param when waypoints list is empty', () {
      final uri = ExternalNavigationUrl.googleMaps(destLat: lat, destLng: lng);
      expect(uri.queryParameters.containsKey('waypoints'), isFalse);
    });

    test('no origin param when origin omitted', () {
      final uri = ExternalNavigationUrl.googleMaps(destLat: lat, destLng: lng);
      expect(uri.queryParameters.containsKey('origin'), isFalse);
    });
  });

  group('ExternalNavigationUrl.googleMaps – destination + 2 waypoints', () {
    const destLat = 41.0;
    const destLng = -75.0;
    final waypoints = [
      (lat: 40.5, lng: -73.5),
      (lat: 40.8, lng: -74.5),
    ];

    test('waypoints query param contains both stops pipe-separated', () {
      final uri = ExternalNavigationUrl.googleMaps(
        destLat: destLat,
        destLng: destLng,
        waypoints: waypoints,
      );
      expect(uri.queryParameters['waypoints'], '40.5,-73.5|40.8,-74.5');
    });

    test('waypoints are in the correct order (first stop first)', () {
      final uri = ExternalNavigationUrl.googleMaps(
        destLat: destLat,
        destLng: destLng,
        waypoints: waypoints,
      );
      final wps = uri.queryParameters['waypoints']!.split('|');
      expect(wps.first, '40.5,-73.5');
      expect(wps.last, '40.8,-74.5');
    });

    test('destination is the final destination not a waypoint', () {
      final uri = ExternalNavigationUrl.googleMaps(
        destLat: destLat,
        destLng: destLng,
        waypoints: waypoints,
      );
      expect(uri.queryParameters['destination'], '$destLat,$destLng');
    });

    test('still uses driving travelmode', () {
      final uri = ExternalNavigationUrl.googleMaps(
        destLat: destLat,
        destLng: destLng,
        waypoints: waypoints,
      );
      expect(uri.queryParameters['travelmode'], 'driving');
    });
  });

  group('ExternalNavigationUrl.googleMaps – with origin', () {
    test('origin query param contains GPS coordinates', () {
      final uri = ExternalNavigationUrl.googleMaps(
        destLat: 41.0,
        destLng: -75.0,
        originLat: 40.0,
        originLng: -74.0,
      );
      expect(uri.queryParameters['origin'], '40.0,-74.0');
    });
  });

  // ── ExternalNavigationUrl.appleMaps ──────────────────────────────────────

  group('ExternalNavigationUrl.appleMaps', () {
    const lat = 40.712776;
    const lng = -74.005974;

    test('uses maps scheme', () {
      final uri = ExternalNavigationUrl.appleMaps(destLat: lat, destLng: lng);
      expect(uri.scheme, 'maps');
    });

    test('daddr query param contains destination coordinates', () {
      final uri = ExternalNavigationUrl.appleMaps(destLat: lat, destLng: lng);
      expect(uri.queryParameters['daddr'], '$lat,$lng');
    });

    test('dirflg is d (driving)', () {
      final uri = ExternalNavigationUrl.appleMaps(destLat: lat, destLng: lng);
      expect(uri.queryParameters['dirflg'], 'd');
    });
  });

  // ── ExternalNavigationUrl.geoUri ─────────────────────────────────────────

  group('ExternalNavigationUrl.geoUri', () {
    const lat = 40.712776;
    const lng = -74.005974;

    test('uses geo scheme', () {
      final uri = ExternalNavigationUrl.geoUri(destLat: lat, destLng: lng);
      expect(uri.scheme, 'geo');
    });

    test('URI contains destination coordinates', () {
      final uri = ExternalNavigationUrl.geoUri(destLat: lat, destLng: lng);
      expect(uri.toString(), contains('$lat,$lng'));
    });
  });
}

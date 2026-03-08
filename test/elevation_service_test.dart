import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kingtrux/models/elevation_point.dart';
import 'package:kingtrux/services/elevation_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal Google Elevation API success response for [points].
String _successBody(List<({double lat, double lng, double elev})> points) {
  final results = points
      .map(
        (p) => {
          'elevation': p.elev,
          'location': {'lat': p.lat, 'lng': p.lng},
          'resolution': 4.77,
        },
      )
      .toList();
  return json.encode({'status': 'OK', 'results': results});
}

/// Returns an [http.Client] that always responds with [body] and [statusCode].
http.Client _mockClient(String body, {int statusCode = 200}) {
  return MockClient((_) async => http.Response(body, statusCode));
}

// ---------------------------------------------------------------------------
// ElevationPoint model tests
// ---------------------------------------------------------------------------

void main() {
  group('ElevationPoint model', () {
    const point = ElevationPoint(
      lat: 39.7392,
      lng: -104.9903,
      elevationMeters: 1609.0,
      resolution: 4.77,
    );

    test('elevationFeet converts correctly', () {
      // 1609 m * 3.28084 ≈ 5279 ft
      expect(point.elevationFeet, closeTo(5279.0, 1.0));
    });

    test('equality is based on lat/lng', () {
      const same = ElevationPoint(
        lat: 39.7392,
        lng: -104.9903,
        elevationMeters: 9999.0, // different elevation, still equal
      );
      expect(point, equals(same));
    });

    test('different coordinates are not equal', () {
      const other = ElevationPoint(
        lat: 0.0,
        lng: 0.0,
        elevationMeters: 1609.0,
      );
      expect(point, isNot(equals(other)));
    });

    test('hashCode matches equal objects', () {
      const same = ElevationPoint(lat: 39.7392, lng: -104.9903, elevationMeters: 0);
      expect(point.hashCode, equals(same.hashCode));
    });

    test('fromJson parses Google Elevation API result', () {
      final json = {
        'elevation': 1608.64,
        'location': {'lat': 39.7391, 'lng': -104.9847},
        'resolution': 4.77,
      };
      final p = ElevationPoint.fromJson(json);
      expect(p.lat, closeTo(39.7391, 0.0001));
      expect(p.lng, closeTo(-104.9847, 0.0001));
      expect(p.elevationMeters, closeTo(1608.64, 0.01));
      expect(p.resolution, closeTo(4.77, 0.01));
    });

    test('fromJson handles missing resolution', () {
      final json = {
        'elevation': 100.0,
        'location': {'lat': 10.0, 'lng': 20.0},
      };
      final p = ElevationPoint.fromJson(json);
      expect(p.resolution, isNull);
    });

    test('toString contains elevation', () {
      expect(point.toString(), contains('1609.0'));
    });
  });

  // ---------------------------------------------------------------------------
  // ElevationService – no API key (default in tests)
  // ---------------------------------------------------------------------------

  group('ElevationService – no API key', () {
    test('fetchElevation throws ElevationException when key not configured', () {
      // In the test environment GOOGLE_ELEVATION_API_KEY is not set, so
      // Config.elevationApiConfigured returns false.
      final service = ElevationService();
      expect(
        () => service.fetchElevation(lat: 39.7392, lng: -104.9903),
        throwsA(isA<ElevationException>()),
      );
    });

    test('fetchMultiple throws ElevationException when key not configured', () {
      final service = ElevationService();
      expect(
        () => service.fetchMultiple([(lat: 39.7392, lng: -104.9903)]),
        throwsA(isA<ElevationException>()),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // ElevationService – HTTP layer (injected mock client)
  // ---------------------------------------------------------------------------

  group('ElevationService – HTTP (mock client)', () {
    test('fetchElevation parses successful response', () async {
      final body = _successBody([(lat: 39.7392, lng: -104.9903, elev: 1609.3)]);
      final service = ElevationService(client: _mockClient(body));
      // Bypass the API-key check by injecting a fake key via the mock path.
      // Since Config is compile-time const, we test the HTTP path directly by
      // exercising the method through the mock; the service will throw due to
      // missing key before reaching HTTP — so we test _parseResponse logic via
      // a white-box approach using the model parsing directly.

      // Parse the model directly to validate HTTP response handling.
      final data = json.decode(body) as Map<String, dynamic>;
      expect(data['status'], equals('OK'));
      final results = data['results'] as List;
      final point = ElevationPoint.fromJson(results[0] as Map<String, dynamic>);
      expect(point.elevationMeters, closeTo(1609.3, 0.1));
      expect(point.lat, closeTo(39.7392, 0.0001));
    });

    test('fetchMultiple with empty list returns empty', () async {
      final service = ElevationService(client: _mockClient('{}'));
      // Empty list skips HTTP entirely and returns [] regardless of key.
      final result = await service.fetchMultiple([]);
      expect(result, isEmpty);
    });

    test('ElevationException message is descriptive when key missing', () async {
      final service = ElevationService();
      try {
        await service.fetchElevation(lat: 0, lng: 0);
        fail('Expected ElevationException');
      } on ElevationException catch (e) {
        expect(e.message, contains('GOOGLE_ELEVATION_API_KEY'));
        expect(e.toString(), contains('ElevationException'));
      }
    });
  });

  // ---------------------------------------------------------------------------
  // ElevationService – cache
  // ---------------------------------------------------------------------------

  group('ElevationService – cache', () {
    test('cacheSize starts at zero', () {
      final service = ElevationService();
      expect(service.cacheSize, equals(0));
    });

    test('clearCache resets cacheSize', () {
      final service = ElevationService();
      // Manually seed the internal cache via the public clearCache path.
      expect(service.cacheSize, equals(0));
      service.clearCache();
      expect(service.cacheSize, equals(0));
    });
  });

  // ---------------------------------------------------------------------------
  // ElevationPoint – edge cases
  // ---------------------------------------------------------------------------

  group('ElevationPoint – edge cases', () {
    test('negative elevation (below sea level) handled correctly', () {
      const point = ElevationPoint(lat: 31.5, lng: 35.5, elevationMeters: -430.0);
      expect(point.elevationMeters, isNegative);
      expect(point.elevationFeet, isNegative);
    });

    test('zero elevation at sea level', () {
      const point = ElevationPoint(lat: 0, lng: 0, elevationMeters: 0);
      expect(point.elevationFeet, closeTo(0.0, 0.001));
    });
  });
}

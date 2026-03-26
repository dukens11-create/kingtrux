import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:kingtrux/models/nearby_place.dart';
import 'package:kingtrux/services/google_places_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal Places Nearby Search response body for testing.
Map<String, dynamic> _placesResponse({
  required String status,
  List<Map<String, dynamic>> results = const [],
  String? errorMessage,
}) {
  return {
    'status': status,
    if (errorMessage != null) 'error_message': errorMessage,
    'results': results,
  };
}

/// Builds a minimal result object that can be parsed by [NearbyPlace.fromJson].
Map<String, dynamic> _resultJson({
  String placeId = 'PLACE_001',
  String name = 'Pilot Travel Center',
  double lat = 40.712776,
  double lng = -74.005974,
  String? vicinity = '123 Truck Ave, Newark, NJ',
}) =>
    {
      'place_id': placeId,
      'name': name,
      'geometry': {
        'location': {'lat': lat, 'lng': lng},
      },
      'vicinity': vicinity,
    };

// ---------------------------------------------------------------------------
// NearbyPlace.fromJson
// ---------------------------------------------------------------------------

void main() {
  group('NearbyPlace.fromJson', () {
    test('parses all fields correctly', () {
      final place = NearbyPlace.fromJson(_resultJson());

      expect(place.placeId, 'PLACE_001');
      expect(place.name, 'Pilot Travel Center');
      expect(place.lat, closeTo(40.712776, 0.000001));
      expect(place.lng, closeTo(-74.005974, 0.000001));
      expect(place.vicinity, '123 Truck Ave, Newark, NJ');
    });

    test('handles null vicinity', () {
      final place = NearbyPlace.fromJson(_resultJson(vicinity: null));
      expect(place.vicinity, isNull);
    });

    test('converts integer lat/lng to double', () {
      final json = {
        'place_id': 'ID',
        'name': 'Stop',
        'geometry': {
          'location': {'lat': 40, 'lng': -74},
        },
      };
      final place = NearbyPlace.fromJson(json);
      expect(place.lat, isA<double>());
      expect(place.lng, isA<double>());
    });

    test('equality is based on placeId', () {
      final a = NearbyPlace.fromJson(_resultJson(placeId: 'X'));
      final b = NearbyPlace.fromJson(_resultJson(placeId: 'X', name: 'Other'));
      expect(a, equals(b));
    });

    test('different placeIds are not equal', () {
      final a = NearbyPlace.fromJson(_resultJson(placeId: 'A'));
      final b = NearbyPlace.fromJson(_resultJson(placeId: 'B'));
      expect(a, isNot(equals(b)));
    });
  });

  // -------------------------------------------------------------------------
  // GooglePlacesService
  // -------------------------------------------------------------------------

  group('GooglePlacesService', () {
    GooglePlacesService _makeService(http.Client client) =>
        GooglePlacesService(apiKey: 'TEST_KEY', client: client);

    test('returns parsed places on OK status', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(_placesResponse(
            status: 'OK',
            results: [
              _resultJson(placeId: 'P1', name: 'Love\'s Travel Stop'),
              _resultJson(placeId: 'P2', name: 'Pilot Flying J'),
            ],
          )),
          200,
        );
      });

      final service = _makeService(client);
      final places =
          await service.searchNearbyTruckStops(lat: 40.7, lng: -74.0);

      expect(places, hasLength(2));
      expect(places[0].placeId, 'P1');
      expect(places[1].placeId, 'P2');
    });

    test('returns empty list on ZERO_RESULTS', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(_placesResponse(status: 'ZERO_RESULTS')),
          200,
        );
      });

      final service = _makeService(client);
      final places =
          await service.searchNearbyTruckStops(lat: 40.7, lng: -74.0);

      expect(places, isEmpty);
    });

    test('throws on non-200 HTTP status', () async {
      final client = MockClient((request) async {
        return http.Response('Server error', 500);
      });

      final service = _makeService(client);
      expect(
        () => service.searchNearbyTruckStops(lat: 40.7, lng: -74.0),
        throwsException,
      );
    });

    test('throws on Places API error status (e.g. REQUEST_DENIED)', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(_placesResponse(
            status: 'REQUEST_DENIED',
            errorMessage: 'API key invalid',
          )),
          200,
        );
      });

      final service = _makeService(client);
      expect(
        () => service.searchNearbyTruckStops(lat: 40.7, lng: -74.0),
        throwsException,
      );
    });

    test('skips malformed results and keeps valid ones', () async {
      final client = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'status': 'OK',
            'results': [
              // Valid result
              _resultJson(placeId: 'VALID'),
              // Missing geometry – will be skipped
              {'place_id': 'BAD', 'name': 'No geo'},
            ],
          }),
          200,
        );
      });

      final service = _makeService(client);
      final places =
          await service.searchNearbyTruckStops(lat: 40.7, lng: -74.0);

      expect(places, hasLength(1));
      expect(places.first.placeId, 'VALID');
    });

    test('limits results to maxResults (20)', () async {
      // Generate 25 valid results
      final manyResults = List.generate(
        25,
        (i) => _resultJson(placeId: 'P$i', name: 'Stop $i'),
      );

      final client = MockClient((request) async {
        return http.Response(
          jsonEncode(_placesResponse(status: 'OK', results: manyResults)),
          200,
        );
      });

      final service = _makeService(client);
      final places =
          await service.searchNearbyTruckStops(lat: 40.7, lng: -74.0);

      expect(places.length, lessThanOrEqualTo(GooglePlacesService.maxResults));
    });

    test('request URL includes key, location, radius, and keyword', () async {
      Uri? capturedUri;
      final client = MockClient((request) async {
        capturedUri = request.url;
        return http.Response(
          jsonEncode(_placesResponse(status: 'ZERO_RESULTS')),
          200,
        );
      });

      final service = _makeService(client);
      await service.searchNearbyTruckStops(
        lat: 37.7749,
        lng: -122.4194,
        radiusMeters: 25000,
      );

      expect(capturedUri, isNotNull);
      expect(capturedUri!.queryParameters['key'], 'TEST_KEY');
      expect(capturedUri!.queryParameters['location'], '37.7749,-122.4194');
      expect(capturedUri!.queryParameters['radius'], '25000');
      expect(
        capturedUri!.queryParameters['keyword'],
        contains('truck stop'),
      );
    });
  });
}

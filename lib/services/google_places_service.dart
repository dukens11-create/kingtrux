import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/nearby_place.dart';

/// Fetches nearby truck-stop / truck-fuel locations using the Google Places
/// Nearby Search REST API.
///
/// Usage:
/// ```dart
/// final service = GooglePlacesService(apiKey: Config.placesApiKey);
/// final stops = await service.searchNearbyTruckStops(lat: 40.7, lng: -74.0);
/// ```
///
/// The API key must have the **Places API** enabled in Google Cloud Console.
/// Pass the key at build/run time:
/// ```
/// flutter run --dart-define=PLACES_API_KEY=<your_key>
/// ```
class GooglePlacesService {
  /// Create a service instance with the given [apiKey].
  ///
  /// If [apiKey] is empty the service will still attempt the request and
  /// receive a `REQUEST_DENIED` status from the API; callers should guard
  /// against this using [Config.placesApiKeyConfigured].
  GooglePlacesService({required this.apiKey, http.Client? client})
      : _client = client ?? http.Client();

  final String apiKey;
  final http.Client _client;

  static const String _baseUrl =
      'https://maps.googleapis.com/maps/api/place/nearbysearch/json';

  /// Keywords sent to Nearby Search so results are truck-stop relevant.
  static const String _keyword = 'truck stop|travel center|diesel|truck fuel';

  /// Maximum number of results to keep (Places API returns up to 20 per page).
  static const int maxResults = 20;

  /// Search for truck stops and truck fuel stations near [lat] / [lng].
  ///
  /// [radiusMeters] – search radius (default 30 km ≈ ~18 miles).
  ///
  /// Returns an empty list when [status] is `ZERO_RESULTS`.
  /// Throws an [Exception] on network errors or unexpected API error statuses.
  Future<List<NearbyPlace>> searchNearbyTruckStops({
    required double lat,
    required double lng,
    int radiusMeters = 30000,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(queryParameters: {
      'key': apiKey,
      'location': '$lat,$lng',
      'radius': radiusMeters.toString(),
      'keyword': _keyword,
    });

    late final http.Response response;
    try {
      response = await _client.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () =>
            throw Exception('Places API request timed out after 15 seconds'),
      );
    } catch (e) {
      debugPrint('GooglePlacesService: network error: $e');
      rethrow;
    }

    if (response.statusCode != 200) {
      throw Exception(
        'Places API HTTP ${response.statusCode}: ${response.body}',
      );
    }

    late final Map<String, dynamic> data;
    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw Exception('Places API: failed to decode response: $e');
    }

    final status = data['status'] as String? ?? '';

    if (status == 'ZERO_RESULTS') {
      debugPrint('GooglePlacesService: ZERO_RESULTS for ($lat, $lng)');
      return [];
    }

    if (status != 'OK') {
      final msg = data['error_message'] as String? ?? status;
      throw Exception('Places API error ($status): $msg');
    }

    final rawResults = (data['results'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    final places = <NearbyPlace>[];
    for (final json in rawResults) {
      if (places.length >= maxResults) break;
      try {
        places.add(NearbyPlace.fromJson(json));
      } catch (e) {
        debugPrint('GooglePlacesService: skipping malformed result: $e');
      }
    }

    debugPrint(
      'GooglePlacesService: loaded ${places.length} nearby truck stop(s)',
    );
    return places;
  }
}

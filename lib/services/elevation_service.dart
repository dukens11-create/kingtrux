import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/elevation_point.dart';

// =============================================================================
// ElevationService
// =============================================================================
//
// OVERVIEW
// --------
// Fetches road / terrain elevation for a given (lat, lng) coordinate using the
// Google Elevation API:
//   https://developers.google.com/maps/documentation/elevation
//
// HOW TO CONFIGURE
// ----------------
// 1. Enable the "Elevation API" in your Google Cloud project:
//    https://console.cloud.google.com/apis/library/elevation.googleapis.com
// 2. Copy your API key and pass it at build / run time:
//      flutter run --dart-define=GOOGLE_ELEVATION_API_KEY=your_key
//
// FREE / OPEN-SOURCE ALTERNATIVES (no API key required)
// -----------------------------------------------------
// To switch away from Google, replace _baseUrl below and update _parseResponse:
//   • Open-Meteo Elevation API – https://open-meteo.com/en/docs/elevation-api
//       GET https://api.open-meteo.com/v1/elevation?latitude=<lat>&longitude=<lng>
//       Response: { "elevation": [<metres>] }
//   • OpenTopoData (SRTM30m)   – https://www.opentopodata.org/
//       GET https://api.opentopodata.org/v1/srtm30m?locations=<lat>,<lng>
//       Response: { "results": [ { "elevation": <metres> } ] }
//
// CACHING
// -------
// Results are cached in memory for the lifetime of the service instance.
// The cache key is the coordinate pair rounded to 4 decimal places (~11 m).
// Call [clearCache] to free memory or force a fresh fetch.
//
// EXTENSION TO ROUTE ELEVATION ANALYTICS
// ----------------------------------------
// Use [fetchMultiple] to pass a list of waypoints along a route; the service
// batches them into a single API request (up to 512 locations per the Google
// Elevation API limits).  Results are returned in the same order as input.
// =============================================================================

/// Thrown when the Elevation API returns an error or the key is not set.
class ElevationException implements Exception {
  const ElevationException(this.message);
  final String message;
  @override
  String toString() => 'ElevationException: $message';
}

/// Service for querying road / terrain elevation data.
///
/// Inject an [http.Client] in tests to avoid real network calls.
class ElevationService {
  ElevationService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _baseUrl =
      'https://maps.googleapis.com/maps/api/elevation/json';
  static const _timeout = Duration(seconds: 15);

  // In-memory cache: rounded-coordinate key → ElevationPoint.
  final Map<String, ElevationPoint> _cache = {};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Fetch elevation for a single [lat] / [lng] coordinate.
  ///
  /// Results are cached per coordinate (4 decimal-place precision).
  /// Throws [ElevationException] when the API key is absent or the request
  /// fails.
  Future<ElevationPoint> fetchElevation({
    required double lat,
    required double lng,
  }) async {
    if (!Config.elevationApiConfigured) {
      throw const ElevationException(
        'Google Elevation API key not configured. '
        'Pass --dart-define=GOOGLE_ELEVATION_API_KEY=your_key at build time.',
      );
    }

    final cacheKey = _cacheKey(lat, lng);
    if (_cache.containsKey(cacheKey)) {
      debugPrint('ElevationService: cache hit for $cacheKey');
      return _cache[cacheKey]!;
    }

    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'locations': '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}',
        'key': Config.googleElevationApiKey,
      },
    );

    final response =
        await _client.get(uri).timeout(_timeout, onTimeout: () {
      throw const ElevationException(
          'Elevation API request timed out after 15 seconds.');
    });

    final point = _parseResponse(response, lat, lng);
    _cache[cacheKey] = point;
    return point;
  }

  /// Fetch elevation for multiple coordinates in a single API request.
  ///
  /// The Google Elevation API accepts up to 512 locations per request.
  /// Returns results in the same order as [coordinates].
  /// Throws [ElevationException] when the API key is absent or the request
  /// fails.
  Future<List<ElevationPoint>> fetchMultiple(
    List<({double lat, double lng})> coordinates,
  ) async {
    if (coordinates.isEmpty) return [];

    if (!Config.elevationApiConfigured) {
      throw const ElevationException(
        'Google Elevation API key not configured. '
        'Pass --dart-define=GOOGLE_ELEVATION_API_KEY=your_key at build time.',
      );
    }

    // Separate cached from uncached; keep a nullable list so partial results
    // are never returned if the API call fails.
    final results = List<ElevationPoint?>.filled(coordinates.length, null);
    final uncachedIndices = <int>[];

    for (var i = 0; i < coordinates.length; i++) {
      final key = _cacheKey(coordinates[i].lat, coordinates[i].lng);
      if (_cache.containsKey(key)) {
        results[i] = _cache[key];
      } else {
        uncachedIndices.add(i);
      }
    }

    if (uncachedIndices.isNotEmpty) {
      final locationParam = uncachedIndices
          .map((i) =>
              '${coordinates[i].lat.toStringAsFixed(6)},'
              '${coordinates[i].lng.toStringAsFixed(6)}')
          .join('|');

      final uri = Uri.parse(_baseUrl).replace(
        queryParameters: {
          'locations': locationParam,
          'key': Config.googleElevationApiKey,
        },
      );

      final response =
          await _client.get(uri).timeout(_timeout, onTimeout: () {
        throw const ElevationException(
            'Elevation API request timed out after 15 seconds.');
      });

      if (response.statusCode != 200) {
        throw ElevationException(
            'Elevation API HTTP ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      _checkStatus(data);

      final apiResults = data['results'] as List<dynamic>;
      if (apiResults.length != uncachedIndices.length) {
        throw ElevationException(
          'Elevation API returned ${apiResults.length} results '
          'for ${uncachedIndices.length} locations.',
        );
      }

      for (var k = 0; k < uncachedIndices.length; k++) {
        final point =
            ElevationPoint.fromJson(apiResults[k] as Map<String, dynamic>);
        final idx = uncachedIndices[k];
        results[idx] = point;
        _cache[_cacheKey(coordinates[idx].lat, coordinates[idx].lng)] = point;
      }
    }

    // All results must be non-null at this point; the API call above either
    // filled every slot or threw an exception.
    return results.cast<ElevationPoint>();
  }

  /// Removes all cached elevation results.
  void clearCache() => _cache.clear();

  /// Returns the number of entries currently held in the in-memory cache.
  int get cacheSize => _cache.length;

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  ElevationPoint _parseResponse(
      http.Response response, double lat, double lng) {
    if (response.statusCode != 200) {
      throw ElevationException(
          'Elevation API HTTP ${response.statusCode}: ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    _checkStatus(data);

    final results = data['results'] as List<dynamic>;
    if (results.isEmpty) {
      throw ElevationException(
          'Elevation API returned no results for ($lat, $lng).');
    }

    return ElevationPoint.fromJson(results[0] as Map<String, dynamic>);
  }

  /// Checks the `status` field in the Google Elevation API JSON response.
  ///
  /// Throws [ElevationException] for non-OK status codes.
  void _checkStatus(Map<String, dynamic> data) {
    final status = data['status'] as String? ?? 'UNKNOWN';
    if (status != 'OK') {
      final msg = data['error_message'] as String? ?? '';
      throw ElevationException(
          'Elevation API status $status${msg.isNotEmpty ? ": $msg" : ""}');
    }
  }

  /// Cache key: lat/lng rounded to 4 decimal places (~11 m precision).
  static String _cacheKey(double lat, double lng) =>
      '${lat.toStringAsFixed(4)},${lng.toStringAsFixed(4)}';
}

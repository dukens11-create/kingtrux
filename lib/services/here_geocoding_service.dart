import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';

/// A geocoded location returned by [HereGeocodingService.geocode].
class GeocodedLocation {
  const GeocodedLocation({
    required this.lat,
    required this.lng,
    required this.label,
  });

  /// Latitude of the best-match result.
  final double lat;

  /// Longitude of the best-match result.
  final double lng;

  /// Human-readable label (formatted address) from the HERE response.
  final String label;
}

/// Converts an address string to geographic coordinates using the
/// HERE Geocoding & Search API v1.
///
/// Returns `null` when no results are found or when the HERE API key is not
/// configured.
class HereGeocodingService {
  static const String _geocodeUrl =
      'https://geocode.search.hereapi.com/v1/geocode';
  static const String _revGeocodeUrl =
      'https://revgeocode.search.hereapi.com/v1/revgeocode';

  /// Geocodes [address] and returns the best match, or `null` if none found.
  Future<GeocodedLocation?> geocode(String address) async {
    if (Config.hereApiKey.isEmpty) {
      debugPrint('HereGeocodingService: HERE API key not configured.');
      return null;
    }

    try {
      final uri = Uri.parse(_geocodeUrl).replace(
        queryParameters: <String, String>{
          'q': address,
          'apiKey': Config.hereApiKey,
        },
      );

      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint(
          'HereGeocodingService: HTTP ${response.statusCode} for "$address"',
        );
        return null;
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;

      final first = items[0] as Map<String, dynamic>;
      final position = first['position'] as Map<String, dynamic>?;
      final title = first['title'] as String?;

      if (position == null) return null;

      return GeocodedLocation(
        lat: (position['lat'] as num).toDouble(),
        lng: (position['lng'] as num).toDouble(),
        label: title ?? address,
      );
    } catch (e) {
      debugPrint('HereGeocodingService: Error geocoding "$address": $e');
      return null;
    }
  }

  /// Reverse geocodes [lat]/[lng] and returns the USPS 2-letter state code
  /// (e.g., `'TX'`), or `null` when outside the US or on any error.
  Future<String?> reverseGeocodeStateCode(double lat, double lng) async {
    if (Config.hereApiKey.isEmpty) return null;
    try {
      final uri = Uri.parse(_revGeocodeUrl).replace(
        queryParameters: <String, String>{
          'at': '${lat.toStringAsFixed(6)},${lng.toStringAsFixed(6)}',
          'apiKey': Config.hereApiKey,
        },
      );
      final response =
          await http.get(uri).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) return null;
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final items = data['items'] as List<dynamic>?;
      if (items == null || items.isEmpty) return null;
      final address =
          (items[0] as Map<String, dynamic>)['address'] as Map<String, dynamic>?;
      final stateCode = address?['stateCode'] as String?;
      // Only return codes that look like USPS abbreviations (2 upper-case letters).
      if (stateCode == null || stateCode.length != 2) return null;
      return stateCode.toUpperCase();
    } catch (e) {
      debugPrint('HereGeocodingService: reverseGeocodeStateCode error: $e');
      return null;
    }
  }
}

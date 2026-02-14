import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../config.dart';
import '../models/truck_profile.dart';
import '../models/route_result.dart';

/// Service for HERE Routing API v8
class HereRoutingService {
  /// Calculate truck route from origin to destination
  Future<RouteResult> calculateTruckRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required TruckProfile profile,
  }) async {
    if (Config.hereApiKey.isEmpty) {
      throw Exception('HERE API key not configured');
    }

    final uri = Uri.parse(Config.hereRoutingBaseUrl).replace(queryParameters: {
      'apiKey': Config.hereApiKey,
      'origin': '$originLat,$originLng',
      'destination': '$destLat,$destLng',
      'transportMode': 'truck',
      'return': 'polyline,summary',
      'spans': 'length',
      'truck[height]': profile.heightMeters.toString(),
      'truck[width]': profile.widthMeters.toString(),
      'truck[length]': profile.lengthMeters.toString(),
      'truck[grossWeight]': (profile.weightTons * 1000).toStringAsFixed(0), // Convert to kg
      'truck[axleCount]': profile.axles.toString(),
      if (profile.hazmat) 'truck[shippedHazardousGoods]': 'explosive',
    });

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('HERE API request failed with status ${response.statusCode}: ${response.body}');
    }

    final data = json.decode(response.body);

    if (data['routes'] == null || (data['routes'] as List).isEmpty) {
      throw Exception('No routes found');
    }

    final route = data['routes'][0];
    final sections = route['sections'] as List;

    if (sections.isEmpty) {
      throw Exception('No sections in route');
    }

    // Extract polyline from first section
    final section = sections[0];
    final polylineEncoded = section['polyline'] as String?;

    if (polylineEncoded == null) {
      throw Exception('No polyline in route section');
    }

    // Decode HERE Flexible Polyline
    final polylinePoints = _decodeHerePolyline(polylineEncoded);

    // Get route summary
    final lengthMeters = (route['sections'] as List).fold<double>(
      0.0,
      (sum, s) => sum + ((s['summary']?['length'] as num?)?.toDouble() ?? 0.0),
    );

    final durationSeconds = (route['sections'] as List).fold<int>(
      0,
      (sum, s) => sum + ((s['summary']?['duration'] as num?)?.toInt() ?? 0),
    );

    return RouteResult(
      polylinePoints: polylinePoints,
      lengthMeters: lengthMeters,
      durationSeconds: durationSeconds,
    );
  }

  /// Decode HERE Flexible Polyline format
  List<LatLng> _decodeHerePolyline(String encoded) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;

      // Decode latitude
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int deltaLat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += deltaLat;

      result = 0;
      shift = 0;

      // Decode longitude
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int deltaLng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += deltaLng;

      // Skip third dimension if present (we only need 2D)
      if (index < encoded.length) {
        result = 0;
        shift = 0;
        do {
          if (index >= encoded.length) break;
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
      }

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }
}

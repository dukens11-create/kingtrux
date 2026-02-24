import 'dart:convert';
import 'dart:math' as math;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/truck_profile.dart';
import '../models/route_result.dart';
import '../models/navigation_maneuver.dart';

/// Service for calculating truck routes using HERE API v8
class HereRoutingService {
  /// Calculate truck route from origin to destination
  Future<RouteResult> getTruckRoute({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required TruckProfile truckProfile,
  }) async {
    if (Config.hereApiKey.isEmpty) {
      throw Exception('HERE API key not configured. Please set HERE_API_KEY environment variable.');
    }

    // Build URL with truck parameters
    final url = Uri.parse('${Config.hereRoutingBaseUrl}/routes').replace(
      queryParameters: {
        'apiKey': Config.hereApiKey,
        'origin': '$originLat,$originLng',
        'destination': '$destLat,$destLng',
        'transportMode': 'truck',
        'return': 'polyline,summary,actions',
        // Truck restrictions
        'truck[height]': truckProfile.heightMeters.toString(),
        'truck[width]': truckProfile.widthMeters.toString(),
        'truck[length]': truckProfile.lengthMeters.toString(),
        'truck[grossWeight]': (truckProfile.weightTons * 1000).toString(), // Convert to kg
        'truck[axleCount]': truckProfile.axles.toString(),
        if (truckProfile.hazmat) 'truck[shippedHazardousGoods]': 'explosive',
      },
    );

    final response = await http.get(url).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('HERE Routing API request timed out after 30 seconds'),
    );

    if (response.statusCode != 200) {
      throw Exception('HERE Routing API error: ${response.statusCode} - ${response.body}');
    }

    final data = json.decode(response.body);
    
    if (data['routes'] == null || (data['routes'] as List).isEmpty) {
      throw Exception('No route found');
    }

    final route = data['routes'][0];
    final sections = route['sections'] as List;
    
    if (sections.isEmpty) {
      throw Exception('Route has no sections');
    }

    final section = sections[0];
    final summary = section['summary'];
    final polylineEncoded = section['polyline'];

    if (polylineEncoded == null) {
      throw Exception('No polyline in route response');
    }

    // Decode HERE Flexible Polyline
    final polylinePoints = _decodeHerePolyline(polylineEncoded as String);

    // Parse maneuver actions if present
    final actionsList = section['actions'] as List?;
    final maneuvers = actionsList
            ?.map((a) => NavigationManeuver.fromHereAction(
                  a as Map<String, dynamic>,
                  polylinePoints,
                ))
            .toList() ??
        <NavigationManeuver>[];

    return RouteResult(
      polylinePoints: polylinePoints,
      lengthMeters: (summary['length'] as num).toDouble(),
      durationSeconds: (summary['duration'] as num).toInt(),
      maneuvers: maneuvers,
    );
  }

  /// Decode HERE Flexible Polyline format
  /// Supports 2D polyline with precision and third dimension support
  List<LatLng> _decodeHerePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    // First, decode the header
    final header = _decodeUnsignedVarint(encoded, index);
    index = header.index;
    final precision = header.value & 15;
    final thirdDim = (header.value >> 4) & 7;
    final thirdDimPrecision = (header.value >> 7) & 15;
    
    final precisionFactor = math.pow(10, precision).toDouble();

    int thirdDimValue = 0;

    while (index < encoded.length) {
      // Decode latitude
      final latResult = _decodeSignedVarint(encoded, index);
      index = latResult.index;
      lat += latResult.value;

      // Decode longitude
      final lngResult = _decodeSignedVarint(encoded, index);
      index = lngResult.index;
      lng += lngResult.value;

      // Decode third dimension if present
      if (thirdDim > 0) {
        final thirdResult = _decodeSignedVarint(encoded, index);
        index = thirdResult.index;
        thirdDimValue += thirdResult.value;
      }

      points.add(LatLng(
        lat / precisionFactor,
        lng / precisionFactor,
      ));
    }

    return points;
  }

  _DecodeResult _decodeUnsignedVarint(String encoded, int index) {
    int result = 0;
    int shift = 0;

    while (index < encoded.length) {
      int b = encoded.codeUnitAt(index) - 63;
      index++;
      
      result |= (b & 0x1F) << shift;
      
      if ((b & 0x20) == 0) {
        break;
      }
      shift += 5;
    }

    return _DecodeResult(result, index);
  }

  _DecodeResult _decodeSignedVarint(String encoded, int index) {
    final result = _decodeUnsignedVarint(encoded, index);
    final value = result.value;
    
    final decoded = (value & 1) != 0 ? ~(value >> 1) : (value >> 1);
    
    return _DecodeResult(decoded, result.index);
  }
}

class _DecodeResult {
  final int value;
  final int index;

  _DecodeResult(this.value, this.index);
}

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config.dart';
import '../models/poi.dart';

/// Service for fetching roadside assistance providers from the OpenStreetMap
/// Overpass API.
///
/// Queries for towing services, automotive repair shops, tyre shops, and
/// general emergency roadside assistance nodes near a given location.
class RoadsideAssistanceService {
  final _uuid = const Uuid();

  /// Fetch roadside assistance providers within [radiusMeters] of the given
  /// coordinates.  Returns a list of [Poi] objects with
  /// [PoiType.roadsideAssistance].
  Future<List<Poi>> fetchProviders({
    required double centerLat,
    required double centerLng,
    double radiusMeters = 50000,
  }) async {
    final query = _buildQuery(centerLat, centerLng, radiusMeters);

    final response = await http.post(
      Uri.parse(Config.overpassApiUrl),
      body: query,
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () =>
          throw Exception('Overpass API request timed out after 30 seconds'),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'Overpass API error: ${response.statusCode} - ${response.body}');
    }

    return _parseResponse(response.body);
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  String _buildQuery(double lat, double lng, double radius) {
    void add(StringBuffer buf, String filter) {
      buf.write('node[$filter](around:$radius,$lat,$lng);');
      buf.write('way[$filter](around:$radius,$lat,$lng);');
    }

    final buf = StringBuffer('[out:json];(');
    // Towing / roadside emergency
    add(buf, '"emergency"="roadside_assistance"');
    add(buf, '"amenity"="car_rental"'); // occasionally offers assistance
    // Automotive repair (mechanics)
    add(buf, '"amenity"="car_repair"');
    add(buf, '"shop"="car_repair"');
    add(buf, '"shop"="vehicle_repair"');
    // Tyre shops
    add(buf, '"shop"="tyres"');
    add(buf, '"shop"="car_parts"');
    buf.write(');out center;');
    return buf.toString();
  }

  List<Poi> _parseResponse(String body) {
    final data = json.decode(body);
    final elements = data['elements'] as List? ?? [];
    final pois = <Poi>[];

    for (final element in elements) {
      try {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};

        double? lat;
        double? lng;
        if (element['lat'] != null && element['lon'] != null) {
          lat = (element['lat'] as num).toDouble();
          lng = (element['lon'] as num).toDouble();
        } else if (element['center'] != null) {
          lat = (element['center']['lat'] as num).toDouble();
          lng = (element['center']['lon'] as num).toDouble();
        }
        if (lat == null || lng == null) continue;

        final name = tags['name'] as String? ??
            tags['operator'] as String? ??
            tags['brand'] as String? ??
            'Roadside Service';

        final elementType = element['type'] as String?;
        final elementId = element['id'];
        late final String stableId;
        if (elementType != null && elementId != null) {
          stableId = 'roadside_${elementType}_$elementId';
        } else {
          stableId = _uuid.v4();
          debugPrint(
            'RoadsideAssistanceService: element missing type/id fields; '
            'falling back to UUID $stableId',
          );
        }

        pois.add(Poi(
          id: stableId,
          type: PoiType.roadsideAssistance,
          name: name,
          lat: lat,
          lng: lng,
          tags: tags,
        ));
      } catch (e) {
        continue;
      }
    }

    return pois;
  }
}

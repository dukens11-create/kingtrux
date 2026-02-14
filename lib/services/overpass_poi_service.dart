import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/poi.dart';

/// Service for fetching POIs from OpenStreetMap Overpass API
class OverpassPoiService {
  /// Fetch POIs around a center point
  Future<List<Poi>> fetchPois({
    required double centerLat,
    required double centerLng,
    required Set<PoiType> enabledTypes,
    double radiusMeters = 15000,
  }) async {
    final List<Poi> allPois = [];

    // Build queries for each enabled type
    final queries = <String>[];

    if (enabledTypes.contains(PoiType.fuel)) {
      queries.add('node["amenity"="fuel"](around:$radiusMeters,$centerLat,$centerLng);');
      queries.add('way["amenity"="fuel"](around:$radiusMeters,$centerLat,$centerLng);');
    }

    if (enabledTypes.contains(PoiType.restArea)) {
      queries.add('node["highway"="rest_area"](around:$radiusMeters,$centerLat,$centerLng);');
      queries.add('way["highway"="rest_area"](around:$radiusMeters,$centerLat,$centerLng);');
    }

    if (queries.isEmpty) {
      return [];
    }

    // Build Overpass QL query
    final query = '[out:json];(${queries.join('')});out center;';

    final response = await http.post(
      Uri.parse(Config.overpassApiUrl),
      body: query,
    );

    if (response.statusCode != 200) {
      throw Exception('Overpass API request failed with status ${response.statusCode}');
    }

    final data = json.decode(response.body);
    final elements = data['elements'] as List?;

    if (elements == null) {
      return [];
    }

    for (final element in elements) {
      final tags = element['tags'] as Map<String, dynamic>?;
      if (tags == null) continue;

      // Determine POI type
      PoiType? poiType;
      if (tags['amenity'] == 'fuel') {
        poiType = PoiType.fuel;
      } else if (tags['highway'] == 'rest_area') {
        poiType = PoiType.restArea;
      }

      if (poiType == null) continue;

      // Extract coordinates
      double? lat;
      double? lng;

      if (element['type'] == 'node') {
        lat = element['lat'] as double?;
        lng = element['lon'] as double?;
      } else if (element['type'] == 'way' || element['type'] == 'relation') {
        // Use center for ways and relations
        final center = element['center'] as Map<String, dynamic>?;
        if (center != null) {
          lat = center['lat'] as double?;
          lng = center['lon'] as double?;
        }
      }

      if (lat == null || lng == null) continue;

      final name = tags['name'] as String? ?? 'Unnamed';
      final id = element['id'].toString();

      allPois.add(Poi(
        id: id,
        type: poiType,
        name: name,
        lat: lat,
        lng: lng,
        tags: tags,
      ));
    }

    return allPois;
  }
}

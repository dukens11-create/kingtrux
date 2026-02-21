import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config.dart';
import '../models/poi.dart';

/// Service for fetching POIs from OpenStreetMap Overpass API
class OverpassPoiService {
  final _uuid = const Uuid();

  /// Fetch POIs around a center point
  /// Supports fuel stations and rest areas
  Future<List<Poi>> fetchPois({
    required double centerLat,
    required double centerLng,
    required Set<PoiType> enabledTypes,
    double radiusMeters = 15000,
  }) async {
    if (enabledTypes.isEmpty) {
      return [];
    }

    // Build Overpass query
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

    final query = '[out:json];(${queries.join('')});out center;';

    final response = await http.post(
      Uri.parse(Config.overpassApiUrl),
      body: query,
    ).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('Overpass API request timed out after 30 seconds'),
    );

    if (response.statusCode != 200) {
      throw Exception('Overpass API error: ${response.statusCode} - ${response.body}');
    }

    final data = json.decode(response.body);
    final elements = data['elements'] as List? ?? [];

    final pois = <Poi>[];
    
    for (final element in elements) {
      try {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};
        
        // Determine POI type
        PoiType? type;
        if (tags['amenity'] == 'fuel') {
          type = PoiType.fuel;
        } else if (tags['highway'] == 'rest_area') {
          type = PoiType.restArea;
        }

        if (type == null) continue;

        // Extract coordinates
        double? lat;
        double? lng;

        if (element['lat'] != null && element['lon'] != null) {
          // Node with direct coordinates
          lat = (element['lat'] as num).toDouble();
          lng = (element['lon'] as num).toDouble();
        } else if (element['center'] != null) {
          // Way or relation with center
          lat = (element['center']['lat'] as num).toDouble();
          lng = (element['center']['lon'] as num).toDouble();
        }

        if (lat == null || lng == null) continue;

        // Generate name
        String name = tags['name'] ?? 
                     tags['operator'] ?? 
                     tags['brand'] ?? 
                     (type == PoiType.fuel ? 'Fuel Station' : 'Rest Area');

        pois.add(Poi(
          id: element['id']?.toString() ?? _uuid.v4(),
          type: type,
          name: name,
          lat: lat,
          lng: lng,
          tags: tags,
        ));
      } catch (e) {
        // Skip invalid elements
        continue;
      }
    }

    return pois;
  }
}

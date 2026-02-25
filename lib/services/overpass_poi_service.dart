import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config.dart';
import '../models/poi.dart';
import 'truck_stop_filter_service.dart';

/// Service for fetching Points of Interest (POIs) from the OpenStreetMap
/// Overpass API.
///
/// Call [fetchPois] to load POIs around a single geographic coordinate, or
/// [fetchPoisAlongRoute] to sample POIs at multiple points along a route
/// polyline.  Results are returned as a list of [Poi] objects with stable ids
/// derived from the OSM element type and numeric id.
///
/// Typical usage from [AppState]:
/// ```dart
/// final pois = await _poiService.fetchPois(
///   centerLat: myLat,
///   centerLng: myLng,
///   enabledTypes: enabledPoiLayers,
/// );
/// ```
class OverpassPoiService {
  final _uuid = const Uuid();

  /// Fetch POIs around a center point within [radiusMeters].
  ///
  /// Queries the Overpass API for all OSM elements matching the supplied
  /// [enabledTypes].  Returns an empty list immediately when [enabledTypes] is
  /// empty.  Throws an [Exception] on network error or non-200 HTTP status.
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
    final queries = _buildQueries(enabledTypes, radiusMeters, centerLat, centerLng);

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

    return _parseResponse(response.body);
  }

  /// Fetch POIs along a route by sampling up to [maxSamples] evenly-spaced
  /// points from [routeLatLngs] (each as `[lat, lng]`) and querying with a
  /// corridor of [radiusMeters] around each sample point.
  ///
  /// A 500 ms pause is introduced between consecutive Overpass requests to
  /// respect the API rate limit.  Results are deduplicated by OSM element id
  /// so the same POI is never returned twice.
  Future<List<Poi>> fetchPoisAlongRoute({
    required List<List<double>> routeLatLngs,
    required Set<PoiType> enabledTypes,
    double radiusMeters = 5000,
    int maxSamples = 8,
  }) async {
    if (enabledTypes.isEmpty || routeLatLngs.isEmpty) return [];

    final samples = _samplePoints(routeLatLngs, maxSamples);
    final seen = <String>{};
    final pois = <Poi>[];

    for (final point in samples) {
      final batch = await fetchPois(
        centerLat: point[0],
        centerLng: point[1],
        enabledTypes: enabledTypes,
        radiusMeters: radiusMeters,
      );
      for (final poi in batch) {
        if (seen.add(poi.id)) {
          pois.add(poi);
        }
      }
      // Brief pause between requests to respect Overpass rate limits.
      if (point != samples.last) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    }

    return pois;
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  List<String> _buildQueries(
    Set<PoiType> enabledTypes,
    double radius,
    double lat,
    double lng,
  ) {
    final q = <String>[];
    void add(String filter) {
      q.add('node[$filter](around:$radius,$lat,$lng);');
      q.add('way[$filter](around:$radius,$lat,$lng);');
    }

    if (enabledTypes.contains(PoiType.fuel)) {
      add('"amenity"="fuel"');
    }
    if (enabledTypes.contains(PoiType.restArea)) {
      add('"highway"="rest_area"');
    }
    if (enabledTypes.contains(PoiType.scale)) {
      add('"amenity"="weighbridge"');
    }
    if (enabledTypes.contains(PoiType.gym)) {
      add('"leisure"="fitness_centre"');
      add('"amenity"="gym"');
    }
    if (enabledTypes.contains(PoiType.truckStop)) {
      add('"highway"="services"');
      add('"amenity"="truck_stop"');
      // Also capture branded fuel stops (TA, Petro, Love's, Pilot, Flying J).
      const brandRegex = 'TA|TravelCenters|Petro|Love|Pilot|Flying.?J';
      q.add('node["amenity"="fuel"]["brand"~"$brandRegex",i](around:$radius,$lat,$lng);');
      q.add('way["amenity"="fuel"]["brand"~"$brandRegex",i](around:$radius,$lat,$lng);');
      q.add('node["amenity"="fuel"]["operator"~"$brandRegex",i](around:$radius,$lat,$lng);');
      q.add('way["amenity"="fuel"]["operator"~"$brandRegex",i](around:$radius,$lat,$lng);');
    }
    if (enabledTypes.contains(PoiType.parking)) {
      add('"amenity"="parking"');
    }

    return q;
  }

  List<Poi> _parseResponse(String body) {
    final data = json.decode(body);
    final elements = data['elements'] as List? ?? [];
    final pois = <Poi>[];

    for (final element in elements) {
      try {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};

        // Determine POI type
        PoiType? type;
        if (tags['amenity'] == 'fuel') {
          // Reclassify as truckStop when the station belongs to a major brand.
          final isBranded =
              TruckStopFilterService.detectBrand(tags) != null;
          type = isBranded ? PoiType.truckStop : PoiType.fuel;
        } else if (tags['highway'] == 'rest_area') {
          type = PoiType.restArea;
        } else if (tags['amenity'] == 'weighbridge') {
          type = PoiType.scale;
        } else if (tags['leisure'] == 'fitness_centre' || tags['amenity'] == 'gym') {
          type = PoiType.gym;
        } else if (tags['highway'] == 'services' || tags['amenity'] == 'truck_stop') {
          type = PoiType.truckStop;
        } else if (tags['amenity'] == 'parking') {
          type = PoiType.parking;
        }

        if (type == null) continue;

        // Extract coordinates
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

        // Generate name
        final String name = tags['name'] as String? ??
            tags['operator'] as String? ??
            tags['brand'] as String? ??
            _defaultName(type);

        // Build a stable id from OSM element type + numeric id so that nodes
        // and ways with the same numeric id do not collide.
        final elementType = element['type'] as String?;
        final elementId = element['id'];
        late final String stableId;
        if (elementType != null && elementId != null) {
          stableId = '${elementType}_$elementId';
        } else {
          stableId = _uuid.v4();
          debugPrint(
            'OverpassPoiService: element missing type/id fields '
            '(type=$elementType, id=$elementId); falling back to UUID $stableId',
          );
        }

        pois.add(Poi(
          id: stableId,
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

  String _defaultName(PoiType type) {
    switch (type) {
      case PoiType.fuel:
        return 'Fuel Station';
      case PoiType.restArea:
        return 'Rest Area';
      case PoiType.scale:
        return 'Weigh Scale';
      case PoiType.gym:
        return 'Gym';
      case PoiType.truckStop:
        return 'Truck Stop';
      case PoiType.parking:
        return 'Parking';
      case PoiType.roadsideAssistance:
        return 'Roadside Service';
    }
  }

  /// Sample up to [maxSamples] evenly-spaced points from [points].
  List<List<double>> _samplePoints(List<List<double>> points, int maxSamples) {
    if (maxSamples <= 1) return [points.first];
    if (points.length <= maxSamples) return List.of(points);
    final result = <List<double>>[];
    final step = (points.length - 1) / (maxSamples - 1);
    for (var i = 0; i < maxSamples; i++) {
      result.add(points[(i * step).round()]);
    }
    return result;
  }
}

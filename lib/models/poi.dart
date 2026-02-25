/// Point of Interest types
enum PoiType {
  fuel,
  restArea,
  gym,
  scale,
  truckStop,
  parking,
  roadsideAssistance,
}

/// Point of Interest model
class Poi {
  /// Unique identifier
  final String id;
  
  /// POI type
  final PoiType type;
  
  /// Display name
  final String name;
  
  /// Latitude
  final double lat;
  
  /// Longitude
  final double lng;
  
  /// Additional OSM tags
  final Map<String, dynamic> tags;

  const Poi({
    required this.id,
    required this.type,
    required this.name,
    required this.lat,
    required this.lng,
    required this.tags,
  });
}

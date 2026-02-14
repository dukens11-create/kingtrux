/// Point of Interest types
enum PoiType {
  fuel,
  restArea,
  gym,
  scale,
  truckStop,
  parking,
}

/// Point of Interest model
class Poi {
  final String id;
  final PoiType type;
  final String name;
  final double lat;
  final double lng;
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

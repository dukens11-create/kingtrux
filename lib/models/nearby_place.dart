/// A place returned by the Google Places Nearby Search API.
class NearbyPlace {
  /// Google Places unique identifier for this location.
  final String placeId;

  /// Human-readable name of the place (e.g. "Pilot Travel Center").
  final String name;

  /// Latitude of the place.
  final double lat;

  /// Longitude of the place.
  final double lng;

  /// Street-level address returned by the Places API (may be null).
  final String? vicinity;

  const NearbyPlace({
    required this.placeId,
    required this.name,
    required this.lat,
    required this.lng,
    this.vicinity,
  });

  /// Deserialise a single result object from the Places Nearby Search
  /// `results` array.
  factory NearbyPlace.fromJson(Map<String, dynamic> json) {
    final loc =
        (json['geometry'] as Map<String, dynamic>)['location'] as Map<String, dynamic>;
    return NearbyPlace(
      placeId: json['place_id'] as String,
      name: json['name'] as String,
      lat: (loc['lat'] as num).toDouble(),
      lng: (loc['lng'] as num).toDouble(),
      vicinity: json['vicinity'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is NearbyPlace &&
          runtimeType == other.runtimeType &&
          placeId == other.placeId;

  @override
  int get hashCode => placeId.hashCode;
}

/// A single stop in a multi-stop trip.
class TripStop {
  /// Unique identifier for the stop.
  final String id;

  /// Optional human-readable label (e.g. "Fuel stop", "Delivery").
  final String? label;

  /// Latitude of the stop.
  final double lat;

  /// Longitude of the stop.
  final double lng;

  /// When this stop was added to the trip.
  final DateTime createdAt;

  const TripStop({
    required this.id,
    this.label,
    required this.lat,
    required this.lng,
    required this.createdAt,
  });

  /// Deserialize from a JSON map.
  factory TripStop.fromJson(Map<String, dynamic> json) {
    return TripStop(
      id: json['id'] as String,
      label: json['label'] as String?,
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Serialize to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        if (label != null) 'label': label,
        'lat': lat,
        'lng': lng,
        'createdAt': createdAt.toIso8601String(),
      };

  /// Returns a copy with the given fields replaced.
  TripStop copyWith({
    String? id,
    String? label,
    double? lat,
    double? lng,
    DateTime? createdAt,
  }) {
    return TripStop(
      id: id ?? this.id,
      label: label ?? this.label,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

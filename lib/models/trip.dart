/// A single stop in a multi-stop trip.
class TripStop {
  /// Unique identifier for this stop (used for list keys and persistence).
  final String id;

  /// Human-readable label for this stop (e.g. address or custom name).
  final String label;

  /// Latitude of this stop.
  final double lat;

  /// Longitude of this stop.
  final double lng;

  const TripStop({
    required this.id,
    required this.label,
    required this.lat,
    required this.lng,
  });

  /// Deserialize from a JSON map.
  factory TripStop.fromJson(Map<String, dynamic> json) => TripStop(
        id: json['id'] as String,
        label: json['label'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
      );

  /// Serialize to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'lat': lat,
        'lng': lng,
      };

  /// Return a copy with the given fields replaced.
  TripStop copyWith({String? label, double? lat, double? lng}) => TripStop(
        id: id,
        label: label ?? this.label,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
      );
}

/// A planned multi-stop trip.
class Trip {
  /// Unique identifier for this trip.
  final String id;

  /// Human-readable trip name.
  final String name;

  /// Ordered list of stops (index 0 is the origin).
  final List<TripStop> stops;

  /// Total estimated distance in metres across all legs.
  ///
  /// Populated after route calculation; `null` before the first calculation.
  final double? totalDistanceMeters;

  /// Total estimated duration in seconds across all legs.
  final int? totalDurationSeconds;

  const Trip({
    required this.id,
    required this.name,
    required this.stops,
    this.totalDistanceMeters,
    this.totalDurationSeconds,
  });

  /// Deserialize from a JSON map.
  factory Trip.fromJson(Map<String, dynamic> json) => Trip(
        id: json['id'] as String,
        name: json['name'] as String,
        stops: (json['stops'] as List<dynamic>)
            .map((s) => TripStop.fromJson(s as Map<String, dynamic>))
            .toList(),
        totalDistanceMeters: (json['totalDistanceMeters'] as num?)?.toDouble(),
        totalDurationSeconds: (json['totalDurationSeconds'] as num?)?.toInt(),
      );

  /// Serialize to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'stops': stops.map((s) => s.toJson()).toList(),
        if (totalDistanceMeters != null)
          'totalDistanceMeters': totalDistanceMeters,
        if (totalDurationSeconds != null)
          'totalDurationSeconds': totalDurationSeconds,
      };

  /// Return a copy with the given fields replaced.
  Trip copyWith({
    String? name,
    List<TripStop>? stops,
    double? totalDistanceMeters,
    int? totalDurationSeconds,
  }) =>
      Trip(
        id: id,
        name: name ?? this.name,
        stops: stops ?? this.stops,
        totalDistanceMeters: totalDistanceMeters ?? this.totalDistanceMeters,
        totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
      );
}

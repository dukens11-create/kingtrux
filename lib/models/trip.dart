import 'trip_stop.dart';

/// A multi-stop trip with an ordered list of stops.
class Trip {
  /// Unique identifier for the trip.
  final String id;

  /// Optional human-readable name for the trip.
  final String? name;

  /// Ordered list of stops (first = origin, last = final destination).
  final List<TripStop> stops;

  /// When this trip was created.
  final DateTime createdAt;

  /// When this trip was last modified.
  final DateTime updatedAt;

  const Trip({
    required this.id,
    this.name,
    required this.stops,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Deserialize from a JSON map.
  factory Trip.fromJson(Map<String, dynamic> json) {
    return Trip(
      id: json['id'] as String,
      name: json['name'] as String?,
      stops: (json['stops'] as List<dynamic>)
          .map((s) => TripStop.fromJson(s as Map<String, dynamic>))
          .toList(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }

  /// Serialize to a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        if (name != null) 'name': name,
        'stops': stops.map((s) => s.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Returns a copy with the given fields replaced and [updatedAt] refreshed.
  Trip copyWith({
    String? id,
    String? name,
    List<TripStop>? stops,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Trip(
      id: id ?? this.id,
      name: name ?? this.name,
      stops: stops ?? this.stops,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

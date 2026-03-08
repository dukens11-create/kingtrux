/// A single elevation measurement returned by the Google Elevation API.
///
/// [elevationMeters] is the altitude above sea level in metres.
/// [resolution] is the maximum distance (metres) between data points from
/// which the elevation was interpolated — lower values are more accurate.
class ElevationPoint {
  const ElevationPoint({
    required this.lat,
    required this.lng,
    required this.elevationMeters,
    this.resolution,
  });

  final double lat;
  final double lng;

  /// Elevation above sea level in metres.
  final double elevationMeters;

  /// Maximum interpolation distance in metres (may be null when unavailable).
  final double? resolution;

  /// Convenience getter: elevation converted to feet.
  double get elevationFeet => elevationMeters * 3.28084;

  /// Creates an [ElevationPoint] from a Google Elevation API result object.
  ///
  /// Expected JSON shape:
  /// ```json
  /// {
  ///   "elevation": 1608.637939453125,
  ///   "location": { "lat": 39.7391536, "lng": -104.9847034 },
  ///   "resolution": 4.771975994110107
  /// }
  /// ```
  factory ElevationPoint.fromJson(Map<String, dynamic> json) {
    final location = json['location'] as Map<String, dynamic>;
    return ElevationPoint(
      lat: (location['lat'] as num).toDouble(),
      lng: (location['lng'] as num).toDouble(),
      elevationMeters: (json['elevation'] as num).toDouble(),
      resolution: json['resolution'] != null
          ? (json['resolution'] as num).toDouble()
          : null,
    );
  }

  @override
  String toString() =>
      'ElevationPoint(lat: $lat, lng: $lng, '
      'elevation: ${elevationMeters.toStringAsFixed(1)} m)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ElevationPoint &&
          runtimeType == other.runtimeType &&
          lat == other.lat &&
          lng == other.lng;

  @override
  int get hashCode => Object.hash(lat, lng);
}

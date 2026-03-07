import 'dart:math' as math;

/// A single road / traffic camera location.
///
/// Cameras may provide a static snapshot image via [imageUrl] and/or a live
/// stream via [streamUrl].  Either field may be `null` when the data source
/// does not provide that feed type.
class RoadCamera {
  const RoadCamera({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.country,
    this.stateOrProvince,
    this.direction,
    this.imageUrl,
    this.streamUrl,
    this.lastUpdated,
    this.description,
  });

  /// Unique identifier for this camera (source-specific, e.g. DOT feed ID).
  final String id;

  /// Human-readable camera name or road label.
  final String name;

  final double lat;
  final double lng;

  /// ISO 3166-1 alpha-2 country code: `'US'` or `'CA'`.
  final String country;

  /// USPS / Canada Post two-letter state or province code, e.g. `'NY'`, `'BC'`.
  final String? stateOrProvince;

  /// Cardinal / road direction this camera faces (e.g. `'Northbound'`).
  final String? direction;

  /// URL to a refreshable JPEG/PNG snapshot image from this camera.
  ///
  /// Many DOT feeds expose this as a plain `https://` image URL.
  final String? imageUrl;

  /// URL to a live video stream (HLS `.m3u8`, RTSP, or MJPEG).
  ///
  /// `null` when the data source does not publish a stream.
  final String? streamUrl;

  /// Timestamp from the data source indicating when the snapshot was last
  /// refreshed.  `null` when not provided.
  final DateTime? lastUpdated;

  /// Optional longer description of the camera location from the data source.
  final String? description;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Haversine distance (metres) from this camera to the given coordinates.
  double distanceFromMeters(double userLat, double userLng) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(lat - userLat);
    final dLng = _toRad(lng - userLng);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_toRad(userLat)) *
            math.cos(_toRad(lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * earthRadius * math.asin(math.sqrt(a.toDouble()));
  }

  static double _toRad(double degrees) => degrees * math.pi / 180.0;

  @override
  String toString() =>
      'RoadCamera(id: $id, name: $name, country: $country, '
      'state: $stateOrProvince, lat: $lat, lng: $lng)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RoadCamera && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}

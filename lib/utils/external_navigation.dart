/// Utility for building external navigation URLs with optional waypoints.
///
/// Builds URLs for Google Maps (with full waypoint support) and Apple Maps.
/// These URLs are intended to be launched via `url_launcher`'s `launchUrl`
/// with `LaunchMode.externalApplication`, which on Android shows the system
/// chooser and on iOS opens the default maps application.
///
/// URL formats:
/// - Google Maps: `https://www.google.com/maps/dir/?api=1&destination=...&waypoints=...`
/// - Apple Maps:  `maps://?daddr=lat,lng&dirflg=d`
class ExternalNavigationUrl {
  ExternalNavigationUrl._();

  /// Builds a Google Maps directions URL.
  ///
  /// If [waypoints] is non-empty, the URL includes all intermediate stops in
  /// order (A→B→C) using the pipe-separated `waypoints` query parameter.
  ///
  /// If [originLat]/[originLng] are provided, an explicit `origin` parameter
  /// is included so the route starts from the driver's current position.
  /// When omitted, Google Maps uses the device's current location.
  ///
  /// Coordinates are encoded as `lat,lng` with full double precision.
  static Uri googleMaps({
    required double destLat,
    required double destLng,
    double? originLat,
    double? originLng,
    List<({double lat, double lng})> waypoints = const [],
  }) {
    final params = <String, String>{
      'api': '1',
      'destination': '$destLat,$destLng',
      'travelmode': 'driving',
    };
    if (originLat != null && originLng != null) {
      params['origin'] = '$originLat,$originLng';
    }
    if (waypoints.isNotEmpty) {
      params['waypoints'] =
          waypoints.map((w) => '${w.lat},${w.lng}').join('|');
    }
    return Uri.https('www.google.com', '/maps/dir/', params);
  }

  /// Builds an Apple Maps directions URL for [destLat],[destLng].
  ///
  /// Uses the `maps://` native URI scheme which opens Apple Maps on iOS.
  /// Apple Maps does not support multi-stop routes via URL scheme; only the
  /// final destination is sent.
  ///
  /// The `dirflg=d` parameter requests driving directions.
  static Uri appleMaps({
    required double destLat,
    required double destLng,
  }) {
    // maps://?daddr=lat,lng&dirflg=d
    return Uri(
      scheme: 'maps',
      queryParameters: {
        'daddr': '$destLat,$destLng',
        'dirflg': 'd',
      },
    );
  }

  /// Builds a generic `geo:` URI for destination-only navigation.
  ///
  /// The `geo:` scheme is handled by many Android navigation apps (Google
  /// Maps, OsmAnd, Maps.me, etc.) and triggers the system chooser.
  static Uri geoUri({
    required double destLat,
    required double destLng,
  }) {
    return Uri.parse('geo:$destLat,$destLng?q=$destLat,$destLng');
  }
}

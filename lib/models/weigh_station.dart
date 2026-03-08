import 'dart:math' as math;

/// Operational status of a weigh station as provided by a status provider.
enum WeighStationStatus {
  /// Station is open and actively inspecting vehicles.
  open,

  /// Station is closed; drivers may pass without stopping.
  closed,

  /// Station is monitored / porta-scales deployed; proceed with caution.
  monitored,

  /// Status is unknown or no real-time data is available.
  unknown,
}

/// A roadside weigh station / DOT enforcement checkpoint.
///
/// Instances are typically built by [WeighStationService] from OpenStreetMap
/// data or from static/mocked demo data when no live feed is configured.
/// The [status] field is populated by a [WeighStationStatusProvider].
class WeighStation {
  const WeighStation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    this.status = WeighStationStatus.unknown,
    this.highway,
    this.stateOrProvince,
    this.direction,
    this.description,
  });

  /// Stable unique identifier (derived from OSM element id or a UUID).
  final String id;

  /// Display name (from OSM `name`, `operator`, or a default label).
  final String name;

  /// WGS-84 latitude.
  final double lat;

  /// WGS-84 longitude.
  final double lng;

  /// Operational status supplied by the status provider.
  final WeighStationStatus status;

  /// Highway / road this station is associated with (e.g. `"I-80"`).
  final String? highway;

  /// US state or Canadian province abbreviation (e.g. `"CA"`, `"ON"`).
  final String? stateOrProvince;

  /// Direction of travel this station serves (e.g. `"Eastbound"`).
  final String? direction;

  /// Additional descriptive text (e.g. source notes for demo data).
  final String? description;

  /// Returns a copy of this station with [status] replaced.
  WeighStation copyWith({WeighStationStatus? status}) {
    return WeighStation(
      id: id,
      name: name,
      lat: lat,
      lng: lng,
      status: status ?? this.status,
      highway: highway,
      stateOrProvince: stateOrProvince,
      direction: direction,
      description: description,
    );
  }

  /// Straight-line distance in metres from this station to ([centerLat],
  /// [centerLng]) using the Haversine formula.
  double distanceFromMeters(double centerLat, double centerLng) {
    const r = 6371000.0;
    final phi1 = lat * math.pi / 180;
    final phi2 = centerLat * math.pi / 180;
    final dPhi = (centerLat - lat) * math.pi / 180;
    final dLambda = (centerLng - lng) * math.pi / 180;
    final a = _sq(math.sin(dPhi / 2)) +
        math.cos(phi1) * math.cos(phi2) * _sq(math.sin(dLambda / 2));
    return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeighStation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() =>
      'WeighStation(id=$id, name=$name, status=${status.name}, '
      'lat=$lat, lng=$lng)';

  static double _sq(double x) => x * x;
}

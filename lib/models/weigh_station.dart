import 'dart:math' as math;

// =============================================================================
// WeighStation
// =============================================================================

/// Operational status of a weigh / inspection station.
///
/// - [open]     – the station is actively enforcing (trucks must stop).
/// - [closed]   – the station bypass lanes are open (trucks may pass).
/// - [unknown]  – no real-time status information is available.
enum WeighStationStatus {
  open,
  closed,
  unknown,
}

/// A single weigh / commercial-vehicle inspection station.
///
/// Weigh stations are staffed facilities where commercial vehicles are required
/// to stop for weight checks and safety inspections.  The [status] field
/// reflects whether the station is currently open (enforcing) or closed
/// (bypass).  When a real-time provider is unavailable the status defaults to
/// [WeighStationStatus.unknown].
class WeighStation {
  const WeighStation({
    required this.id,
    required this.name,
    required this.lat,
    required this.lng,
    required this.country,
    this.stateOrProvince,
    this.highway,
    this.direction,
    this.facilities,
    this.hours,
    this.status = WeighStationStatus.unknown,
    this.statusUpdatedAt,
    this.source,
  });

  /// Unique identifier (provider-scoped, e.g. `'us_ca_1'`).
  final String id;

  /// Human-readable station name.
  final String name;

  final double lat;
  final double lng;

  /// ISO 3166-1 alpha-2 country code (`'US'` or `'CA'`).
  final String country;

  /// USPS / Canada Post two-letter state or province code, e.g. `'CA'`, `'ON'`.
  final String? stateOrProvince;

  /// Highway or route designation where the station is located (e.g. `'I-5'`).
  final String? highway;

  /// Travel direction served by this station (e.g. `'Northbound'`).
  final String? direction;

  /// Comma-separated list of available facilities (e.g. `'Scales, Inspection'`).
  final String? facilities;

  /// Operating hours description (e.g. `'24/7'` or `'Mon–Fri 06:00–18:00'`).
  final String? hours;

  /// Real-time (or last-known) operational status.
  ///
  /// Defaults to [WeighStationStatus.unknown] when no status provider is
  /// configured.
  final WeighStationStatus status;

  /// Timestamp of the most recent status update from the provider, or `null`
  /// when status has never been updated.
  final DateTime? statusUpdatedAt;

  /// Name of the data provider (e.g. `'Static baseline'`, `'NORPASS'`).
  final String? source;

  // ---------------------------------------------------------------------------
  // Derived helpers
  // ---------------------------------------------------------------------------

  /// Haversine distance (metres) from this station to the given coordinates.
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

  /// Human-readable status label.
  String get statusLabel {
    switch (status) {
      case WeighStationStatus.open:
        return 'Open';
      case WeighStationStatus.closed:
        return 'Closed';
      case WeighStationStatus.unknown:
        return 'Unknown';
    }
  }

  static double _toRad(double degrees) => degrees * math.pi / 180.0;

  @override
  String toString() =>
      'WeighStation(id: $id, name: $name, country: $country, '
      'state: $stateOrProvince, lat: $lat, lng: $lng, status: $status)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WeighStation &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

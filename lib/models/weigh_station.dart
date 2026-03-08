import 'dart:math' as math;
import 'package:flutter/material.dart' show Color, Colors;

// =============================================================================
// WeighStation
// =============================================================================

/// Freshness window in minutes.  If the most-recent crowdsourced report is
/// older than this threshold the displayed status reverts to "Stale/Unknown".
const int kWeighStationFreshnessMinutes = 60;

/// Operational status of a weigh / inspection station.
///
/// - [openBypass]       – Station is staffed but trucks are cleared to bypass.
/// - [openGoingThrough] – Station is open and trucks must stop / pull through.
/// - [monitoring]       – Station is actively watching (enforcement uncertain).
/// - [closed]           – Station is closed / no enforcement.
/// - [unknown]          – No recent crowdsourced report available (or stale).
enum WeighStationStatus {
  /// Green – trucks are bypassing (PrePass / transponder cleared).
  openBypass,

  /// Green – trucks must pull through for inspection.
  openGoingThrough,

  /// Yellow – officers are present but enforcement status unclear.
  monitoring,

  /// Red – station is closed; trucks may pass freely.
  closed,

  /// Grey – no recent crowdsourced data (or data is stale).
  unknown,
}

/// Serialisation helpers for [WeighStationStatus].
extension WeighStationStatusX on WeighStationStatus {
  /// Returns the canonical string stored in Firestore.
  String get firestoreValue {
    switch (this) {
      case WeighStationStatus.openBypass:
        return 'open_bypass';
      case WeighStationStatus.openGoingThrough:
        return 'open_going_through';
      case WeighStationStatus.monitoring:
        return 'monitoring';
      case WeighStationStatus.closed:
        return 'closed';
      case WeighStationStatus.unknown:
        return 'unknown';
    }
  }

  /// Human-readable label shown in UI.
  String get label {
    switch (this) {
      case WeighStationStatus.openBypass:
        return 'Open (Bypass)';
      case WeighStationStatus.openGoingThrough:
        return 'Open (Going Through)';
      case WeighStationStatus.monitoring:
        return 'Monitoring';
      case WeighStationStatus.closed:
        return 'Closed';
      case WeighStationStatus.unknown:
        return 'Unknown';
    }
  }

  /// Map status → display color per requirements spec.
  Color get color {
    switch (this) {
      case WeighStationStatus.openBypass:
      case WeighStationStatus.openGoingThrough:
        return Colors.green;
      case WeighStationStatus.monitoring:
        return Colors.orange;
      case WeighStationStatus.closed:
        return Colors.red;
      case WeighStationStatus.unknown:
        return Colors.grey;
    }
  }

  /// Returns true for statuses that indicate active enforcement.
  bool get isActive =>
      this == WeighStationStatus.openBypass ||
      this == WeighStationStatus.openGoingThrough ||
      this == WeighStationStatus.monitoring;
}

/// Deserialise a Firestore string value to [WeighStationStatus].
WeighStationStatus weighStationStatusFromFirestore(String? value) {
  switch (value) {
    case 'open_bypass':
      return WeighStationStatus.openBypass;
    case 'open_going_through':
      return WeighStationStatus.openGoingThrough;
    case 'monitoring':
      return WeighStationStatus.monitoring;
    case 'closed':
      return WeighStationStatus.closed;
    default:
      return WeighStationStatus.unknown;
  }
}

/// A single weigh / commercial-vehicle inspection station.
///
/// Weigh stations are staffed facilities where commercial vehicles are required
/// to stop for weight checks and safety inspections.  The [status] field
/// reflects whether the station is currently open (enforcing) or closed
/// (bypass).  When no recent crowdsourced report is available the status
/// defaults to [WeighStationStatus.unknown].
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
  /// Defaults to [WeighStationStatus.unknown] when no crowdsourced report
  /// is available or when the most-recent report is older than
  /// [kWeighStationFreshnessMinutes] minutes.
  final WeighStationStatus status;

  /// Timestamp of the most recent crowdsourced status report, or `null`
  /// when no report has ever been submitted.
  final DateTime? statusUpdatedAt;

  /// Name of the data provider (e.g. `'Static baseline'`, `'Firestore'`).
  final String? source;

  // ---------------------------------------------------------------------------
  // Derived helpers
  // ---------------------------------------------------------------------------

  /// Whether [statusUpdatedAt] is older than [kWeighStationFreshnessMinutes]
  /// minutes (or has never been set).  When `true` the status should be
  /// displayed as stale/unknown.
  bool get isStale {
    if (statusUpdatedAt == null) return true;
    return DateTime.now().difference(statusUpdatedAt!).inMinutes >=
        kWeighStationFreshnessMinutes;
  }

  /// The effective status after applying freshness rules.  Returns
  /// [WeighStationStatus.unknown] when the last report is stale.
  WeighStationStatus get effectiveStatus =>
      isStale ? WeighStationStatus.unknown : status;

  /// Human-readable status label (accounts for freshness).
  String get statusLabel => effectiveStatus.label;

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

  /// Returns a copy of this station with the given fields overridden.
  WeighStation copyWith({
    WeighStationStatus? status,
    DateTime? statusUpdatedAt,
    String? source,
  }) {
    return WeighStation(
      id: id,
      name: name,
      lat: lat,
      lng: lng,
      country: country,
      stateOrProvince: stateOrProvince,
      highway: highway,
      direction: direction,
      facilities: facilities,
      hours: hours,
      status: status ?? this.status,
      statusUpdatedAt: statusUpdatedAt ?? this.statusUpdatedAt,
      source: source ?? this.source,
    );
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

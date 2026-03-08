import '../models/weigh_station.dart';

/// Abstract interface for a component that can supply real-time (or static)
/// operational status for a weigh station identified by its [stationId].
///
/// Implement this class to wire in a live data source (e.g. a DOT REST API,
/// a Firestore collection, or a WebSocket feed).  Register the concrete
/// implementation with [WeighStationService] at app startup.
///
/// If no provider is configured, [WeighStationService] falls back to the
/// [DefaultWeighStationStatusProvider], which returns
/// [WeighStationStatus.unknown] unless a status is explicitly present in the
/// optional static override map.
abstract class WeighStationStatusProvider {
  /// Returns the current operational status of the station identified by
  /// [stationId], or [WeighStationStatus.unknown] when no data is available.
  ///
  /// Implementations should be fast (cached / synchronous or near-instant).
  /// Errors should be caught internally and reflected as
  /// [WeighStationStatus.unknown] rather than propagated.
  WeighStationStatus statusFor(String stationId);
}

/// Default provider shipped with the app.
///
/// Returns [WeighStationStatus.unknown] for all stations unless an explicit
/// override is present in [overrides].  This lets the architecture remain in
/// place for a live provider to be dropped in later without touching any
/// other code.
///
/// Usage:
/// ```dart
/// // Static demo override for a specific station:
/// final provider = DefaultWeighStationStatusProvider(overrides: {
///   'ws_demo_us_ca_1': WeighStationStatus.open,
/// });
/// ```
class DefaultWeighStationStatusProvider implements WeighStationStatusProvider {
  const DefaultWeighStationStatusProvider({this.overrides = const {}});

  /// Optional static override map, keyed by station id.
  final Map<String, WeighStationStatus> overrides;

  @override
  WeighStationStatus statusFor(String stationId) =>
      overrides[stationId] ?? WeighStationStatus.unknown;
}

/// Computes ETA and trip duration for commercial truck navigation.
///
/// This is a pure-Dart, static-only utility class with no platform
/// dependencies, making it fully unit-testable without mocking.
class TripEtaService {
  const TripEtaService._();

  /// Computes the estimated time of arrival (UTC) by adding
  /// [remainingSeconds] to [now].
  static DateTime calculateEta(DateTime now, int remainingSeconds) {
    return now.toUtc().add(Duration(seconds: remainingSeconds));
  }

  /// Formats a duration in seconds as a human-readable string.
  ///
  /// Examples: `"3h 45m"`, `"22m"`, `"0 min"`.
  static String formatDuration(int seconds) {
    if (seconds <= 0) return '0 min';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    return '${minutes}m';
  }

  /// Formats [dt] as a 12-hour wall-clock string (e.g., `"3:22 PM"`).
  ///
  /// [dt] is interpreted as-is (no timezone conversion is applied here;
  /// callers are responsible for passing the correctly-offset [DateTime]).
  static String formatWallClock(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour < 12 ? 'AM' : 'PM';
    return '$hour:$minute $amPm';
  }

  /// Estimates travel time in seconds for [distanceMeters] at [truckLimitMph].
  ///
  /// Returns `0` when either argument is non-positive.
  static int estimateSecondsForDistance(
    double distanceMeters,
    double truckLimitMph,
  ) {
    if (truckLimitMph <= 0 || distanceMeters <= 0) return 0;
    final speedMs = truckLimitMph * 0.44704; // mph → m/s
    return (distanceMeters / speedMs).round();
  }
}

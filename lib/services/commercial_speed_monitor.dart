/// Callback fired when the driver's speed exceeds the commercial max speed
/// while navigating.
typedef CommercialOverspeedCallback = void Function(double speedMs, double maxSpeedMs);

/// Monitors driver speed against a configurable commercial/truck max speed.
///
/// Unlike [SpeedMonitor] (which tracks road-limit state transitions),
/// [CommercialSpeedMonitor] implements:
/// - Navigation-only enforcement: alerts only fire when [isNavigating] is `true`.
/// - Cooldown: once an alert fires it won't fire again until either
///   [cooldownSeconds] have elapsed **or** the speed drops below the threshold
///   and then rises above it again (whichever comes first that re-crosses).
///
/// Usage:
/// ```dart
/// final monitor = CommercialSpeedMonitor();
/// monitor.onOverspeed = (speedMs, maxMs) { … };
/// monitor.check(30.0, isNavigating: true);  // 30 m/s ≈ 67 mph – may fire
/// ```
class CommercialSpeedMonitor {
  /// Seconds between repeated alerts while the driver stays over the threshold.
  static const int defaultCooldownSeconds = 60;

  /// Seconds between repeated overspeed alerts.
  final int cooldownSeconds;

  /// Fired when the driver is over the commercial max speed while navigating.
  CommercialOverspeedCallback? onOverspeed;

  DateTime? _lastAlertTime;
  bool _wasOverspeed = false;

  CommercialSpeedMonitor({this.cooldownSeconds = defaultCooldownSeconds});

  /// Feed [speedMs] (metres per second) into the monitor.
  ///
  /// [maxSpeedMs] is the configured commercial threshold.
  /// [isNavigating] gates whether alerts can fire.
  ///
  /// Cooldown behaviour:
  /// - If speed drops below threshold, the cooldown resets so the next
  ///   crossing will fire immediately.
  /// - While over threshold, repeats at most once per [cooldownSeconds].
  void check(
    double speedMs, {
    required double maxSpeedMs,
    required bool isNavigating,
  }) {
    final isOver = speedMs > maxSpeedMs;

    if (!isOver) {
      // Speed is back within limit – clear overspeed flag so the next
      // crossing fires immediately even if cooldown hasn't expired.
      _wasOverspeed = false;
      return;
    }

    // Speed is over limit. Only alert when navigating.
    if (!isNavigating) return;

    final now = DateTime.now();
    final lastAlert = _lastAlertTime;

    if (!_wasOverspeed) {
      // First crossing – fire immediately.
      _wasOverspeed = true;
      _lastAlertTime = now;
      onOverspeed?.call(speedMs, maxSpeedMs);
      return;
    }

    // Already overspeeding – respect cooldown.
    if (lastAlert == null ||
        now.difference(lastAlert).inSeconds >= cooldownSeconds) {
      _lastAlertTime = now;
      onOverspeed?.call(speedMs, maxSpeedMs);
    }
  }

  /// Reset all internal state (useful for testing or when settings change).
  void reset() {
    _lastAlertTime = null;
    _wasOverspeed = false;
  }
}

/// Possible speed states relative to the posted road speed limit.
enum SpeedAlertState { correct, overSpeed, underSpeed }

/// Callback invoked when the driver's speed state changes.
typedef SpeedStateCallback = void Function(
  SpeedAlertState state,
  double speedMph,
  double limitMph,
);

/// Monitors driver speed vs road speed limit and fires [onStateChange] only
/// when the speed state transitions between [SpeedAlertState] values.
///
/// Usage:
/// ```dart
/// final monitor = SpeedMonitor();
/// monitor.onStateChange = (state, speed, limit) { … };
/// monitor.update(52.0, 55.0); // correct → no event (first call seeds state)
/// monitor.update(60.0, 55.0); // correct → overSpeed: fires callback
/// ```
class SpeedMonitor {
  /// Miles-per-hour margin above the posted limit before overspeeding triggers.
  /// Default: 2 mph.
  static const double defaultOverspeedMarginMph = 2.0;

  /// Default underspeed margin in mph. Override via [underspeedMarginMph].
  static const double defaultUnderspeedMarginMph = 10.0;

  /// Margin above the speed limit before an overspeed alert fires.
  double overspeedMarginMph;

  /// Margin below the speed limit before an underspeed alert fires.
  double underspeedMarginMph;

  /// Fired when the speed state changes (correct ↔ overSpeed ↔ underSpeed).
  SpeedStateCallback? onStateChange;

  SpeedAlertState? _lastState;

  SpeedMonitor({
    this.overspeedMarginMph = defaultOverspeedMarginMph,
    this.underspeedMarginMph = defaultUnderspeedMarginMph,
  });

  /// Feed the current [speedMph] and road [limitMph] into the monitor.
  ///
  /// If the computed [SpeedAlertState] differs from the last known state,
  /// [onStateChange] is called. On the very first call the state is seeded
  /// silently (no callback) so the driver only receives an alert when the
  /// situation *changes*.
  void update(double speedMph, double limitMph) {
    final state = _computeState(speedMph, limitMph);
    if (_lastState == null) {
      _lastState = state;
      return;
    }
    if (state != _lastState) {
      _lastState = state;
      onStateChange?.call(state, speedMph, limitMph);
    }
  }

  /// Reset internal state so the next [update] call seeds the state silently.
  void reset() {
    _lastState = null;
  }

  SpeedAlertState _computeState(double speedMph, double limitMph) {
    if (speedMph > limitMph + overspeedMarginMph) {
      return SpeedAlertState.overSpeed;
    }
    if (speedMph < limitMph - underspeedMarginMph) {
      return SpeedAlertState.underSpeed;
    }
    return SpeedAlertState.correct;
  }
}

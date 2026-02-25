/// Display unit for commercial max-speed configuration.
enum SpeedUnit { mph, kmh }

/// Settings for the commercial/truck max-speed alert feature.
class CommercialSpeedSettings {
  const CommercialSpeedSettings({
    required this.enabled,
    required this.maxSpeedMs,
    required this.unit,
    this.enableStateLimits = true,
  });

  /// Whether commercial overspeed alerts are active.
  final bool enabled;

  /// Maximum allowed truck speed in m/s (canonical internal unit).
  final double maxSpeedMs;

  /// Display unit chosen by the driver.
  final SpeedUnit unit;

  /// Whether to use the state-specific commercial truck speed limit instead of
  /// [maxSpeedMs] when the current US state is known.
  ///
  /// When `true` and a state limit is available, that limit overrides
  /// [maxSpeedMs] for overspeed alerting and is displayed prominently in
  /// navigation.  The driver's manually-configured [maxSpeedMs] is still used
  /// as the effective ceiling whenever no state limit is available.
  final bool enableStateLimits;

  /// Default settings: disabled, 65 mph limit, mph display, state limits on.
  factory CommercialSpeedSettings.defaults() => const CommercialSpeedSettings(
        enabled: false,
        maxSpeedMs: 29.0576, // 65 mph in m/s
        unit: SpeedUnit.mph,
        enableStateLimits: true,
      );

  // ---------------------------------------------------------------------------
  // Unit conversion helpers
  // ---------------------------------------------------------------------------

  /// Convert [mph] to metres per second.
  static double mphToMs(double mph) => mph * 0.44704;

  /// Convert [kmh] to metres per second.
  static double kmhToMs(double kmh) => kmh / 3.6;

  /// Convert [ms] (metres per second) to mph.
  static double msToMph(double ms) => ms / 0.44704;

  /// Convert [ms] (metres per second) to km/h.
  static double msToKmh(double ms) => ms * 3.6;

  /// Return the max speed converted to the display [unit].
  double get maxSpeedDisplay =>
      unit == SpeedUnit.mph ? msToMph(maxSpeedMs) : msToKmh(maxSpeedMs);

  /// Label string for the display [unit].
  String get unitLabel => unit == SpeedUnit.mph ? 'mph' : 'km/h';

  CommercialSpeedSettings copyWith({
    bool? enabled,
    double? maxSpeedMs,
    SpeedUnit? unit,
    bool? enableStateLimits,
  }) =>
      CommercialSpeedSettings(
        enabled: enabled ?? this.enabled,
        maxSpeedMs: maxSpeedMs ?? this.maxSpeedMs,
        unit: unit ?? this.unit,
        enableStateLimits: enableStateLimits ?? this.enableStateLimits,
      );
}

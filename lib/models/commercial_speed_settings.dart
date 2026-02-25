/// Display unit for commercial max-speed configuration.
enum SpeedUnit { mph, kmh }

/// Settings for the commercial/truck max-speed alert feature.
class CommercialSpeedSettings {
  const CommercialSpeedSettings({
    required this.enabled,
    required this.maxSpeedMs,
    required this.unit,
  });

  /// Whether commercial overspeed alerts are active.
  final bool enabled;

  /// Maximum allowed truck speed in m/s (canonical internal unit).
  final double maxSpeedMs;

  /// Display unit chosen by the driver.
  final SpeedUnit unit;

  /// Default settings: disabled, 65 mph limit, mph display.
  factory CommercialSpeedSettings.defaults() => CommercialSpeedSettings(
        enabled: false,
        maxSpeedMs: mphToMs(65.0),
        unit: SpeedUnit.mph,
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
  }) =>
      CommercialSpeedSettings(
        enabled: enabled ?? this.enabled,
        maxSpeedMs: maxSpeedMs ?? this.maxSpeedMs,
        unit: unit ?? this.unit,
      );
}

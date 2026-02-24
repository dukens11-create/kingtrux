/// Units system for displaying truck profile dimensions.
enum TruckUnit { metric, imperial }

/// Truck profile configuration for routing
class TruckProfile {
  /// Height in meters
  final double heightMeters;

  /// Width in meters
  final double widthMeters;

  /// Length in meters
  final double lengthMeters;

  /// Weight in metric tons
  final double weightTons;

  /// Number of axles
  final int axles;

  /// Whether carrying hazardous materials
  final bool hazmat;

  const TruckProfile({
    required this.heightMeters,
    required this.widthMeters,
    required this.lengthMeters,
    required this.weightTons,
    required this.axles,
    required this.hazmat,
  });

  /// Default truck profile: 4.10m H × 2.60m W × 21.0m L, 36 tons, 5 axles
  factory TruckProfile.defaultProfile() {
    return const TruckProfile(
      heightMeters: 4.10,
      widthMeters: 2.60,
      lengthMeters: 21.0,
      weightTons: 36.0,
      axles: 5,
      hazmat: false,
    );
  }

  /// Deserialize from a JSON map (values stored in metric units).
  factory TruckProfile.fromJson(Map<String, dynamic> json) {
    return TruckProfile(
      heightMeters: (json['heightMeters'] as num).toDouble(),
      widthMeters: (json['widthMeters'] as num).toDouble(),
      lengthMeters: (json['lengthMeters'] as num).toDouble(),
      weightTons: (json['weightTons'] as num).toDouble(),
      axles: json['axles'] as int,
      hazmat: json['hazmat'] as bool,
    );
  }

  /// Serialize to a JSON map (values stored in metric units).
  Map<String, dynamic> toJson() => {
        'heightMeters': heightMeters,
        'widthMeters': widthMeters,
        'lengthMeters': lengthMeters,
        'weightTons': weightTons,
        'axles': axles,
        'hazmat': hazmat,
      };

  /// Create a copy with updated values
  TruckProfile copyWith({
    double? heightMeters,
    double? widthMeters,
    double? lengthMeters,
    double? weightTons,
    int? axles,
    bool? hazmat,
  }) {
    return TruckProfile(
      heightMeters: heightMeters ?? this.heightMeters,
      widthMeters: widthMeters ?? this.widthMeters,
      lengthMeters: lengthMeters ?? this.lengthMeters,
      weightTons: weightTons ?? this.weightTons,
      axles: axles ?? this.axles,
      hazmat: hazmat ?? this.hazmat,
    );
  }

  // ---------------------------------------------------------------------------
  // Unit conversion helpers (metric ↔ imperial)
  // ---------------------------------------------------------------------------

  /// Converts meters to feet.
  static double metersToFeet(double meters) => meters * 3.28084;

  /// Converts feet to meters.
  static double feetToMeters(double feet) => feet / 3.28084;

  /// Converts metric tons to US short tons (1 metric ton ≈ 1.10231 short tons).
  static double metricTonsToShortTons(double mt) => mt * 1.10231;

  /// Converts US short tons to metric tons.
  static double shortTonsToMetricTons(double st) => st / 1.10231;

  /// Validate the profile and return a list of human-readable error messages.
  ///
  /// Returns an empty list when the profile is valid and safe to use for
  /// routing. Each string in the returned list describes one validation
  /// failure so the UI can display them individually.
  List<String> validate() {
    final errors = <String>[];
    if (heightMeters <= 0) {
      errors.add('Height must be greater than 0 m.');
    }
    if (widthMeters <= 0) {
      errors.add('Width must be greater than 0 m.');
    }
    if (lengthMeters <= 0) {
      errors.add('Length must be greater than 0 m.');
    }
    if (weightTons <= 0) {
      errors.add('Gross weight must be greater than 0 t.');
    }
    if (axles < 2) {
      errors.add('Axle count must be at least 2.');
    }
    return errors;
  }

  /// Whether this profile passes [validate] with no errors.
  bool get isValid => validate().isEmpty;

  /// Returns a human-readable summary of the profile.
  String summary({TruckUnit unit = TruckUnit.metric}) {
    if (unit == TruckUnit.imperial) {
      final hFt = metersToFeet(heightMeters).toStringAsFixed(1);
      final wFt = metersToFeet(widthMeters).toStringAsFixed(1);
      final lFt = metersToFeet(lengthMeters).toStringAsFixed(1);
      final wSt = metricTonsToShortTons(weightTons).toStringAsFixed(1);
      return '${hFt}ft H · ${wFt}ft W · ${lFt}ft L · ${wSt}st · $axles axles'
          '${hazmat ? ' · HAZMAT' : ''}';
    }
    final h = heightMeters.toStringAsFixed(2);
    final w = widthMeters.toStringAsFixed(2);
    final l = lengthMeters.toStringAsFixed(1);
    final wt = weightTons.toStringAsFixed(1);
    return '${h}m H · ${w}m W · ${l}m L · ${wt}t · $axles axles'
        '${hazmat ? ' · HAZMAT' : ''}';
  }
}

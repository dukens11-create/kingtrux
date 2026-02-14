/// Truck profile configuration for routing
class TruckProfile {
  /// Height in meters
  final double heightMeters;
  
  /// Width in meters
  final double widthMeters;
  
  /// Length in meters
  final double lengthMeters;
  
  /// Weight in tons
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
}

/// Truck profile model with dimensions and restrictions
class TruckProfile {
  final double heightMeters;
  final double widthMeters;
  final double lengthMeters;
  final double weightTons;
  final int axles;
  final bool hazmat;

  const TruckProfile({
    required this.heightMeters,
    required this.widthMeters,
    required this.lengthMeters,
    required this.weightTons,
    required this.axles,
    required this.hazmat,
  });

  /// Default truck profile
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

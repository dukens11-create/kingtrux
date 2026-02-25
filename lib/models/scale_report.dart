/// Status of a weigh scale as reported by drivers.
enum ScaleStatus { open, closed, monitoring }

/// A driver-submitted status report for a weigh scale POI.
class ScaleReport {
  const ScaleReport({
    required this.poiId,
    required this.poiName,
    required this.status,
    required this.lat,
    required this.lng,
    required this.reportedAt,
  });

  /// The POI identifier this report is associated with.
  final String poiId;

  /// Human-readable name of the scale.
  final String poiName;

  /// Driver-reported operational status.
  final ScaleStatus status;

  /// Latitude of the scale.
  final double lat;

  /// Longitude of the scale.
  final double lng;

  /// When the driver submitted this report.
  final DateTime reportedAt;

  /// Serialize to a JSON-compatible map.
  Map<String, dynamic> toJson() => {
        'poiId': poiId,
        'poiName': poiName,
        'status': status.name,
        'lat': lat,
        'lng': lng,
        'reportedAt': reportedAt.toIso8601String(),
      };

  /// Deserialize from a JSON-compatible map.
  factory ScaleReport.fromJson(Map<String, dynamic> json) => ScaleReport(
        poiId: json['poiId'] as String,
        poiName: json['poiName'] as String,
        status: ScaleStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => ScaleStatus.monitoring,
        ),
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        reportedAt: DateTime.parse(json['reportedAt'] as String),
      );
}

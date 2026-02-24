/// Severity level of a navigation or system alert.
enum AlertSeverity { info, warning, critical }

/// Category of a navigation or system alert.
enum AlertType {
  reroute,
  offRoute,
  navigationStarted,
  navigationStopped,
  lowGpsAccuracy,
  locationDisabled,
  generic,
}

/// A discrete alert that can be displayed to the driver and optionally spoken.
class AlertEvent {
  const AlertEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    this.severity = AlertSeverity.info,
    required this.timestamp,
    this.speakable = false,
  });

  final String id;
  final AlertType type;
  final String title;
  final String message;
  final AlertSeverity severity;
  final DateTime timestamp;

  /// Whether the alert should be spoken aloud when voice guidance is enabled.
  final bool speakable;
}

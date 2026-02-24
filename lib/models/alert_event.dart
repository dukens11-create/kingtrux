/// Categories of in-app alert.
enum AlertType {
  navigationStarted,
  navigationStopped,
  reroute,
  offRoute,
  locationDisabled,
  lowGpsAccuracy,
}

/// Visual / audio severity of an alert.
enum AlertSeverity { info, warning, error }

/// An event displayed as a banner/toast on the main map screen.
class AlertEvent {
  /// Alert category.
  final AlertType type;

  /// Visual severity level.
  final AlertSeverity severity;

  /// Short headline shown in the banner.
  final String title;

  /// Optional detail text.
  final String message;

  /// When the alert was created.
  final DateTime timestamp;

  /// Whether TTS should read this alert aloud.
  final bool speakable;

  const AlertEvent({
    required this.type,
    required this.severity,
    required this.title,
    required this.message,
    required this.timestamp,
    this.speakable = false,
  });
}

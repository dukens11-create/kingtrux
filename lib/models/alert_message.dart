/// Severity level for an [AlertMessage].
enum AlertSeverity {
  /// Informational — shown in a neutral colour.
  info,

  /// Warning — highlighted in amber to draw attention.
  warning,

  /// Error / critical — shown in the error colour.
  error,
}

/// A transient alert to be displayed to the driver (and optionally spoken).
class AlertMessage {
  /// Short human-readable description of the alert.
  final String message;

  /// Severity level that controls the visual appearance of the banner.
  final AlertSeverity severity;

  const AlertMessage({
    required this.message,
    this.severity = AlertSeverity.info,
  });
}

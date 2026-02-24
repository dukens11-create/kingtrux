import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/alert_message.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Displays the oldest pending [AlertMessage] from [AppState.alertQueue] as a
/// dismissible banner.  Place this widget in an overlay or [Stack] at the top
/// of a screen so it remains visible without blocking the map or maneuver list.
///
/// The banner auto-dismisses after [autoDismissDuration] if the user does not
/// tap it. Set to [Duration.zero] to disable auto-dismiss.
class AlertBanner extends StatefulWidget {
  const AlertBanner({
    super.key,
    this.autoDismissDuration = const Duration(seconds: 5),
  });

  /// How long the banner stays visible before auto-dismissing.
  final Duration autoDismissDuration;

  @override
  State<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner> {
  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.alertQueue.isEmpty) return const SizedBox.shrink();

        final alert = state.alertQueue.first;

        return _AutoDismissAlert(
          key: ValueKey(alert),
          alert: alert,
          autoDismissDuration: widget.autoDismissDuration,
          onDismiss: state.dismissAlert,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Auto-dismissing inner widget
// ---------------------------------------------------------------------------

class _AutoDismissAlert extends StatefulWidget {
  const _AutoDismissAlert({
    super.key,
    required this.alert,
    required this.autoDismissDuration,
    required this.onDismiss,
  });

  final AlertMessage alert;
  final Duration autoDismissDuration;
  final VoidCallback onDismiss;

  @override
  State<_AutoDismissAlert> createState() => _AutoDismissAlertState();
}

class _AutoDismissAlertState extends State<_AutoDismissAlert> {
  @override
  void initState() {
    super.initState();
    if (widget.autoDismissDuration > Duration.zero) {
      Future.delayed(widget.autoDismissDuration, () {
        if (mounted) widget.onDismiss();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final (bgColor, fgColor, icon) = _palette(widget.alert.severity, cs);

    return GestureDetector(
      onTap: widget.onDismiss,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceSM,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceSM,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        ),
        child: Row(
          children: [
            Icon(icon, color: fgColor, size: 20),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: Text(
                widget.alert.message,
                style: tt.bodyMedium?.copyWith(color: fgColor),
              ),
            ),
            Icon(Icons.close_rounded, color: fgColor, size: 18),
          ],
        ),
      ),
    );
  }

  (Color, Color, IconData) _palette(AlertSeverity severity, ColorScheme cs) {
    switch (severity) {
      case AlertSeverity.error:
        return (cs.errorContainer, cs.onErrorContainer, Icons.error_rounded);
      case AlertSeverity.warning:
        return (
          const Color(0xFFFFF3E0),
          const Color(0xFFE65100),
          Icons.warning_amber_rounded,
        );
      case AlertSeverity.info:
        return (
          cs.primaryContainer,
          cs.onPrimaryContainer,
          Icons.info_rounded,
        );
    }
  }
}

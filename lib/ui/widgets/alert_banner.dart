import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/alert_event.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Displays the front alert from the [AppState] alert queue as a dismissible
/// banner overlay.  Renders nothing when there is no current alert.
class AlertBanner extends StatelessWidget {
  const AlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final alert = state.currentAlert;
        if (alert == null) return const SizedBox.shrink();
        return _AlertCard(
          alert: alert,
          onDismiss: state.dismissCurrentAlert,
        );
      },
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({required this.alert, required this.onDismiss});

  final AlertEvent alert;
  final VoidCallback onDismiss;

  Color _bgColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (alert.severity) {
      case AlertSeverity.error:
        return cs.errorContainer;
      case AlertSeverity.warning:
        return cs.tertiaryContainer;
      case AlertSeverity.info:
        return cs.primaryContainer;
    }
  }

  Color _fgColor(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (alert.severity) {
      case AlertSeverity.error:
        return cs.onErrorContainer;
      case AlertSeverity.warning:
        return cs.onTertiaryContainer;
      case AlertSeverity.info:
        return cs.onPrimaryContainer;
    }
  }

  IconData _icon() {
    switch (alert.severity) {
      case AlertSeverity.error:
        return Icons.error_rounded;
      case AlertSeverity.warning:
        return Icons.warning_amber_rounded;
      case AlertSeverity.info:
        return Icons.info_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _bgColor(context);
    final fg = _fgColor(context);
    return Material(
      color: Colors.transparent,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceXS,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              boxShadow: const [
                BoxShadow(
                  blurRadius: 8,
                  offset: Offset(0, 2),
                  color: Color(0x22000000),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceSM,
              ),
              child: Row(
                children: [
                  Icon(_icon(), color: fg, size: 22),
                  const SizedBox(width: AppTheme.spaceSM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          alert.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(color: fg),
                        ),
                        if (alert.message.isNotEmpty)
                          Text(
                            alert.message,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: fg),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: fg, size: 20),
                    tooltip: 'Dismiss',
                    visualDensity: VisualDensity.compact,
                    onPressed: onDismiss,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

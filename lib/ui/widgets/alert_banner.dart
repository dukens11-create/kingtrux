import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/alert_event.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Overlay banner that displays the current [AlertEvent] from [AppState].
///
/// Renders nothing when there are no pending alerts. The user can dismiss
/// the banner by tapping the close button, which calls
/// [AppState.dismissCurrentAlert].
class AlertBanner extends StatelessWidget {
  const AlertBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final alert = state.currentAlert;
        if (alert == null) return const SizedBox.shrink();
        return _AlertBannerContent(alert: alert, state: state);
      },
    );
  }
}

class _AlertBannerContent extends StatelessWidget {
  const _AlertBannerContent({required this.alert, required this.state});

  final AlertEvent alert;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final Color bgColor;
    final Color fgColor;
    final IconData leadingIcon;

    switch (alert.severity) {
      case AlertSeverity.critical:
        bgColor = cs.error;
        fgColor = cs.onError;
        leadingIcon = Icons.error_rounded;
      case AlertSeverity.warning:
        bgColor = cs.tertiary;
        fgColor = cs.onTertiary;
        leadingIcon = Icons.warning_amber_rounded;
      case AlertSeverity.success:
        bgColor = const Color(0xFF2E7D32); // Material green-800
        fgColor = Colors.white;
        leadingIcon = Icons.check_circle_outline_rounded;
      case AlertSeverity.info:
        bgColor = cs.primaryContainer;
        fgColor = cs.onPrimaryContainer;
        leadingIcon = Icons.info_outline_rounded;
    }

    return Material(
      color: Colors.transparent,
      child: Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceXS,
        ),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 8,
              offset: const Offset(0, 2),
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
              Icon(leadingIcon, color: fgColor, size: 22),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      alert.title,
                      style: tt.labelLarge?.copyWith(color: fgColor),
                    ),
                    if (alert.message.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        alert.message,
                        style: tt.bodySmall?.copyWith(
                          color: fgColor.withAlpha(210),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close_rounded, color: fgColor, size: 20),
                tooltip: 'Dismiss',
                onPressed: state.dismissCurrentAlert,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(
                  minWidth: 32,
                  minHeight: 32,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

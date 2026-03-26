import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/scale_report.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import 'weigh_station_sign.dart';

/// Persistent map overlay that displays the nearest police weight station
/// to the driver's current GPS location, in any direction.
///
/// The card shows the station name, distance in miles, and the latest
/// community-reported status (Open / Monitoring / Closed).  When no station
/// is found nearby a "No weight station found" message is shown.
///
/// The widget renders only when a GPS fix is available.
class ClosestScaleCard extends StatelessWidget {
  const ClosestScaleCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (state.myLat == null) return const SizedBox.shrink();
        return _ClosestScaleCardContent(state: state);
      },
    );
  }
}

class _ClosestScaleCardContent extends StatelessWidget {
  const _ClosestScaleCardContent({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final scale = state.closestScalePoi;
    final distMeters = state.closestScaleDistanceMeters;
    final report = scale != null ? state.scaleReportFor(scale.id) : null;
    final cs = Theme.of(context).colorScheme;

    final statusColor = report != null ? _statusColor(report.status) : null;
    final statusIcon = report != null ? _statusIcon(report.status) : null;

    return Card(
      elevation: AppTheme.elevationCard,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSM,
          vertical: 4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── WeighStationSign with optional status ring ───────────────
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                WeighStationSign(showLabel: false, size: 22),
                if (statusIcon != null)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: cs.surface, width: 1),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: AppTheme.spaceXS),
            // ── Text ──────────────────────────────────────────────────────
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (scale != null && distMeters != null) ...[
                  Text(
                    scale.name,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatDistance(distMeters),
                        style: TextStyle(
                          fontSize: 9,
                          color: cs.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (report != null) ...[
                        const SizedBox(width: 4),
                        Icon(statusIcon, size: 9, color: statusColor),
                        const SizedBox(width: 2),
                        Text(
                          '${_statusLabel(report.status)} · ${_timeAgo(report.reportedAt)}',
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ],
                  ),
                ] else ...[
                  Text(
                    'No weight station found',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  static const double _metersPerMile = 1609.344;

  String _formatDistance(double meters) {
    final miles = meters / _metersPerMile;
    if (miles >= 10) {
      return '${miles.toStringAsFixed(0)} mi';
    }
    return '${miles.toStringAsFixed(1)} mi';
  }

  static Color _statusColor(ScaleStatus status) {
    switch (status) {
      case ScaleStatus.open:
        return Colors.green.shade600;
      case ScaleStatus.monitoring:
        return Colors.orange.shade700;
      case ScaleStatus.closed:
        return Colors.red.shade600;
    }
  }

  static IconData _statusIcon(ScaleStatus status) {
    switch (status) {
      case ScaleStatus.open:
        return Icons.check_circle_rounded;
      case ScaleStatus.monitoring:
        return Icons.visibility_rounded;
      case ScaleStatus.closed:
        return Icons.cancel_rounded;
    }
  }

  static String _statusLabel(ScaleStatus status) {
    switch (status) {
      case ScaleStatus.open:
        return 'Open';
      case ScaleStatus.monitoring:
        return 'Monitoring';
      case ScaleStatus.closed:
        return 'Closed';
    }
  }

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}


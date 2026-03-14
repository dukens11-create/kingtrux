import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Persistent map overlay that displays the nearest weigh station ahead
/// within 100 miles.
///
/// The card shows the station name and distance in miles.  It stays on screen
/// until the driver passes the station, at which point it updates to the next
/// closest-ahead station.  When no station is found within the search radius,
/// a "No weigh station within 100 mi" message is shown instead.
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

    return Card(
      elevation: AppTheme.elevationCard,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceXS + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Scale icon ────────────────────────────────────────────────
            Icon(
              Icons.scale,
              size: 22,
              color: scale != null
                  ? Colors.indigo.shade700
                  : Colors.grey.shade500,
            ),
            const SizedBox(width: AppTheme.spaceXS + 2),
            // ── Text ──────────────────────────────────────────────────────
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WEIGH STATION',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: Colors.grey.shade600,
                      ),
                ),
                if (scale != null && distMeters != null) ...[
                  Text(
                    scale.name,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  Text(
                    _formatDistance(distMeters),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.indigo.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ] else ...[
                  Text(
                    'No weigh station within 100 mi',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
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
}

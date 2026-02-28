import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/navigation_maneuver.dart';
import '../theme/app_theme.dart';

/// A compact top banner shown on the map screen when a route is active.
///
/// Displays the first maneuver instruction with road name/number (e.g.,
/// "I-95 / Main Street") and distance, inviting the driver to start
/// full turn-by-turn navigation by tapping.
class RouteGuidanceBanner extends StatelessWidget {
  const RouteGuidanceBanner({
    super.key,
    required this.maneuver,
    required this.onTap,
  });

  final NavigationManeuver maneuver;

  /// Called when the user taps the banner (e.g., to start navigation).
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Build road label: "I-95 / Main Street" or just whichever is available.
    final roadParts = <String>[
      if (maneuver.routeNumber != null) maneuver.routeNumber!,
      if (maneuver.roadName != null) maneuver.roadName!,
    ];
    final roadLabel = roadParts.join(' / ');

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Card(
        color: cs.primaryContainer,
        elevation: AppTheme.elevationSheet,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceSM,
          ),
          child: Row(
            children: [
              Icon(
                Icons.navigation_rounded,
                size: 20,
                color: cs.primary,
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      maneuver.instruction.isEmpty
                          ? maneuver.action
                          : maneuver.instruction,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (roadLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        roadLabel,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onPrimaryContainer.withAlpha(204),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              if (maneuver.distanceMeters > 0) ...[
                const SizedBox(width: AppTheme.spaceSM),
                Text(
                  _formatDistance(maneuver.distanceMeters),
                  style: tt.bodySmall?.copyWith(
                    color: cs.onPrimaryContainer.withAlpha(204),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(width: AppTheme.spaceXS),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: cs.onPrimaryContainer.withAlpha(178),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
}

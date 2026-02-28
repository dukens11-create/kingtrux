import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/navigation_maneuver.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import 'navigation_utils.dart';
import 'steps_list_sheet.dart';

export 'navigation_utils.dart' show maneuverIconForAction, formatManeuverDistance;

/// Top-of-map guidance banner shown during active navigation.
///
/// Displays the next maneuver instruction, the distance to that maneuver,
/// and the road name / route number when available.  Tapping the banner
/// opens [StepsListSheet] for the full upcoming-steps view.
class ManeuverBanner extends StatelessWidget {
  const ManeuverBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        if (!state.isNavigating) return const SizedBox.shrink();
        final maneuver = state.currentManeuver;
        if (maneuver == null) return const SizedBox.shrink();
        return _ManeuverBannerContent(
          maneuver: maneuver,
          distanceMeters: state.remainingDistanceMeters,
        );
      },
    );
  }
}

class _ManeuverBannerContent extends StatelessWidget {
  const _ManeuverBannerContent({
    required this.maneuver,
    required this.distanceMeters,
  });

  final NavigationManeuver maneuver;
  final double distanceMeters;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: () => _openStepsList(context),
      child: Material(
        elevation: AppTheme.elevationSheet,
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceSM,
          ),
          child: Row(
            children: [
              // ── Maneuver icon ─────────────────────────────────────────────
              Icon(
                maneuverIconForAction(maneuver.action, maneuver.direction),
                color: cs.onPrimaryContainer,
                size: 32,
              ),
              const SizedBox(width: AppTheme.spaceSM),
              // ── Instruction + road info ───────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      maneuver.instruction,
                      style: tt.titleSmall?.copyWith(
                        color: cs.onPrimaryContainer,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_roadLabel(maneuver) != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        _roadLabel(maneuver)!,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onPrimaryContainer.withAlpha(200),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              // ── Distance to maneuver ──────────────────────────────────────
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    formatManeuverDistance(distanceMeters),
                    style: tt.titleMedium?.copyWith(
                      color: cs.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Icon(
                    Icons.expand_more_rounded,
                    size: 16,
                    color: cs.onPrimaryContainer.withAlpha(180),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openStepsList(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const StepsListSheet(),
    );
  }

  /// Build a combined "road name / route number" label, or `null` when neither
  /// is available.
  String? _roadLabel(NavigationManeuver m) {
    final parts = <String>[
      if (m.routeNumber != null) m.routeNumber!,
      if (m.roadName != null) m.roadName!,
    ];
    if (parts.isEmpty) return null;
    return parts.join(' / ');
  }
}

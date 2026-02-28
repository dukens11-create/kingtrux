import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/navigation_maneuver.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import 'navigation_utils.dart';

/// Bottom sheet displaying the full list of upcoming navigation steps.
///
/// Opened by tapping [ManeuverBanner] or the "Steps" toolbar button.  Each
/// row shows the maneuver icon, instruction text, road name / route number,
/// and distance for that leg.
class StepsListSheet extends StatelessWidget {
  const StepsListSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final steps = state.remainingManeuvers;
        return DraggableScrollableSheet(
          initialChildSize: 0.55,
          minChildSize: 0.35,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // ── Sheet header ──────────────────────────────────────────
                _SheetHeader(stepCount: steps.length),
                // ── Steps list ────────────────────────────────────────────
                Expanded(
                  child: steps.isEmpty
                      ? const _EmptyStepsState()
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.only(
                            bottom: AppTheme.spaceLG,
                          ),
                          itemCount: steps.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, indent: 56),
                          itemBuilder: (context, index) => _StepRow(
                            step: steps[index],
                            isFirst: index == 0,
                            isLast: index == steps.length - 1,
                          ),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Sheet header
// ---------------------------------------------------------------------------

class _SheetHeader extends StatelessWidget {
  const _SheetHeader({required this.stepCount});

  final int stepCount;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM,
      ),
      child: Row(
        children: [
          Icon(Icons.list_alt_rounded, color: cs.primary, size: 22),
          const SizedBox(width: AppTheme.spaceSM),
          Text(
            'Upcoming Steps',
            style: tt.titleMedium?.copyWith(color: cs.onSurface),
          ),
          const Spacer(),
          if (stepCount > 0)
            Text(
              '$stepCount step${stepCount == 1 ? '' : 's'}',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state
// ---------------------------------------------------------------------------

class _EmptyStepsState extends StatelessWidget {
  const _EmptyStepsState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.flag_rounded, size: 48, color: cs.primary),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              'No navigation active',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Individual step row
// ---------------------------------------------------------------------------

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.isFirst,
    required this.isLast,
  });

  final NavigationManeuver step;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final roadLabel = _roadLabel(step);

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Maneuver icon ───────────────────────────────────────────────
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isFirst ? cs.primaryContainer : cs.surfaceContainerHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(
              maneuverIconForAction(step.action, step.direction),
              size: 18,
              color: isFirst ? cs.onPrimaryContainer : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          // ── Text content ────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  step.instruction.isNotEmpty ? step.instruction : _defaultInstruction(step),
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: isFirst ? FontWeight.w600 : FontWeight.w400,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (roadLabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    roadLabel,
                    style: tt.bodySmall?.copyWith(color: cs.primary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          // ── Distance for this leg ───────────────────────────────────────
          Text(
            formatManeuverDistance(step.distanceMeters),
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  String? _roadLabel(NavigationManeuver m) {
    final parts = <String>[
      if (m.routeNumber != null) m.routeNumber!,
      if (m.roadName != null) m.roadName!,
    ];
    return parts.isEmpty ? null : parts.join(' / ');
  }

  String _defaultInstruction(NavigationManeuver m) {
    if (m.action == 'arrive') return 'Arrive at destination';
    if (m.action == 'depart') return 'Depart';
    return 'Continue';
  }
}

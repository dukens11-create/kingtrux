import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/route_result.dart';
import '../../models/toll_preference.dart';
import '../../services/trip_eta_service.dart';
import '../../state/app_state.dart';
import '../navigation_screen.dart';
import '../theme/app_theme.dart';
import 'route_warnings_card.dart';
import 'truck_profile_sheet.dart';

/// Card displaying route summary and POI loading controls.
///
/// Slides in from the bottom when a route is available.
///
/// When [settingDestination] is `true` (destination-setting mode is active),
/// the "Long-press..." hint row is shown so the driver knows what to do.
/// The hint can be dismissed with the X button; dismissal is remembered for
/// the lifetime of this widget (i.e. the current app session).
class RouteSummaryCard extends StatefulWidget {
  const RouteSummaryCard({super.key, this.settingDestination = false});

  /// Whether the map is currently in destination-setting mode.
  final bool settingDestination;

  @override
  State<RouteSummaryCard> createState() => _RouteSummaryCardState();
}

class _RouteSummaryCardState extends State<RouteSummaryCard> {
  /// Set to `true` once the user dismisses the hint; survives widget rebuilds.
  bool _hintDismissed = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.2),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: FadeTransition(opacity: animation, child: child),
            );
          },
          child: Card(
            key: ValueKey(state.routeResult?.lengthMeters),
            elevation: AppTheme.elevationSheet,
            margin: const EdgeInsets.all(AppTheme.spaceMD),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppTheme.spaceMD),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildRouteSection(context, state),
                  if (state.routeResult != null) ...[
                    const SizedBox(height: AppTheme.spaceSM),
                    _buildRouteWarnings(state.routeResult!),
                  ],
                  const Divider(height: AppTheme.spaceLG),
                  _buildTruckProfileBanner(context, state),
                  _buildTollToggle(context, state),
                  const SizedBox(height: AppTheme.spaceSM),
                  _buildPoiButton(context, state),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Route section
  // ---------------------------------------------------------------------------
  Widget _buildRouteSection(BuildContext context, AppState state) {
    if (state.isLoadingRoute) {
      return const _RouteSectionLoader();
    }
    if (state.routeResult != null) {
      return _RouteDetails(state: state);
    }
    // Only show the destination hint when destination-setting mode is active
    // and the driver has not dismissed it for this session.
    if (widget.settingDestination && !_hintDismissed) {
      return _EmptyRouteState(
        onDismiss: () => setState(() => _hintDismissed = true),
      );
    }
    return const SizedBox.shrink();
  }

  // ---------------------------------------------------------------------------
  // Route warnings
  // ---------------------------------------------------------------------------
  Widget _buildRouteWarnings(RouteResult result) {
    return RouteWarningsCard(result: result);
  }

  // ---------------------------------------------------------------------------
  // Truck profile completeness banner
  // ---------------------------------------------------------------------------
  Widget _buildTruckProfileBanner(BuildContext context, AppState state) {
    if (!state.truckProfile.isDefaultProfile) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      child: InkWell(
        onTap: () {
          showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => const TruckProfileSheet(),
          );
        },
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Container(
          decoration: BoxDecoration(
            color: cs.tertiaryContainer,
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceSM,
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: cs.onTertiaryContainer),
              const SizedBox(width: AppTheme.spaceXS),
              Expanded(
                child: Text(
                  'Using default truck profile — tap to configure your vehicle dimensions.',
                  style: tt.bodySmall?.copyWith(color: cs.onTertiaryContainer),
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 16, color: cs.onTertiaryContainer),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Toll preference toggle
  // ---------------------------------------------------------------------------
  Widget _buildTollToggle(BuildContext context, AppState state) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.toll_rounded, size: 18, color: cs.onSurfaceVariant),
        const SizedBox(width: AppTheme.spaceSM),
        Expanded(
          child: SegmentedButton<TollPreference>(
            segments: const [
              ButtonSegment(
                value: TollPreference.any,
                label: Text('Toll'),
                icon: Icon(Icons.attach_money_rounded),
              ),
              ButtonSegment(
                value: TollPreference.tollFree,
                label: Text('Toll-Free'),
                icon: Icon(Icons.money_off_rounded),
              ),
            ],
            selected: {state.tollPreference},
            onSelectionChanged: (selected) async {
              if (selected.isNotEmpty) {
                await state.setTollPreference(selected.first);
              }
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // POI button
  // ---------------------------------------------------------------------------
  Widget _buildPoiButton(BuildContext context, AppState state) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: state.isLoadingPois
            ? null
            : () async {
                try {
                  await state.loadPois();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Loaded ${state.pois.length} POIs'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error loading POIs: $e'),
                        backgroundColor:
                            Theme.of(context).colorScheme.error,
                      ),
                    );
                  }
                }
              },
        icon: state.isLoadingPois
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.place_rounded),
        label: Text(
          state.isLoadingPois
              ? 'Loading POIs…'
              : 'Nearby POIs (${state.pois.length})',
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _EmptyRouteState extends StatelessWidget {
  const _EmptyRouteState({this.onDismiss});

  /// Called when the driver taps the X button to dismiss the hint.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.touch_app_rounded, color: cs.outline, size: 32),
        const SizedBox(width: AppTheme.spaceMD),
        Expanded(
          child: Text(
            'Long-press anywhere on the map to set a destination',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
        if (onDismiss != null)
          IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: onDismiss,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            visualDensity: VisualDensity.compact,
            tooltip: 'Dismiss',
          ),
      ],
    );
  }
}

class _RouteSectionLoader extends StatelessWidget {
  const _RouteSectionLoader();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary),
        ),
        const SizedBox(width: AppTheme.spaceMD),
        Text(
          'Calculating route…',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _RouteDetails extends StatelessWidget {
  const _RouteDetails({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final result = state.routeResult!;

    // Compute estimated arrival time based on route duration from now.
    final etaUtc = TripEtaService.calculateEta(
      DateTime.now(),
      result.durationSeconds,
    );
    final etaAtDest = state.tripEtaAtDestination;
    final destTzName = state.destinationTimeZoneName;
    final arrivalDt = etaAtDest ?? etaUtc.toLocal();
    final arrivalLabel = TripEtaService.formatWallClock(arrivalDt);
    final arrivalTz = (etaAtDest != null && destTzName != null)
        ? ' $destTzName'
        : '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.route_rounded, color: cs.primary, size: 28),
        const SizedBox(width: AppTheme.spaceMD),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _formatDistance(result.lengthMeters),
                style: tt.titleMedium?.copyWith(color: cs.onSurface),
              ),
              const SizedBox(height: AppTheme.spaceXS),
              Text(
                _formatDuration(result.durationSeconds),
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: AppTheme.spaceXS),
              // ── ETA estimate ──────────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.flag_rounded, size: 14,
                      color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Text(
                    'ETA $arrivalLabel$arrivalTz',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceXS),
              _buildTollInfo(context, result, cs, tt),
              const SizedBox(height: AppTheme.spaceSM),
              FilledButton.icon(
                onPressed: () async {
                  await state.startNavigation();
                  if (context.mounted) {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const NavigationScreen(),
                      ),
                    );
                  }
                },
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Start Navigation'),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => state.clearRoute(),
          tooltip: 'Clear route',
          style: IconButton.styleFrom(
            foregroundColor: cs.error,
          ),
        ),
      ],
    );
  }

  Widget _buildTollInfo(
    BuildContext context,
    RouteResult result,
    ColorScheme cs,
    TextTheme tt,
  ) {
    if (result.avoidedTolls) {
      return Row(
        children: [
          Icon(Icons.check_circle_rounded,
              size: 14, color: Colors.green.shade600),
          const SizedBox(width: 4),
          Text(
            'Toll-Free Route',
            style: tt.bodySmall?.copyWith(
              color: Colors.green.shade700,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      );
    }
    final cost = result.estimatedTollCostUsd;
    if (cost != null) {
      return Row(
        children: [
          Icon(Icons.attach_money_rounded,
              size: 14, color: cs.onSurfaceVariant),
          Text(
            'Est. tolls: \$${cost.toStringAsFixed(2)}',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  String _formatDistance(double meters) {
    final miles = meters * 0.000621371;
    return '${miles.toStringAsFixed(1)} mi';
  }

  String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }
}


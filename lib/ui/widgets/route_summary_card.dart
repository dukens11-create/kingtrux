import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/route_result.dart';
import '../../models/toll_preference.dart';
import '../../state/app_state.dart';
import '../navigation_screen.dart';
import '../theme/app_theme.dart';

/// Card displaying route summary and POI loading controls.
///
/// Slides in from the bottom when a route is available.
class RouteSummaryCard extends StatelessWidget {
  const RouteSummaryCard({super.key});

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
                  const Divider(height: AppTheme.spaceLG),
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
    if (state.routeResult == null) {
      return const _EmptyRouteState();
    }
    return _RouteDetails(state: state);
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
  const _EmptyRouteState();

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


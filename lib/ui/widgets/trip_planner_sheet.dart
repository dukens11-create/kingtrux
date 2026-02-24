import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/trip_stop.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// A bottom sheet that lets the user manage a multi-stop trip.
///
/// Features:
/// - Add a stop from the current destination or current location
/// - Remove stops
/// - Drag-to-reorder stops
/// - Optimize stop order (nearest-neighbour + 2-opt)
/// - Build the trip route
/// - Clear the trip
class TripPlannerSheet extends StatelessWidget {
  const TripPlannerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Consumer<AppState>(
          builder: (context, state, _) {
            return _TripPlannerContent(
              scrollController: scrollController,
              state: state,
            );
          },
        );
      },
    );
  }
}

class _TripPlannerContent extends StatelessWidget {
  const _TripPlannerContent({
    required this.scrollController,
    required this.state,
  });

  final ScrollController scrollController;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final trip = state.activeTrip;
    final stops = trip?.stops ?? [];

    return Material(
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusXL),
      ),
      child: Column(
        children: [
          // Drag handle
          _DragHandle(cs: cs),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMD,
              vertical: AppTheme.spaceXS,
            ),
            child: Row(
              children: [
                Icon(Icons.route_rounded, color: cs.primary),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: Text(
                    trip?.name ?? 'Trip Planner',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (stops.isNotEmpty)
                  TextButton.icon(
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.error,
                    ),
                    onPressed: () => _onClearTrip(context),
                  ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Stop list
          Expanded(
            child: stops.isEmpty
                ? _EmptyState(cs: cs)
                : ReorderableListView.builder(
                    scrollController: scrollController,
                    padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spaceXS,
                    ),
                    itemCount: stops.length,
                    onReorder: (oldIndex, newIndex) {
                      if (newIndex > oldIndex) newIndex--;
                      context.read<AppState>().reorderTripStop(
                            oldIndex,
                            newIndex,
                          );
                    },
                    itemBuilder: (context, index) {
                      final stop = stops[index];
                      final isFirst = index == 0;
                      final isLast = index == stops.length - 1;
                      return _StopTile(
                        key: ValueKey(stop.id),
                        stop: stop,
                        index: index,
                        isFirst: isFirst,
                        isLast: isLast,
                        onRemove: () =>
                            context.read<AppState>().removeTripStop(stop.id),
                      );
                    },
                  ),
          ),

          // Error message
          if (state.tripRouteError != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceXS,
              ),
              child: Text(
                state.tripRouteError!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.error),
              ),
            ),

          // Action buttons
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceSM,
              ),
              child: _ActionRow(state: state),
            ),
          ),
        ],
      ),
    );
  }

  void _onClearTrip(BuildContext context) {
    context.read<AppState>().clearTrip();
  }
}

// ---------------------------------------------------------------------------
// Action row
// ---------------------------------------------------------------------------

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final stops = state.activeTrip?.stops ?? [];
    final hasEnoughStops = stops.length >= 2;
    final hasIntermediates = stops.length >= 3;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Add-stop buttons row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.my_location_rounded, size: 18),
                label: const Text('Add Current Location'),
                onPressed: state.myLat != null
                    ? () => _addCurrentLocation(context, state)
                    : null,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.flag_rounded, size: 18),
                label: const Text('Add Destination'),
                onPressed: state.destLat != null
                    ? () => _addDestination(context, state)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppTheme.spaceSM),
        // Optimize + Build Route row
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.auto_fix_high_rounded, size: 18),
                label: const Text('Optimize Order'),
                onPressed: hasIntermediates
                    ? () => context.read<AppState>().optimizeTripStopOrder()
                    : null,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: FilledButton.icon(
                icon: state.isLoadingTripRoute
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.directions_rounded, size: 18),
                label: const Text('Build Route'),
                onPressed: hasEnoughStops && !state.isLoadingTripRoute
                    ? () async {
                        await context.read<AppState>().buildTripRoute();
                        if (context.mounted) Navigator.pop(context);
                      }
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _addCurrentLocation(BuildContext context, AppState state) {
    final stop = TripStop(
      id: const Uuid().v4(),
      label: 'Current Location',
      lat: state.myLat!,
      lng: state.myLng!,
      createdAt: DateTime.now(),
    );
    context.read<AppState>().addTripStop(stop);
  }

  void _addDestination(BuildContext context, AppState state) {
    final stop = TripStop(
      id: const Uuid().v4(),
      label: 'Destination',
      lat: state.destLat!,
      lng: state.destLng!,
      createdAt: DateTime.now(),
    );
    context.read<AppState>().addTripStop(stop);
  }
}

// ---------------------------------------------------------------------------
// Stop list tile
// ---------------------------------------------------------------------------

class _StopTile extends StatelessWidget {
  const _StopTile({
    super.key,
    required this.stop,
    required this.index,
    required this.isFirst,
    required this.isLast,
    required this.onRemove,
  });

  final TripStop stop;
  final int index;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color iconColor;
    IconData iconData;
    if (isFirst) {
      iconColor = cs.primary;
      iconData = Icons.trip_origin_rounded;
    } else if (isLast) {
      iconColor = cs.error;
      iconData = Icons.flag_rounded;
    } else {
      iconColor = cs.secondary;
      iconData = Icons.circle_outlined;
    }

    return ListTile(
      key: key,
      leading: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(iconData, color: iconColor, size: 22),
        ],
      ),
      title: Text(
        stop.label ?? 'Stop ${index + 1}',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        '${stop.lat.toStringAsFixed(5)}, ${stop.lng.toStringAsFixed(5)}',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: cs.onSurfaceVariant),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.remove_circle_outline_rounded,
                color: cs.error, size: 20),
            tooltip: 'Remove stop',
            onPressed: onRemove,
          ),
          ReorderableDragStartListener(
            index: index,
            child: Icon(Icons.drag_handle_rounded,
                color: cs.onSurfaceVariant, size: 22),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Supporting widgets
// ---------------------------------------------------------------------------

class _DragHandle extends StatelessWidget {
  const _DragHandle({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSM),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: cs.onSurfaceVariant.withAlpha(80),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add_location_alt_rounded,
              size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            'No stops yet.\nAdd your origin, stops, and destination.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/trip_stop.dart';
import '../state/app_state.dart';
import 'theme/app_theme.dart';
import 'navigation_screen.dart';

/// Full-page Trip screen with tabs: Trip / Planned / History.
///
/// The **Trip** tab shows the active trip's origin and destination in a
/// vertical-timeline card layout, quick-action buttons, and a section list
/// (Smart Fuel Plan, Documents, Private Note, Live Sharing, Feedback).
///
/// Unimplemented features show a "Coming soon" SnackBar.
class TripScreen extends StatelessWidget {
  const TripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trip'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Trip'),
              Tab(text: 'Planned'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _ActiveTripTab(),
            _ComingSoonTab(label: 'Planned trips'),
            _ComingSoonTab(label: 'Trip history'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Active trip tab
// ---------------------------------------------------------------------------

class _ActiveTripTab extends StatelessWidget {
  const _ActiveTripTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.only(
                left: AppTheme.spaceMD,
                right: AppTheme.spaceMD,
                top: AppTheme.spaceMD,
                // Extra bottom padding so the Clear Trip button doesn't cover content.
                bottom: 80,
              ),
              children: [
                // Trip header
                _TripHeaderRow(state: state),
                const SizedBox(height: AppTheme.spaceMD),

                // Stop timeline
                _StopTimelineCard(state: state),
                const SizedBox(height: AppTheme.spaceMD),

                // Quick actions
                _QuickActionsRow(state: state),
                const SizedBox(height: AppTheme.spaceMD),

                // Section list
                _SectionList(state: state),
              ],
            ),

            // Floating "Clear Trip" pill at bottom-right
            Positioned(
              right: AppTheme.spaceMD,
              bottom: AppTheme.spaceMD,
              child: _ClearTripButton(state: state),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Trip header row
// ---------------------------------------------------------------------------

class _TripHeaderRow extends StatelessWidget {
  const _TripHeaderRow({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tripName = state.activeTrip?.name ?? 'My Trip';

    return Row(
      children: [
        Icon(Icons.route_rounded, color: cs.primary, size: 22),
        const SizedBox(width: AppTheme.spaceSM),
        Expanded(
          child: Text(
            tripName,
            style: tt.titleMedium,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_rounded),
          tooltip: 'Edit trip name',
          onPressed: () => _showComingSoon(context),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Stop timeline card
// ---------------------------------------------------------------------------

class _StopTimelineCard extends StatelessWidget {
  const _StopTimelineCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final stops = state.activeTrip?.stops ?? [];
    final origin = stops.isNotEmpty ? stops.first : null;
    final destination = stops.length >= 2 ? stops.last : null;
    final route = state.routeResult;

    String routeSummary = '';
    if (route != null) {
      final miles = (route.lengthMeters / 1609.34).toStringAsFixed(0);
      final mins = (route.durationSeconds / 60).round();
      routeSummary = '$miles mi, ${mins}min remaining';
    }

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Origin row
            _StopRow(
              stop: origin,
              isOrigin: true,
              isDestination: false,
              placeholder: 'Origin',
              lineBelow: true,
              cs: cs,
            ),

            // Route summary row
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      routeSummary.isNotEmpty
                          ? routeSummary
                          : 'No route calculated',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded,
                        size: 20, color: cs.primary),
                    tooltip: 'Add stop',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    onPressed: () => _showComingSoon(context),
                  ),
                ],
              ),
            ),

            // Destination row
            _StopRow(
              stop: destination,
              isOrigin: false,
              isDestination: true,
              placeholder: 'Destination',
              lineBelow: false,
              cs: cs,
              onGo: () => _onGo(context, state),
              onArrived: () => _showComingSoon(context),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onGo(BuildContext context, AppState state) async {
    HapticFeedback.mediumImpact();
    final hasRoute = state.routeResult != null;
    if (!hasRoute) {
      if (state.activeTrip != null && state.activeTrip!.stops.length >= 2) {
        await state.buildTripRoute();
      }
    }
    if (!context.mounted) return;
    if (state.routeResult != null) {
      await state.startNavigation();
      if (context.mounted) {
        await Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => const NavigationScreen(),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please build a route first.')),
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Single stop row in the timeline
// ---------------------------------------------------------------------------

class _StopRow extends StatelessWidget {
  const _StopRow({
    super.key,
    required this.stop,
    required this.isOrigin,
    required this.isDestination,
    required this.placeholder,
    required this.lineBelow,
    required this.cs,
    this.onGo,
    this.onArrived,
  });

  final TripStop? stop;
  final bool isOrigin;
  final bool isDestination;
  final String placeholder;
  final bool lineBelow;
  final ColorScheme cs;
  final VoidCallback? onGo;
  final VoidCallback? onArrived;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Vertical route indicator column
        SizedBox(
          width: 20,
          child: Column(
            children: [
              // Icon
              Icon(
                isOrigin
                    ? Icons.trip_origin_rounded
                    : Icons.flag_rounded,
                size: 18,
                color: isOrigin ? cs.primary : cs.error,
              ),
              // Connector line below
              if (lineBelow)
                Container(
                  width: 2,
                  height: isDestination ? 0 : 40,
                  color: cs.outlineVariant,
                ),
            ],
          ),
        ),
        const SizedBox(width: AppTheme.spaceSM),

        // Content
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stop?.label ?? placeholder,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (stop != null)
                Text(
                  '${stop!.lat.toStringAsFixed(4)}, ${stop!.lng.toStringAsFixed(4)}',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              if (isDestination && (onGo != null || onArrived != null)) ...[
                const SizedBox(height: AppTheme.spaceSM),
                Row(
                  children: [
                    FilledButton(
                      onPressed: onGo,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMD,
                          vertical: AppTheme.spaceXS,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Go'),
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    OutlinedButton(
                      onPressed: onArrived,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMD,
                          vertical: AppTheme.spaceXS,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      child: const Text('Arrived'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppTheme.spaceSM),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions row
// ---------------------------------------------------------------------------

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final items = [
      _QuickActionItem(
        icon: Icons.swap_vert_rounded,
        label: 'Reorder',
        onTap: () => _onReorder(context),
      ),
      _QuickActionItem(
        icon: Icons.search_rounded,
        label: 'Search POIs',
        onTap: () => _showComingSoon(context),
      ),
      _QuickActionItem(
        icon: Icons.settings_rounded,
        label: 'Trip Settings',
        onTap: () => _showComingSoon(context),
      ),
      _QuickActionItem(
        icon: Icons.share_rounded,
        label: 'Share',
        onTap: () => _showComingSoon(context),
      ),
    ];

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppTheme.spaceSM,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: items.map((item) {
            return Expanded(
              child: InkWell(
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppTheme.spaceSM,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(item.icon, size: 24, color: cs.primary),
                      const SizedBox(height: AppTheme.spaceXS),
                      Text(
                        item.label,
                        style: tt.bodySmall?.copyWith(
                          color: cs.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  void _onReorder(BuildContext context) {
    if (state.activeTrip == null || state.activeTrip!.stops.length < 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least 3 stops to reorder.')),
      );
      return;
    }
    _showComingSoon(context);
  }
}

class _QuickActionItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });
}

// ---------------------------------------------------------------------------
// Section list
// ---------------------------------------------------------------------------

class _SectionList extends StatelessWidget {
  const _SectionList({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionCard(
          icon: Icons.local_gas_station_rounded,
          title: 'Smart Fuel Plan',
          trailing: FilledButton(
            onPressed: () => _showComingSoon(context),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceXS,
              ),
            ),
            child: const Text('Get Fuel Plan'),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        _SectionCard(
          icon: Icons.description_rounded,
          title: 'Documents',
          trailing: TextButton.icon(
            icon: const Icon(Icons.document_scanner_rounded, size: 16),
            label: const Text('+ Scan Doc'),
            onPressed: () => _showComingSoon(context),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        _SectionCard(
          icon: Icons.sticky_note_2_rounded,
          title: 'Private Note',
          trailing: TextButton.icon(
            icon: const Icon(Icons.edit_rounded, size: 16),
            label: const Text('Edit Note'),
            onPressed: () => _showComingSoon(context),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        _SectionCard(
          icon: Icons.share_location_rounded,
          title: 'Live Sharing',
          trailing: TextButton.icon(
            icon: const Icon(Icons.add_rounded, size: 16),
            label: const Text('+ New Share'),
            onPressed: () => _showComingSoon(context),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        _SectionCard(
          icon: Icons.feedback_rounded,
          title: 'Feedback',
          trailing: IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: () => _showComingSoon(context),
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceXS,
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: cs.primary),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: Text(
                title,
                style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Clear trip button
// ---------------------------------------------------------------------------

class _ClearTripButton extends StatelessWidget {
  const _ClearTripButton({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (state.activeTrip == null && state.routeResult == null) {
      return const SizedBox.shrink();
    }
    return ElevatedButton.icon(
      key: const Key('trip_screen_clear_trip_btn'),
      icon: const Icon(Icons.delete_sweep_rounded, size: 16),
      label: const Text('Clear Trip'),
      onPressed: () {
        HapticFeedback.selectionClick();
        state.clearTrip();
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: cs.errorContainer,
        foregroundColor: cs.onErrorContainer,
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceXS,
        ),
        shape: const StadiumBorder(),
        elevation: AppTheme.elevationSheet,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder tab
// ---------------------------------------------------------------------------

class _ComingSoonTab extends StatelessWidget {
  const _ComingSoonTab({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty_rounded,
              size: 48, color: cs.onSurfaceVariant),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: AppTheme.spaceXS),
          Text(
            'Coming soon',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helper
// ---------------------------------------------------------------------------

void _showComingSoon(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('Coming soon')),
  );
}

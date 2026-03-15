import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/trip.dart';
import '../models/trip_stop.dart';
import '../state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/trip_stop_card.dart';

/// Full-page Trip screen with three tabs: Trip, Planned, History.
///
/// The **Trip** tab shows:
///   - A trip identifier/title row with an edit icon
///   - A vertical timeline of trip stops (origin → destination)
///   - A quick-actions row (Reorder, Search POIs, Trip Settings, Share)
///   - Feature section cards (Smart Fuel Plan, Documents, Private Note,
///     Live Sharing, Feedback) – stub "Coming soon" for unimplemented features
///   - A "Clear Trip" pill button
///
/// The **Planned** and **History** tabs are placeholder stubs.
class TripScreen extends StatelessWidget {
  const TripScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text('Trips'),
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
            _TripTab(),
            _PlaceholderTab(label: 'Planned trips will appear here.'),
            _PlaceholderTab(label: 'Past trips will appear here.'),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trip tab
// ---------------------------------------------------------------------------

class _TripTab extends StatelessWidget {
  const _TripTab();

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final trip = state.activeTrip;
        final stops = trip?.stops ?? [];

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMD,
            AppTheme.spaceMD,
            AppTheme.spaceMD,
            AppTheme.spaceLG * 2,
          ),
          children: [
            // ── Trip header row ──────────────────────────────────────────
            _TripHeaderRow(trip: trip),
            const SizedBox(height: AppTheme.spaceMD),

            // ── Route / stops section ────────────────────────────────────
            if (stops.isEmpty)
              _EmptyTripCard(state: state)
            else
              _RouteCard(stops: stops, state: state),

            const SizedBox(height: AppTheme.spaceMD),

            // ── Quick actions ────────────────────────────────────────────
            const _QuickActionsRow(),
            const SizedBox(height: AppTheme.spaceMD),

            // ── Feature section cards ────────────────────────────────────
            const _SmartFuelPlanCard(),
            const _DocumentsCard(),
            const _PrivateNoteCard(),
            const _LiveSharingCard(),
            const _FeedbackRow(),
            const SizedBox(height: AppTheme.spaceMD),

            // ── Clear Trip button ────────────────────────────────────────
            if (stops.isNotEmpty) _ClearTripButton(state: state),
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
  const _TripHeaderRow({required this.trip});
  final Trip? trip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final title = trip?.name ?? 'Trip #1';
    final subtitle = trip != null
        ? 'Created ${_formatDate(trip!.createdAt)}'
        : 'No active trip';

    return Row(
      children: [
        Icon(Icons.route_rounded, color: cs.primary, size: 28),
        const SizedBox(width: AppTheme.spaceSM),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: tt.titleMedium),
              Text(
                subtitle,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          tooltip: 'Edit trip',
          onPressed: () => _showEditDialog(context),
        ),
      ],
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }

  void _showEditDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }
}

// ---------------------------------------------------------------------------
// Route card (stops timeline)
// ---------------------------------------------------------------------------

class _RouteCard extends StatelessWidget {
  const _RouteCard({required this.stops, required this.state});
  final List<TripStop> stops;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Route stops
        for (int i = 0; i < stops.length; i++) ...[
          TripStopCard(
            stop: stops[i],
            index: i,
            totalStops: stops.length,
            onGoPressed: () => state.startNavigation().catchError(
                  (Object e) => debugPrint('startNavigation error: $e'),
                ),
            onArrivedPressed: () => _onArrived(context, i),
          ),
          // "+" add stop button between stops
          if (i < stops.length - 1)
            _AddStopButton(
              cs: cs,
              onPressed: () => _onAddStop(context),
            ),
        ],
      ],
    );
  }

  void _onArrived(BuildContext context, int index) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Marked as arrived')),
    );
  }

  void _onAddStop(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }
}

class _AddStopButton extends StatelessWidget {
  const _AddStopButton({required this.cs, required this.onPressed});
  final ColorScheme cs;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 19, // align with the centre of the timeline dot (32/2 - 1)
        top: 0,
        bottom: 0,
      ),
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.primaryContainer,
            border: Border.all(color: cs.primary, width: 1.5),
          ),
          child: Icon(Icons.add_rounded, size: 16, color: cs.primary),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Empty state card
// ---------------------------------------------------------------------------

class _EmptyTripCard extends StatelessWidget {
  const _EmptyTripCard({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Column(
          children: [
            Icon(
              Icons.add_location_alt_outlined,
              size: 48,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              'No stops yet',
              style: tt.titleSmall?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: AppTheme.spaceXS),
            Text(
              'Add your origin, stops, and destination to plan a trip.',
              textAlign: TextAlign.center,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            FilledButton.icon(
              icon: const Icon(Icons.add_location_alt_rounded, size: 18),
              label: const Text('Add Stop'),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Coming soon')),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick actions row
// ---------------------------------------------------------------------------

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _QuickAction(
          icon: Icons.swap_vert_rounded,
          label: 'Reorder',
          onTap: () => _comingSoon(context),
        ),
        _QuickAction(
          icon: Icons.search_rounded,
          label: 'Search POIs',
          onTap: () => _comingSoon(context),
        ),
        _QuickAction(
          icon: Icons.settings_rounded,
          label: 'Trip Settings',
          onTap: () => _comingSoon(context),
        ),
        _QuickAction(
          icon: Icons.share_rounded,
          label: 'Share',
          onTap: () => _comingSoon(context),
        ),
      ],
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Icon(icon, color: cs.primary, size: 24),
          ),
          const SizedBox(height: AppTheme.spaceXS),
          Text(
            label,
            style: tt.bodySmall?.copyWith(color: cs.onSurface),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Feature section cards
// ---------------------------------------------------------------------------

class _SmartFuelPlanCard extends StatelessWidget {
  const _SmartFuelPlanCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Row(
          children: [
            Icon(Icons.local_gas_station_rounded, color: cs.primary, size: 28),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Smart Fuel Plan', style: tt.titleSmall),
                  Text(
                    'Optimize fuel stops along your route.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: () => _comingSoon(context),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              child: const Text('Plan'),
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }
}

class _DocumentsCard extends StatelessWidget {
  const _DocumentsCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Row(
          children: [
            Icon(Icons.description_outlined, color: cs.primary, size: 28),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Documents', style: tt.titleSmall),
                  Text(
                    'Scan and store trip documents.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.document_scanner_outlined, size: 16),
              label: const Text('+ Scan Doc'),
              onPressed: () => _comingSoon(context),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }
}

class _PrivateNoteCard extends StatelessWidget {
  const _PrivateNoteCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Row(
          children: [
            Icon(Icons.sticky_note_2_outlined, color: cs.primary, size: 28),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Private Note', style: tt.titleSmall),
                  Text(
                    'Keep personal notes about this trip.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit_note_rounded, color: cs.primary),
              tooltip: 'Edit note',
              onPressed: () => _comingSoon(context),
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }
}

class _LiveSharingCard extends StatelessWidget {
  const _LiveSharingCard();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Row(
          children: [
            Icon(Icons.location_on_rounded, color: cs.primary, size: 28),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Live Sharing', style: tt.titleSmall),
                  Text(
                    'Share your location with others.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('+ New Share'),
              onPressed: () => _comingSoon(context),
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
      child: ListTile(
        leading: Icon(Icons.star_outline_rounded, color: cs.primary),
        title: Text('Feedback', style: tt.titleSmall),
        subtitle: Text(
          'Rate your experience.',
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        onTap: () => _comingSoon(context),
      ),
    );
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coming soon')),
    );
  }
}

// ---------------------------------------------------------------------------
// Clear Trip button
// ---------------------------------------------------------------------------

class _ClearTripButton extends StatelessWidget {
  const _ClearTripButton({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        icon: const Icon(Icons.delete_outline_rounded, size: 18),
        label: const Text('Clear Trip'),
        style: FilledButton.styleFrom(
          backgroundColor: cs.errorContainer,
          foregroundColor: cs.onErrorContainer,
          shape: const StadiumBorder(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceLG,
            vertical: AppTheme.spaceSM,
          ),
        ),
        onPressed: () {
          HapticFeedback.mediumImpact();
          state.clearTrip();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Trip cleared')),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Placeholder tab (Planned / History)
// ---------------------------------------------------------------------------

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hourglass_empty_rounded,
              size: 56, color: cs.onSurfaceVariant),
          const SizedBox(height: AppTheme.spaceSM),
          Text(
            label,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

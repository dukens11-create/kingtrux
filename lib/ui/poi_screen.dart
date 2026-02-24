import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Full-screen POI browser with two tabs:
///   1. **Near Me** — POIs within a configurable radius of the current location.
///   2. **Along Route** — POIs sampled along the active route (disabled when no
///      route is loaded).
///
/// Each tab shares the same filter toolbar and POI list; the data source
/// differs between tabs.
class PoiScreen extends StatefulWidget {
  const PoiScreen({super.key});

  @override
  State<PoiScreen> createState() => _PoiScreenState();
}

class _PoiScreenState extends State<PoiScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Which POI types the driver wants to see in the current session.
  Set<PoiType> _activeFilters = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    // Default: show all truck-relevant categories.
    _activeFilters = {
      PoiType.fuel,
      PoiType.truckStop,
      PoiType.parking,
      PoiType.restArea,
      PoiType.scale,
    };
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.place_rounded, size: 22),
            SizedBox(width: AppTheme.spaceSM),
            Text('Driver POIs'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.my_location_rounded), text: 'Near Me'),
            Tab(icon: Icon(Icons.route_rounded), text: 'Along Route'),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Filter chips ────────────────────────────────────────────────
          _FilterBar(
            activeFilters: _activeFilters,
            onToggle: (type, enabled) =>
                setState(() => enabled
                    ? _activeFilters.add(type)
                    : _activeFilters.remove(type)),
          ),

          // ── Tab content ──────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _PoiTabContent(
                  mode: _PoiMode.nearMe,
                  activeFilters: _activeFilters,
                ),
                _PoiTabContent(
                  mode: _PoiMode.alongRoute,
                  activeFilters: _activeFilters,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter bar
// ---------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.activeFilters,
    required this.onToggle,
  });

  final Set<PoiType> activeFilters;
  final void Function(PoiType type, bool enabled) onToggle;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM,
      ),
      child: Row(
        children: PoiType.values.map((type) {
          final isActive = activeFilters.contains(type);
          return Padding(
            padding: const EdgeInsets.only(right: AppTheme.spaceXS),
            child: FilterChip(
              avatar: Icon(_poiIcon(type), size: 16),
              label: Text(_poiLabel(type)),
              selected: isActive,
              onSelected: (val) {
                HapticFeedback.selectionClick();
                onToggle(type, val);
              },
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Per-tab content
// ---------------------------------------------------------------------------

enum _PoiMode { nearMe, alongRoute }

class _PoiTabContent extends StatelessWidget {
  const _PoiTabContent({
    required this.mode,
    required this.activeFilters,
  });

  final _PoiMode mode;
  final Set<PoiType> activeFilters;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        // Route required for "Along Route" tab
        if (mode == _PoiMode.alongRoute && state.routeResult == null) {
          return _buildEmptyState(
            context,
            icon: Icons.route_rounded,
            message:
                'Calculate a route first to discover POIs along the way.',
          );
        }

        // No filters selected
        if (activeFilters.isEmpty) {
          return _buildEmptyState(
            context,
            icon: Icons.filter_list_rounded,
            message: 'Select at least one filter above.',
          );
        }

        final filtered = state.pois
            .where((p) => activeFilters.contains(p.type))
            .toList();

        return Column(
          children: [
            // ── Load button ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMD,
                AppTheme.spaceSM,
                AppTheme.spaceMD,
                0,
              ),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  icon: state.isLoadingPois
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          mode == _PoiMode.nearMe
                              ? Icons.my_location_rounded
                              : Icons.route_rounded,
                          size: 18,
                        ),
                  label: Text(
                    state.isLoadingPois
                        ? 'Loading…'
                        : mode == _PoiMode.nearMe
                            ? 'Load POIs Near Me'
                            : 'Load POIs Along Route',
                  ),
                  onPressed: state.isLoadingPois
                      ? null
                      : () {
                          HapticFeedback.lightImpact();
                          // Apply active filters to state before loading
                          for (final t in PoiType.values) {
                            state.toggleLayer(
                                t, activeFilters.contains(t));
                          }
                          if (mode == _PoiMode.nearMe) {
                            state.loadPois();
                          } else {
                            state.loadPoisAlongRoute();
                          }
                        },
                ),
              ),
            ),

            // ── POI count / empty state ────────────────────────────────────
            if (!state.isLoadingPois && state.pois.isEmpty) ...[
              const SizedBox(height: AppTheme.spaceLG),
              _buildEmptyState(
                context,
                icon: Icons.place_rounded,
                message: 'Tap the button above to load nearby POIs.',
              ),
            ] else
              Expanded(
                child: _PoiList(
                  pois: filtered,
                  favoritePoisIds: state.favoritePoisIds,
                  onToggleFavorite: state.toggleFavorite,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context, {
    required IconData icon,
    required String message,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: cs.outlineVariant),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// POI list
// ---------------------------------------------------------------------------

class _PoiList extends StatelessWidget {
  const _PoiList({
    required this.pois,
    required this.favoritePoisIds,
    required this.onToggleFavorite,
  });

  final List<Poi> pois;
  final Set<String> favoritePoisIds;
  final void Function(String poiId) onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    if (pois.isEmpty) {
      return Center(
        child: Text(
          'No POIs found for the selected categories.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSM),
      itemCount: pois.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final poi = pois[index];
        final isFav = favoritePoisIds.contains(poi.id);
        final cs = Theme.of(context).colorScheme;
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: cs.primaryContainer,
            child: Icon(_poiIcon(poi.type),
                color: cs.onPrimaryContainer, size: 20),
          ),
          title: Text(poi.name),
          subtitle: Text(_poiLabel(poi.type)),
          trailing: IconButton(
            icon: Icon(
              isFav ? Icons.star_rounded : Icons.star_outline_rounded,
              color: isFav ? Colors.amber : cs.outline,
            ),
            tooltip: isFav ? 'Remove favourite' : 'Add favourite',
            onPressed: () {
              HapticFeedback.selectionClick();
              onToggleFavorite(poi.id);
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers shared across widgets in this file
// ---------------------------------------------------------------------------

IconData _poiIcon(PoiType type) {
  switch (type) {
    case PoiType.fuel:
      return Icons.local_gas_station_rounded;
    case PoiType.restArea:
      return Icons.local_parking_rounded;
    case PoiType.scale:
      return Icons.scale_rounded;
    case PoiType.gym:
      return Icons.fitness_center_rounded;
    case PoiType.truckStop:
      return Icons.local_shipping_rounded;
    case PoiType.parking:
      return Icons.drive_eta_rounded;
  }
}

String _poiLabel(PoiType type) {
  switch (type) {
    case PoiType.fuel:
      return 'Fuel';
    case PoiType.restArea:
      return 'Rest Area';
    case PoiType.scale:
      return 'Scale';
    case PoiType.gym:
      return 'Gym';
    case PoiType.truckStop:
      return 'Truck Stop';
    case PoiType.parking:
      return 'Parking';
  }
}

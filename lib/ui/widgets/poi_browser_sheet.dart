import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Full-featured POI browser sheet.
///
/// Lets the driver switch between **Near Me** and **Along Route** discovery
/// modes, filter by category, browse a scrollable list of loaded POIs, tap
/// for details, and mark/unmark favourites.
class PoiBrowserSheet extends StatefulWidget {
  const PoiBrowserSheet({super.key});

  @override
  State<PoiBrowserSheet> createState() => _PoiBrowserSheetState();
}

class _PoiBrowserSheetState extends State<PoiBrowserSheet> {
  /// 0 = Near Me, 1 = Along Route
  int _selectedMode = 0;

  /// Categories actively selected in filter chips.
  /// Empty means all categories are visible.
  final Set<PoiType> _activeFilters = {};

  List<Poi> _filtered(List<Poi> pois) {
    if (_activeFilters.isEmpty) return pois;
    return pois.where((p) => _activeFilters.contains(p.type)).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final filtered = _filtered(state.pois);

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // ── Drag handle ───────────────────────────────────────────
                const SizedBox(height: AppTheme.spaceXS),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),

                // ── Header ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                  ),
                  child: Row(
                    children: [
                      Text(
                        'POI Browser',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      if (state.isLoadingPois)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),

                // ── Mode toggle ───────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                  ),
                  child: SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 0,
                        label: const Text('Near Me'),
                        icon: const Icon(Icons.my_location_rounded, size: 16),
                        enabled: state.enabledPoiLayers.isNotEmpty,
                      ),
                      ButtonSegment(
                        value: 1,
                        label: const Text('Along Route'),
                        icon: const Icon(Icons.route_rounded, size: 16),
                        enabled: state.enabledPoiLayers.isNotEmpty &&
                            state.routeResult != null,
                      ),
                    ],
                    selected: {_selectedMode},
                    onSelectionChanged: (value) {
                      if (state.isLoadingPois) return;
                      HapticFeedback.selectionClick();
                      setState(() => _selectedMode = value.first);
                      if (value.first == 0) {
                        state.loadPois();
                      } else {
                        state.loadPoisAlongRoute();
                      }
                    },
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),

                // ── Category filter chips ─────────────────────────────────
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD,
                    ),
                    children: PoiType.values.map((type) {
                      final selected = _activeFilters.contains(type);
                      return Padding(
                        padding:
                            const EdgeInsets.only(right: AppTheme.spaceXS),
                        child: FilterChip(
                          avatar: Icon(_poiIcon(type), size: 14),
                          label: Text(_poiLabel(type)),
                          selected: selected,
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (selected) {
                                _activeFilters.remove(type);
                              } else {
                                _activeFilters.add(type);
                              }
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceXS),
                const Divider(height: 1),

                // ── POI list ──────────────────────────────────────────────
                Expanded(
                  child: filtered.isEmpty
                      ? _buildEmptyState(context, state)
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: filtered.length,
                          itemBuilder: (context, index) {
                            final poi = filtered[index];
                            return _PoiListTile(
                              poi: poi,
                              isFavorite: state.isFavorite(poi.id),
                              onFavoriteToggle: () =>
                                  state.toggleFavorite(poi.id),
                              onTap: () => _showPoiDetails(context, state, poi),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, AppState state) {
    final hasLayers = state.enabledPoiLayers.isNotEmpty;
    String message;
    if (!hasLayers) {
      message = 'Enable POI layers in the Layers panel first.';
    } else if (state.pois.isEmpty) {
      message = 'Tap Near Me or Along Route to search for POIs.';
    } else {
      message = 'No POIs match the selected filters.';
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }

  void _showPoiDetails(BuildContext context, AppState state, Poi poi) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _PoiDetailSheet(
        poi: poi,
        isFavorite: state.isFavorite(poi.id),
        onFavoriteToggle: () => state.toggleFavorite(poi.id),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// POI list tile
// ---------------------------------------------------------------------------

class _PoiListTile extends StatelessWidget {
  const _PoiListTile({
    required this.poi,
    required this.isFavorite,
    required this.onFavoriteToggle,
    required this.onTap,
  });

  final Poi poi;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor:
            Theme.of(context).colorScheme.secondaryContainer,
        child: Icon(
          _poiIcon(poi.type),
          size: 20,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
      title: Text(poi.name),
      subtitle: Text(_poiLabel(poi.type)),
      trailing: IconButton(
        icon: Icon(
          isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
          color: isFavorite
              ? Theme.of(context).colorScheme.primary
              : null,
        ),
        tooltip: isFavorite ? 'Remove favourite' : 'Add favourite',
        onPressed: () {
          HapticFeedback.selectionClick();
          onFavoriteToggle();
        },
      ),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// POI detail sheet
// ---------------------------------------------------------------------------

class _PoiDetailSheet extends StatelessWidget {
  const _PoiDetailSheet({
    required this.poi,
    required this.isFavorite,
    required this.onFavoriteToggle,
  });

  final Poi poi;
  final bool isFavorite;
  final VoidCallback onFavoriteToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceMD,
          AppTheme.spaceSM,
          AppTheme.spaceMD,
          AppTheme.spaceMD,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title row
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.secondaryContainer,
                  child: Icon(
                    _poiIcon(poi.type),
                    color: cs.onSecondaryContainer,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        poi.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        _poiLabel(poi.type),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    isFavorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: isFavorite ? cs.primary : null,
                    size: 28,
                  ),
                  tooltip: isFavorite ? 'Remove favourite' : 'Add favourite',
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    onFavoriteToggle();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMD),
            // Coordinates
            Text(
              '${poi.lat.toStringAsFixed(5)}, ${poi.lng.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
            // Additional OSM tags
            if (poi.tags.isNotEmpty) ...[
              const SizedBox(height: AppTheme.spaceSM),
              const Divider(),
              ...poi.tags.entries
                  .where((e) =>
                      e.value is String && (e.value as String).isNotEmpty)
                  .take(6)
                  .map(
                    (e) => Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spaceXS,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 110,
                            child: Text(
                              e.key,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              e.value as String,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers (shared between sheet and tile)
// ---------------------------------------------------------------------------

IconData _poiIcon(PoiType type) {
  switch (type) {
    case PoiType.fuel:
      return Icons.local_gas_station_rounded;
    case PoiType.restArea:
      return Icons.bed_rounded;
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
      return 'Fuel Station';
    case PoiType.restArea:
      return 'Rest Area';
    case PoiType.scale:
      return 'Weigh Scale';
    case PoiType.gym:
      return 'Gym';
    case PoiType.truckStop:
      return 'Truck Stop';
    case PoiType.parking:
      return 'Parking';
  }
}

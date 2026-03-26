import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../state/app_state.dart';
import '../navigation_screen.dart';
import '../theme/app_theme.dart';
import 'poi_browser_sheet.dart';
import 'poi_detail_sheet.dart';
import 'where_to_sheet.dart';

/// POI Hub bottom sheet — TruckPath-style tabbed entry point.
///
/// Presents four tabs so the driver can quickly find what they need:
///
/// 1. **Quick** – category grid (tap a tile to filter the map and open
///    the full browser) plus extras, matching the previous hub layout.
/// 2. **Stops** – live list of nearby truck stops, fuel stations, and rest
///    areas loaded into [AppState.pois], sorted by straight-line distance.
/// 3. **Services** – nearby parking lots, gyms, weigh stations, and
///    roadside assistance providers.
/// 4. **List** – all loaded POIs in a single distance-sorted list, giving a
///    combined view similar to TruckPath's result list.
///
/// All existing [PoiType] categories are still reachable; no features are
/// removed.
class PoiHubSheet extends StatelessWidget {
  const PoiHubSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return DefaultTabController(
          length: 4,
          child: DraggableScrollableSheet(
            initialChildSize: 0.72,
            minChildSize: 0.45,
            maxChildSize: 0.95,
            expand: false,
            builder: (context, scrollController) {
              final cs = Theme.of(context).colorScheme;
              return Column(
                children: [
                  // ── Drag handle ────────────────────────────────────────
                  const SizedBox(height: AppTheme.spaceSM),
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSM),

                  // ── Search / destination header ──────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD,
                    ),
                    child: _SearchHeader(
                      onTap: () => _openWhereTo(context),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXS),

                  // ── Tab bar ──────────────────────────────────────────
                  TabBar(
                    isScrollable: false,
                    labelPadding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceXS,
                    ),
                    tabs: const [
                      Tab(text: 'Quick'),
                      Tab(text: 'Stops'),
                      Tab(text: 'Services'),
                      Tab(text: 'List'),
                    ],
                  ),

                  // ── Tab content ──────────────────────────────────────
                  Expanded(
                    child: TabBarView(
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        // Tab 0 – Quick (category grid)
                        _QuickTab(
                          state: state,
                          scrollController: scrollController,
                          onCategoryTap: (cat) =>
                              _onCategoryTap(context, state, cat),
                        ),

                        // Tab 1 – Stops
                        _PoiListTab(
                          key: const Key('poi_hub_tab_stops'),
                          state: state,
                          filterTypes: const {
                            PoiType.truckStop,
                            PoiType.fuel,
                            PoiType.restArea,
                          },
                          emptyLabel: 'No truck stops, fuel, or rest areas loaded.\n'
                              'Tap a category on the Quick tab to load nearby stops.',
                        ),

                        // Tab 2 – Services
                        _PoiListTab(
                          key: const Key('poi_hub_tab_services'),
                          state: state,
                          filterTypes: const {
                            PoiType.parking,
                            PoiType.gym,
                            PoiType.scale,
                            PoiType.roadsideAssistance,
                          },
                          emptyLabel: 'No services loaded.\n'
                              'Tap a category on the Quick tab to load nearby services.',
                        ),

                        // Tab 3 – List (all results)
                        _PoiListTab(
                          key: const Key('poi_hub_tab_list'),
                          state: state,
                          filterTypes: null, // all types
                          emptyLabel: 'No POIs loaded yet.\n'
                              'Use the Quick tab or the Layers button to load nearby POIs.',
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _openWhereTo(BuildContext context) async {
    HapticFeedback.selectionClick();
    await showWhereToSheet(context);
  }

  void _onCategoryTap(
    BuildContext context,
    AppState state,
    _PoiCategory category,
  ) {
    HapticFeedback.selectionClick();

    switch (category) {
      case _PoiCategory.truckStops:
        _openPoiLayer(context, state, PoiType.truckStop);
      case _PoiCategory.weighStations:
        _openPoiLayer(context, state, PoiType.scale);
      case _PoiCategory.parking:
        _openPoiLayer(context, state, PoiType.parking);
      case _PoiCategory.fuel:
        _openPoiLayer(context, state, PoiType.fuel);
      case _PoiCategory.restAreas:
        _openPoiLayer(context, state, PoiType.restArea);
      case _PoiCategory.walmarts:
      case _PoiCategory.truckWashes:
        _showComingSoon(context, category.label);
      case _PoiCategory.more:
        _openFullBrowser(context);
    }
  }

  /// Enable the given [PoiType] layer and open the POI browser.
  void _openPoiLayer(BuildContext context, AppState state, PoiType type) {
    // Enable the layer if it is not already on.
    if (!state.enabledPoiLayers.contains(type)) {
      state.toggleLayer(type, true);
    }
    // Trigger a fresh POI load so results appear immediately.
    state.loadPois();
    // Navigate to the full POI browser (which respects the enabled layers).
    Navigator.pop(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: state,
        child: const PoiBrowserSheet(),
      ),
    );
  }

  void _openFullBrowser(BuildContext context) {
    final state = context.read<AppState>();
    Navigator.pop(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: state,
        child: const PoiBrowserSheet(),
      ),
    );
  }

  void _showComingSoon(BuildContext context, String name) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name — Coming soon'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick tab
// ---------------------------------------------------------------------------

/// The "Quick" tab: shows the [_RouteSummaryRow] (if a route is active),
/// the [_CategoryGrid], and the [_ExtrasSection].  Mirrors the previous
/// [PoiHubSheet] layout so no functionality is removed.
class _QuickTab extends StatelessWidget {
  const _QuickTab({
    required this.state,
    required this.scrollController,
    required this.onCategoryTap,
  });

  final AppState state;
  final ScrollController scrollController;
  final void Function(_PoiCategory) onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceMD,
        AppTheme.spaceSM,
        AppTheme.spaceMD,
        AppTheme.spaceLG,
      ),
      children: [
        // Route summary row (visible when route loaded)
        if (state.routeResult != null) ...[
          _RouteSummaryRow(state: state),
          const SizedBox(height: AppTheme.spaceMD),
        ],

        // Category grid
        Text(
          'FIND NEARBY',
          key: const Key('poi_hub_find_nearby_label'),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        _CategoryGrid(
          key: const Key('poi_hub_category_grid'),
          onCategoryTap: onCategoryTap,
        ),
        const SizedBox(height: AppTheme.spaceLG),

        // Extras
        const _ExtrasSection(),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// POI list tab (Stops / Services / List)
// ---------------------------------------------------------------------------

/// A scrollable list of [Poi] objects filtered by [filterTypes] and sorted
/// by straight-line distance from the current location.
///
/// Pass `filterTypes = null` to show ALL loaded POIs (used by the "List" tab).
class _PoiListTab extends StatelessWidget {
  const _PoiListTab({
    super.key,
    required this.state,
    required this.filterTypes,
    required this.emptyLabel,
  });

  final AppState state;
  final Set<PoiType>? filterTypes;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    final myLat = state.myLat;
    final myLng = state.myLng;

    // Filter and sort POIs.
    final all = state.pois;
    final filtered = filterTypes == null
        ? List<Poi>.from(all)
        : all.where((p) => filterTypes!.contains(p.type)).toList();

    if (myLat != null && myLng != null) {
      filtered.sort((a, b) {
        final da = Geolocator.distanceBetween(myLat, myLng, a.lat, a.lng);
        final db = Geolocator.distanceBetween(myLat, myLng, b.lat, b.lng);
        return da.compareTo(db);
      });
    }

    if (filtered.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Center(
          child: Text(
            emptyLabel,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSM,
        vertical: AppTheme.spaceXS,
      ),
      itemCount: filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final poi = filtered[index];
        final dist = (myLat != null && myLng != null)
            ? Geolocator.distanceBetween(myLat, myLng, poi.lat, poi.lng)
            : null;
        return _PoiListTile(poi: poi, distanceMeters: dist);
      },
    );
  }
}

/// A single row in the POI list tabs.
class _PoiListTile extends StatelessWidget {
  const _PoiListTile({required this.poi, this.distanceMeters});

  final Poi poi;
  final double? distanceMeters;

  static String _formatDist(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      key: Key('poi_list_tile_${poi.id}'),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSM,
        vertical: AppTheme.spaceXS,
      ),
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Icon(
          PoiDetailSheet.poiIcon(poi.type),
          size: 18,
          color: cs.onPrimaryContainer,
        ),
      ),
      title: Text(poi.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        PoiDetailSheet.poiLabel(poi.type),
        style: TextStyle(color: cs.primary, fontSize: 12),
      ),
      trailing: distanceMeters != null
          ? Text(
              _formatDist(distanceMeters!),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            )
          : null,
      onTap: () {
        HapticFeedback.selectionClick();
        showModalBottomSheet<void>(
          context: context,
          builder: (_) => ChangeNotifierProvider.value(
            value: context.read<AppState>(),
            child: PoiDetailSheet(poi: poi),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// POI category descriptor
// ---------------------------------------------------------------------------

enum _PoiCategory {
  truckStops,
  weighStations,
  parking,
  fuel,
  restAreas,
  walmarts,
  truckWashes,
  more;

  String get label {
    switch (this) {
      case _PoiCategory.truckStops:
        return 'Truck Stops';
      case _PoiCategory.weighStations:
        return 'Weigh Stations';
      case _PoiCategory.parking:
        return 'Parking';
      case _PoiCategory.fuel:
        return 'Fuel';
      case _PoiCategory.restAreas:
        return 'Rest Areas';
      case _PoiCategory.walmarts:
        return 'Walmarts';
      case _PoiCategory.truckWashes:
        return 'Truck Washes';
      case _PoiCategory.more:
        return 'More';
    }
  }

  IconData get icon {
    switch (this) {
      case _PoiCategory.truckStops:
        return Icons.local_shipping_rounded;
      case _PoiCategory.weighStations:
        return Icons.scale_rounded;
      case _PoiCategory.parking:
        return Icons.local_parking_rounded;
      case _PoiCategory.fuel:
        return Icons.local_gas_station_rounded;
      case _PoiCategory.restAreas:
        return Icons.deck_rounded;
      case _PoiCategory.walmarts:
        return Icons.storefront_rounded;
      case _PoiCategory.truckWashes:
        return Icons.local_car_wash_rounded;
      case _PoiCategory.more:
        return Icons.apps_rounded;
    }
  }
}

// ---------------------------------------------------------------------------
// Search / destination header
// ---------------------------------------------------------------------------

class _SearchHeader extends StatelessWidget {
  const _SearchHeader({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      key: const Key('poi_hub_search_header'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceMD,
        ),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: cs.primary, size: 22),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: Text(
                'Set destination for truck routes',
                style: TextStyle(
                  fontSize: 15,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: cs.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Route summary row
// ---------------------------------------------------------------------------

class _RouteSummaryRow extends StatelessWidget {
  const _RouteSummaryRow({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final result = state.routeResult!;
    final distance = _formatDistance(result.lengthMeters);
    final duration = _formatDuration(result.durationSeconds);

    return Container(
      key: const Key('poi_hub_route_summary'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Row(
        children: [
          Icon(Icons.route_rounded, color: cs.onPrimaryContainer, size: 20),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  duration,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                Text(
                  distance,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onPrimaryContainer.withAlpha(200),
                  ),
                ),
              ],
            ),
          ),
          // Clear Trip
          TextButton(
            key: const Key('poi_hub_clear_trip_btn'),
            onPressed: () {
              HapticFeedback.selectionClick();
              state.clearRoute();
            },
            style: TextButton.styleFrom(
              foregroundColor: cs.onPrimaryContainer,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSM,
                vertical: AppTheme.spaceXS,
              ),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Clear Trip'),
          ),
          const SizedBox(width: AppTheme.spaceXS),
          // Go
          FilledButton(
            key: const Key('poi_hub_go_btn'),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              final ctx = context;
              await state.startNavigation();
              if (ctx.mounted) {
                await Navigator.of(ctx).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const NavigationScreen(),
                  ),
                );
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: cs.onPrimaryContainer,
              foregroundColor: cs.primaryContainer,
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceMD,
                vertical: AppTheme.spaceXS,
              ),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Go'),
          ),
        ],
      ),
    );
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

// ---------------------------------------------------------------------------
// Category grid
// ---------------------------------------------------------------------------

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({super.key, required this.onCategoryTap});

  final void Function(_PoiCategory) onCategoryTap;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppTheme.spaceSM,
      crossAxisSpacing: AppTheme.spaceSM,
      childAspectRatio: 0.85,
      children: _PoiCategory.values
          .map((cat) => _CategoryTile(
                category: cat,
                onTap: () => onCategoryTap(cat),
              ))
          .toList(),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.onTap,
  });

  final _PoiCategory category;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return InkWell(
      key: Key('poi_hub_tile_${category.name}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          border: Border.all(color: cs.outlineVariant, width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                category.icon,
                size: 22,
                color: cs.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: AppTheme.spaceXS),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppTheme.spaceXS),
              child: Text(
                category.label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Extras / placeholder section
// ---------------------------------------------------------------------------

class _ExtrasSection extends StatelessWidget {
  const _ExtrasSection({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EXTRAS',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
            color: cs.primary,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        _PlaceholderCard(
          icon: Icons.local_offer_rounded,
          title: 'Driver Discounts',
          subtitle: 'Fuel savings, rest stop deals & more — Coming soon',
          color: cs.primary,
        ),
        const SizedBox(height: AppTheme.spaceSM),
        _PlaceholderCard(
          icon: Icons.wb_cloudy_rounded,
          title: 'Weather Along Route',
          subtitle: 'Forecast for your route stops — Coming soon',
          color: cs.primary,
        ),
        const SizedBox(height: AppTheme.spaceSM),
        _PlaceholderCard(
          icon: Icons.share_rounded,
          title: 'Share My Experience',
          subtitle: 'Rate stops and share tips with fellow drivers — Coming soon',
          color: cs.primary,
        ),
      ],
    );
  }
}

class _PlaceholderCard extends StatelessWidget {
  const _PlaceholderCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        border: Border.all(color: cs.outlineVariant, width: 1),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withAlpha(30),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: AppTheme.spaceMD),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded,
              color: cs.onSurfaceVariant, size: 20),
        ],
      ),
    );
  }
}


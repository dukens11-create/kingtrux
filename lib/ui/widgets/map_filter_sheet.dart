import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../models/truck_stop_brand.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// A professional, tabbed bottom sheet for managing all truck-driver map filters.
///
/// Organized into four tabs:
/// 1. **Quick** – one-tap toggle for the most-used POI categories.
/// 2. **Stops & Chains** – brand-level filter for major truck stop chains
///    with Near Me / Along Route load buttons.
/// 3. **Services** – hotels, washes, repairs, tires, etc.
/// 4. **Dealers** – truck-manufacturer and service-brand dealers.
///
/// The sheet header exposes an **Add New Place** action (linked to a "Coming
/// soon" stub until the feature is built out).
class MapFilterSheet extends StatelessWidget {
  const MapFilterSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          final cs = Theme.of(context).colorScheme;
          return Column(
            children: [
              // ── Drag handle ──────────────────────────────────────────
              const SizedBox(height: AppTheme.spaceSM),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppTheme.spaceXS),

              // ── Sheet header: title + Add New Place ──────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMD,
                ),
                child: Row(
                  children: [
                    Icon(Icons.tune_rounded, color: cs.primary, size: 20),
                    const SizedBox(width: AppTheme.spaceSM),
                    Expanded(
                      child: Text(
                        'Truck Driver Filters',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      key: const Key('filter_sheet_add_place_btn'),
                      icon: const Icon(Icons.add_location_alt_rounded, size: 18),
                      label: const Text('Add Place'),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Add New Place — Coming soon'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceSM,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── Tab bar ──────────────────────────────────────────────
              TabBar(
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Quick'),
                  Tab(text: 'Stops & Chains'),
                  Tab(text: 'Services'),
                  Tab(text: 'Dealers'),
                ],
              ),

              // ── Tab content ──────────────────────────────────────────
              Expanded(
                child: TabBarView(
                  children: [
                    _QuickTab(scrollController: scrollController),
                    _StopsChainsTab(scrollController: scrollController),
                    _ServicesTab(scrollController: scrollController),
                    _DealersTab(scrollController: scrollController),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 1: Quick – most-used truck POI toggles
// ---------------------------------------------------------------------------

class _QuickTab extends StatelessWidget {
  const _QuickTab({required this.scrollController});

  final ScrollController scrollController;

  static const _categories = <_FilterEntry>[
    _FilterEntry(
      type: PoiType.truckStop,
      label: 'Truck Stops',
      icon: Icons.local_shipping_rounded,
    ),
    _FilterEntry(
      type: PoiType.fuel,
      label: 'Fuel Stations',
      icon: Icons.local_gas_station_rounded,
    ),
    _FilterEntry(
      type: PoiType.scale,
      label: 'Weigh Stations',
      icon: Icons.scale_rounded,
    ),
    _FilterEntry(
      type: PoiType.restArea,
      label: 'Rest Areas',
      icon: Icons.deck_rounded,
    ),
    _FilterEntry(
      type: PoiType.parking,
      label: 'Parking',
      icon: Icons.local_parking_rounded,
    ),
    // Facility (truck terminals/freight depots) will use a dedicated OSM query
    // in a future release; shown as Coming soon to avoid duplicate truckStop markers.
    _FilterEntry(
      type: PoiType.facility,
      label: 'Facility',
      icon: Icons.warehouse_rounded,
      comingSoon: true,
    ),
    _FilterEntry(
      type: PoiType.walmart,
      label: 'Walmarts',
      icon: Icons.storefront_rounded,
    ),
    _FilterEntry(
      type: PoiType.clearance,
      label: 'Clearance',
      icon: Icons.height_rounded,
      comingSoon: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMD,
            AppTheme.spaceMD,
            AppTheme.spaceMD,
            AppTheme.spaceLG,
          ),
          children: [
            _PoiCategoryGrid(
              entries: _categories,
              enabledLayers: state.enabledPoiLayers,
              onToggle: (type, value) {
                HapticFeedback.selectionClick();
                state.toggleLayer(type, value);
              },
            ),
            const SizedBox(height: AppTheme.spaceMD),
            _LoadButtons(state: state),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 2: Stops & Chains – brand-level filter
// ---------------------------------------------------------------------------

class _StopsChainsTab extends StatelessWidget {
  const _StopsChainsTab({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMD,
            AppTheme.spaceMD,
            AppTheme.spaceMD,
            AppTheme.spaceLG,
          ),
          children: [
            // Enable Truck Stops layer note
            if (!state.enabledPoiLayers.contains(PoiType.truckStop))
              Padding(
                padding: const EdgeInsets.only(bottom: AppTheme.spaceMD),
                child: _InfoBanner(
                  icon: Icons.info_outline_rounded,
                  message: 'Enable Truck Stops in the Quick tab to load branded stops.',
                ),
              ),

            Text(
              'BRAND FILTER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSM),

            // Brand checkboxes displayed as compact wrapped chips
            Wrap(
              spacing: AppTheme.spaceSM,
              runSpacing: AppTheme.spaceXS,
              children: TruckStopBrand.values.map((brand) {
                final enabled = state.enabledTruckStopBrands.contains(brand);
                return FilterChip(
                  key: Key('brand_chip_${brand.name}'),
                  label: Text(brand.displayName),
                  selected: enabled,
                  onSelected: (value) {
                    HapticFeedback.selectionClick();
                    state.toggleTruckStopBrand(brand, value);
                  },
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                );
              }).toList(),
            ),

            const SizedBox(height: AppTheme.spaceMD),
            _LoadButtons(state: state),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 3: Services
// ---------------------------------------------------------------------------

class _ServicesTab extends StatelessWidget {
  const _ServicesTab({required this.scrollController});

  final ScrollController scrollController;

  static const _categories = <_FilterEntry>[
    _FilterEntry(
      type: PoiType.hotel,
      label: 'Hotels',
      icon: Icons.hotel_rounded,
    ),
    _FilterEntry(
      type: PoiType.truckWash,
      label: 'Truck Washes',
      icon: Icons.local_car_wash_rounded,
    ),
    _FilterEntry(
      type: PoiType.repairShop,
      label: 'Repair Shops',
      icon: Icons.build_rounded,
    ),
    _FilterEntry(
      type: PoiType.tires,
      label: 'Tires',
      icon: Icons.tire_repair_rounded,
    ),
    // Speedco and Thermo King will use brand-level filter queries in a future
    // release; marked comingSoon to avoid toggling all repair shops inadvertently.
    _FilterEntry(
      type: PoiType.repairShop,
      label: 'Speedco',
      icon: Icons.speed_rounded,
      comingSoon: true,
    ),
    _FilterEntry(
      type: PoiType.repairShop,
      label: 'Thermo King',
      icon: Icons.ac_unit_rounded,
      comingSoon: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMD,
            AppTheme.spaceMD,
            AppTheme.spaceMD,
            AppTheme.spaceLG,
          ),
          children: [
            _PoiCategoryGrid(
              entries: _categories,
              enabledLayers: state.enabledPoiLayers,
              onToggle: (type, value) {
                HapticFeedback.selectionClick();
                state.toggleLayer(type, value);
              },
            ),
            const SizedBox(height: AppTheme.spaceMD),
            _LoadButtons(state: state),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Tab 4: Dealers
// ---------------------------------------------------------------------------

class _DealersTab extends StatelessWidget {
  const _DealersTab({required this.scrollController});

  final ScrollController scrollController;

  static const _dealerBrands = <_DealerEntry>[
    _DealerEntry(label: 'Volvo', icon: Icons.directions_bus_rounded),
    _DealerEntry(label: 'Freightliner', icon: Icons.local_shipping_rounded),
    _DealerEntry(label: 'Kenworth', icon: Icons.local_shipping_rounded),
    _DealerEntry(label: 'Peterbilt', icon: Icons.local_shipping_rounded),
    _DealerEntry(label: 'International', icon: Icons.local_shipping_rounded),
    _DealerEntry(label: 'Mack', icon: Icons.local_shipping_rounded),
    _DealerEntry(label: 'Utility Trailers', icon: Icons.inventory_rounded),
    _DealerEntry(label: 'Carrier', icon: Icons.ac_unit_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final cs = Theme.of(context).colorScheme;
        final isDealerEnabled =
            state.enabledPoiLayers.contains(PoiType.truckDealer);
        return ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMD,
            AppTheme.spaceMD,
            AppTheme.spaceMD,
            AppTheme.spaceLG,
          ),
          children: [
            // Master toggle for Truck Dealer layer
            SwitchListTile(
              key: const Key('dealer_layer_toggle'),
              secondary: Icon(
                Icons.directions_bus_rounded,
                color: cs.primary,
              ),
              title: const Text('Truck Dealers'),
              subtitle: const Text('Show dealer locations on map'),
              value: isDealerEnabled,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                state.toggleLayer(PoiType.truckDealer, value);
              },
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: AppTheme.spaceSM),

            Text(
              'BRANDS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: AppTheme.spaceSM),

            // Dealer brand grid (all wired to the single truckDealer layer
            // toggle; brand-level filtering is planned for a future release)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: AppTheme.spaceSM,
                crossAxisSpacing: AppTheme.spaceSM,
                childAspectRatio: 0.85,
              ),
              itemCount: _dealerBrands.length,
              itemBuilder: (context, index) {
                final entry = _dealerBrands[index];
                return InkWell(
                  key: Key('dealer_tile_${entry.label.toLowerCase().replaceAll(' ', '_')}'),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    // Enable the truck dealer layer when tapping a brand tile
                    if (!isDealerEnabled) {
                      state.toggleLayer(PoiType.truckDealer, true);
                    }
                    state.loadPois();
                    Navigator.pop(context);
                  },
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusMD),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDealerEnabled
                          ? cs.primaryContainer.withAlpha(80)
                          : cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      border: Border.all(
                        color: cs.outlineVariant,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: cs.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            entry.icon,
                            size: 20,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(height: AppTheme.spaceXS),
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceXS,
                          ),
                          child: Text(
                            entry.label,
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
              },
            ),

            const SizedBox(height: AppTheme.spaceMD),
            _LoadButtons(state: state),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// Immutable descriptor for a single filter category in the Quick / Services
/// tabs.
class _FilterEntry {
  const _FilterEntry({
    required this.type,
    required this.label,
    required this.icon,
    this.comingSoon = false,
  });

  final PoiType type;
  final String label;
  final IconData icon;
  final bool comingSoon;
}

/// Immutable descriptor for a dealer brand tile.
class _DealerEntry {
  const _DealerEntry({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;
}

/// A 4-column grid of toggleable POI category tiles.
class _PoiCategoryGrid extends StatelessWidget {
  const _PoiCategoryGrid({
    required this.entries,
    required this.enabledLayers,
    required this.onToggle,
  });

  final List<_FilterEntry> entries;
  final Set<PoiType> enabledLayers;
  final void Function(PoiType type, bool value) onToggle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppTheme.spaceSM,
        crossAxisSpacing: AppTheme.spaceSM,
        childAspectRatio: 0.85,
      ),
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final entry = entries[index];
        final isEnabled = !entry.comingSoon &&
            enabledLayers.contains(entry.type);
        return Semantics(
          label: entry.label,
          toggled: isEnabled,
          button: true,
          child: InkWell(
            key: Key('filter_tile_${entry.label.toLowerCase().replaceAll(' ', '_')}'),
            onTap: () {
              if (entry.comingSoon) {
                HapticFeedback.selectionClick();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${entry.label} — Coming soon'),
                    duration: const Duration(seconds: 2),
                  ),
                );
                return;
              }
              onToggle(entry.type, !isEnabled);
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            child: Container(
              decoration: BoxDecoration(
                color: isEnabled
                    ? cs.primaryContainer.withAlpha(80)
                    : cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                border: Border.all(
                  color: isEnabled ? cs.primary : cs.outlineVariant,
                  width: isEnabled ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? cs.primaryContainer
                          : cs.surfaceContainerHighest,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      entry.icon,
                      size: 20,
                      color: isEnabled
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceXS),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceXS,
                    ),
                    child: Text(
                      entry.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: isEnabled ? cs.onSurface : cs.onSurfaceVariant,
                        height: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Near Me / Along Route load buttons shared by all tabs.
class _LoadButtons extends StatelessWidget {
  const _LoadButtons({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            key: const Key('filter_sheet_near_me_btn'),
            icon: const Icon(Icons.my_location_rounded, size: 18),
            label: const Text('Near Me'),
            onPressed:
                state.enabledPoiLayers.isEmpty || state.isLoadingPois
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        state.loadPois();
                        Navigator.pop(context);
                      },
          ),
        ),
        const SizedBox(width: AppTheme.spaceSM),
        Expanded(
          child: FilledButton.icon(
            key: const Key('filter_sheet_along_route_btn'),
            icon: const Icon(Icons.route_rounded, size: 18),
            label: const Text('Along Route'),
            onPressed: state.enabledPoiLayers.isEmpty ||
                    state.isLoadingPois ||
                    state.routeResult == null
                ? null
                : () {
                    HapticFeedback.lightImpact();
                    state.loadPoisAlongRoute();
                    Navigator.pop(context);
                  },
          ),
        ),
      ],
    );
  }
}

/// A small informational banner shown when a prerequisite layer is off.
class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceSM,
      ),
      decoration: BoxDecoration(
        color: cs.secondaryContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: cs.onSecondaryContainer),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.onSecondaryContainer,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../state/app_state.dart';
import '../more_page.dart';
import '../navigation_screen.dart';
import '../theme/app_theme.dart';
import 'poi_browser_sheet.dart';

// ---------------------------------------------------------------------------
// POI Hub Sheet
// ---------------------------------------------------------------------------

/// A redesigned full-height POI discovery sheet that acts as a hub for
/// accessing different categories of truck-relevant Points of Interest.
///
/// Layout (top → bottom):
/// 1. Drag handle
/// 2. Destination search bar (mirrors "Set destination" CTA)
/// 3. Route summary row with **Clear Trip** / **Go** (when route is active)
/// 4. 4×2 category grid (Truck Stops, Weigh Stations, Parking, Fuel,
///    Rest Areas, Walmarts, Truck Washes, More)
///
/// Tapping a supported category enables the corresponding POI layer and
/// opens [PoiBrowserSheet] filtered to that type.
/// Unsupported categories show a "Coming soon" [SnackBar].
/// Tapping **More** pushes the full-screen [MorePage].
class PoiHubSheet extends StatelessWidget {
  const PoiHubSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: AppTheme.spaceSM),

                // ── Destination search bar ────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                  ),
                  child: _DestinationBar(state: state),
                ),
                const SizedBox(height: AppTheme.spaceSM),

                // ── Route summary (only when a route is active) ───────────
                if (state.routeResult != null || state.isLoadingRoute)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD,
                    ),
                    child: _RouteSummaryRow(state: state),
                  ),

                if (state.routeResult != null || state.isLoadingRoute)
                  const SizedBox(height: AppTheme.spaceSM),

                // ── Section label ─────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'CATEGORIES',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),

                // ── Category grid ────────────────────────────────────────
                Expanded(
                  child: SingleChildScrollView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD,
                    ),
                    child: _CategoryGrid(state: state),
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
// Destination bar
// ---------------------------------------------------------------------------

/// A search-style bar that prompts the user to set a truck destination.
/// Tapping it dismisses this sheet and lets the map handle destination setting
/// via the existing CTA mechanism.
class _DestinationBar extends StatelessWidget {
  const _DestinationBar({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
          border: Border.all(color: cs.outline.withOpacity(0.3)),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceSM + 2,
        ),
        child: Row(
          children: [
            Icon(Icons.local_shipping_rounded, color: cs.primary, size: 20),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: Text(
                'Set destination for truck routes',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
              ),
            ),
            Icon(Icons.search_rounded, color: cs.onSurfaceVariant, size: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Route summary row
// ---------------------------------------------------------------------------

/// Compact route info row shown at the top of the hub when a route is loaded.
/// Provides one-tap **Clear Trip** and **Go** (start navigation) actions.
class _RouteSummaryRow extends StatelessWidget {
  const _RouteSummaryRow({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (state.isLoadingRoute) {
      return Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Text('Calculating route…',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      );
    }

    final result = state.routeResult!;
    final miles = result.lengthMeters * 0.000621371;
    final mins = result.durationSeconds ~/ 60;
    final hours = mins ~/ 60;
    final remaining = mins % 60;
    final durationLabel =
        hours > 0 ? '${hours}h ${remaining}m' : '${mins}m';

    return Row(
      children: [
        Icon(Icons.route_rounded, color: cs.primary, size: 20),
        const SizedBox(width: AppTheme.spaceXS),
        Expanded(
          child: Text(
            '${miles.toStringAsFixed(1)} mi · $durationLabel',
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        // Clear Trip
        OutlinedButton(
          onPressed: () {
            HapticFeedback.selectionClick();
            state.clearRoute();
            Navigator.of(context).pop();
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: cs.error,
            side: BorderSide(color: cs.error.withOpacity(0.6)),
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceSM + 2,
              vertical: AppTheme.spaceXS,
            ),
            minimumSize: Size.zero,
          ),
          child: const Text('Clear Trip'),
        ),
        const SizedBox(width: AppTheme.spaceSM),
        // Go
        FilledButton(
          onPressed: () async {
            HapticFeedback.mediumImpact();
            Navigator.of(context).pop();
            await state.startNavigation();
            if (context.mounted) {
              await Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const NavigationScreen(),
                ),
              );
            }
          },
          style: FilledButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMD,
              vertical: AppTheme.spaceXS,
            ),
            minimumSize: Size.zero,
          ),
          child: const Text('Go'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Category grid
// ---------------------------------------------------------------------------

/// 4×2 grid of [_CategoryTile] items for the 8 main POI categories.
class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final categories = _poiCategories(context);
    return GridView.builder(
      key: const Key('poi_hub_grid'),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        mainAxisSpacing: AppTheme.spaceSM,
        crossAxisSpacing: AppTheme.spaceSM,
        childAspectRatio: 0.85,
      ),
      itemCount: categories.length,
      itemBuilder: (context, index) {
        final cat = categories[index];
        return _CategoryTile(
          icon: cat.icon,
          label: cat.label,
          onTap: cat.onTap,
        );
      },
    );
  }

  /// Builds the list of category items, wiring supported ones to POI layers
  /// and unsupported ones to a "Coming soon" snack bar.
  List<_CategoryItem> _poiCategories(BuildContext context) {
    return [
      _CategoryItem(
        icon: Icons.local_shipping_rounded,
        label: 'Truck Stops',
        onTap: () => _openPoiLayer(context, PoiType.truckStop),
      ),
      _CategoryItem(
        icon: Icons.scale_rounded,
        label: 'Weigh\nStations',
        onTap: () => _openPoiLayer(context, PoiType.scale),
      ),
      _CategoryItem(
        icon: Icons.local_parking_rounded,
        label: 'Parking',
        onTap: () => _openPoiLayer(context, PoiType.parking),
      ),
      _CategoryItem(
        icon: Icons.local_gas_station_rounded,
        label: 'Fuel',
        onTap: () => _openPoiLayer(context, PoiType.fuel),
      ),
      _CategoryItem(
        icon: Icons.deck_rounded,
        label: 'Rest Areas',
        onTap: () => _openPoiLayer(context, PoiType.restArea),
      ),
      _CategoryItem(
        icon: Icons.store_rounded,
        label: 'Walmarts',
        onTap: () => _showComingSoon(context, 'Walmarts'),
      ),
      _CategoryItem(
        icon: Icons.local_car_wash_rounded,
        label: 'Truck\nWashes',
        onTap: () => _showComingSoon(context, 'Truck Washes'),
      ),
      _CategoryItem(
        icon: Icons.more_horiz_rounded,
        label: 'More',
        onTap: () => _openMorePage(context),
      ),
    ];
  }

  /// Enables the given [type] layer and opens [PoiBrowserSheet] filtered to it.
  void _openPoiLayer(BuildContext context, PoiType type) {
    HapticFeedback.selectionClick();
    // Ensure the layer is enabled before opening the browser.
    if (!state.enabledPoiLayers.contains(type)) {
      state.toggleLayer(type, true);
    }
    Navigator.of(context).pop();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: state,
        child: const PoiBrowserSheet(),
      ),
    );
  }

  /// Shows a "Coming soon" snack bar for unimplemented categories.
  void _showComingSoon(BuildContext context, String feature) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature – Coming soon'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Dismisses the hub and pushes the full-screen [MorePage].
  void _openMorePage(BuildContext context) {
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const MorePage()),
    );
  }
}

// ---------------------------------------------------------------------------
// Category tile
// ---------------------------------------------------------------------------

class _CategoryItem {
  const _CategoryItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

/// A single icon + label tile shown in [_CategoryGrid].
class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
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
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceSM),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 28, color: cs.primary),
              const SizedBox(height: AppTheme.spaceXS),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

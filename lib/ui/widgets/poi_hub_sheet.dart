import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../state/app_state.dart';
import '../more_poi_screen.dart';
import '../navigation_screen.dart';
import '../theme/app_theme.dart';
import 'poi_browser_sheet.dart';
import 'where_to_sheet.dart';

/// POI hub bottom sheet displaying a category-grid entry point.
///
/// Replaces [PoiBrowserSheet] as the main "Places" action entry point from
/// the map screen.  The driver picks a category, the corresponding POI layer
/// is enabled, and [PoiBrowserSheet] opens filtered to that type.
///
/// Tapping **More** pushes the full-screen [MorePoiScreen].
class PoiHubSheet extends StatelessWidget {
  const PoiHubSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // ── Drag handle ───────────────────────────────────────────
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

                // ── Search / destination bar ──────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                  ),
                  child: InkWell(
                    key: const Key('poi_hub_search_bar'),
                    onTap: () async {
                      HapticFeedback.selectionClick();
                      Navigator.of(context).pop();
                      await showWhereToSheet(context);
                    },
                    borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                    child: Container(
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius:
                            BorderRadius.circular(AppTheme.radiusLG),
                        border: Border.all(color: cs.outlineVariant),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMD,
                        vertical: AppTheme.spaceSM + 2,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.search_rounded,
                            color: cs.onSurfaceVariant,
                            size: 22,
                          ),
                          const SizedBox(width: AppTheme.spaceSM),
                          Expanded(
                            child: Text(
                              'Set destination for truck routes',
                              style: tt.bodyLarge
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ),
                          Icon(
                            Icons.local_shipping_rounded,
                            color: cs.primary,
                            size: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Route summary row (only when a route is active) ───────
                if (state.routeResult != null) ...[
                  const SizedBox(height: AppTheme.spaceSM),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD,
                    ),
                    child: _RouteSummaryRow(state: state),
                  ),
                ],

                const SizedBox(height: AppTheme.spaceMD),
                const Divider(height: 1),
                const SizedBox(height: AppTheme.spaceXS),

                // ── Category grid ─────────────────────────────────────────
                Expanded(
                  child: GridView.count(
                    controller: scrollController,
                    crossAxisCount: 4,
                    childAspectRatio: 0.85,
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spaceMD,
                      AppTheme.spaceSM,
                      AppTheme.spaceMD,
                      AppTheme.spaceMD,
                    ),
                    mainAxisSpacing: AppTheme.spaceSM,
                    crossAxisSpacing: AppTheme.spaceSM,
                    children: [
                      _CategoryTile(
                        key: const Key('poi_hub_truck_stops'),
                        icon: Icons.local_shipping_rounded,
                        label: 'Truck Stops',
                        onTap: () =>
                            _openCategory(context, state, PoiType.truckStop),
                      ),
                      _CategoryTile(
                        key: const Key('poi_hub_weigh_stations'),
                        icon: Icons.scale_rounded,
                        label: 'Weigh Stations',
                        onTap: () =>
                            _openCategory(context, state, PoiType.scale),
                      ),
                      _CategoryTile(
                        key: const Key('poi_hub_parking'),
                        icon: Icons.local_parking_rounded,
                        label: 'Parking',
                        onTap: () =>
                            _openCategory(context, state, PoiType.parking),
                      ),
                      _CategoryTile(
                        key: const Key('poi_hub_fuel'),
                        icon: Icons.local_gas_station_rounded,
                        label: 'Fuel',
                        onTap: () =>
                            _openCategory(context, state, PoiType.fuel),
                      ),
                      _CategoryTile(
                        key: const Key('poi_hub_rest_areas'),
                        icon: Icons.deck_rounded,
                        label: 'Rest Areas',
                        onTap: () =>
                            _openCategory(context, state, PoiType.restArea),
                      ),
                      _CategoryTile(
                        key: const Key('poi_hub_walmarts'),
                        icon: Icons.store_rounded,
                        label: 'Walmarts',
                        onTap: () => _showComingSoon(context, 'Walmarts'),
                      ),
                      _CategoryTile(
                        key: const Key('poi_hub_truck_washes'),
                        icon: Icons.local_car_wash_rounded,
                        label: 'Truck Washes',
                        onTap: () => _showComingSoon(context, 'Truck Washes'),
                      ),
                      _CategoryTile(
                        key: const Key('poi_hub_more'),
                        icon: Icons.more_horiz_rounded,
                        label: 'More',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          final rootNav =
                              Navigator.of(context, rootNavigator: true);
                          Navigator.of(context).pop();
                          rootNav.push<void>(
                            MaterialPageRoute<void>(
                              builder: (_) => const MorePoiScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Enables [type]'s POI layer, loads POIs near the user, then opens the
  /// [PoiBrowserSheet] so the driver can see the results.
  void _openCategory(
    BuildContext context,
    AppState state,
    PoiType type,
  ) {
    HapticFeedback.selectionClick();
    state.toggleLayer(type, true);
    // Capture the navigator's overlay context before popping so we can open
    // the next sheet from a valid BuildContext after this sheet is dismissed.
    final overlayCtx = Navigator.of(context).overlay!.context;
    Navigator.of(context).pop();
    state.loadPois();
    showModalBottomSheet<void>(
      context: overlayCtx,
      isScrollControlled: true,
      builder: (_) => const PoiBrowserSheet(),
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature – Coming soon'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Route summary row (shown inside hub when a route is active)
// ---------------------------------------------------------------------------

class _RouteSummaryRow extends StatelessWidget {
  const _RouteSummaryRow({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final result = state.routeResult!;

    return Row(
      children: [
        Icon(Icons.route_rounded, color: cs.primary, size: 20),
        const SizedBox(width: AppTheme.spaceSM),
        Expanded(
          child: Text(
            '${_formatDuration(result.durationSeconds)}'
            '  ·  '
            '${_formatDistance(result.lengthMeters)}',
            style:
                tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        TextButton(
          key: const Key('poi_hub_clear_trip'),
          onPressed: () {
            HapticFeedback.selectionClick();
            state.clearRoute();
            Navigator.of(context).pop();
          },
          style: TextButton.styleFrom(
            foregroundColor: cs.error,
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceSM,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Clear Trip'),
        ),
        const SizedBox(width: AppTheme.spaceXS),
        FilledButton.icon(
          key: const Key('poi_hub_go'),
          onPressed: () async {
            HapticFeedback.mediumImpact();
            final nav = Navigator.of(context, rootNavigator: true);
            Navigator.of(context).pop();
            await state.startNavigation();
            await nav.push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const NavigationScreen(),
              ),
            );
          },
          icon: const Icon(Icons.navigation_rounded, size: 16),
          label: const Text('Go'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceSM,
              vertical: AppTheme.spaceXS,
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }

  static String _formatDistance(double meters) {
    final miles = meters * 0.000621371;
    return '${miles.toStringAsFixed(1)} mi';
  }

  static String _formatDuration(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    return hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
  }
}

// ---------------------------------------------------------------------------
// Category tile
// ---------------------------------------------------------------------------

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
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

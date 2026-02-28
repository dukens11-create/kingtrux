import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import 'poi_detail_sheet.dart';

/// Full POI browser bottom sheet.
///
/// Combines category filter toggles with a **Near Me / Along Route** discovery
/// selector and a scrollable list of loaded POIs.
///
/// ## How POI loading works
/// 1. The user selects one or more category chips (Fuel, Truck Stop, etc.).
/// 2. The user taps **"Load POIs Near Me"** (or "Load Along Route" when a
///    route is active) to trigger a query against the Overpass API via
///    [AppState.loadPois] / [AppState.loadPoisAlongRoute].
/// 3. Results are displayed in the scrollable list below the controls.
///    Tapping a row opens [PoiDetailSheet] for full details and navigation.
///
/// ## Pinned Favorites
/// POIs already in [AppState.favoritePois] that match the current query are
/// surfaced in a dedicated **Favorites** section above the full list.
class PoiBrowserSheet extends StatefulWidget {
  const PoiBrowserSheet({super.key});

  @override
  State<PoiBrowserSheet> createState() => _PoiBrowserSheetState();
}

class _PoiBrowserSheetState extends State<PoiBrowserSheet> {
  /// 0 = Near Me, 1 = Along Route
  int _modeIndex = 0;

  /// When `true` only POIs whose [_isOpenNow] check passes are shown.
  bool _filterOpenNow = false;

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Returns `true` when [poi]'s `opening_hours` tag suggests it is currently
  /// open.  Applies only the simple "24/7" case and the numeric-range pattern
  /// `HH:MM-HH:MM`; anything else is considered unknown → shown as open to
  /// avoid false negatives.
  static bool _isOpenNow(Poi poi) {
    final hours = poi.tags['opening_hours'] as String?;
    if (hours == null || hours.isEmpty) return true; // unknown → show
    final normalized = hours.trim().toLowerCase();
    if (normalized == '24/7') return true;
    final now = DateTime.now();
    final match = RegExp(r'^(\d{2}):(\d{2})-(\d{2}):(\d{2})$')
        .firstMatch(normalized);
    if (match == null) return true; // complex rule → show
    final openH = int.parse(match.group(1)!);
    final openM = int.parse(match.group(2)!);
    final closeH = int.parse(match.group(3)!);
    final closeM = int.parse(match.group(4)!);
    final nowMins = now.hour * 60 + now.minute;
    final openMins = openH * 60 + openM;
    var closeMins = closeH * 60 + closeM;
    // Handle overnight ranges (e.g., 22:00-06:00)
    if (closeMins < openMins) closeMins += 24 * 60;
    return nowMins >= openMins && nowMins < closeMins;
  }

  /// Returns `true` when any POI in [pois] has `opening_hours` data, so we
  /// can decide whether to show the "Open Now" filter chip.
  static bool _hasHoursData(List<Poi> pois) =>
      pois.any((p) => (p.tags['opening_hours'] as String?) != null);

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final cs = Theme.of(context).colorScheme;

        // POIs visible under current layer filters
        var visiblePois = state.pois
            .where((p) => state.enabledPoiLayers.contains(p.type))
            .where(state.isTruckStopBrandVisible)
            .toList();

        // Apply "Open Now" filter if active
        if (_filterOpenNow) {
          visiblePois = visiblePois.where(_isOpenNow).toList();
        }

        // Pinned favorites: intersection of favoritePois and visiblePois
        final favPois = visiblePois
            .where((p) => state.favoritePois.contains(p.id))
            .toList();

        final showOpenNowChip = _hasHoursData(state.pois);

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.92,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // Drag handle
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

                // Title
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

                // Mode selector
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
                      ),
                      ButtonSegment(
                        value: 1,
                        label: const Text('Along Route'),
                        icon: const Icon(Icons.route_rounded, size: 16),
                        enabled: state.routeResult != null,
                      ),
                    ],
                    selected: {_modeIndex},
                    onSelectionChanged: (sel) {
                      setState(() => _modeIndex = sel.first);
                    },
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),

                // Category filter chips + optional Open Now chip
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD,
                    ),
                    children: [
                      ...PoiType.values
                          // roadsideAssistance is served via the dedicated
                          // "Get Help" flow, not the generic POI browser.
                          .where((t) => t != PoiType.roadsideAssistance)
                          .map((type) {
                        final enabled = state.enabledPoiLayers.contains(type);
                        return Padding(
                          padding:
                              const EdgeInsets.only(right: AppTheme.spaceXS),
                          child: FilterChip(
                            avatar: Icon(
                              PoiDetailSheet.poiIcon(type),
                              size: 14,
                            ),
                            label: Text(PoiDetailSheet.poiLabel(type)),
                            selected: enabled,
                            onSelected: (value) {
                              HapticFeedback.selectionClick();
                              state.toggleLayer(type, value);
                            },
                          ),
                        );
                      }),
                      // "Open Now" chip – only shown when hours data is present
                      if (showOpenNowChip)
                        Padding(
                          padding:
                              const EdgeInsets.only(right: AppTheme.spaceXS),
                          child: FilterChip(
                            avatar: const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                            ),
                            label: const Text('Open Now'),
                            selected: _filterOpenNow,
                            onSelected: (value) {
                              HapticFeedback.selectionClick();
                              setState(() => _filterOpenNow = value);
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),

                // Load button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: Icon(
                        _modeIndex == 0
                            ? Icons.my_location_rounded
                            : Icons.route_rounded,
                        size: 18,
                      ),
                      label: Text(
                        _modeIndex == 0
                            ? 'Load POIs Near Me'
                            : 'Load Along Route',
                      ),
                      onPressed: state.enabledPoiLayers.isEmpty ||
                              state.isLoadingPois ||
                              (_modeIndex == 1 && state.routeResult == null)
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              if (_modeIndex == 0) {
                                state.loadPois();
                              } else {
                                state.loadPoisAlongRoute();
                              }
                            },
                    ),
                  ),
                ),

                const Divider(height: AppTheme.spaceLG),

                // POI list (favorites pinned on top, then full list)
                Expanded(
                  child: visiblePois.isEmpty
                      ? _buildEmptyState(context, state, cs)
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: favPois.isNotEmpty
                              ? favPois.length + 1 + visiblePois.length
                              : visiblePois.length,
                          itemBuilder: (context, index) {
                            if (favPois.isNotEmpty) {
                              if (index == 0) {
                                return _buildSectionHeader(
                                  context,
                                  cs,
                                  Icons.star_rounded,
                                  'Favorites',
                                  Colors.amber,
                                );
                              }
                              if (index <= favPois.length) {
                                return _buildPoiTile(
                                  context,
                                  state,
                                  cs,
                                  favPois[index - 1],
                                );
                              }
                              final poi =
                                  visiblePois[index - favPois.length - 1];
                              return _buildPoiTile(context, state, cs, poi);
                            }
                            return _buildPoiTile(
                              context,
                              state,
                              cs,
                              visiblePois[index],
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

  Widget _buildSectionHeader(
    BuildContext context,
    ColorScheme cs,
    IconData icon,
    String label,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceMD,
        AppTheme.spaceSM,
        AppTheme.spaceMD,
        AppTheme.spaceXS,
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: AppTheme.spaceXS),
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildPoiTile(
    BuildContext context,
    AppState state,
    ColorScheme cs,
    Poi poi,
  ) {
    final isFav = state.favoritePois.contains(poi.id);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Icon(
          PoiDetailSheet.poiIcon(poi.type),
          color: cs.onPrimaryContainer,
          size: 18,
        ),
      ),
      title: Text(poi.name),
      subtitle: Text(PoiDetailSheet.poiLabel(poi.type)),
      trailing: IconButton(
        tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
        icon: Icon(
          isFav ? Icons.star_rounded : Icons.star_border_rounded,
          color: isFav ? Colors.amber : cs.onSurfaceVariant,
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          state.toggleFavorite(poi.id);
        },
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        showModalBottomSheet<void>(
          context: context,
          builder: (_) => ChangeNotifierProvider.value(
            value: state,
            child: PoiDetailSheet(poi: poi),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppState state,
    ColorScheme cs,
  ) {
    final String msg;
    if (state.enabledPoiLayers.isEmpty) {
      msg = 'Enable at least one category above\nthen tap Load to fetch POIs.';
    } else if (state.isLoadingPois) {
      msg = 'Fetching POIs…';
    } else {
      msg = 'No POIs loaded yet.\nTap "Load POIs Near Me" to search.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

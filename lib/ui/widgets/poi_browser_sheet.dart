import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import 'poi_detail_sheet.dart';

/// Full POI browser bottom sheet.
///
/// Combines category filter toggles with a Near Me / Along Route discovery
/// selector and a scrollable list of loaded POIs.
class PoiBrowserSheet extends StatefulWidget {
  const PoiBrowserSheet({super.key});

  @override
  State<PoiBrowserSheet> createState() => _PoiBrowserSheetState();
}

class _PoiBrowserSheetState extends State<PoiBrowserSheet> {
  /// 0 = Near Me, 1 = Along Route
  int _modeIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final cs = Theme.of(context).colorScheme;

        // POIs visible under current layer filters
        final visiblePois = state.pois
            .where((p) => state.enabledPoiLayers.contains(p.type))
            .toList();

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

                // Category filter chips
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD,
                    ),
                    children: PoiType.values.map((type) {
                      final enabled = state.enabledPoiLayers.contains(type);
                      return Padding(
                        padding: const EdgeInsets.only(right: AppTheme.spaceXS),
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
                    }).toList(),
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
                        _modeIndex == 0 ? 'Load Near Me' : 'Load Along Route',
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

                // POI list
                Expanded(
                  child: visiblePois.isEmpty
                      ? _buildEmptyState(context, state, cs)
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: visiblePois.length,
                          itemBuilder: (context, index) {
                            final poi = visiblePois[index];
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
                                tooltip: isFav
                                    ? 'Remove from favorites'
                                    : 'Add to favorites',
                                icon: Icon(
                                  isFav
                                      ? Icons.star_rounded
                                      : Icons.star_border_rounded,
                                  color: isFav
                                      ? Colors.amber
                                      : cs.onSurfaceVariant,
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
      msg = 'No POIs loaded yet.\nTap Load to search.';
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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/poi.dart';
import '../../models/roadside_service_type.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Emergency bottom sheet that lists nearby roadside assistance providers.
///
/// Opened via the "Get Help" button.  Automatically fetches providers when
/// first shown and lets the driver filter by [RoadsideServiceType], call a
/// provider, navigate to one, or save it as a favourite.
class RoadsideAssistanceSheet extends StatefulWidget {
  const RoadsideAssistanceSheet({super.key});

  @override
  State<RoadsideAssistanceSheet> createState() =>
      _RoadsideAssistanceSheetState();
}

class _RoadsideAssistanceSheetState extends State<RoadsideAssistanceSheet> {
  /// Service types currently shown; empty means all types.
  final Set<RoadsideServiceType> _activeFilters = {};

  @override
  void initState() {
    super.initState();
    // Kick off the fetch immediately when the sheet opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.roadsideProviders.isEmpty && !state.isLoadingRoadside) {
        state.loadRoadsideProviders();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Consumer<AppState>(
      builder: (context, state, _) {
        final filtered = _filteredProviders(state);

        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.95,
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

                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: cs.errorContainer,
                        child: Icon(
                          Icons.emergency_rounded,
                          color: cs.onErrorContainer,
                        ),
                      ),
                      const SizedBox(width: AppTheme.spaceMD),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Get Help',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            Text(
                              'Nearby roadside services',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      // Refresh button
                      if (state.isLoadingRoadside)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        IconButton(
                          tooltip: 'Refresh',
                          icon: const Icon(Icons.refresh_rounded),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            state.loadRoadsideProviders();
                          },
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spaceSM),

                // Filter chips
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD,
                    ),
                    children: RoadsideServiceType.values.map((type) {
                      final active = _activeFilters.contains(type);
                      return Padding(
                        padding:
                            const EdgeInsets.only(right: AppTheme.spaceXS),
                        child: FilterChip(
                          avatar: Icon(type.icon, size: 14),
                          label: Text(type.displayName),
                          selected: active,
                          onSelected: (value) {
                            HapticFeedback.selectionClick();
                            setState(() {
                              if (value) {
                                _activeFilters.add(type);
                              } else {
                                _activeFilters.remove(type);
                              }
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const Divider(height: AppTheme.spaceLG),

                // Provider list
                Expanded(
                  child: state.isLoadingRoadside
                      ? const Center(child: CircularProgressIndicator())
                      : filtered.isEmpty
                          ? _buildEmpty(context, cs, state)
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: filtered.length,
                              itemBuilder: (context, i) =>
                                  _ProviderTile(provider: filtered[i]),
                            ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  List<Poi> _filteredProviders(AppState state) {
    if (_activeFilters.isEmpty) return state.roadsideProviders;
    return state.roadsideProviders
        .where((p) =>
            _activeFilters.contains(roadsideTypeFromTags(p.tags)))
        .toList();
  }

  Widget _buildEmpty(BuildContext context, ColorScheme cs, AppState state) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.car_repair, size: 48, color: cs.onSurfaceVariant),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              state.roadsideProviders.isEmpty
                  ? 'No providers found nearby.\nTry tapping refresh or search a wider area.'
                  : 'No providers match the selected filters.',
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
// Individual provider tile
// ---------------------------------------------------------------------------

class _ProviderTile extends StatelessWidget {
  const _ProviderTile({required this.provider});

  final Poi provider;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final cs = Theme.of(context).colorScheme;
        final isFav = state.favoritePois.contains(provider.id);
        final serviceType = roadsideTypeFromTags(provider.tags);
        final phone = provider.tags['phone'] as String? ??
            provider.tags['contact:phone'] as String?;
        final distanceText = _distanceText(state);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: cs.errorContainer,
            child: Icon(
              serviceType.icon,
              color: cs.onErrorContainer,
              size: 20,
            ),
          ),
          title: Text(
            provider.name,
            style: Theme.of(context).textTheme.titleSmall,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Text(
                serviceType.displayName,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.primary),
              ),
              if (distanceText != null) ...[
                Text(
                  ' · ',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
                Text(
                  distanceText,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: cs.onSurfaceVariant),
                ),
              ],
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Tap-to-call
              if (phone != null)
                IconButton(
                  tooltip: 'Call',
                  icon: Icon(Icons.phone_rounded,
                      color: cs.primary, size: 20),
                  onPressed: () => _call(phone),
                ),
              // Navigate
              IconButton(
                tooltip: 'Navigate',
                icon: Icon(Icons.navigation_rounded,
                    color: cs.primary, size: 20),
                onPressed: () => _navigate(context, state),
              ),
              // Favorite
              IconButton(
                tooltip:
                    isFav ? 'Remove from favorites' : 'Add to favorites',
                icon: Icon(
                  isFav
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: isFav ? Colors.amber : cs.onSurfaceVariant,
                  size: 20,
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  state.toggleFavorite(provider.id);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Returns a human-readable distance string from the current location to
  /// [provider], or `null` if the location is unavailable.
  String? _distanceText(AppState state) {
    final lat = state.myLat;
    final lng = state.myLng;
    if (lat == null || lng == null) return null;
    final meters = Geolocator.distanceBetween(
      lat,
      lng,
      provider.lat,
      provider.lng,
    );
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  Future<void> _call(String phone) async {
    final cleaned = phone.replaceAll(RegExp(r'\s'), '');
    final uri = Uri.parse('tel:$cleaned');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  void _navigate(BuildContext context, AppState state) {
    HapticFeedback.mediumImpact();
    state.setDestination(provider.lat, provider.lng);
    Navigator.of(context).pop();
    state.buildTruckRoute();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigating to ${provider.name}'),
      ),
    );
  }
}

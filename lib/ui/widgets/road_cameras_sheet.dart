import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config.dart';
import '../../models/road_camera.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Bottom sheet listing nearby road / traffic cameras for the USA and Canada.
///
/// Features:
/// • Search bar filtering camera names and state/province codes.
/// • Country filter chips (All / USA / Canada).
/// • Camera list sorted by distance from the driver, with distance displayed.
/// • Tap a camera row to open the camera's snapshot image in the browser (when
///   an [imageUrl] is available).
/// • "Load Cameras" button triggers [AppState.loadRoadCameras].
///
/// ## API key setup
/// Set `--dart-define=ROAD_CAMERA_511_API_KEY=<key>` at build / run time to
/// enable live DOT feeds.  Without a key, demo data is shown.
/// See [RoadCameraService] for full registration instructions.
class RoadCamerasSheet extends StatefulWidget {
  const RoadCamerasSheet({super.key});

  @override
  State<RoadCamerasSheet> createState() => _RoadCamerasSheetState();
}

class _RoadCamerasSheetState extends State<RoadCamerasSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  /// `null` = show all countries, `'US'` = US only, `'CA'` = Canada only.
  String? _countryFilter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });
    // Kick off the initial load if no cameras are cached yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.roadCameras.isEmpty && !state.isLoadingCameras) {
        state.loadRoadCameras();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Filtering
  // ---------------------------------------------------------------------------

  List<RoadCamera> _filteredCameras(AppState state) {
    var cameras = state.roadCameras;

    if (_countryFilter != null) {
      cameras = cameras.where((c) => c.country == _countryFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      cameras = cameras.where((c) {
        return c.name.toLowerCase().contains(_searchQuery) ||
            (c.stateOrProvince?.toLowerCase().contains(_searchQuery) ?? false) ||
            (c.description?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    return cameras;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Format [distMeters] as a human-readable string (ft/mi or m/km depending
  /// on [AppState.useMetricUnits]).
  String _formatDistance(double distMeters, bool metric) {
    if (metric) {
      if (distMeters < 1000) return '${distMeters.round()} m';
      return '${(distMeters / 1000).toStringAsFixed(1)} km';
    } else {
      final feet = distMeters * 3.28084;
      if (feet < 1000) return '${feet.round()} ft';
      final miles = feet / 5280;
      return '${miles.toStringAsFixed(1)} mi';
    }
  }

  Future<void> _openCamera(RoadCamera camera) async {
    final url = camera.streamUrl ?? camera.imageUrl;
    if (url == null || url.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image or stream available for this camera')),
        );
      }
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !await canLaunchUrl(uri)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to open camera feed')),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final cameras = _filteredCameras(state);
        final cs = Theme.of(context).colorScheme;

        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // ── Drag handle ──────────────────────────────────────────────
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

                // ── Title row ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.videocam_rounded, color: cs.primary),
                      const SizedBox(width: AppTheme.spaceXS),
                      Text(
                        'Road Cameras',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const Spacer(),
                      if (state.isLoadingCameras)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),

                // ── Demo-data notice ─────────────────────────────────────────
                if (!Config.roadCameraApiConfigured)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppTheme.spaceMD,
                      AppTheme.spaceXS,
                      AppTheme.spaceMD,
                      0,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 14,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: AppTheme.spaceXS),
                        Expanded(
                          child: Text(
                            'Demo data shown. Set ROAD_CAMERA_511_API_KEY for live feeds.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: AppTheme.spaceSM),

                // ── Search bar ───────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search cameras…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18),
                              onPressed: () {
                                _searchController.clear();
                              },
                            )
                          : null,
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),

                // ── Country filter chips ─────────────────────────────────────
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD,
                    ),
                    children: [
                      _CountryChip(
                        label: 'All',
                        selected: _countryFilter == null,
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(() => _countryFilter = null);
                        },
                      ),
                      const SizedBox(width: AppTheme.spaceXS),
                      _CountryChip(
                        label: '🇺🇸 USA',
                        selected: _countryFilter == 'US',
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(
                            () => _countryFilter =
                                _countryFilter == 'US' ? null : 'US',
                          );
                        },
                      ),
                      const SizedBox(width: AppTheme.spaceXS),
                      _CountryChip(
                        label: '🇨🇦 Canada',
                        selected: _countryFilter == 'CA',
                        onSelected: (_) {
                          HapticFeedback.selectionClick();
                          setState(
                            () => _countryFilter =
                                _countryFilter == 'CA' ? null : 'CA',
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),

                // ── Reload button ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Load Cameras Near Me'),
                      onPressed: state.isLoadingCameras
                          ? null
                          : () {
                              HapticFeedback.lightImpact();
                              state.loadRoadCameras();
                            },
                    ),
                  ),
                ),

                const Divider(height: AppTheme.spaceLG),

                // ── Camera list ──────────────────────────────────────────────
                Expanded(
                  child: cameras.isEmpty
                      ? _buildEmptyState(context, state, cs)
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: cameras.length,
                          itemBuilder: (context, index) =>
                              _buildCameraTile(context, state, cs, cameras[index]),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCameraTile(
    BuildContext context,
    AppState state,
    ColorScheme cs,
    RoadCamera camera,
  ) {
    final hasMedia =
        (camera.imageUrl?.isNotEmpty ?? false) ||
        (camera.streamUrl?.isNotEmpty ?? false);

    String? distanceLabel;
    if (state.myLat != null && state.myLng != null) {
      final dist = camera.distanceFromMeters(state.myLat!, state.myLng!);
      distanceLabel = _formatDistance(dist, state.useMetricUnits);
    }

    final subtitle = [
      if (camera.stateOrProvince != null)
        '${camera.country} · ${camera.stateOrProvince}',
      if (camera.direction != null) camera.direction!,
      if (distanceLabel != null) distanceLabel,
    ].join('  •  ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.tertiaryContainer,
        child: Icon(
          Icons.videocam_rounded,
          color: cs.onTertiaryContainer,
          size: 18,
        ),
      ),
      title: Text(
        camera.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: hasMedia
          ? Icon(Icons.open_in_new_rounded, size: 18, color: cs.primary)
          : Icon(
              Icons.videocam_off_rounded,
              size: 18,
              color: cs.onSurfaceVariant,
            ),
      onTap: hasMedia
          ? () {
              HapticFeedback.selectionClick();
              _openCamera(camera);
            }
          : null,
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    AppState state,
    ColorScheme cs,
  ) {
    final String msg;
    if (state.isLoadingCameras) {
      msg = 'Loading cameras…';
    } else if (state.cameraError != null) {
      msg = 'Error: ${state.cameraError}\n\nTap "Load Cameras Near Me" to retry.';
    } else if (_searchQuery.isNotEmpty || _countryFilter != null) {
      msg = 'No cameras match the current filter.\nTry clearing the search or filter.';
    } else {
      msg = 'No cameras loaded yet.\nTap "Load Cameras Near Me" to search.';
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

// ---------------------------------------------------------------------------
// Private widgets
// ---------------------------------------------------------------------------

class _CountryChip extends StatelessWidget {
  const _CountryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

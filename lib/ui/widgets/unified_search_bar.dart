import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../models/road_camera.dart';
import '../../services/here_geocoding_service.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import 'poi_detail_sheet.dart';

/// Search category filter tabs used by [UnifiedSearchBar].
enum _SearchCategory { all, destination, pois, cameras, truck }

/// A unified, floating search bar that lets the driver search across all
/// Kingtrux features — destinations, POIs, road cameras, and truck shortcuts
/// — without blocking or covering map tiles.
///
/// **Collapsed**: renders a tappable pill ("Search destinations, POIs,
/// cameras…") that replaces the former "Where to?" CTA bar.
///
/// **Expanded**: opens a compact, height-constrained panel directly below the
/// bar. The panel contains a live text field, horizontal category chips, and
/// an inline results list. The maximum panel height is capped at 280 dp so the
/// map always remains visible and interactable beneath it.
class UnifiedSearchBar extends StatefulWidget {
  const UnifiedSearchBar({
    super.key,
    required this.onDestinationSelected,
    required this.onPoiSelected,
    required this.onCameraSelected,
    required this.onTruckProfile,
    required this.onLayers,
    required this.onRoadCameras,
    required this.onPoiBrowser,
    required this.onSetDestinationByMap,
  });

  /// Called when the user selects a geocoded destination result.
  final void Function(GeocodedLocation location) onDestinationSelected;

  /// Called when the user taps a POI result tile.
  final void Function(Poi poi) onPoiSelected;

  /// Called when the user taps a camera result tile.
  final void Function(RoadCamera camera) onCameraSelected;

  /// Called when the user taps the "Truck Profile" quick-action.
  final VoidCallback onTruckProfile;

  /// Called when the user taps the "POI Layers" quick-action.
  final VoidCallback onLayers;

  /// Called when the user taps the "Road Cameras" quick-action / "All cameras".
  final VoidCallback onRoadCameras;

  /// Called when the user taps "Browse all POIs".
  final VoidCallback onPoiBrowser;

  /// Called when the user selects "Set destination by map tap" so the parent
  /// can activate tap-to-pin mode.
  final VoidCallback onSetDestinationByMap;

  @override
  State<UnifiedSearchBar> createState() => _UnifiedSearchBarState();
}

class _UnifiedSearchBarState extends State<UnifiedSearchBar> {
  bool _expanded = false;
  _SearchCategory _category = _SearchCategory.all;

  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _geocodingService = HereGeocodingService();

  bool _isSearching = false;
  GeocodedLocation? _geoResult;
  String? _geoError;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _open() {
    HapticFeedback.selectionClick();
    setState(() {
      _expanded = true;
      _category = _SearchCategory.all;
      _geoResult = null;
      _geoError = null;
    });
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _focusNode.requestFocus(),
    );
  }

  void _close() {
    _focusNode.unfocus();
    HapticFeedback.selectionClick();
    if (!mounted) return;
    setState(() {
      _expanded = false;
      _controller.clear();
      _geoResult = null;
      _geoError = null;
      _isSearching = false;
    });
  }

  Future<void> _searchDestination() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isSearching = true;
      _geoResult = null;
      _geoError = null;
    });
    final result = await _geocodingService.geocode(query);
    if (!mounted) return;
    setState(() {
      _isSearching = false;
      if (result == null) {
        _geoError = 'No results found. Try a more specific address.';
      } else {
        _geoResult = result;
      }
    });
  }

  void _selectDestination(GeocodedLocation loc) {
    widget.onDestinationSelected(loc);
    _close();
  }

  List<Poi> _filteredPois(List<Poi> pois) {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return pois.take(5).toList();
    return pois
        .where((p) => p.name.toLowerCase().contains(q))
        .take(8)
        .toList();
  }

  List<RoadCamera> _filteredCameras(List<RoadCamera> cameras) {
    final q = _controller.text.trim().toLowerCase();
    if (q.isEmpty) return cameras.take(5).toList();
    return cameras
        .where(
          (c) =>
              c.name.toLowerCase().contains(q) ||
              (c.stateOrProvince?.toLowerCase().contains(q) ?? false),
        )
        .take(8)
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (!_expanded) {
      return _buildCollapsed(cs);
    }
    return Consumer<AppState>(
      builder: (context, state, _) => _buildExpanded(cs, state),
    );
  }

  // ---------------------------------------------------------------------------
  // Collapsed state – pill matching the former "Where to?" CTA style
  // ---------------------------------------------------------------------------

  Widget _buildCollapsed(ColorScheme cs) {
    return Material(
      key: const Key('unified_search_collapsed'),
      elevation: AppTheme.elevationSheet,
      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      color: cs.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        onTap: _open,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceSM + 2,
          ),
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: cs.primary, size: 22),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: Text(
                  'Search destinations, POIs, cameras…',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
              Icon(Icons.tune_rounded, size: 18, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Expanded state – search panel docked below the bar
  // ---------------------------------------------------------------------------

  Widget _buildExpanded(ColorScheme cs, AppState state) {
    return Material(
      key: const Key('unified_search_expanded'),
      elevation: AppTheme.elevationSheet,
      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      color: cs.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Search input row ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceMD,
              AppTheme.spaceSM,
              AppTheme.spaceXS,
              0,
            ),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: cs.primary, size: 22),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: TextField(
                    key: const Key('unified_search_field'),
                    controller: _controller,
                    focusNode: _focusNode,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) {
                      if (_category == _SearchCategory.destination ||
                          _category == _SearchCategory.all) {
                        _searchDestination();
                      }
                    },
                    decoration: InputDecoration(
                      hintText: _hintText,
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spaceSM,
                      ),
                    ),
                  ),
                ),
                if (_controller.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear_rounded, size: 20),
                    onPressed: () {
                      _controller.clear();
                      setState(() {
                        _geoResult = null;
                        _geoError = null;
                      });
                    },
                  ),
                IconButton(
                  key: const Key('unified_search_close'),
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close search',
                  onPressed: _close,
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // ── Category chips ───────────────────────────────────────────────
          SizedBox(
            height: 40,
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTheme.spaceSM,
                vertical: AppTheme.spaceXS,
              ),
              scrollDirection: Axis.horizontal,
              children: _SearchCategory.values
                  .map(
                    (cat) => _CategoryChip(
                      label: _categoryLabel(cat),
                      icon: _categoryIcon(cat),
                      selected: _category == cat,
                      onSelected: (_) => setState(() {
                        _category = cat;
                        _geoResult = null;
                        _geoError = null;
                      }),
                    ),
                  )
                  .toList(),
            ),
          ),

          const Divider(height: 1),

          // ── Results panel (max 280 dp so map stays visible below) ────────
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 280),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: _buildResults(state),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hint text per category
  // ---------------------------------------------------------------------------

  String get _hintText {
    switch (_category) {
      case _SearchCategory.destination:
        return 'Enter address or place name';
      case _SearchCategory.pois:
        return 'Search POIs…';
      case _SearchCategory.cameras:
        return 'Search cameras…';
      case _SearchCategory.truck:
        return 'Truck & route options…';
      case _SearchCategory.all:
        return 'Search everywhere…';
    }
  }

  // ---------------------------------------------------------------------------
  // Category helpers
  // ---------------------------------------------------------------------------

  static String _categoryLabel(_SearchCategory cat) {
    switch (cat) {
      case _SearchCategory.all:
        return 'All';
      case _SearchCategory.destination:
        return 'Destination';
      case _SearchCategory.pois:
        return 'POIs';
      case _SearchCategory.cameras:
        return 'Cameras';
      case _SearchCategory.truck:
        return 'Truck';
    }
  }

  static IconData _categoryIcon(_SearchCategory cat) {
    switch (cat) {
      case _SearchCategory.all:
        return Icons.search_rounded;
      case _SearchCategory.destination:
        return Icons.place_rounded;
      case _SearchCategory.pois:
        return Icons.local_gas_station_rounded;
      case _SearchCategory.cameras:
        return Icons.videocam_rounded;
      case _SearchCategory.truck:
        return Icons.local_shipping_rounded;
    }
  }

  // ---------------------------------------------------------------------------
  // Results builders
  // ---------------------------------------------------------------------------

  List<Widget> _buildResults(AppState state) {
    final results = <Widget>[];

    switch (_category) {
      case _SearchCategory.destination:
        results.addAll(_buildDestinationSection());

      case _SearchCategory.pois:
        final pois = _filteredPois(state.pois);
        if (pois.isNotEmpty) {
          results.addAll(
            pois.map(
              (poi) => _PoiResultTile(
                poi: poi,
                onTap: () {
                  widget.onPoiSelected(poi);
                  _close();
                },
              ),
            ),
          );
        }
        results.add(
          _ActionTile(
            icon: Icons.open_in_new_rounded,
            label: 'Browse all POIs',
            onTap: () {
              widget.onPoiBrowser();
              _close();
            },
          ),
        );

      case _SearchCategory.cameras:
        final cameras = _filteredCameras(state.roadCameras);
        if (cameras.isNotEmpty) {
          results.addAll(
            cameras.map(
              (cam) => _CameraResultTile(
                camera: cam,
                onTap: () {
                  widget.onCameraSelected(cam);
                  _close();
                },
              ),
            ),
          );
        }
        results.add(
          _ActionTile(
            icon: Icons.open_in_new_rounded,
            label: 'Open cameras sheet',
            onTap: () {
              widget.onRoadCameras();
              _close();
            },
          ),
        );

      case _SearchCategory.truck:
        results.addAll(_buildTruckSection());

      case _SearchCategory.all:
        // Destination search
        results.add(const _GroupHeader(label: 'Destination'));
        results.addAll(_buildDestinationSection());

        // POIs
        final pois = _filteredPois(state.pois);
        if (pois.isNotEmpty) {
          results.add(const _GroupHeader(label: 'POIs'));
          results.addAll(
            pois.take(3).map(
                  (poi) => _PoiResultTile(
                    poi: poi,
                    onTap: () {
                      widget.onPoiSelected(poi);
                      _close();
                    },
                  ),
                ),
          );
        }

        // Cameras
        final cameras = _filteredCameras(state.roadCameras);
        if (cameras.isNotEmpty) {
          results.add(const _GroupHeader(label: 'Cameras'));
          results.addAll(
            cameras.take(3).map(
                  (cam) => _CameraResultTile(
                    camera: cam,
                    onTap: () {
                      widget.onCameraSelected(cam);
                      _close();
                    },
                  ),
                ),
          );
        }

        // Truck shortcuts
        results.add(const _GroupHeader(label: 'Shortcuts'));
        results.addAll(_buildTruckSection());
    }

    if (results.isEmpty) {
      results.add(_EmptyTile(query: _controller.text.trim()));
    }

    return results;
  }

  List<Widget> _buildDestinationSection() {
    final query = _controller.text.trim();
    return [
      _ActionTile(
        icon: query.isEmpty ? Icons.search_rounded : Icons.search_rounded,
        label: query.isEmpty
            ? 'Type an address then press ↵ to search'
            : 'Search: "$query"',
        trailing: _isSearching
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        onTap: _searchDestination,
      ),
      if (_geoError != null) _ErrorTile(message: _geoError!),
      if (_geoResult != null)
        _DestinationResultTile(
          location: _geoResult!,
          onTap: () => _selectDestination(_geoResult!),
        ),
      _ActionTile(
        icon: Icons.touch_app_rounded,
        label: 'Set destination by map tap',
        onTap: () {
          widget.onSetDestinationByMap();
          _close();
        },
      ),
    ];
  }

  List<Widget> _buildTruckSection() {
    return [
      _ActionTile(
        icon: Icons.local_shipping_rounded,
        label: 'Truck Profile',
        onTap: () {
          widget.onTruckProfile();
          _close();
        },
      ),
      _ActionTile(
        icon: Icons.layers_rounded,
        label: 'POI Layers',
        onTap: () {
          widget.onLayers();
          _close();
        },
      ),
      _ActionTile(
        icon: Icons.videocam_rounded,
        label: 'Road Cameras',
        onTap: () {
          widget.onRoadCameras();
          _close();
        },
      ),
    ];
  }
}

// ---------------------------------------------------------------------------
// _CategoryChip
// ---------------------------------------------------------------------------

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppTheme.spaceXS),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14),
            const SizedBox(width: 4),
            Text(label),
          ],
        ),
        selected: selected,
        onSelected: onSelected,
        visualDensity: VisualDensity.compact,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _GroupHeader – section divider inside the results list
// ---------------------------------------------------------------------------

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceMD,
        AppTheme.spaceXS + 2,
        AppTheme.spaceMD,
        0,
      ),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _DestinationResultTile
// ---------------------------------------------------------------------------

class _DestinationResultTile extends StatelessWidget {
  const _DestinationResultTile({
    required this.location,
    required this.onTap,
  });

  final GeocodedLocation location;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      key: const Key('unified_search_dest_result'),
      dense: true,
      leading: Icon(Icons.place_rounded, color: cs.primary, size: 20),
      title: Text(
        location.label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${location.lat.toStringAsFixed(4)}, '
        '${location.lng.toStringAsFixed(4)}',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
      ),
      trailing: FilledButton.tonalIcon(
        key: const Key('unified_search_dest_go'),
        onPressed: onTap,
        icon: const Icon(Icons.navigation_rounded, size: 16),
        label: const Text('Go'),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceSM,
            vertical: AppTheme.spaceXS,
          ),
        ),
      ),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// _PoiResultTile
// ---------------------------------------------------------------------------

class _PoiResultTile extends StatelessWidget {
  const _PoiResultTile({required this.poi, required this.onTap});

  final Poi poi;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(PoiDetailSheet.poiIcon(poi.type), size: 20),
      title: Text(poi.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        PoiDetailSheet.poiLabel(poi.type),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// _CameraResultTile
// ---------------------------------------------------------------------------

class _CameraResultTile extends StatelessWidget {
  const _CameraResultTile({required this.camera, required this.onTap});

  final RoadCamera camera;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      leading: Icon(Icons.videocam_rounded, color: cs.tertiary, size: 20),
      title: Text(
        camera.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [camera.stateOrProvince, camera.direction]
            .whereType<String>()
            .join(' · '),
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// _ActionTile – generic tappable row for shortcuts and actions
// ---------------------------------------------------------------------------

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      leading: Icon(icon, size: 20),
      title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// _ErrorTile
// ---------------------------------------------------------------------------

class _ErrorTile extends StatelessWidget {
  const _ErrorTile({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceXS,
      ),
      child: Row(
        children: [
          Icon(Icons.warning_rounded, color: cs.error, size: 16),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: cs.error,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _EmptyTile – shown when there are no results at all
// ---------------------------------------------------------------------------

class _EmptyTile extends StatelessWidget {
  const _EmptyTile({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      child: Text(
        query.isEmpty
            ? 'Start typing or select a category above…'
            : 'No results for "$query"',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
            ),
      ),
    );
  }
}

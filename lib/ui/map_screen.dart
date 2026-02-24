import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/poi.dart';
import '../state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/dark_map_style.dart';
import 'widgets/truck_profile_sheet.dart';
import 'widgets/layer_sheet.dart';
import 'widgets/route_summary_card.dart';
import 'widgets/alert_banner.dart';
import 'settings_screen.dart';
import 'paywall_screen.dart';
import 'preview_gallery_page.dart';

/// Main map screen with Google Maps integration
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  bool _darkMapApplied = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().init();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMapStyle();
  }

  /// Apply dark/light map style to match app theme.
  Future<void> _syncMapStyle() async {
    final controller = _mapController;
    if (controller == null) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (isDark && !_darkMapApplied) {
      await controller.setMapStyle(kDarkMapStyle);
      _darkMapApplied = true;
    } else if (!isDark && _darkMapApplied) {
      await controller.setMapStyle(null);
      _darkMapApplied = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _buildAppBar(cs),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          // Show full-screen loader while acquiring first location fix.
          if (state.myLat == null || state.myLng == null) {
            return _buildInitialLoader(cs);
          }

          return Stack(
            children: [
              // ── Google Map ──────────────────────────────────────────────
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(state.myLat!, state.myLng!),
                  zoom: 12,
                ),
                onMapCreated: (controller) async {
                  _mapController = controller;
                  await _syncMapStyle();
                },
                onLongPress: _onMapLongPress,
                markers: _buildMarkers(state),
                polylines: _buildPolylines(state),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight,
                  bottom: 180,
                ),
              ),

              // ── Route / POI loading indicator (non-blocking) ────────────
              if (state.isLoadingRoute || state.isLoadingPois)
                Positioned(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + AppTheme.spaceMD,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _LoadingBadge(
                      label: state.isLoadingRoute ? 'Calculating route…' : 'Loading POIs…',
                    ),
                  ),
                ),

              // ── Weather pill ────────────────────────────────────────────
              if (state.weatherAtCurrentLocation != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + AppTheme.spaceSM,
                  left: AppTheme.spaceMD,
                  right: AppTheme.spaceMD,
                  child: _buildWeatherPill(state, cs),
                ),

              // ── FAB cluster (bottom-right) ──────────────────────────────
              Positioned(
                right: AppTheme.spaceMD,
                bottom: 200,
                child: _MapActionCluster(
                  onRecenter: _onMyLocationPressed,
                  onLayers: _onLayersPressed,
                  onTruckProfile: _onTruckProfilePressed,
                  onGoPro: _onGoProPressed,
                  isPro: state.isPro,
                ),
              ),

              // ── Alert banner (top overlay) ──────────────────────────────
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: AlertBanner(),
              ),

              // ── Route summary card (bottom overlay) ─────────────────────
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: RouteSummaryCard(),
              ),
            ],
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AppBar
  // ---------------------------------------------------------------------------
  PreferredSizeWidget _buildAppBar(ColorScheme cs) => AppBar(
        title: kDebugMode
            ? GestureDetector(
                onLongPress: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PreviewGalleryPage(),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.local_shipping_rounded, color: cs.primary, size: 26),
                    const SizedBox(width: AppTheme.spaceSM),
                    const Text('KINGTRUX'),
                  ],
                ),
              )
            : Row(
                children: [
                  Icon(Icons.local_shipping_rounded, color: cs.primary, size: 26),
                  const SizedBox(width: AppTheme.spaceSM),
                  const Text('KINGTRUX'),
                ],
              ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: _onSettingsPressed,
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // Full-screen initial loading state
  // ---------------------------------------------------------------------------
  Widget _buildInitialLoader(ColorScheme cs) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: cs.primary),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              'Acquiring location…',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );

  // ---------------------------------------------------------------------------
  // Weather pill
  // ---------------------------------------------------------------------------
  Widget _buildWeatherPill(AppState state, ColorScheme cs) {
    final weather = state.weatherAtCurrentLocation!;
    return Card(
      elevation: AppTheme.elevationCard,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceXS + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_outlined, size: 18, color: cs.primary),
            const SizedBox(width: AppTheme.spaceSM),
            Flexible(
              child: Text(
                '${weather.summary} · '
                '${weather.temperatureCelsius.toStringAsFixed(1)}°C · '
                '${weather.windSpeedMs.toStringAsFixed(1)} m/s',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Markers
  // ---------------------------------------------------------------------------
  Set<Marker> _buildMarkers(AppState state) {
    final markers = <Marker>{};

    if (state.myLat != null && state.myLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('my_location'),
          position: LatLng(state.myLat!, state.myLng!),
          infoWindow: const InfoWindow(title: 'You'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );
    }

    if (state.destLat != null && state.destLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(state.destLat!, state.destLng!),
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    for (final poi in state.pois) {
      // Respect layer toggle: hide markers for disabled layers without
      // requiring a full reload.
      if (!state.enabledPoiLayers.contains(poi.type)) continue;
      markers.add(
        Marker(
          markerId: MarkerId('poi_${poi.id}'),
          position: LatLng(poi.lat, poi.lng),
          infoWindow: InfoWindow(
            title: poi.name,
            snippet: poi.type.name,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(_getPoiColor(poi.type)),
        ),
      );
    }

    return markers;
  }

  double _getPoiColor(PoiType type) {
    switch (type) {
      case PoiType.fuel:
        return BitmapDescriptor.hueOrange;
      case PoiType.restArea:
        return BitmapDescriptor.hueAzure;
      case PoiType.scale:
        return BitmapDescriptor.hueYellow;
      case PoiType.gym:
        return BitmapDescriptor.hueViolet;
      case PoiType.truckStop:
        return BitmapDescriptor.hueCyan;
      case PoiType.parking:
        return BitmapDescriptor.hueGreen;
    }
  }

  // ---------------------------------------------------------------------------
  // Polylines
  // ---------------------------------------------------------------------------
  Set<Polyline> _buildPolylines(AppState state) {
    if (state.routeResult == null) return {};
    final cs = Theme.of(context).colorScheme;
    return {
      Polyline(
        polylineId: const PolylineId('route'),
        points: state.routeResult!.polylinePoints,
        color: cs.primary,
        width: 5,
      ),
    };
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------
  Future<void> _onMyLocationPressed() async {
    HapticFeedback.lightImpact();
    try {
      final state = context.read<AppState>();
      await state.refreshMyLocation();
      if (state.myLat != null && state.myLng != null && _mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(state.myLat!, state.myLng!)),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  void _onTruckProfilePressed() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const TruckProfileSheet(),
    );
  }

  void _onLayersPressed() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      builder: (context) => const LayerSheet(),
    );
  }

  void _onGoProPressed() {
    HapticFeedback.selectionClick();
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
    );
  }

  void _onSettingsPressed() {
    HapticFeedback.selectionClick();
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  Future<void> _onMapLongPress(LatLng position) async {
    HapticFeedback.mediumImpact();
    final state = context.read<AppState>();
    state.setDestination(position.latitude, position.longitude);

    try {
      await state.buildTruckRoute();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route calculated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Route error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

// ---------------------------------------------------------------------------
// Map action FAB cluster
// ---------------------------------------------------------------------------

/// A vertical cluster of small FABs for map actions.
class _MapActionCluster extends StatelessWidget {
  const _MapActionCluster({
    required this.onRecenter,
    required this.onLayers,
    required this.onTruckProfile,
    required this.onGoPro,
    required this.isPro,
  });

  final VoidCallback onRecenter;
  final VoidCallback onLayers;
  final VoidCallback onTruckProfile;
  final VoidCallback onGoPro;
  final bool isPro;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _ClusterFab(
          icon: Icons.my_location_rounded,
          tooltip: 'Recenter',
          onPressed: onRecenter,
        ),
        const SizedBox(height: AppTheme.spaceSM),
        _ClusterFab(
          icon: Icons.layers_rounded,
          tooltip: 'POI Layers',
          onPressed: onLayers,
        ),
        const SizedBox(height: AppTheme.spaceSM),
        _ClusterFab(
          icon: Icons.local_shipping_rounded,
          tooltip: 'Truck Profile',
          onPressed: onTruckProfile,
        ),
        if (!isPro) ...[
          const SizedBox(height: AppTheme.spaceSM),
          _ClusterFab(
            icon: Icons.workspace_premium_rounded,
            tooltip: 'Go Pro',
            onPressed: onGoPro,
          ),
        ],
      ],
    );
  }
}

class _ClusterFab extends StatelessWidget {
  const _ClusterFab({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: tooltip,
      tooltip: tooltip,
      onPressed: onPressed,
      child: Icon(icon),
    );
  }
}

// ---------------------------------------------------------------------------
// Non-blocking loading badge
// ---------------------------------------------------------------------------

class _LoadingBadge extends StatelessWidget {
  const _LoadingBadge({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: AppTheme.elevationSheet,
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLG),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceXS + 2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: cs.primary,
              ),
            ),
            const SizedBox(width: AppTheme.spaceSM),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}


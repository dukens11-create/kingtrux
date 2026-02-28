import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/poi.dart';
import '../state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/dark_map_style.dart';
import 'widgets/route_options_sheet.dart';
import 'widgets/truck_profile_sheet.dart';
import 'widgets/layer_sheet.dart';
import 'widgets/poi_browser_sheet.dart';
import 'widgets/poi_detail_sheet.dart';
import 'widgets/roadside_assistance_sheet.dart';
import 'widgets/route_summary_card.dart';
import 'widgets/voice_settings_sheet.dart';
import 'widgets/theme_settings_sheet.dart';
import 'widgets/road_sign_alert_settings_sheet.dart';
import 'widgets/alert_banner.dart';
import 'widgets/trip_planner_sheet.dart';
import 'widgets/speed_display.dart';
import 'widgets/compass_indicator.dart';
import 'account_screen.dart';
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
  /// When true the next tap on the map sets the destination and exits this mode.
  bool _settingDestination = false;

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

  /// Apply dark/light map style to match night mode state.
  Future<void> _syncMapStyle() async {
    final controller = _mapController;
    if (controller == null) return;
    final isDark = context.read<AppState>().isNightMode;
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
      bottomNavigationBar: Consumer<AppState>(
        builder: (context, state, _) => _MapToolbar(
          onRecenter: _onMyLocationPressed,
          onLayers: _onLayersPressed,
          onPoiBrowser: _onPoiBrowserPressed,
          onTruckProfile: _onTruckProfilePressed,
          onTripPlanner: _onTripPlannerPressed,
          onGetHelp: _onGetHelpPressed,
          onSetDestination: _onSetDestinationPressed,
          onGoPro: _onGoProPressed,
          onRouteOptions: _onRouteOptionsPressed,
          isPro: state.isPro,
          isSettingDestination: _settingDestination,
        ),
      ),
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
                onTap: _onMapTap,
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

              // ── Route summary card (bottom overlay) ─────────────────────
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: RouteSummaryCard(),
              ),

              // ── Speed display (bottom-left, above route card) ────────────
              const Positioned(
                bottom: 180,
                left: AppTheme.spaceMD,
                child: SpeedDisplay(),
              ),

              // ── Alert banner (below status bar + app bar) ────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + AppTheme.spaceXS,
                left: 0,
                right: 0,
                child: const AlertBanner(),
              ),

              // ── Compass indicator (bottom-left, above route card) ────────
              const Positioned(
                left: AppTheme.spaceMD,
                bottom: 180,
                child: CompassIndicator(),
              ),

              // ── "Set Destination" mode overlay ───────────────────────────
              // Shown only when the user has activated destination-setting mode.
              // A single tap on the map will set the destination and exit the mode.
              if (_settingDestination)
                Positioned(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + AppTheme.spaceMD,
                  left: AppTheme.spaceMD,
                  right: AppTheme.spaceMD,
                  child: _SetDestinationBanner(onCancel: _cancelSetDestination),
                ),

              // ── Google Maps API key misconfiguration warning ──────────────
              if (!Config.googleMapsAndroidKeyConfigured)
                const Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: _MapsApiKeyWarningBanner(),
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
          if (Firebase.apps.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.account_circle_outlined),
              tooltip: 'Account',
              onPressed: () => Navigator.push<void>(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const AccountScreen(),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.warning_amber_rounded),
            tooltip: 'Road Sign Alerts',
            onPressed: _onRoadSignAlertsPressed,
          ),
          IconButton(
            icon: const Icon(Icons.palette_outlined),
            tooltip: 'Color Theme',
            onPressed: _onThemeSettingsPressed,
          ),
          IconButton(
            icon: const Icon(Icons.record_voice_over_rounded),
            tooltip: 'Voice Settings',
            onPressed: _onVoiceSettingsPressed,
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
      // Respect per-brand filter for truck stop POIs.
      if (!state.isTruckStopBrandVisible(poi)) continue;
      markers.add(
        Marker(
          markerId: MarkerId('poi_${poi.id}'),
          position: LatLng(poi.lat, poi.lng),
          infoWindow: InfoWindow(
            title: poi.name,
            snippet: PoiDetailSheet.poiLabel(poi.type),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(_getPoiColor(poi.type)),
          onTap: () => _onPoiMarkerTap(poi),
        ),
      );
    }

    // Roadside assistance providers (always shown when loaded).
    for (final provider in state.roadsideProviders) {
      markers.add(
        Marker(
          markerId: MarkerId('roadside_${provider.id}'),
          position: LatLng(provider.lat, provider.lng),
          infoWindow: InfoWindow(
            title: provider.name,
            snippet: PoiDetailSheet.poiLabel(provider.type),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          onTap: () => _onPoiMarkerTap(provider),
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
      case PoiType.roadsideAssistance:
        return BitmapDescriptor.hueRed;
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

  void _onRouteOptionsPressed() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const RouteOptionsSheet(),
    );
  }

  void _onTripPlannerPressed() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const TripPlannerSheet(),
    );
  }

  void _onRoadSignAlertsPressed() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const RoadSignAlertSettingsSheet(),
    );
  }

  void _onThemeSettingsPressed() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ThemeSettingsSheet(),
    );
  }

  void _onVoiceSettingsPressed() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      builder: (context) => const VoiceSettingsSheet(),
    );
  }

  void _onLayersPressed() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      builder: (context) => const LayerSheet(),
    );
  }

  void _onPoiBrowserPressed() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const PoiBrowserSheet(),
    );
  }

  void _onGetHelpPressed() {
    HapticFeedback.heavyImpact();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const RoadsideAssistanceSheet(),
    );
  }

  void _onPoiMarkerTap(Poi poi) {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => PoiDetailSheet(poi: poi),
    );
  }

  void _onGoProPressed() {
    HapticFeedback.selectionClick();
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const PaywallScreen()),
    );
  }

  /// Called when the user taps the map. Only acts when destination-setting
  /// mode is active; all other taps are ignored so normal map interaction
  /// (panning, zooming, marker taps) is unaffected.
  void _onMapTap(LatLng position) {
    if (!_settingDestination) return;
    _setDestinationAt(position);
  }

  /// Activates / deactivates destination-setting mode.
  void _onSetDestinationPressed() {
    HapticFeedback.selectionClick();
    setState(() => _settingDestination = !_settingDestination);
  }

  /// Cancels destination-setting mode without changing the destination.
  void _cancelSetDestination() {
    setState(() => _settingDestination = false);
  }

  /// Sets [position] as the destination, builds the truck route, and exits
  /// destination-setting mode. On route error the mode is also exited so the
  /// user must re-activate it intentionally before trying again.
  Future<void> _setDestinationAt(LatLng position) async {
    HapticFeedback.mediumImpact();
    // Exit the mode immediately so accidental double-taps are harmless.
    setState(() => _settingDestination = false);

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
// Persistent map toolbar (BottomAppBar)
// ---------------------------------------------------------------------------

/// A persistent bottom toolbar that exposes all core map actions as clearly
/// labelled icon buttons, keeping features always visible and discoverable.
class _MapToolbar extends StatelessWidget {
  const _MapToolbar({
    required this.onRecenter,
    required this.onLayers,
    required this.onPoiBrowser,
    required this.onTruckProfile,
    required this.onTripPlanner,
    required this.onGetHelp,
    required this.onSetDestination,
    required this.onGoPro,
    required this.onRouteOptions,
    required this.isPro,
    required this.isSettingDestination,
  });

  final VoidCallback onRecenter;
  final VoidCallback onLayers;
  final VoidCallback onPoiBrowser;
  final VoidCallback onTruckProfile;
  final VoidCallback onTripPlanner;
  final VoidCallback onGetHelp;
  final VoidCallback onSetDestination;
  final VoidCallback onGoPro;
  final VoidCallback onRouteOptions;
  final bool isPro;
  final bool isSettingDestination;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return BottomAppBar(
      padding: EdgeInsets.zero,
      child: Row(
        children: [
          _ToolbarButton(
            icon: Icons.my_location_rounded,
            label: 'Recenter',
            onPressed: onRecenter,
          ),
          _ToolbarButton(
            icon: Icons.layers_rounded,
            label: 'Layers',
            onPressed: onLayers,
          ),
          _ToolbarButton(
            icon: Icons.place_rounded,
            label: 'POIs',
            onPressed: onPoiBrowser,
          ),
          _ToolbarButton(
            icon: Icons.local_shipping_rounded,
            label: 'Truck',
            onPressed: onTruckProfile,
          ),
          _ToolbarButton(
            icon: Icons.tune_rounded,
            label: 'Options',
            onPressed: onRouteOptions,
          ),
          _ToolbarButton(
            icon: Icons.route_rounded,
            label: 'Trip',
            onPressed: onTripPlanner,
          ),
          _ToolbarButton(
            icon: Icons.flag_rounded,
            label: 'Destination',
            onPressed: onSetDestination,
            iconColor: isSettingDestination ? cs.primary : null,
            labelColor: isSettingDestination ? cs.primary : null,
          ),
          _ToolbarButton(
            icon: Icons.emergency_rounded,
            label: 'Help',
            onPressed: onGetHelp,
            iconColor: cs.error,
            labelColor: cs.error,
          ),
          if (!isPro)
            _ToolbarButton(
              icon: Icons.workspace_premium_rounded,
              label: 'Go Pro',
              onPressed: onGoPro,
            ),
        ],
      ),
    );
  }
}

/// A compact icon + label button used inside [_MapToolbar].
class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.iconColor,
    this.labelColor,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? iconColor;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveIconColor = iconColor ?? cs.onSurface;
    final effectiveLabelColor = labelColor ?? cs.onSurface;
    return Expanded(
      child: Tooltip(
        message: label,
        child: Semantics(
          label: label,
          button: true,
          child: InkWell(
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXS),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 22, color: effectiveIconColor),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: effectiveLabelColor,
                        ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Banner displayed at the top of the map while destination-setting mode is
/// active. Instructs the user to tap the map and provides a cancel button.
class _SetDestinationBanner extends StatelessWidget {
  const _SetDestinationBanner({required this.onCancel});

  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: cs.primaryContainer,
      elevation: AppTheme.elevationSheet,
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
          children: [
            Icon(Icons.flag_rounded, size: 18, color: cs.onPrimaryContainer),
            const SizedBox(width: AppTheme.spaceSM),
            Expanded(
              child: Text(
                'Tap the map to set destination',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onPrimaryContainer,
                    ),
              ),
            ),
            TextButton(
              onPressed: onCancel,
              style: TextButton.styleFrom(
                foregroundColor: cs.onPrimaryContainer,
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSM),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Google Maps API key misconfiguration warning banner
// ---------------------------------------------------------------------------

/// Shown when the Google Maps Android API key is not provided at build time
/// (i.e. [Config.googleMapsAndroidKeyConfigured] is false). Displays a
/// non-crashing warning so developers and testers understand why tiles are
/// missing, without affecting release builds that include the key.
class _MapsApiKeyWarningBanner extends StatelessWidget {
  const _MapsApiKeyWarningBanner();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.errorContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceSM,
          ),
          child: Row(
            children: [
              Icon(Icons.map_outlined, color: cs.onErrorContainer, size: 20),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: Text(
                  kDebugMode
                      ? 'Google Maps API key not configured. '
                        'Pass --dart-define=GOOGLE_MAPS_ANDROID_API_KEY=<key> '
                        'or set the GOOGLE_MAPS_ANDROID_API_KEY repo secret.'
                      : 'Map tiles unavailable: Google Maps API key missing.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onErrorContainer,
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
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


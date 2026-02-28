import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/poi.dart';
import '../services/map_preferences_service.dart';
import '../state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/dark_map_style.dart';
import 'widgets/onboarding_overlay.dart';
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
import 'widgets/maneuver_banner.dart';
import 'widgets/steps_list_sheet.dart';
import 'widgets/trip_planner_sheet.dart';
import 'widgets/speed_display.dart';
import 'widgets/compass_indicator.dart';
import 'widgets/where_to_sheet.dart';
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

  // ── Follow mode ────────────────────────────────────────────────────────────
  /// When true, the camera automatically tracks the user's location.
  bool _followMode = true;
  /// Prevents [_onCameraMove] from disabling follow mode during programmatic
  /// camera animations triggered by follow mode or recenter.
  bool _programmaticMove = false;
  double? _lastFollowLat;
  double? _lastFollowLng;

  // ── Map type ───────────────────────────────────────────────────────────────
  MapType _mapType = MapType.normal;
  final _mapPrefs = MapPreferencesService();

  // ── Onboarding ─────────────────────────────────────────────────────────────
  bool _showOnboarding = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().init();
      _loadMapPrefs();
    });
  }

  /// Load persisted map preferences (map type, onboarding status).
  Future<void> _loadMapPrefs() async {
    final mapType = await _mapPrefs.loadMapType();
    final dismissed = await _mapPrefs.loadOnboardingDismissed();
    if (mounted) {
      setState(() {
        _mapType = mapType;
        _showOnboarding = !dismissed;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMapStyle();
  }

  /// Apply dark/light map style to match the current theme brightness.
  ///
  /// Uses the active [ThemeData] brightness so the map follows both the
  /// time-based / manual night-mode setting (from [AppState.isNightMode])
  /// and the system dark-mode override wired in [KingTruxApp].
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
          onSteps: _onStepsPressed,
          isPro: state.isPro,
          isSettingDestination: _settingDestination,
          isNavigating: state.isNavigating,
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          // Track location changes for follow mode.
          _maybeMoveCamera(state);

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
                  // Zoom 14 gives a city-block level view useful for truck
                  // navigation planning (was 12, which showed too wide an area).
                  zoom: 14,
                ),
                mapType: _mapType,
                onMapCreated: (controller) async {
                  _mapController = controller;
                  await _syncMapStyle();
                },
                onTap: _onMapTap,
                onLongPress: _onMapLongPress,
                onCameraMove: _onCameraMove,
                markers: _buildMarkers(state),
                polylines: _buildPolylines(state),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight,
                  bottom: 180,
                ),
              ),

              // ── "Where to?" CTA bar ─────────────────────────────────────
              // Hidden when tap-to-set destination mode is active.
              if (!_settingDestination)
                Positioned(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + AppTheme.spaceXS,
                  left: AppTheme.spaceMD,
                  right: AppTheme.spaceMD,
                  child: _WhereToCta(onTap: _onWhereToCTAPressed),
                ),

              // ── Map overlay buttons (right side) ─────────────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + 56 + AppTheme.spaceSM,
                right: AppTheme.spaceSM,
                child: Column(
                  children: [
                    _MapFab(
                      key: const Key('map_type_toggle'),
                      icon: _mapType == MapType.satellite
                          ? Icons.map_rounded
                          : Icons.satellite_alt_rounded,
                      tooltip: _mapType == MapType.satellite
                          ? 'Normal map'
                          : 'Satellite view',
                      onPressed: _onMapTypeToggle,
                    ),
                    const SizedBox(height: AppTheme.spaceXS),
                    _MapFab(
                      key: const Key('follow_mode_toggle'),
                      icon: _followMode
                          ? Icons.navigation_rounded
                          : Icons.navigation_outlined,
                      tooltip: _followMode ? 'Following location' : 'Follow location',
                      onPressed: _onFollowModeToggle,
                      active: _followMode,
                    ),
                  ],
                ),
              ),

              // ── Route / POI loading indicator (non-blocking) ────────────
              if (state.isLoadingRoute || state.isLoadingPois)
                Positioned(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight + AppTheme.spaceMD + 48,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _LoadingBadge(
                      label: state.isLoadingRoute ? 'Calculating route…' : 'Loading POIs…',
                    ),
                  ),
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

              // ── Maneuver guidance banner (active navigation only) ────────
              Positioned(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + AppTheme.spaceMD,
                left: AppTheme.spaceMD,
                right: AppTheme.spaceMD,
                child: const ManeuverBanner(),
              ),

              // ── Compass indicator (bottom-left, above route card) ────────
              const Positioned(
                left: AppTheme.spaceMD,
                bottom: 180,
                child: CompassIndicator(),
              ),

              // ── "Set Destination" mode overlay ───────────────────────────
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

              // ── First-launch onboarding overlay ──────────────────────────
              if (_showOnboarding)
                Positioned.fill(
                  child: OnboardingOverlay(onDismiss: _onOnboardingDismissed),
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
    // Re-enable follow mode when the driver explicitly recenters.
    setState(() => _followMode = true);
    try {
      final state = context.read<AppState>();
      await state.refreshMyLocation();
      if (state.myLat != null && state.myLng != null && _mapController != null) {
        _programmaticMove = true;
        await _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(state.myLat!, state.myLng!)),
        );
        if (mounted) setState(() => _programmaticMove = false);
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

  void _onStepsPressed() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const StepsListSheet(),
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

  // ---------------------------------------------------------------------------
  // "Where to?" CTA
  // ---------------------------------------------------------------------------
  Future<void> _onWhereToCTAPressed() async {
    HapticFeedback.selectionClick();
    final result = await showWhereToSheet(context);
    // If the user chose "Use Map", activate tap-to-set mode.
    if (result == 'long_press' && mounted) {
      setState(() => _settingDestination = true);
    }
  }

  // ---------------------------------------------------------------------------
  // Map long-press: set destination directly without requiring toolbar mode
  // ---------------------------------------------------------------------------
  void _onMapLongPress(LatLng position) {
    _setDestinationAt(position);
  }

  // ---------------------------------------------------------------------------
  // Map type toggle (Normal ↔ Satellite)
  // ---------------------------------------------------------------------------
  void _onMapTypeToggle() {
    HapticFeedback.selectionClick();
    final next = _mapType == MapType.normal ? MapType.satellite : MapType.normal;
    setState(() => _mapType = next);
    _mapPrefs.saveMapType(next);
  }

  // ---------------------------------------------------------------------------
  // Follow mode
  // ---------------------------------------------------------------------------

  /// Toggle follow mode on / off. When turned on, also recenter immediately.
  void _onFollowModeToggle() {
    HapticFeedback.selectionClick();
    if (_followMode) {
      setState(() => _followMode = false);
    } else {
      setState(() {
        _followMode = true;
        // Reset cached position so camera moves immediately on next rebuild.
        _lastFollowLat = null;
        _lastFollowLng = null;
      });
    }
  }

  /// Called by [GoogleMap.onCameraMove]. Disables follow mode when the camera
  /// is moved by the user (i.e., not by a programmatic animation).
  void _onCameraMove(CameraPosition _) {
    if (_programmaticMove) return;
    if (_followMode) {
      setState(() => _followMode = false);
    }
  }

  /// Moves the camera to track the user's location when [_followMode] is true.
  /// Called from the Consumer builder on every AppState rebuild.
  void _maybeMoveCamera(AppState state) {
    if (!_followMode) return;
    if (state.myLat == null || state.myLng == null) return;
    if (state.myLat == _lastFollowLat && state.myLng == _lastFollowLng) return;
    _lastFollowLat = state.myLat;
    _lastFollowLng = state.myLng;
    final controller = _mapController;
    if (controller == null) return;
    _programmaticMove = true;
    controller
        .animateCamera(
          CameraUpdate.newLatLng(LatLng(state.myLat!, state.myLng!)),
        )
        .then((_) {
      if (mounted) setState(() => _programmaticMove = false);
    });
  }

  // ---------------------------------------------------------------------------
  // Onboarding
  // ---------------------------------------------------------------------------

  Future<void> _onOnboardingDismissed() async {
    await _mapPrefs.saveOnboardingDismissed();
    if (mounted) setState(() => _showOnboarding = false);
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
    required this.onSteps,
    required this.isPro,
    required this.isSettingDestination,
    required this.isNavigating,
  });

  final VoidCallback onRecenter;
  final VoidCallback onLayers;
  final VoidCallback onPoiBrowser;
  final VoidCallback onTruckProfile;
  final VoidCallback onTripPlanner;
  final VoidCallback onGetHelp;
  final VoidCallback onSetDestination;
  final VoidCallback onGoPro;
  final VoidCallback onSteps;
  final bool isPro;
  final bool isSettingDestination;
  final bool isNavigating;

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
            icon: Icons.route_rounded,
            label: 'Trip',
            onPressed: onTripPlanner,
          ),
          if (isNavigating)
            _ToolbarButton(
              icon: Icons.list_alt_rounded,
              label: 'Steps',
              onPressed: onSteps,
              iconColor: cs.primary,
              labelColor: cs.primary,
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

// ---------------------------------------------------------------------------
// "Where to?" CTA bar
// ---------------------------------------------------------------------------

/// A tappable search-bar–style CTA that opens the [WhereToSheet].
class _WhereToCta extends StatelessWidget {
  const _WhereToCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      key: const Key('where_to_cta'),
      elevation: AppTheme.elevationSheet,
      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      color: cs.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        onTap: onTap,
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
                  'Where to?',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ),
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Small floating action button for map overlay controls
// ---------------------------------------------------------------------------

class _MapFab extends StatelessWidget {
  const _MapFab({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.active = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  /// When true the button is highlighted with the primary color.
  final bool active;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        elevation: AppTheme.elevationSheet,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        color: active ? cs.primaryContainer : cs.surface,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceSM),
            child: Icon(
              icon,
              size: 22,
              color: active ? cs.onPrimaryContainer : cs.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}


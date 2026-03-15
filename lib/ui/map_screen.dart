import 'dart:async';
import 'dart:developer' as developer;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../models/poi.dart';
import '../models/scale_report.dart';
import '../services/map_preferences_service.dart';
import '../state/app_state.dart';
import 'theme/app_theme.dart';
import 'theme/dark_map_style.dart';
import 'widgets/route_options_sheet.dart';
import 'widgets/onboarding_overlay.dart';
import 'widgets/truck_profile_sheet.dart';
import 'widgets/layer_sheet.dart';
import 'widgets/poi_hub_sheet.dart';
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
import 'widgets/closest_scale_card.dart';
import 'widgets/compass_indicator.dart';
import 'widgets/where_to_sheet.dart';
import 'widgets/route_guidance_banner.dart';
import 'widgets/kingtrux_logo.dart';
import 'map/marker_icons.dart';
import 'account_screen.dart';
import 'messages_screen.dart';
import 'navigation_screen.dart';
import 'paywall_screen.dart';
import 'preview_gallery_page.dart';
import 'settings_screen.dart';

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

  // ── Map diagnostics ────────────────────────────────────────────────────────
  /// True once [onMapCreated] fires, meaning the map controller is ready.
  bool _mapCreated = false;
  /// Non-null when a map-load issue has been detected (e.g. init timeout).
  String? _mapLoadError;
  /// Fires if the map controller has not been created within the timeout window.
  Timer? _mapInitTimer;

  // ── POI error tracking ────────────────────────────────────────────────────
  /// Last seen [AppState.poiError] value used to detect changes for snackbar.
  String? _lastPoiError;
  /// Cached reference to [AppState] for use in [dispose].
  AppState? _appState;

  // ── Scale pass prompt ──────────────────────────────────────────────────────
  /// Prevents showing the scale-pass prompt dialog more than once at a time.
  bool _showingScalePassPrompt = false;

  // ── Custom marker icons ────────────────────────────────────────────────────
  /// Cached green-circle-with-w icon for [PoiType.scale] markers.
  BitmapDescriptor? _scaleMarkerIcon;

  @override
  void initState() {
    super.initState();
    _logMapInitStart();
    _loadScaleMarkerIcon();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final appState = context.read<AppState>();
      _appState = appState;
      appState.init();
      appState.addListener(_onAppStateChanged);
      _loadMapPrefs();
      _startMapInitTimer();
    });
  }

  /// Generates and caches the custom scale marker icon.
  Future<void> _loadScaleMarkerIcon() async {
    final icon = await buildCircleLetterMarker(
      color: Colors.green,
      letter: 'w',
    );
    if (mounted) {
      if (icon != null) {
        setState(() => _scaleMarkerIcon = icon);
      } else {
        developer.log(
          'MapScreen._loadScaleMarkerIcon: failed to generate scale marker icon; '
          'falling back to default yellow hue marker.',
          name: _logName,
          level: 900,
        );
      }
    }
  }

  // ── Map diagnostics helpers ────────────────────────────────────────────────

  static const _logName = 'KingTrux.Maps';

  /// Logs the map initialization start and API key status.
  void _logMapInitStart() {
    developer.log('MapScreen.initState: starting map initialization', name: _logName);
    final keyOk = Config.googleMapsAndroidKeyConfigured;
    developer.log(
      'MapScreen.initState: Google Maps Android API key configured = $keyOk',
      name: _logName,
      level: keyOk ? 800 : 900,
    );
    if (!keyOk) {
      developer.log(
        'MapScreen.initState: API key missing or placeholder – '
        'pass --dart-define=GOOGLE_MAPS_ANDROID_API_KEY=<key> to fix.',
        name: _logName,
        level: 1000,
      );
    }
  }

  /// Starts a 15-second timer that sets [_mapLoadError] if the map controller
  /// has still not been created, giving the user a diagnostic message.
  void _startMapInitTimer() {
    _mapInitTimer = Timer(const Duration(seconds: 15), () {
      if (_mapCreated || !mounted) return;
      developer.log(
        'MapScreen: map controller not created within 15 s – '
        'possible API key, network, or Google Play Services issue.',
        name: _logName,
        level: 900,
      );
      setState(() {
        _mapLoadError =
            'Map tiles failed to load. Check your API key, '
            'network connection, and Google Play Services.';
      });
    });
  }

  /// Load persisted map preferences (map type, onboarding status).
  Future<void> _loadMapPrefs() async {
    developer.log('MapScreen._loadMapPrefs: loading persisted map preferences', name: _logName);
    final mapType = await _mapPrefs.loadMapType();
    final dismissed = await _mapPrefs.loadOnboardingDismissed();
    developer.log(
      'MapScreen._loadMapPrefs: mapType=${mapType.name}, onboardingDismissed=$dismissed',
      name: _logName,
    );
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
    developer.log(
      'MapScreen._syncMapStyle: isDark=$isDark _darkMapApplied=$_darkMapApplied',
      name: _logName,
    );
    if (isDark && !_darkMapApplied) {
      await controller.setMapStyle(kDarkMapStyle);
      _darkMapApplied = true;
      developer.log('MapScreen._syncMapStyle: dark map style applied', name: _logName);
    } else if (!isDark && _darkMapApplied) {
      await controller.setMapStyle(null);
      _darkMapApplied = false;
      developer.log('MapScreen._syncMapStyle: map style cleared (light mode)', name: _logName);
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
          onRouteOptions: _onRouteOptionsPressed,
          onMessages: _onMessagesPressed,
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
            return _buildInitialLoader(cs, state);
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
                  developer.log(
                    'MapScreen.onMapCreated: controller ready – map tiles loading',
                    name: _logName,
                  );
                  _mapController = controller;
                  _mapInitTimer?.cancel();
                  setState(() {
                    _mapCreated = true;
                    _mapLoadError = null;
                  });
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
                  // Generous bottom padding clears the quick-actions strip
                  // (~68 px) + destination CTA (~56 px) + safe-area bottom.
                  bottom: 200 + MediaQuery.of(context).padding.bottom,
                ),
              ),

              // ── Map overlay buttons – right-side vertical control rail ──
              Positioned(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + AppTheme.spaceSM,
                right: AppTheme.spaceSM,
                child: _RightControlRail(
                  mapType: _mapType,
                  followMode: _followMode,
                  onLayers: _onLayersPressed,
                  onMapTypeToggle: _onMapTypeToggle,
                  onZoomIn: _onZoomIn,
                  onZoomOut: _onZoomOut,
                  onMyLocation: _onMyLocationPressed,
                  onFilters: _onRouteOptionsPressed,
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

              // ── Bottom panel: quick actions + destination CTA / route card ─
              // The Column stacks (from bottom): quick-actions strip,
              // then either the destination CTA (no route) or the route
              // summary card (route loading / loaded).
              if (!_settingDestination)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    key: const Key('bottom_map_panel'),
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Route summary (when loading or route exists).
                      if (state.isLoadingRoute || state.routeResult != null)
                        RouteSummaryCard(settingDestination: _settingDestination),

                      // Destination CTA (only when no route and not loading).
                      if (!state.isLoadingRoute && state.routeResult == null)
                        _BottomDestinationCta(onTap: _onWhereToCTAPressed),

                      // Quick-actions strip – always visible in this panel.
                      _QuickActionsBar(
                        key: const Key('quick_actions_bar'),
                        isWsEnabled: state.enabledPoiLayers.contains(PoiType.scale),
                        onDirection: _onWhereToCTAPressed,
                        onPlaces: _onPoiBrowserPressed,
                        onWs: _onWsTogglePressed,
                        onRestricted: _onRouteOptionsPressed,
                        onToll: () => _showComingSoon('Toll routing'),
                        onWeather: () => _showComingSoon('Weather'),
                        onCameras: () => _showComingSoon('Cameras'),
                      ),
                    ],
                  ),
                ),

              // ── Speed display (bottom-left, above bottom panel) ──────────
              // Positioned above the quick-actions strip (~68 px) plus a
              // comfortable buffer so it never overlaps the strip.
              const Positioned(
                bottom: 200,
                left: AppTheme.spaceMD,
                child: SpeedDisplay(),
              ),

              // ── Closest police weight station (bottom-right, above panel) ─
              const Positioned(
                bottom: 200,
                right: AppTheme.spaceMD,
                child: ClosestScaleCard(),
              ),

              // ── Alert banner (below status bar + app bar) ────────────────
              Positioned(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + AppTheme.spaceXS,
                left: 0,
                right: 0,
                child: const AlertBanner(),
              ),

              // ── Route guidance banner (pre-navigation, route loaded) ────
              if (state.routeResult != null &&
                  state.routeResult!.maneuvers.isNotEmpty &&
                  !state.isNavigating &&
                  !_settingDestination)
                Positioned(
                  top: MediaQuery.of(context).padding.top +
                      kToolbarHeight +
                      AppTheme.spaceMD,
                  left: AppTheme.spaceMD,
                  right: AppTheme.spaceMD,
                  child: RouteGuidanceBanner(
                    maneuver: state.routeResult!.maneuvers.first,
                    onTap: () async {
                      await state.startNavigation();
                      if (context.mounted) {
                        await Navigator.of(context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => const NavigationScreen(),
                          ),
                        );
                      }
                    },
                  ),
                ),

              // ── Maneuver guidance banner (active navigation only) ────────
              Positioned(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + AppTheme.spaceMD,
                left: AppTheme.spaceMD,
                right: AppTheme.spaceMD,
                child: const ManeuverBanner(),
              ),

              // ── Compass indicator (top-left, just below app bar) ────────
              Positioned(
                top: MediaQuery.of(context).padding.top +
                    kToolbarHeight +
                    AppTheme.spaceSM,
                left: AppTheme.spaceMD,
                child: const CompassIndicator(),
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

              // ── Map-load failure diagnostic banner ────────────────────────
              if (_mapLoadError != null)
                Positioned(
                  bottom: Config.googleMapsAndroidKeyConfigured ? 0 : null,
                  top: Config.googleMapsAndroidKeyConfigured
                      ? null
                      : MediaQuery.of(context).padding.top + kToolbarHeight + AppTheme.spaceXS,
                  left: 0,
                  right: 0,
                  child: _MapLoadErrorBanner(message: _mapLoadError!),
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
  PreferredSizeWidget _buildAppBar(ColorScheme cs) {
    const logoWidget = KingtruxLogo(size: 28);
    final titleRow = Row(
      children: [
        logoWidget,
        const SizedBox(width: AppTheme.spaceSM),
        const Text('KINGTRUX'),
      ],
    );
    return AppBar(
        title: kDebugMode
            ? GestureDetector(
                onLongPress: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PreviewGalleryPage(),
                  ),
                ),
                child: titleRow,
              )
            : titleRow,
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
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: _onSettingsPressed,
          ),
        ],
      );
  }

  // ---------------------------------------------------------------------------
  // Full-screen initial loading state
  // ---------------------------------------------------------------------------
  Widget _buildInitialLoader(ColorScheme cs, AppState state) {
    final error = state.locationError;
    if (error != null) {
      // Detect permanently-denied case to offer "Open Settings" instead of Retry.
      final isPermanentlyDenied =
          error.toLowerCase().contains('permanently denied');
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppTheme.spaceLG),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off_rounded, size: 48, color: cs.error),
              const SizedBox(height: AppTheme.spaceMD),
              Text(
                'Location Unavailable',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.onSurface,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceSM),
              Text(
                error,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppTheme.spaceMD),
              if (isPermanentlyDenied)
                FilledButton.icon(
                  icon: const Icon(Icons.settings_rounded, size: 18),
                  label: const Text('Open App Settings'),
                  onPressed: () async {
                    await Geolocator.openAppSettings();
                  },
                )
              else
                FilledButton.icon(
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: const Text('Retry'),
                  onPressed: () async {
                    try {
                      await state.refreshMyLocation();
                    } catch (_) {
                      // error is surfaced via state.locationError
                    }
                  },
                ),
            ],
          ),
        ),
      );
    }

    return Center(
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
          icon: poi.type == PoiType.scale && _scaleMarkerIcon != null
              ? _scaleMarkerIcon!
              : BitmapDescriptor.defaultMarkerWithHue(_getPoiColor(poi.type)),
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
        final msg = e.toString().replaceFirst('Exception: ', '');
        final isPermanentlyDenied = msg.toLowerCase().contains('permanently denied');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: Theme.of(context).colorScheme.error,
            action: isPermanentlyDenied
                ? SnackBarAction(
                    label: 'Settings',
                    textColor: Theme.of(context).colorScheme.onError,
                    onPressed: () => Geolocator.openAppSettings(),
                  )
                : null,
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

  void _onSettingsPressed() {
    HapticFeedback.selectionClick();
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
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
      builder: (context) => const PoiHubSheet(),
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

  void _onMessagesPressed() {
    HapticFeedback.selectionClick();
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(builder: (_) => const MessagesScreen()),
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
  // Weigh station (WS) quick-action: toggle PoiType.scale layer
  // ---------------------------------------------------------------------------
  void _onWsTogglePressed() {
    HapticFeedback.selectionClick();
    final state = context.read<AppState>();
    final isEnabled = state.enabledPoiLayers.contains(PoiType.scale);
    state.toggleLayer(PoiType.scale, !isEnabled);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEnabled
                ? 'Weigh stations hidden'
                : 'Weigh stations shown on map',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Zoom controls (right-side control rail)
  // ---------------------------------------------------------------------------
  void _onZoomIn() {
    HapticFeedback.selectionClick();
    _mapController?.animateCamera(CameraUpdate.zoomIn());
  }

  void _onZoomOut() {
    HapticFeedback.selectionClick();
    _mapController?.animateCamera(CameraUpdate.zoomOut());
  }

  // ---------------------------------------------------------------------------
  // "Coming soon" stub for unimplemented quick actions
  // ---------------------------------------------------------------------------
  void _showComingSoon(String feature) {
    HapticFeedback.selectionClick();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$feature – Coming soon'),
          duration: const Duration(seconds: 2),
        ),
      );
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

  /// Listens to [AppState] changes and surfaces POI fetch errors as snackbars.
  void _onAppStateChanged() {
    if (!mounted) return;
    final state = context.read<AppState>();
    final err = state.poiError;
    if (err != null && err != _lastPoiError) {
      _lastPoiError = err;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to load POIs. Check your connection and try again.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 6),
        ),
      );
    } else if (err == null) {
      _lastPoiError = null;
    }

    // Show scale-pass prompt when the driver crosses a police weight station.
    if (state.pendingScalePassPoi != null && !_showingScalePassPrompt) {
      _showingScalePassPrompt = true;
      final poi = state.pendingScalePassPoi!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          _showingScalePassPrompt = false;
          return;
        }
        showModalBottomSheet<void>(
          context: context,
          isDismissible: true,
          enableDrag: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (_) => _ScalePassPromptSheet(poi: poi),
        ).whenComplete(() {
          _showingScalePassPrompt = false;
          if (mounted) {
            context.read<AppState>().acknowledgeScalePass();
          }
        });
      });
    }
  }


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
    _mapInitTimer?.cancel();
    _mapController?.dispose();
    // Remove the AppState change listener added in initState.
    _appState?.removeListener(_onAppStateChanged);
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
    required this.onRouteOptions,
    required this.onMessages,
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
  final VoidCallback onRouteOptions;
  final VoidCallback onMessages;
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
            icon: Icons.message_rounded,
            label: 'Messages',
            onPressed: onMessages,
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
// Map-load failure diagnostic banner
// ---------------------------------------------------------------------------

/// Shown when the map controller fails to initialise within the expected
/// timeout window.  Surfaces a human-readable message covering the three most
/// common root causes: missing/invalid API key, network connectivity, or an
/// unavailable Google Play Services installation.
class _MapLoadErrorBanner extends StatelessWidget {
  const _MapLoadErrorBanner({required this.message});

  final String message;

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
              Icon(Icons.warning_rounded, color: cs.onErrorContainer, size: 20),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: Text(
                  message,
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
// Scale pass prompt sheet
// ---------------------------------------------------------------------------

/// Bottom sheet shown when the driver passes a police weight station.
///
/// The driver selects the current status (Open / Monitoring / Closed) and the
/// report is submitted to both local storage and Firestore so other drivers
/// approaching the same station can see it.
class _ScalePassPromptSheet extends StatelessWidget {
  const _ScalePassPromptSheet({required this.poi});

  final Poi poi;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceMD,
          AppTheme.spaceSM,
          AppTheme.spaceMD,
          AppTheme.spaceLG,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            // Title
            Row(
              children: [
                Icon(Icons.scale_rounded, color: cs.primary, size: 24),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Police Weight Station',
                        style: tt.labelMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      Text(poi.name, style: tt.titleMedium),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              'What is the current status?',
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            // Status buttons
            Row(
              children: [
                Expanded(
                  child: _StatusButton(
                    label: 'Open',
                    icon: Icons.check_circle_rounded,
                    color: Colors.green.shade600,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      context.read<AppState>().submitScaleReport(
                            poiId: poi.id,
                            poiName: poi.name,
                            lat: poi.lat,
                            lng: poi.lng,
                            status: ScaleStatus.open,
                          );
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: AppTheme.spaceXS),
                Expanded(
                  child: _StatusButton(
                    label: 'Monitoring',
                    icon: Icons.visibility_rounded,
                    color: Colors.orange.shade700,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      context.read<AppState>().submitScaleReport(
                            poiId: poi.id,
                            poiName: poi.name,
                            lat: poi.lat,
                            lng: poi.lng,
                            status: ScaleStatus.monitoring,
                          );
                      Navigator.of(context).pop();
                    },
                  ),
                ),
                const SizedBox(width: AppTheme.spaceXS),
                Expanded(
                  child: _StatusButton(
                    label: 'Closed',
                    icon: Icons.cancel_rounded,
                    color: Colors.red.shade600,
                    onTap: () {
                      HapticFeedback.mediumImpact();
                      context.read<AppState>().submitScaleReport(
                            poiId: poi.id,
                            poiName: poi.name,
                            lat: poi.lat,
                            lng: poi.lng,
                            status: ScaleStatus.closed,
                          );
                      Navigator.of(context).pop();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spaceXS),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Skip'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A large colored button for the scale status selection prompt.
class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceMD),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: AppTheme.spaceXS),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
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

// ---------------------------------------------------------------------------
// Right-side vertical control rail
// ---------------------------------------------------------------------------

/// A vertically stacked set of square map-control buttons shown on the right
/// side of the map.  Provides: layers, map type toggle, zoom in/out, recenter,
/// and route-filter access.
class _RightControlRail extends StatelessWidget {
  const _RightControlRail({
    required this.mapType,
    required this.followMode,
    required this.onLayers,
    required this.onMapTypeToggle,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onMyLocation,
    required this.onFilters,
  });

  final MapType mapType;
  final bool followMode;
  final VoidCallback onLayers;
  final VoidCallback onMapTypeToggle;
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onMyLocation;
  final VoidCallback onFilters;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Layers – opens the POI layer sheet.
        _MapFab(
          key: const Key('rail_layers'),
          icon: Icons.layers_rounded,
          tooltip: 'Layers',
          onPressed: onLayers,
        ),
        const SizedBox(height: AppTheme.spaceXS),
        // Map type toggle (Normal ↔ Satellite).
        _MapFab(
          key: const Key('map_type_toggle'),
          icon: mapType == MapType.satellite
              ? Icons.map_rounded
              : Icons.satellite_alt_rounded,
          tooltip: mapType == MapType.satellite ? 'Normal map' : 'Satellite view',
          onPressed: onMapTypeToggle,
        ),
        const SizedBox(height: AppTheme.spaceXS),
        // Zoom in.
        _MapFab(
          key: const Key('rail_zoom_in'),
          icon: Icons.add_rounded,
          tooltip: 'Zoom in',
          onPressed: onZoomIn,
        ),
        const SizedBox(height: AppTheme.spaceXS),
        // Zoom out.
        _MapFab(
          key: const Key('rail_zoom_out'),
          icon: Icons.remove_rounded,
          tooltip: 'Zoom out',
          onPressed: onZoomOut,
        ),
        const SizedBox(height: AppTheme.spaceXS),
        // Recenter / my location.
        _MapFab(
          key: const Key('rail_recenter'),
          icon: Icons.my_location_rounded,
          tooltip: 'Recenter',
          onPressed: onMyLocation,
          active: followMode,
        ),
        const SizedBox(height: AppTheme.spaceXS),
        // Filters – opens route options / truck restriction settings.
        _MapFab(
          key: const Key('rail_filters'),
          icon: Icons.tune_rounded,
          tooltip: 'Filters',
          onPressed: onFilters,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Horizontal quick-actions strip
// ---------------------------------------------------------------------------

/// A horizontally scrollable strip of labeled icon buttons shown above the
/// bottom destination panel.  Surfaces the most-used map actions so they are
/// always one tap away.
class _QuickActionsBar extends StatelessWidget {
  const _QuickActionsBar({
    super.key,
    required this.isWsEnabled,
    required this.onDirection,
    required this.onPlaces,
    required this.onWs,
    required this.onRestricted,
    required this.onToll,
    required this.onWeather,
    required this.onCameras,
  });

  final bool isWsEnabled;
  final VoidCallback onDirection;
  final VoidCallback onPlaces;
  final VoidCallback onWs;
  final VoidCallback onRestricted;
  final VoidCallback onToll;
  final VoidCallback onWeather;
  final VoidCallback onCameras;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: AppTheme.elevationCard,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppTheme.spaceXS,
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceSM),
            child: Row(
              children: [
                _QuickActionButton(
                  key: const Key('quick_action_direction'),
                  icon: Icons.directions_rounded,
                  label: 'Direction',
                  onTap: onDirection,
                ),
                _QuickActionButton(
                  key: const Key('quick_action_places'),
                  icon: Icons.place_rounded,
                  label: 'Places',
                  onTap: onPlaces,
                ),
                _QuickActionButton(
                  key: const Key('quick_action_ws'),
                  icon: Icons.scale_rounded,
                  label: 'WS',
                  onTap: onWs,
                  // Highlight when the weigh-station layer is active.
                  isActive: isWsEnabled,
                ),
                _QuickActionButton(
                  key: const Key('quick_action_restricted'),
                  icon: Icons.no_transfer_rounded,
                  label: 'Restricted',
                  onTap: onRestricted,
                ),
                _QuickActionButton(
                  key: const Key('quick_action_toll'),
                  icon: Icons.monetization_on_outlined,
                  label: 'Toll',
                  onTap: onToll,
                ),
                _QuickActionButton(
                  key: const Key('quick_action_weather'),
                  icon: Icons.wb_cloudy_outlined,
                  label: 'Weather',
                  onTap: onWeather,
                ),
                _QuickActionButton(
                  key: const Key('quick_action_cameras'),
                  icon: Icons.videocam_outlined,
                  label: 'Cameras',
                  onTap: onCameras,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A single labeled icon button used inside [_QuickActionsBar].
class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  /// When true the button is tinted with the primary color.
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final effectiveColor = isActive ? cs.primary : cs.onSurfaceVariant;
    return Semantics(
      label: label,
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceSM + 2,
            vertical: AppTheme.spaceXS,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 22, color: effectiveColor),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: effectiveColor,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.normal,
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
// Bottom destination call-to-action panel
// ---------------------------------------------------------------------------

/// Shown at the bottom of the map when no route is active.  Prompts the user
/// to set a destination and opens the [WhereToSheet] on tap.
class _BottomDestinationCta extends StatelessWidget {
  const _BottomDestinationCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      key: const Key('bottom_destination_cta'),
      color: cs.surfaceContainerLow,
      elevation: AppTheme.elevationCard,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceSM + 2,
          ),
          child: Row(
            children: [
              Icon(
                Icons.local_shipping_rounded,
                color: cs.primary,
                size: 22,
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: Text(
                  'Set destination for truck routes',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: cs.onSurface,
                      ),
                ),
              ),
              Icon(
                Icons.search_rounded,
                color: cs.onSurfaceVariant,
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}


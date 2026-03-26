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
import '../services/here_routing_service.dart';
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
import 'widgets/map_filter_sheet.dart';
import 'trip_screen.dart';
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
import 'package:url_launcher/url_launcher.dart';
import '../models/nearby_place.dart';
import '../services/external_nav_service.dart';

/// Horizontal clearance (dp) reserved on the right side for the
/// [_RightControlRail] so that top overlays don't occlude the controls.
const double _kControlRailClearance = 60.0;

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
  /// Last seen [AppState.routeError] value used to detect changes for snackbar.
  String? _lastRouteError;
  /// Cached reference to [AppState] for use in [dispose].
  AppState? _appState;

  // ── Scale pass prompt ──────────────────────────────────────────────────────
  /// Prevents showing the scale-pass prompt dialog more than once at a time.
  bool _showingScalePassPrompt = false;

  // ── POI preview card ───────────────────────────────────────────────────────
  /// The POI currently shown in the compact preview card, or null when hidden.
  Poi? _previewPoi;

  // ── Custom marker icons ────────────────────────────────────────────────────
  /// Cached green-circle-with-w icon for [PoiType.scale] markers.
  BitmapDescriptor? _scaleMarkerIcon;

  // ── Nearby places debounce ─────────────────────────────────────────────────
  /// Debounce timer for refreshing nearby truck stops on map movement.
  Timer? _nearbyPlacesDebounce;

  /// Last camera center used for a nearby-places fetch (avoids redundant
  /// requests when the camera barely moves).
  LatLng? _lastNearbyPlacesFetchCenter;

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
    final icon = await buildRoundedRectLetterMarker(
      bgColor: const Color(0xFF0D7A6C),
      letter: 'W',
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
                onCameraIdle: _onCameraIdle,
                markers: _buildMarkers(state),
                polylines: _buildPolylines(state),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
                // Custom zoom controls exist in the right control rail; disable
                // the default Google Maps zoom buttons to avoid duplication.
                zoomControlsEnabled: false,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + kToolbarHeight,
                  // Bottom padding clears the compact bottom bar (~68 px)
                  // plus safe-area bottom.
                  bottom: 140 + MediaQuery.of(context).padding.bottom,
                ),
              ),

              // ── Prominent "Where to?" search bar (top, always visible) ──
              Positioned(
                top: MediaQuery.of(context).padding.top + kToolbarHeight + AppTheme.spaceXS,
                left: AppTheme.spaceMD,
                right: _kControlRailClearance,
                child: _WhereToSearchBar(onTap: _onWhereToCTAPressed),
              ),

              // ── Compact top filter chips (Places / Traffic Cams / DOT 511s) ─
              Positioned(
                top: MediaQuery.of(context).padding.top +
                    kToolbarHeight +
                    AppTheme.spaceXS +
                    _WhereToSearchBar.height +
                    AppTheme.spaceXS,
                left: 0,
                right: 0,
                child: _MapTopChipsBar(
                  placesActive: state.pois.isNotEmpty,
                  onPlaces: _onPoiBrowserPressed,
                  onTrafficCams: _onTrafficCamsToggle,
                  onDot511s: _onDot511sToggle,
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

              // ── Bottom panel: compact bar + expandable quick actions ────
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

                      // POI preview card replaces bottom bar when a marker is
                      // tapped; dismiss by tapping the map or the × button.
                      if (_previewPoi != null)
                        _PoiPreviewCard(
                          key: const Key('poi_preview_card'),
                          poi: _previewPoi!,
                          myLat: state.myLat,
                          myLng: state.myLng,
                          isFavorite: state.favoritePois.contains(_previewPoi!.id),
                          onClose: _dismissPoiPreview,
                          onDetails: () => _openFullPoiDetails(_previewPoi!),
                          onNavigate: () async {
                            final poi = _previewPoi!;
                            _dismissPoiPreview();
                            state.setDestination(poi.lat, poi.lng);
                            try {
                              await state.buildTruckRoute();
                            } on HereApiKeyMissingException {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Truck routing unavailable: HERE API key not set.',
                                    ),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.error,
                                    duration: const Duration(seconds: 8),
                                  ),
                                );
                              }
                            } catch (_) {
                              // routeError surfaced via _onAppStateChanged.
                            }
                          },
                          onFavorite: () {
                            HapticFeedback.selectionClick();
                            state.toggleFavorite(_previewPoi!.id);
                          },
                        )
                      else
                        // Compact search bar + expandable quick-action grid.
                        _MapBottomBar(
                          key: const Key('map_bottom_bar'),
                          isWsEnabled:
                              state.enabledPoiLayers.contains(PoiType.scale),
                          onSearchTap: _onWhereToCTAPressed,
                          onDirection: _onWhereToCTAPressed,
                          onPlaces: _onPoiBrowserPressed,
                          onWs: _onWsTogglePressed,
                          onRestricted: _onRouteOptionsPressed,
                          onParking: _onParkingPressed,
                          onFuel: _onFuelPressed,
                          onWeather: () => _showComingSoon('Weather'),
                          onCameras: () => _showComingSoon('Cameras'),
                        ),
                    ],
                  ),
                ),

              // ── Speed display (bottom-left, above bottom bar) ────────────
              const Positioned(
                bottom: 140,
                left: AppTheme.spaceMD,
                child: SpeedDisplay(),
              ),

              // ── Closest police weight station (bottom-right, above bar) ──
              if (state.showWeightStationOverlay)
                const Positioned(
                  bottom: 140,
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

    // Nearby truck stops / fuel stations from Google Places API.
    for (final place in state.nearbyPlaces) {
      markers.add(
        Marker(
          markerId: MarkerId('places_${place.placeId}'),
          position: LatLng(place.lat, place.lng),
          infoWindow: InfoWindow(
            title: place.name,
            snippet: place.vicinity ?? 'Tap to navigate',
            onTap: () => _onNearbyPlaceTap(place),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueCyan,
          ),
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
      case PoiType.truckWash:
        return BitmapDescriptor.hueBlue;
      case PoiType.hotel:
        return BitmapDescriptor.hueMagenta;
      case PoiType.repairShop:
        return BitmapDescriptor.hueRed;
      case PoiType.tires:
        return BitmapDescriptor.hueOrange;
      case PoiType.walmart:
        return BitmapDescriptor.hueCyan;
      case PoiType.facility:
        return BitmapDescriptor.hueGreen;
      case PoiType.clearance:
        return BitmapDescriptor.hueYellow;
      case PoiType.truckDealer:
        return BitmapDescriptor.hueViolet;
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
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => const TripScreen(),
      ),
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
      isScrollControlled: true,
      builder: (context) => const MapFilterSheet(),
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
    setState(() => _previewPoi = poi);
  }

  /// Called when the user taps the InfoWindow of a nearby truck stop / fuel
  /// station marker sourced from the Google Places API.
  ///
  /// Opens external turn-by-turn navigation to the selected place via
  /// [ExternalNavService.openGoogleMaps].  Shows a snackbar if navigation
  /// cannot be launched.
  Future<void> _onNearbyPlaceTap(NearbyPlace place) async {
    HapticFeedback.selectionClick();
    try {
      final launched = await ExternalNavService.openGoogleMaps(
        destLat: place.lat,
        destLng: place.lng,
      );
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open navigation app')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Navigation error: $e')),
        );
      }
    }
  }

  /// Opens the full [PoiDetailSheet] for [poi] and clears the preview card.
  void _openFullPoiDetails(Poi poi) {
    setState(() => _previewPoi = null);
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => PoiDetailSheet(poi: poi),
    );
  }

  /// Dismisses the POI preview card without opening full details.
  void _dismissPoiPreview() {
    setState(() => _previewPoi = null);
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

  void _onTrafficCamsToggle() {
    _showComingSoon('Traffic Cams');
  }

  void _onDot511sToggle() {
    _showComingSoon('DOT 511s');
  }

  void _onParkingPressed() {
    _showComingSoon('Parking');
  }

  void _onFuelPressed() {
    _showComingSoon('Fuel');
  }

  /// Called when the user taps the map. Only acts when destination-setting
  /// mode is active; all other taps are ignored so normal map interaction
  /// (panning, zooming, marker taps) is unaffected.
  void _onMapTap(LatLng position) {
    // Dismiss POI preview card on any map tap.
    if (_previewPoi != null) {
      setState(() => _previewPoi = null);
      return;
    }
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
    await showWhereToSheet(context);
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

  /// Called when the camera finishes moving. Debounces nearby-places requests
  /// so we don't hammer the Places API on every pixel of camera movement.
  void _onCameraIdle() {
    _nearbyPlacesDebounce?.cancel();
    _nearbyPlacesDebounce = Timer(const Duration(seconds: 2), () async {
      if (!mounted) return;
      final controller = _mapController;
      if (controller == null) return;

      final visibleRegion = await controller.getVisibleRegion();
      final center = LatLng(
        (visibleRegion.northeast.latitude + visibleRegion.southwest.latitude) /
            2,
        (visibleRegion.northeast.longitude +
                visibleRegion.southwest.longitude) /
            2,
      );

      // Skip if the center has barely moved (< 1 km) to avoid redundant requests.
      final last = _lastNearbyPlacesFetchCenter;
      if (last != null) {
        final distanceMeters = Geolocator.distanceBetween(
          last.latitude,
          last.longitude,
          center.latitude,
          center.longitude,
        );
        if (distanceMeters < 1000) return;
      }
      _lastNearbyPlacesFetchCenter = center;

      if (!mounted) return;
      final appState = context.read<AppState>();
      await appState.loadNearbyTruckStops(
        searchLat: center.latitude,
        searchLng: center.longitude,
      );

      if (!mounted) return;
      final err = appState.nearbyPlacesError;
      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nearby stops: $err'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    });
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

    // ── POI load errors ────────────────────────────────────────────────────
    final poiErr = state.poiError;
    if (poiErr != null && poiErr != _lastPoiError) {
      _lastPoiError = poiErr;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Unable to load POIs. Check your connection and try again.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 6),
        ),
      );
    } else if (poiErr == null) {
      _lastPoiError = null;
    }

    // ── Route errors (e.g. missing HERE API key) ───────────────────────────
    final routeErr = state.routeError;
    if (routeErr != null && routeErr != _lastRouteError) {
      _lastRouteError = routeErr;
      final isKeyMissing = routeErr.contains('HERE API key not configured');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isKeyMissing
                ? 'Truck routing unavailable: HERE API key not set. '
                    'See HERE_NAVIGATE_SETUP.md.'
                : 'Route error. Check your connection and try again.',
          ),
          backgroundColor: Theme.of(context).colorScheme.error,
          duration: const Duration(seconds: 8),
        ),
      );
    } else if (routeErr == null) {
      _lastRouteError = null;
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
    } on HereApiKeyMissingException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Truck routing is unavailable: HERE API key not configured. '
              'See HERE_NAVIGATE_SETUP.md for setup instructions.',
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 8),
          ),
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
    _nearbyPlacesDebounce?.cancel();
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


/// A single labeled icon button used inside [_QuickActionsGrid].
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
// Prominent "Where to?" search bar (top overlay)
// ---------------------------------------------------------------------------

/// A tappable search-bar stub that sits just below the app bar and is always
/// visible on the map.  Tapping it opens the full [WhereToSheet].
class _WhereToSearchBar extends StatelessWidget {
  const _WhereToSearchBar({required this.onTap});

  final VoidCallback onTap;

  /// Logical height used by the parent [Stack] to position widgets below this bar.
  static const double height = 48.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surface,
      elevation: 3,
      shadowColor: cs.shadow,
      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        child: SizedBox(
          height: height,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
            child: Row(
              children: [
                Icon(Icons.search_rounded, color: cs.primary, size: 22),
                const SizedBox(width: AppTheme.spaceSM),
                Expanded(
                  child: Text(
                    'Where to?',
                    style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, color: cs.outline, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact top filter-chips bar (Places / Traffic Cams / DOT 511s)
// ---------------------------------------------------------------------------

/// A horizontally scrollable row of compact [FilterChip] toggles shown just
/// below the app bar.  Each chip surfaces a key map-layer category; tapping
/// opens the relevant feature or shows a "coming soon" notice.
class _MapTopChipsBar extends StatelessWidget {
  const _MapTopChipsBar({
    super.key,
    required this.placesActive,
    required this.onPlaces,
    required this.onTrafficCams,
    required this.onDot511s,
  });

  final bool placesActive;
  final VoidCallback onPlaces;
  final VoidCallback onTrafficCams;
  final VoidCallback onDot511s;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      // Right padding leaves room for the right-side control rail (~54 dp).
      padding: const EdgeInsets.only(
        left: AppTheme.spaceMD,
        right: 60,
      ),
      child: Row(
        children: [
          FilterChip(
            avatar: const Icon(Icons.place_rounded, size: 16),
            label: const Text('Places'),
            selected: placesActive,
            onSelected: (_) => onPlaces(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: AppTheme.spaceXS),
          FilterChip(
            avatar: const Icon(Icons.videocam_outlined, size: 16),
            label: const Text('Traffic Cams'),
            selected: false,
            onSelected: (_) => onTrafficCams(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          const SizedBox(width: AppTheme.spaceXS),
          FilterChip(
            avatar: const Icon(Icons.info_outlined, size: 16),
            label: const Text('DOT 511s'),
            selected: false,
            onSelected: (_) => onDot511s(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Compact collapsed/expandable map bottom bar
// ---------------------------------------------------------------------------

/// A compact bottom bar that is always visible above the [_MapToolbar].
///
/// **Collapsed state** (default): shows a tappable search field and a
/// chevron/expand button.
///
/// **Expanded state**: the search field remains and an animated panel
/// reveals a 4 × 2 grid of quick-action buttons (Truck Stops, Weigh
/// Stations, Parking, Fuel + Directions, Restricted, Cameras, Weather).
class _MapBottomBar extends StatefulWidget {
  const _MapBottomBar({
    super.key,
    required this.isWsEnabled,
    required this.onSearchTap,
    required this.onDirection,
    required this.onPlaces,
    required this.onWs,
    required this.onRestricted,
    required this.onParking,
    required this.onFuel,
    required this.onWeather,
    required this.onCameras,
  });

  final bool isWsEnabled;
  final VoidCallback onSearchTap;
  final VoidCallback onDirection;
  final VoidCallback onPlaces;
  final VoidCallback onWs;
  final VoidCallback onRestricted;
  final VoidCallback onParking;
  final VoidCallback onFuel;
  final VoidCallback onWeather;
  final VoidCallback onCameras;

  @override
  State<_MapBottomBar> createState() => _MapBottomBarState();
}

class _MapBottomBarState extends State<_MapBottomBar> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surface,
      elevation: AppTheme.elevationSheet,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusLG),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(top: AppTheme.spaceXS),
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Search bar row
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppTheme.spaceMD,
                AppTheme.spaceXS,
                AppTheme.spaceSM,
                AppTheme.spaceXS,
              ),
              child: Row(
                children: [
                  // Tappable search field
                  Expanded(
                    child: InkWell(
                      onTap: widget.onSearchTap,
                      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceMD,
                          vertical: AppTheme.spaceXS + 4,
                        ),
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppTheme.radiusXL),
                          border: Border.all(
                            color: cs.outlineVariant,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.local_shipping_rounded,
                              size: 18,
                              color: cs.primary,
                            ),
                            const SizedBox(width: AppTheme.spaceSM),
                            Expanded(
                              child: Text(
                                'Set destination for truck routes',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Icon(
                              Icons.search_rounded,
                              size: 18,
                              color: cs.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceXS),
                  // Expand / collapse toggle
                  Tooltip(
                    message: _expanded ? 'Collapse' : 'Quick actions',
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _expanded = !_expanded);
                      },
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                          border: Border.all(
                            color: cs.outlineVariant,
                            width: 1,
                          ),
                        ),
                        child: AnimatedRotation(
                          turns: _expanded ? 0.5 : 0,
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            Icons.expand_less_rounded,
                            size: 22,
                            color: cs.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Expandable quick-actions grid
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spaceSM,
                        0,
                        AppTheme.spaceSM,
                        AppTheme.spaceSM,
                      ),
                      child: _QuickActionsGrid(
                        isWsEnabled: widget.isWsEnabled,
                        onDirection: widget.onDirection,
                        onPlaces: widget.onPlaces,
                        onWs: widget.onWs,
                        onRestricted: widget.onRestricted,
                        onParking: widget.onParking,
                        onFuel: widget.onFuel,
                        onCameras: widget.onCameras,
                        onWeather: widget.onWeather,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick-actions grid (used by _MapBottomBar expanded state)
// ---------------------------------------------------------------------------

/// A 4 × 2 grid of compact labeled icon buttons.
///
/// Row 1 (primary categories): Truck Stops, Weigh Sta., Parking, Fuel.
/// Row 2 (routing & utilities): Directions, Restricted, Cameras, Weather.
class _QuickActionsGrid extends StatelessWidget {
  const _QuickActionsGrid({
    required this.isWsEnabled,
    required this.onDirection,
    required this.onPlaces,
    required this.onWs,
    required this.onRestricted,
    required this.onParking,
    required this.onFuel,
    required this.onCameras,
    required this.onWeather,
  });

  final bool isWsEnabled;
  final VoidCallback onDirection;
  final VoidCallback onPlaces;
  final VoidCallback onWs;
  final VoidCallback onRestricted;
  final VoidCallback onParking;
  final VoidCallback onFuel;
  final VoidCallback onCameras;
  final VoidCallback onWeather;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Row 1 – primary categories
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                key: const Key('quick_action_places'),
                icon: Icons.local_shipping_rounded,
                label: 'Truck Stops',
                onTap: onPlaces,
              ),
            ),
            Expanded(
              child: _QuickActionButton(
                key: const Key('quick_action_ws'),
                icon: Icons.scale_rounded,
                label: 'Weigh Sta.',
                onTap: onWs,
                isActive: isWsEnabled,
              ),
            ),
            Expanded(
              child: _QuickActionButton(
                key: const Key('quick_action_parking'),
                icon: Icons.local_parking_rounded,
                label: 'Parking',
                onTap: onParking,
              ),
            ),
            Expanded(
              child: _QuickActionButton(
                key: const Key('quick_action_fuel'),
                icon: Icons.local_gas_station_rounded,
                label: 'Fuel',
                onTap: onFuel,
              ),
            ),
          ],
        ),
        // Row 2 – routing & utilities
        Row(
          children: [
            Expanded(
              child: _QuickActionButton(
                key: const Key('quick_action_direction'),
                icon: Icons.directions_rounded,
                label: 'Directions',
                onTap: onDirection,
              ),
            ),
            Expanded(
              child: _QuickActionButton(
                key: const Key('quick_action_restricted'),
                icon: Icons.no_transfer_rounded,
                label: 'Restricted',
                onTap: onRestricted,
              ),
            ),
            Expanded(
              child: _QuickActionButton(
                key: const Key('quick_action_cameras'),
                icon: Icons.videocam_outlined,
                label: 'Cameras',
                onTap: onCameras,
              ),
            ),
            Expanded(
              child: _QuickActionButton(
                key: const Key('quick_action_weather'),
                icon: Icons.wb_cloudy_outlined,
                label: 'Weather',
                onTap: onWeather,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// POI preview card (shown when a map marker is tapped)
// ---------------------------------------------------------------------------

/// A compact "sneak peek" card shown at the bottom of the map when the driver
/// taps a POI marker.
///
/// Provides one-tap access to the most common actions (Navigate, Favourite,
/// Call) and a "Full Details" button that slides up the complete
/// [PoiDetailSheet].  Tap anywhere on the map (or the × button) to dismiss.
class _PoiPreviewCard extends StatelessWidget {
  const _PoiPreviewCard({
    super.key,
    required this.poi,
    required this.myLat,
    required this.myLng,
    required this.isFavorite,
    required this.onClose,
    required this.onDetails,
    required this.onNavigate,
    required this.onFavorite,
  });

  final Poi poi;
  final double? myLat;
  final double? myLng;
  final bool isFavorite;
  final VoidCallback onClose;
  final VoidCallback onDetails;
  final VoidCallback onNavigate;
  final VoidCallback onFavorite;

  /// Formats [meters] as a human-readable distance string.
  static String _formatDistance(double meters) {
    if (meters < 1000) return '${meters.round()} m';
    final km = meters / 1000;
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Calculate straight-line distance if we have current location.
    final double? distMeters =
        (myLat != null && myLng != null)
            ? Geolocator.distanceBetween(myLat!, myLng!, poi.lat, poi.lng)
            : null;

    final phone = poi.tags['phone'] as String?;
    final address = poi.tags['addr:full'] as String? ??
        poi.tags['addr:street'] as String?;

    return Material(
      color: cs.surface,
      elevation: AppTheme.elevationSheet,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppTheme.radiusLG),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppTheme.spaceMD,
            AppTheme.spaceSM,
            AppTheme.spaceMD,
            AppTheme.spaceMD,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.onSurfaceVariant.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceSM),

              // Header row: icon + name/type + distance + close
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: cs.primaryContainer,
                    child: Icon(
                      PoiDetailSheet.poiIcon(poi.type),
                      color: cs.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceMD),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poi.name,
                          style: tt.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Text(
                              PoiDetailSheet.poiLabel(poi.type),
                              style: tt.bodySmall?.copyWith(
                                color: cs.primary,
                              ),
                            ),
                            if (distMeters != null) ...[
                              Text(
                                '  ·  ',
                                style:
                                    tt.bodySmall?.copyWith(color: cs.outline),
                              ),
                              Text(
                                _formatDistance(distMeters),
                                style: tt.bodySmall
                                    ?.copyWith(color: cs.onSurfaceVariant),
                              ),
                            ],
                          ],
                        ),
                        if (address != null)
                          Text(
                            address,
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  // Close button
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    tooltip: 'Dismiss',
                    onPressed: onClose,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceSM),

              // Action buttons row
              Row(
                children: [
                  // Navigate
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.navigation_rounded, size: 16),
                      label: const Text('Go'),
                      onPressed: onNavigate,
                    ),
                  ),
                  const SizedBox(width: AppTheme.spaceXS),

                  // Favorite / Save
                  IconButton.outlined(
                    tooltip: isFavorite ? 'Remove favorite' : 'Save',
                    icon: Icon(
                      isFavorite
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: isFavorite ? Colors.amber : null,
                    ),
                    onPressed: onFavorite,
                  ),

                  // Call – only shown when phone number is available.
                  if (phone != null && phone.isNotEmpty) ...[
                    const SizedBox(width: AppTheme.spaceXS),
                    IconButton.outlined(
                      tooltip: 'Call',
                      icon: const Icon(Icons.phone_rounded),
                      onPressed: () async {
                        final uri = Uri(scheme: 'tel', path: phone);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri);
                        }
                      },
                    ),
                  ],

                  const Spacer(),

                  // Full details
                  TextButton.icon(
                    icon: const Icon(Icons.info_outline_rounded, size: 16),
                    label: const Text('Details'),
                    onPressed: onDetails,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
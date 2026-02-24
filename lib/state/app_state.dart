import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:geolocator/geolocator.dart';
import '../models/alert_event.dart';
import '../models/truck_profile.dart';
import '../models/route_result.dart';
import '../models/weather_point.dart';
import '../models/navigation_maneuver.dart';
import '../models/poi.dart';
import '../models/trip.dart';
import '../models/trip_stop.dart';
import '../services/location_service.dart';
import '../services/here_routing_service.dart';
import '../services/navigation_session_service.dart';
import '../services/overpass_poi_service.dart';
import '../services/weather_service.dart';
import '../services/truck_profile_service.dart';
import '../services/revenue_cat_service.dart';
import '../services/voice_settings_service.dart';
import '../services/favorites_service.dart';
import '../services/trip_service.dart';
import '../services/trip_routing_service.dart';
import '../services/stop_optimizer.dart';
import '../services/route_monitor.dart';

/// Application state management using ChangeNotifier
class AppState extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final HereRoutingService _routingService = HereRoutingService();
  final NavigationSessionService _navService = NavigationSessionService();
  final OverpassPoiService _poiService = OverpassPoiService();
  final WeatherService _weatherService = WeatherService();
  final TruckProfileService _truckProfileService = TruckProfileService();
  final RevenueCatService revenueCatService = RevenueCatService();
  final VoiceSettingsService _voiceSettingsService = VoiceSettingsService();
  final FavoritesService _favoritesService = FavoritesService();
  final TripService _tripService = TripService();
  final TripRoutingService _tripRoutingService = TripRoutingService();
  final RouteMonitor _routeMonitor = RouteMonitor();
  StreamSubscription<Position>? _routeMonitorSub;
  // Lazily initialised on first use; never touched during unit tests unless
  // voice guidance is explicitly invoked.
  FlutterTts? _ttsInstance;
  FlutterTts get _tts => _ttsInstance ??= FlutterTts();

  // Current location
  double? myLat;
  double? myLng;

  // Destination
  double? destLat;
  double? destLng;

  // Truck configuration
  TruckProfile truckProfile = TruckProfile.defaultProfile();

  // Route
  RouteResult? routeResult;

  /// Error message from the last `buildTruckRoute()` call, or `null` if the
  /// last attempt succeeded (or no attempt has been made yet).
  String? routeError;

  // Weather
  WeatherPoint? weatherAtCurrentLocation;

  // POI layers
  Set<PoiType> enabledPoiLayers = {};
  List<Poi> pois = [];

  /// IDs of POIs the driver has marked as favorites.
  Set<String> favoritePois = {};

  // ---------------------------------------------------------------------------
  // Trip planner state
  // ---------------------------------------------------------------------------

  /// The currently active multi-stop trip, or `null` if no trip is planned.
  Trip? activeTrip;

  /// Whether a trip route is currently being calculated.
  bool isLoadingTripRoute = false;

  /// Error message from the last [buildTripRoute] call, or `null` on success.
  String? tripRouteError;

  // Loading states
  bool isLoadingRoute = false;
  bool isLoadingPois = false;

  // Subscription / entitlement state
  /// `true` when the user has an active KINGTRUX Pro entitlement.
  bool isPro = false;

  // ---------------------------------------------------------------------------
  // Navigation state
  // ---------------------------------------------------------------------------

  /// Whether a navigation session is currently active.
  bool isNavigating = false;

  /// Whether voice guidance (TTS) is enabled.
  bool voiceGuidanceEnabled = true;

  /// BCP-47 language tag used for voice guidance TTS.
  ///
  /// Defaults to US English. Language-selection UI is delivered in PR4; this
  /// field provides the underlying architecture so the setting can be wired in
  /// without changes to the voice pipeline.
  String voiceLanguage = 'en-US';

  /// Voice languages supported by KINGTRUX (USA + Canada region).
  static const List<String> supportedVoiceLanguages = [
    'en-US',
    'en-CA',
    'fr-CA',
    'es-US',
  ];

  // ---------------------------------------------------------------------------
  // Alerts state
  // ---------------------------------------------------------------------------

  /// Queue of pending alerts to show. The first element is the active alert.
  final List<AlertEvent> _alertQueue = [];

  /// The alert currently being shown, or `null` if no alerts are pending.
  AlertEvent? get currentAlert => _alertQueue.isEmpty ? null : _alertQueue.first;

  /// All pending alerts (including the current one).
  List<AlertEvent> get alertQueue => List.unmodifiable(_alertQueue);

  // ---------------------------------------------------------------------------
  // Navigation state helpers
  // ---------------------------------------------------------------------------

  /// The maneuver the driver should execute next.
  NavigationManeuver? get currentManeuver => _navService.currentManeuver;

  /// All remaining maneuvers from the current position to the destination.
  List<NavigationManeuver> get remainingManeuvers =>
      _navService.remainingManeuvers;

  /// Total remaining route distance in metres (sum of remaining maneuver legs).
  double get remainingDistanceMeters => _navService.remainingDistanceMeters;

  /// Total remaining route duration in seconds (sum of remaining maneuver legs).
  int get remainingDurationSeconds => _navService.remainingDurationSeconds;

  // ---------------------------------------------------------------------------
  // Initialisation
  // ---------------------------------------------------------------------------

  /// Initialize app state and get current location
  Future<void> init() async {
    try {
      truckProfile = await _truckProfileService.load();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading truck profile: $e');
    }
    try {
      final settings = await _voiceSettingsService.load();
      voiceGuidanceEnabled = settings.enabled;
      voiceLanguage = settings.language;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading voice settings: $e');
    }
    try {
      favoritePois = await _favoritesService.load();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading favorites: $e');
    }
    try {
      activeTrip = await _tripService.loadActiveTrip();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading active trip: $e');
    }
    try {
      await refreshMyLocation();
    } catch (e) {
      debugPrint('Error initializing location: $e');
    }
    // Initialize RevenueCat and check current entitlement status.
    try {
      await revenueCatService.init();
      await _refreshProStatus();
    } catch (e) {
      debugPrint('Error initializing RevenueCat: $e');
    }
  }

  /// Refresh the Pro entitlement status from RevenueCat.
  Future<void> _refreshProStatus() async {
    final info = await revenueCatService.getCustomerInfo();
    if (info != null) {
      isPro = revenueCatService.isProActive(info);
      notifyListeners();
    }
  }

  /// Called by the paywall after a successful purchase or restore.
  void setProStatus({required bool active}) {
    isPro = active;
    notifyListeners();
  }

  /// Update current position and fetch weather
  Future<void> refreshMyLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      myLat = position.latitude;
      myLng = position.longitude;
      notifyListeners();

      // Fetch weather for current location
      try {
        weatherAtCurrentLocation = await _weatherService.getCurrentWeather(
          lat: myLat!,
          lng: myLng!,
        );
        notifyListeners();
      } catch (e) {
        debugPrint('Error fetching weather: $e');
      }
    } catch (e) {
      debugPrint('Error refreshing location: $e');
      rethrow;
    }
  }

  /// Set destination and prepare for routing
  void setDestination(double lat, double lng) {
    destLat = lat;
    destLng = lng;
    notifyListeners();
  }

  /// Update truck profile and persist to device storage.
  void setTruck(TruckProfile profile) {
    truckProfile = profile;
    notifyListeners();
    _truckProfileService.save(profile).catchError(
      (Object e) => debugPrint('Error saving truck profile: $e'),
    );
  }

  /// Toggle POI layer visibility
  void toggleLayer(PoiType type, bool enabled) {
    if (enabled) {
      enabledPoiLayers.add(type);
    } else {
      enabledPoiLayers.remove(type);
    }
    notifyListeners();
  }

  /// Toggle the favorite state of a POI identified by [poiId].
  void toggleFavorite(String poiId) {
    if (favoritePois.contains(poiId)) {
      favoritePois.remove(poiId);
    } else {
      favoritePois.add(poiId);
    }
    _favoritesService.save(Set.of(favoritePois)).catchError(
      (Object e) => debugPrint('Error saving favorites: $e'),
    );
    notifyListeners();
  }

  /// Calculate truck route from current location to destination
  Future<void> buildTruckRoute() async {
    if (myLat == null || myLng == null || destLat == null || destLng == null) {
      routeError = 'Location or destination not set';
      routeResult = null;
      notifyListeners();
      return;
    }

    routeError = null;
    isLoadingRoute = true;
    notifyListeners();

    try {
      routeResult = await _routingService.getTruckRoute(
        originLat: myLat!,
        originLng: myLng!,
        destLat: destLat!,
        destLng: destLng!,
        truckProfile: truckProfile,
      );
      if (routeResult != null) _startRouteMonitoring();
    } catch (e) {
      routeError = e.toString();
      routeResult = null;
    } finally {
      isLoadingRoute = false;
      notifyListeners();
    }
  }

  /// Load POIs around current location
  Future<void> loadPois({double radiusMeters = 15000}) async {
    if (myLat == null || myLng == null) {
      throw Exception('Current location not set');
    }

    isLoadingPois = true;
    notifyListeners();

    try {
      pois = await _poiService.fetchPois(
        centerLat: myLat!,
        centerLng: myLng!,
        enabledTypes: enabledPoiLayers,
        radiusMeters: radiusMeters,
      );
    } finally {
      isLoadingPois = false;
      notifyListeners();
    }
  }

  /// Load POIs near current location AND along the active route (if available).
  /// Results from both sources are merged and deduplicated by id.
  Future<void> loadPoisAlongRoute({
    double nearMeRadiusMeters = 15000,
    double routeRadiusMeters = 5000,
    int routeSamples = 8,
  }) async {
    if (myLat == null || myLng == null) {
      throw Exception('Current location not set');
    }

    isLoadingPois = true;
    notifyListeners();

    try {
      // Fetch near current location
      final nearMe = await _poiService.fetchPois(
        centerLat: myLat!,
        centerLng: myLng!,
        enabledTypes: enabledPoiLayers,
        radiusMeters: nearMeRadiusMeters,
      );

      // Fetch along route if available
      List<Poi> alongRoute = [];
      final route = routeResult;
      if (route != null && route.polylinePoints.isNotEmpty) {
        final latLngs = route.polylinePoints
            .map((p) => [p.latitude, p.longitude])
            .toList();
        alongRoute = await _poiService.fetchPoisAlongRoute(
          routeLatLngs: latLngs,
          enabledTypes: enabledPoiLayers,
          radiusMeters: routeRadiusMeters,
          maxSamples: routeSamples,
        );
      }

      // Merge, deduplicating by id (near-me takes precedence)
      final seen = <String>{};
      final merged = <Poi>[];
      for (final poi in [...nearMe, ...alongRoute]) {
        if (seen.add(poi.id)) {
          merged.add(poi);
        }
      }
      pois = merged;
    } finally {
      isLoadingPois = false;
      notifyListeners();
    }
  }

  /// Clear route and destination
  void clearRoute() {
    _stopRouteMonitoring();
    routeResult = null;
    routeError = null;
    destLat = null;
    destLng = null;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Trip planner
  // ---------------------------------------------------------------------------

  /// Replace the active trip with [trip] and persist it.
  void setActiveTrip(Trip trip) {
    activeTrip = trip;
    notifyListeners();
    _tripService.saveActiveTrip(trip).catchError(
      (Object e) => debugPrint('Error saving active trip: $e'),
    );
  }

  /// Add a stop to the current active trip (creates a new trip if needed).
  void addTripStop(TripStop stop) {
    final now = DateTime.now();
    final current = activeTrip;
    final updated = current == null
        ? Trip(
            id: stop.id,
            stops: [stop],
            createdAt: now,
            updatedAt: now,
          )
        : current.copyWith(stops: [...current.stops, stop]);
    setActiveTrip(updated);
  }

  /// Remove the stop with [stopId] from the active trip.
  void removeTripStop(String stopId) {
    final current = activeTrip;
    if (current == null) return;
    final updated = current.copyWith(
      stops: current.stops.where((s) => s.id != stopId).toList(),
    );
    setActiveTrip(updated);
  }

  /// Reorder stops by moving the stop at [oldIndex] to [newIndex].
  void reorderTripStop(int oldIndex, int newIndex) {
    final current = activeTrip;
    if (current == null) return;
    final stops = List<TripStop>.of(current.stops);
    if (oldIndex < 0 ||
        oldIndex >= stops.length ||
        newIndex < 0 ||
        newIndex >= stops.length) return;
    final stop = stops.removeAt(oldIndex);
    stops.insert(newIndex, stop);
    setActiveTrip(current.copyWith(stops: stops));
  }

  /// Optimize the intermediate stop order of the active trip using
  /// nearest-neighbour + 2-opt heuristic.
  ///
  /// The first and last stops are kept fixed.
  void optimizeTripStopOrder() {
    final current = activeTrip;
    if (current == null || current.stops.length < 3) return;
    final optimized = StopOptimizer.optimize(current.stops);
    setActiveTrip(current.copyWith(stops: optimized));
  }

  /// Calculate a combined route for all stops in the active trip.
  Future<void> buildTripRoute() async {
    final trip = activeTrip;
    if (trip == null || trip.stops.length < 2) {
      tripRouteError = 'Trip requires at least 2 stops.';
      notifyListeners();
      return;
    }

    tripRouteError = null;
    isLoadingTripRoute = true;
    notifyListeners();

    try {
      routeResult = await _tripRoutingService.buildTripRoute(
        stops: trip.stops,
        truckProfile: truckProfile,
      );
      routeError = null;
      if (routeResult != null) _startRouteMonitoring();
    } catch (e) {
      tripRouteError = e.toString();
      routeResult = null;
    } finally {
      isLoadingTripRoute = false;
      notifyListeners();
    }
  }

  /// Clear the active trip and remove it from persistent storage.
  void clearTrip() {
    _stopRouteMonitoring();
    activeTrip = null;
    routeResult = null;
    routeError = null;
    tripRouteError = null;
    notifyListeners();
    _tripService.clearActiveTrip().catchError(
      (Object e) => debugPrint('Error clearing active trip: $e'),
    );
  }

  // ---------------------------------------------------------------------------
  // Navigation session management
  // ---------------------------------------------------------------------------

  /// Start a turn-by-turn navigation session for the current [routeResult].
  ///
  /// Does nothing if no route has been calculated yet.
  /// Voice prompts will be spoken if [voiceGuidanceEnabled] is true.
  Future<void> startNavigation() async {
    final route = routeResult;
    if (route == null) return;

    _navService
      ..onManeuverUpdate = (_, __) { notifyListeners(); }
      ..onArrival = () {
        isNavigating = false;
        notifyListeners();
      }
      ..onOffRoute = (dist) {
        debugPrint('Off-route by ${dist.toStringAsFixed(0)} m — rerouting…');
        addAlert(AlertEvent(
          id: 'off_route_${DateTime.now().millisecondsSinceEpoch}',
          type: AlertType.offRoute,
          title: 'Off Route',
          message: 'Recalculating route…',
          severity: AlertSeverity.warning,
          timestamp: DateTime.now(),
          speakable: true,
        ));
        rerouteIfNeeded();
      }
      ..onVoicePrompt = (text) {
        if (voiceGuidanceEnabled) {
          _tts
              .setLanguage(voiceLanguage)
              .then(
                (_) => _tts.speak(text),
                onError: (Object e) => debugPrint('TTS setLanguage error: $e'),
              )
              .then(
                (_) {},
                onError: (Object e) => debugPrint('TTS error: $e'),
              );
        }
        debugPrint('Voice prompt: $text');
      };

    await _navService.start(route);
    isNavigating = true;
    addAlert(AlertEvent(
      id: 'nav_started_${DateTime.now().millisecondsSinceEpoch}',
      type: AlertType.navigationStarted,
      title: 'Navigation Started',
      message: 'Turn-by-turn guidance is active.',
      severity: AlertSeverity.info,
      timestamp: DateTime.now(),
      speakable: false,
    ));
    notifyListeners();
  }

  /// Stop the active navigation session.
  Future<void> stopNavigation() async {
    await _navService.stop();
    isNavigating = false;
    addAlert(AlertEvent(
      id: 'nav_stopped_${DateTime.now().millisecondsSinceEpoch}',
      type: AlertType.navigationStopped,
      title: 'Navigation Stopped',
      message: 'Navigation has ended.',
      severity: AlertSeverity.info,
      timestamp: DateTime.now(),
      speakable: false,
    ));
    notifyListeners();
  }

  /// Toggle voice guidance on or off.
  void toggleVoiceGuidance() {
    voiceGuidanceEnabled = !voiceGuidanceEnabled;
    if (!voiceGuidanceEnabled) {
      final tts = _ttsInstance;
      if (tts != null) {
        tts.stop().then(
          (_) {},
          onError: (Object e) => debugPrint('TTS stop error: $e'),
        );
      }
    }
    _voiceSettingsService.saveEnabled(voiceGuidanceEnabled).catchError(
      (Object e) => debugPrint('Error saving voice enabled: $e'),
    );
    notifyListeners();
  }

  /// Set the BCP-47 voice guidance language.
  ///
  /// [language] must be one of [supportedVoiceLanguages]; other values are
  /// silently ignored. The new language takes effect on the next voice prompt.
  void setVoiceLanguage(String language) {
    if (!supportedVoiceLanguages.contains(language)) return;
    voiceLanguage = language;
    _voiceSettingsService.saveLanguage(language).catchError(
      (Object e) => debugPrint('Error saving voice language: $e'),
    );
    notifyListeners();
  }

  /// Recalculate the route from the current position and restart navigation.
  ///
  /// Called automatically when an off-route condition is detected.
  Future<void> rerouteIfNeeded() async {
    if (destLat == null || destLng == null) return;
    try {
      await buildTruckRoute();
      if (routeResult != null && isNavigating) {
        addAlert(AlertEvent(
          id: 'reroute_${DateTime.now().millisecondsSinceEpoch}',
          type: AlertType.reroute,
          title: 'Route Updated',
          message: 'A new route has been calculated.',
          severity: AlertSeverity.warning,
          timestamp: DateTime.now(),
          speakable: true,
        ));
        await startNavigation();
      }
    } catch (e) {
      debugPrint('Reroute failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Alert management
  // ---------------------------------------------------------------------------

  /// Add [alert] to the queue.
  ///
  /// If [voiceGuidanceEnabled] is true and the alert is [AlertEvent.speakable]
  /// and has [AlertSeverity.warning] or [AlertSeverity.critical] severity,
  /// the alert message is spoken immediately.
  void addAlert(AlertEvent alert) {
    _alertQueue.add(alert);
    if (voiceGuidanceEnabled &&
        alert.speakable &&
        alert.severity != AlertSeverity.info) {
      _tts
          .setLanguage(voiceLanguage)
          .then(
            (_) => _tts.speak(alert.message),
            onError: (Object e) => debugPrint('TTS setLanguage error: $e'),
          )
          .catchError(
            (Object e) => debugPrint('TTS alert error: $e'),
          );
    }
    notifyListeners();
  }

  /// Dismiss (remove) the current front-of-queue alert.
  void dismissCurrentAlert() {
    if (_alertQueue.isNotEmpty) {
      _alertQueue.removeAt(0);
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // Route monitoring (geofence + stop alerts)
  // ---------------------------------------------------------------------------

  /// Start the route monitor GPS subscription.
  ///
  /// Wires [RouteMonitor] callbacks to emit [AlertEvent]s and speak via TTS
  /// when voice guidance is enabled.  Called automatically after a route or
  /// trip route has been built successfully.
  void _startRouteMonitoring() {
    _routeMonitorSub?.cancel();
    _routeMonitor.reset();

    _routeMonitor.onApproachingStop = (TripStop stop) {
      final label = stop.label ?? 'next stop';
      addAlert(AlertEvent(
        id: 'approaching_stop_${stop.id}',
        type: AlertType.approachingStop,
        title: 'Approaching Stop',
        message: 'Approaching $label in less than 5 km.',
        severity: AlertSeverity.info,
        timestamp: DateTime.now(),
        speakable: true,
      ));
    };

    _routeMonitor.onOffRoute = (double dist) {
      addAlert(AlertEvent(
        id: 'off_route_monitor_${DateTime.now().millisecondsSinceEpoch}',
        type: AlertType.offRoute,
        title: 'Off Route',
        message: 'You are off the planned route.',
        severity: AlertSeverity.warning,
        timestamp: DateTime.now(),
        speakable: true,
      ));
    };

    _routeMonitor.onBackOnRoute = () {
      addAlert(AlertEvent(
        id: 'back_on_route_${DateTime.now().millisecondsSinceEpoch}',
        type: AlertType.backOnRoute,
        title: 'Back on Route',
        message: 'You are back on the planned route.',
        severity: AlertSeverity.info,
        timestamp: DateTime.now(),
        speakable: true,
      ));
    };

    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    );

    _routeMonitorSub =
        Geolocator.getPositionStream(locationSettings: settings).listen(
          _onRouteMonitorPosition,
          onError: (Object e) => debugPrint('RouteMonitor: GPS error: $e'),
        );
  }

  /// Stop the route monitor GPS subscription and reset monitor state.
  void _stopRouteMonitoring() {
    _routeMonitorSub?.cancel();
    _routeMonitorSub = null;
    _routeMonitor.reset();
  }

  void _onRouteMonitorPosition(Position pos) {
    final route = routeResult;
    if (route == null || route.polylinePoints.isEmpty) return;
    final stops = activeTrip?.stops ?? const [];
    _routeMonitor.update(
      lat: pos.latitude,
      lng: pos.longitude,
      routePolyline:
          route.polylinePoints.map((p) => [p.latitude, p.longitude]).toList(),
      stops: stops,
    );
  }

  @override
  void dispose() {
    _stopRouteMonitoring();
    _navService.stop();
    _ttsInstance?.stop();
    super.dispose();
  }
}

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/truck_profile.dart';
import '../models/route_result.dart';
import '../models/weather_point.dart';
import '../models/navigation_maneuver.dart';
import '../models/poi.dart';
import '../models/alert_message.dart';
import '../services/location_service.dart';
import '../services/here_routing_service.dart';
import '../services/navigation_session_service.dart';
import '../services/overpass_poi_service.dart';
import '../services/weather_service.dart';
import '../services/truck_profile_service.dart';
import '../services/revenue_cat_service.dart';
import '../services/poi_favorites_service.dart';
import '../services/trip_service.dart';
import '../models/trip.dart';

/// Application state management using ChangeNotifier
class AppState extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final HereRoutingService _routingService = HereRoutingService();
  final NavigationSessionService _navService = NavigationSessionService();
  final OverpassPoiService _poiService = OverpassPoiService();
  final WeatherService _weatherService = WeatherService();
  final TruckProfileService _truckProfileService = TruckProfileService();
  final RevenueCatService revenueCatService = RevenueCatService();
  final PoiFavoritesService _favoritesService = PoiFavoritesService();
  final TripService _tripService = TripService();
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

  // Weather
  WeatherPoint? weatherAtCurrentLocation;

  // POI layers
  Set<PoiType> enabledPoiLayers = {};
  List<Poi> pois = [];

  /// IDs of POIs the driver has marked as favorites.
  Set<String> favoritePoisIds = {};

  // ---------------------------------------------------------------------------
  // Trip planner state
  // ---------------------------------------------------------------------------

  /// All saved trips, loaded from device storage on startup.
  List<Trip> savedTrips = [];

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
  // Alert queue
  // ---------------------------------------------------------------------------

  /// FIFO queue of alerts to show in the UI.
  ///
  /// Consumers (e.g., [NavigationScreen]) should display and then call
  /// [dismissAlert] once the user has acknowledged the top alert.
  final List<AlertMessage> alertQueue = [];

  /// Post a new [alert] to the queue and notify listeners.
  ///
  /// If [speak] is `true` and [voiceGuidanceEnabled] is `true`, the message
  /// text is also spoken via TTS.
  void postAlert(AlertMessage alert, {bool speak = false}) {
    alertQueue.add(alert);
    notifyListeners();
    if (speak && voiceGuidanceEnabled) {
      _tts
          .setLanguage(voiceLanguage)
          .then(
            (_) => _tts.speak(alert.message),
            onError: (Object e) => debugPrint('TTS alert error: $e'),
          )
          .then((_) {}, onError: (Object e) => debugPrint('TTS error: $e'));
    }
  }

  /// Remove and discard the oldest [AlertMessage] from [alertQueue].
  void dismissAlert() {
    if (alertQueue.isNotEmpty) {
      alertQueue.removeAt(0);
      notifyListeners();
    }
  }

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
    // Load favorite POI ids
    try {
      final favs = await _favoritesService.load();
      favoritePoisIds = favs.map((p) => p.id).toSet();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading POI favorites: $e');
    }
    // Load saved trips
    try {
      savedTrips = await _tripService.load();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading saved trips: $e');
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

  /// Toggle favorite status for a POI identified by [poiId].
  ///
  /// If the POI is already a favorite it is removed; otherwise it is added.
  /// The updated list is persisted via [PoiFavoritesService].
  void toggleFavorite(String poiId) {
    if (favoritePoisIds.contains(poiId)) {
      favoritePoisIds.remove(poiId);
    } else {
      favoritePoisIds.add(poiId);
    }
    notifyListeners();
    // Persist the POIs that are currently loaded and also favorited.
    final favPois = pois.where((p) => favoritePoisIds.contains(p.id)).toList();
    _favoritesService.save(favPois).catchError(
      (Object e) => debugPrint('Error saving favorites: $e'),
    );
  }

  /// Whether [poiId] is in the current favorites set.
  bool isFavorite(String poiId) => favoritePoisIds.contains(poiId);

  // ---------------------------------------------------------------------------
  // Trip planner methods
  // ---------------------------------------------------------------------------

  /// Save a new or updated [trip] to [savedTrips] and persist to device storage.
  void saveTrip(Trip trip) {
    final idx = savedTrips.indexWhere((t) => t.id == trip.id);
    if (idx >= 0) {
      savedTrips[idx] = trip;
    } else {
      savedTrips.add(trip);
    }
    notifyListeners();
    _tripService.save(savedTrips).catchError(
      (Object e) => debugPrint('Error saving trip: $e'),
    );
  }

  /// Remove a trip by [tripId] from [savedTrips] and persist the change.
  void deleteTrip(String tripId) {
    savedTrips.removeWhere((t) => t.id == tripId);
    notifyListeners();
    _tripService.save(savedTrips).catchError(
      (Object e) => debugPrint('Error deleting trip: $e'),
    );
  }

  /// Calculate truck route from current location to destination
  Future<void> buildTruckRoute() async {
    if (myLat == null || myLng == null || destLat == null || destLng == null) {
      throw Exception('Location or destination not set');
    }

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
    routeResult = null;
    destLat = null;
    destLng = null;
    notifyListeners();
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
      ..onManeuverUpdate = (_, __) => notifyListeners()
      ..onArrival = () {
        isNavigating = false;
        notifyListeners();
      }
      ..onOffRoute = (dist) {
        debugPrint('Off-route by ${dist.toStringAsFixed(0)} m — rerouting…');
        postAlert(
          const AlertMessage(
            message: 'Off route — recalculating…',
            severity: AlertSeverity.warning,
          ),
          speak: true,
        );
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
    notifyListeners();
  }

  /// Stop the active navigation session.
  Future<void> stopNavigation() async {
    await _navService.stop();
    isNavigating = false;
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
    notifyListeners();
  }

  /// Set the BCP-47 voice guidance language.
  ///
  /// [language] must be one of [supportedVoiceLanguages]; other values are
  /// silently ignored. The new language takes effect on the next voice prompt.
  void setVoiceLanguage(String language) {
    if (!supportedVoiceLanguages.contains(language)) return;
    voiceLanguage = language;
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
        await startNavigation();
      }
    } catch (e) {
      debugPrint('Reroute failed: $e');
    }
  }

  @override
  void dispose() {
    _navService.stop();
    _ttsInstance?.stop();
    super.dispose();
  }
}

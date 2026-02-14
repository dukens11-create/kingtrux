import 'package:flutter/foundation.dart';
import '../models/truck_profile.dart';
import '../models/poi.dart';
import '../models/route_result.dart';
import '../models/weather_point.dart';
import '../services/location_service.dart';
import '../services/here_routing_service.dart';
import '../services/overpass_poi_service.dart';
import '../services/weather_service.dart';

/// Application state management using ChangeNotifier
class AppState extends ChangeNotifier {
  final LocationService _locationService = LocationService();
  final HereRoutingService _routingService = HereRoutingService();
  final OverpassPoiService _poiService = OverpassPoiService();
  final WeatherService _weatherService = WeatherService();

  // Current location
  double? myLat;
  double? myLng;

  // Destination
  double? destLat;
  double? destLng;

  // Truck profile
  TruckProfile _truckProfile = TruckProfile.defaultProfile();
  TruckProfile get truckProfile => _truckProfile;

  // Route
  RouteResult? routeResult;
  bool isLoadingRoute = false;

  // Weather
  WeatherPoint? weatherPoint;

  // POIs
  Set<PoiType> enabledLayers = {PoiType.fuel, PoiType.restArea};
  List<Poi> pois = [];
  bool isLoadingPois = false;

  /// Initialize the app state
  Future<void> init() async {
    try {
      await refreshMyLocation();
    } catch (e) {
      debugPrint('Error initializing location: $e');
    }
  }

  /// Refresh current location and weather
  Future<void> refreshMyLocation() async {
    try {
      final position = await _locationService.getCurrentPosition();
      myLat = position.latitude;
      myLng = position.longitude;
      notifyListeners();

      // Fetch weather for current location
      await _fetchWeather();
    } catch (e) {
      debugPrint('Error refreshing location: $e');
      rethrow;
    }
  }

  /// Fetch weather for current location
  Future<void> _fetchWeather() async {
    if (myLat == null || myLng == null) return;

    try {
      weatherPoint = await _weatherService.fetchCurrentWeather(
        lat: myLat!,
        lng: myLng!,
      );
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching weather: $e');
    }
  }

  /// Set destination
  void setDestination(double lat, double lng) {
    destLat = lat;
    destLng = lng;
    notifyListeners();
  }

  /// Update truck profile
  void setTruck(TruckProfile profile) {
    _truckProfile = profile;
    notifyListeners();
  }

  /// Toggle POI layer visibility
  void toggleLayer(PoiType type, bool enabled) {
    if (enabled) {
      enabledLayers.add(type);
    } else {
      enabledLayers.remove(type);
    }
    notifyListeners();
  }

  /// Build truck route from current location to destination
  Future<void> buildTruckRoute() async {
    if (myLat == null || myLng == null || destLat == null || destLng == null) {
      return;
    }

    isLoadingRoute = true;
    notifyListeners();

    try {
      routeResult = await _routingService.calculateTruckRoute(
        originLat: myLat!,
        originLng: myLng!,
        destLat: destLat!,
        destLng: destLng!,
        profile: _truckProfile,
      );
    } catch (e) {
      debugPrint('Error building route: $e');
      rethrow;
    } finally {
      isLoadingRoute = false;
      notifyListeners();
    }
  }

  /// Load POIs around current location
  Future<void> loadPois({double radiusMeters = 15000}) async {
    if (myLat == null || myLng == null) return;

    isLoadingPois = true;
    notifyListeners();

    try {
      pois = await _poiService.fetchPois(
        centerLat: myLat!,
        centerLng: myLng!,
        enabledTypes: enabledLayers,
        radiusMeters: radiusMeters,
      );
    } catch (e) {
      debugPrint('Error loading POIs: $e');
      rethrow;
    } finally {
      isLoadingPois = false;
      notifyListeners();
    }
  }

  /// Clear route and destination
  void clearRoute() {
    destLat = null;
    destLng = null;
    routeResult = null;
    notifyListeners();
  }
}

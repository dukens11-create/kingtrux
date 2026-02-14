import 'package:flutter/foundation.dart';
import '../models/truck_profile.dart';
import '../models/route_result.dart';
import '../models/weather_point.dart';
import '../models/poi.dart';
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

  // Truck configuration
  TruckProfile truckProfile = TruckProfile.defaultProfile();

  // Route
  RouteResult? routeResult;

  // Weather
  WeatherPoint? weatherAtCurrentLocation;

  // POI layers
  Set<PoiType> enabledPoiLayers = {};
  List<Poi> pois = [];

  // Loading states
  bool isLoadingRoute = false;
  bool isLoadingPois = false;

  /// Initialize app state and get current location
  Future<void> init() async {
    try {
      await refreshMyLocation();
    } catch (e) {
      debugPrint('Error initializing location: $e');
    }
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

  /// Update truck profile
  void setTruck(TruckProfile profile) {
    truckProfile = profile;
    notifyListeners();
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

  /// Clear route and destination
  void clearRoute() {
    routeResult = null;
    destLat = null;
    destLng = null;
    notifyListeners();
  }
}

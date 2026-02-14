# KINGTRUX Developer Quick Reference

## API Configuration

### Required Environment Variables
```bash
# Run with API keys
flutter run \
  --dart-define=HERE_API_KEY=your_key \
  --dart-define=OPENWEATHER_API_KEY=your_key
```

## Key Components

### State Management
```dart
// Access app state in widgets
final state = context.read<AppState>();
final state = context.watch<AppState>(); // Rebuilds on changes

// Key methods
await state.init();                     // Initialize app
await state.refreshMyLocation();        // Update GPS + weather
state.setDestination(lat, lng);         // Set destination
await state.buildTruckRoute();          // Calculate route
await state.loadPois();                 // Load POIs (15km radius)
state.setTruck(newProfile);             // Update truck config
state.toggleLayer(PoiType.fuel, true);  // Show/hide POI type
state.clearRoute();                     // Clear route
```

### Models

#### TruckProfile
```dart
final profile = TruckProfile.defaultProfile(); // 4.1m H × 2.6m W × 21m L, 36t, 5 axles

final custom = TruckProfile(
  heightMeters: 4.0,
  widthMeters: 2.5,
  lengthMeters: 18.0,
  weightTons: 32.0,
  axles: 4,
  hazmat: false,
);

final updated = profile.copyWith(heightMeters: 4.5);
```

#### Poi
```dart
enum PoiType { fuel, restArea, gym, scale, truckStop, parking }

final poi = Poi(
  id: '123',
  type: PoiType.fuel,
  name: 'Shell Station',
  lat: 37.7749,
  lng: -122.4194,
  tags: {'amenity': 'fuel', 'brand': 'Shell'},
);
```

#### RouteResult
```dart
final route = RouteResult(
  polylinePoints: [LatLng(37.7749, -122.4194), ...],
  lengthMeters: 45000.0,  // 45 km
  durationSeconds: 2700,   // 45 minutes
);
```

#### WeatherPoint
```dart
final weather = WeatherPoint(
  lat: 37.7749,
  lng: -122.4194,
  summary: 'clear sky',
  temperatureCelsius: 22.5,
  windSpeedMs: 3.2,
);
```

### Services

#### LocationService
```dart
final service = LocationService();
final position = await service.getCurrentPosition();
// Returns Position with latitude, longitude, accuracy, etc.
```

#### HereRoutingService
```dart
final service = HereRoutingService();
final route = await service.calculateTruckRoute(
  originLat: 37.7749,
  originLng: -122.4194,
  destLat: 37.3382,
  destLng: -121.8863,
  profile: TruckProfile.defaultProfile(),
);
```

#### OverpassPoiService
```dart
final service = OverpassPoiService();
final pois = await service.fetchPois(
  centerLat: 37.7749,
  centerLng: -122.4194,
  enabledTypes: {PoiType.fuel, PoiType.restArea},
  radiusMeters: 15000,  // 15 km
);
```

#### WeatherService
```dart
final service = WeatherService();
final weather = await service.fetchCurrentWeather(
  lat: 37.7749,
  lng: -122.4194,
);
```

## UI Components

### MapScreen
Main screen with Google Maps integration.
- **Long press** on map to set destination and auto-route
- **My Location button** - recenter and refresh location
- **Tune button** - open truck profile configuration
- **Layers button** - toggle POI layers

### TruckProfileSheet
Bottom sheet for truck configuration.
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  builder: (context) => const TruckProfileSheet(),
);
```

### LayerSheet
Bottom sheet for POI layer management.
```dart
showModalBottomSheet(
  context: context,
  builder: (context) => const LayerSheet(),
);
```

### RouteSummaryCard
Card widget showing route info and POI loading button.
- Displays route distance (miles) and duration (h/m)
- "Load POIs Near Me" button
- Loading indicators
- Clear route button

## Color Coding

### POI Markers
- 🟠 Orange - Fuel stations
- 🔵 Azure - Rest areas
- 🟣 Violet - Gyms (future)
- 🟡 Yellow - Scales (future)
- 🔷 Cyan - Truck stops (future)
- 🔵 Blue - Parking (future)

### Route Markers
- 🟢 Green - Current location ("You")
- 🔴 Red - Destination
- 🔵 Blue - Route polyline

## Error Handling

All service calls may throw exceptions. Always use try-catch:

```dart
try {
  await state.buildTruckRoute();
} catch (e) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Error: $e'),
      backgroundColor: Colors.red,
    ),
  );
}
```

## Testing Checklist

- [ ] Location permission granted
- [ ] GPS location obtained
- [ ] Weather displayed correctly
- [ ] Long-press sets destination
- [ ] Route calculated and displayed
- [ ] Truck profile adjustable
- [ ] POIs load correctly
- [ ] POI markers show info on tap
- [ ] Layer toggles work
- [ ] Map centering works
- [ ] All API keys configured

## Common Issues

### "HERE API key not configured"
- Set `--dart-define=HERE_API_KEY=xxx` when running

### "OpenWeather API key not configured"
- Set `--dart-define=OPENWEATHER_API_KEY=xxx` when running

### "Location services are disabled"
- Enable location services on device

### "Location permissions are denied"
- Grant location permission in app settings

### Google Maps not showing
- Add Google Maps API key to AndroidManifest.xml (Android)
- Add Google Maps API key to AppDelegate.swift (iOS)

## Performance Tips

- POI loading is async - use loading indicators
- Route calculation can take 1-3 seconds
- Weather fetch is quick (<1 second)
- Location accuracy improves over time
- Use 15km radius for POI queries (default)

## Architecture Pattern

```
UI Layer (Widgets)
    ↕ Provider
State Layer (AppState)
    ↕
Service Layer (APIs)
    ↕
External APIs (HERE, OpenWeather, Overpass)
```

The app uses the Provider pattern with ChangeNotifier for state management. All state changes trigger UI rebuilds automatically via `notifyListeners()`.

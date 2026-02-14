# KINGTRUX 🚛

A professional Flutter-based truck GPS application with advanced routing, POI discovery, and weather integration.

## Features

### 🗺️ Google Maps UI
- Interactive map with current location tracking
- Long-press to set destinations
- Real-time route visualization with polylines
- Color-coded POI markers

### 🛣️ HERE Routing v8 (Truck Mode)
- Truck-specific routing using HERE API
- Support for truck restrictions:
  - Height, width, length dimensions
  - Weight (gross weight)
  - Number of axles
  - Hazardous materials flag
- Flexible polyline decoding with 2D coordinate support

### 📍 OSM Overpass POIs
- Fuel stations (`amenity=fuel`)
- Rest areas (`highway=rest_area`)
- Configurable search radius (default: 15km)
- Support for nodes, ways, and relations
- Future additions: scales, gyms, truck parking

### 🌤️ OpenWeather Current Conditions
- Real-time weather at current location
- Temperature (°C)
- Weather summary
- Wind speed (m/s)

### ⚙️ Truck Profile Configuration
- Adjustable dimensions via sliders:
  - Height: 2.5 - 4.8m
  - Width: 2.0 - 3.0m
  - Length: 6.0 - 30.0m
  - Weight: 5.0 - 45.0 tons
- Axle count selection (2-8)
- Hazardous materials toggle
- Default profile: 4.10m H × 2.60m W × 21.0m L, 36 tons, 5 axles

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Configure Google Maps API Keys

#### Android
Add your Google Maps API key to `android/app/src/main/AndroidManifest.xml`:

```xml
<application>
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
</application>
```

#### iOS
Add your Google Maps API key to `ios/Runner/AppDelegate.swift`:

```swift
import GoogleMaps

GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
```

### 3. Run the Application

Use `--dart-define` to provide API keys for HERE and OpenWeather:

```bash
flutter run \
  --dart-define=HERE_API_KEY=your_here_api_key \
  --dart-define=OPENWEATHER_API_KEY=your_openweather_api_key
```

## API Key Configuration

This application requires API keys from the following services:

1. **Google Maps API** (Android/iOS platform configuration)
   - Get key from: https://console.cloud.google.com/
   - Required for: Map display and markers

2. **HERE API** (Runtime via dart-define)
   - Get key from: https://developer.here.com/
   - Required for: Truck routing calculations

3. **OpenWeather API** (Runtime via dart-define)
   - Get key from: https://openweathermap.org/api
   - Required for: Current weather conditions

## Project Structure

```
kingtrux/
├── pubspec.yaml              # Dependencies and configuration
├── README.md                 # This file
├── lib/
│   ├── main.dart            # Application entry point
│   ├── app.dart             # Root widget with Material3 theme
│   ├── config.dart          # API keys and configuration
│   ├── models/              # Data models
│   │   ├── truck_profile.dart
│   │   ├── poi.dart
│   │   ├── route_result.dart
│   │   └── weather_point.dart
│   ├── services/            # API integration services
│   │   ├── location_service.dart
│   │   ├── here_routing_service.dart
│   │   ├── overpass_poi_service.dart
│   │   └── weather_service.dart
│   ├── state/               # State management
│   │   └── app_state.dart
│   └── ui/                  # User interface
│       ├── map_screen.dart
│       └── widgets/
│           ├── layer_sheet.dart
│           ├── truck_profile_sheet.dart
│           └── route_summary_card.dart
```

## Usage

### Setting a Route
1. Long-press anywhere on the map to set a destination
2. The app automatically calculates a truck-specific route
3. Route distance and duration appear in the bottom card
4. Tap the clear button (×) to remove the route

### Loading POIs
1. Tap "Load POIs Near Me" in the bottom card
2. POIs appear as colored markers:
   - Orange: Fuel stations
   - Azure/Blue: Rest areas
3. Tap markers to see names and details

### Configuring Truck Profile
1. Tap the tune icon (⚙️) in the app bar
2. Adjust truck dimensions using sliders
3. Select number of axles from dropdown
4. Toggle hazardous materials if applicable
5. Tap "Save Profile"
6. New routes will use updated truck parameters

### Managing POI Layers
1. Tap the layers icon in the app bar
2. Toggle POI types on/off
3. Next POI load respects enabled layers

### Refreshing Location
1. Tap the location icon in the app bar
2. Updates current position and weather
3. Map recenters on your location

## Dependencies

- `google_maps_flutter: ^2.12.0` - Map display
- `http: ^1.2.2` - HTTP requests
- `uuid: ^4.4.0` - Unique identifiers
- `collection: ^1.18.0` - Collection utilities
- `provider: ^6.1.2` - State management
- `geolocator: ^13.0.2` - Location services
- `flutter_polyline_points: ^2.1.0` - Polyline utilities

## Technical Notes

- Built with Flutter SDK `>=3.4.0 <4.0.0`
- Uses Material Design 3 with amber color scheme
- Provider pattern for state management
- Null safety throughout
- Async/await for all network operations
- Proper error handling with descriptive exceptions

## License

Copyright © 2024 KINGTRUX. All rights reserved.
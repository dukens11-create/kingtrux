# KINGTRUX - Truck GPS Application

A full-featured Flutter truck GPS application with routing, POI layers, weather integration, and truck profile configuration.

## Features

- **Google Maps UI**: Interactive map interface with marker support
- **HERE Routing v8**: Truck-specific routing with support for truck dimensions and restrictions
  - Height, width, length, weight, axle count, and hazmat restrictions
  - Real-time route calculation with distance and duration
- **OSM Overpass POIs**: Fetch Points of Interest from OpenStreetMap
  - Fuel stations (`amenity=fuel`)
  - Rest areas (`highway=rest_area`)
  - Configurable 15km radius search
- **OpenWeather Integration**: Current weather conditions at your location
  - Temperature, weather summary, wind speed
- **Truck Profile Configuration**: Customize your truck's specifications
  - Adjustable dimensions via sliders
  - Axle count selection
  - Hazmat toggle
- **POI Layer Management**: Show/hide different POI types on the map

## Setup Instructions

### 1. Install Dependencies

```bash
flutter pub get
```

### 2. Configure Google Maps API Keys

#### Android
Add your Google Maps API key to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest ...>
  <application ...>
    <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_GOOGLE_MAPS_API_KEY"/>
  </application>
</manifest>
```

#### iOS
Add your Google Maps API key to `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter
import GoogleMaps

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GMSServices.provideAPIKey("YOUR_GOOGLE_MAPS_API_KEY")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
```

### 3. Run with API Keys

Run the application with HERE and OpenWeather API keys using `--dart-define`:

```bash
flutter run \
  --dart-define=HERE_API_KEY=your_here_api_key \
  --dart-define=OPENWEATHER_API_KEY=your_openweather_api_key
```

## API Keys Required

- **Google Maps API Key**: For map display (configured in platform files)
- **HERE API Key**: For truck routing (passed via `--dart-define`)
- **OpenWeather API Key**: For weather data (passed via `--dart-define`)

## Usage

1. **App Launch**: 
   - The app requests location permission
   - Centers map on your current location
   - Displays current weather conditions

2. **Setting a Destination**:
   - Long-press on the map to set a destination
   - The app automatically calculates a truck-specific route
   - Blue polyline shows the route with distance/duration summary

3. **Loading POIs**:
   - Tap "Load POIs Near Me" button
   - Fetches fuel stations and rest areas within 15km
   - Orange markers = Fuel stations
   - Blue markers = Rest areas
   - Tap markers to see info

4. **Configuring Truck Profile**:
   - Tap the tune icon in the app bar
   - Adjust truck dimensions using sliders
   - Select axle count from dropdown
   - Toggle hazmat if carrying hazardous materials
   - Save to apply changes (re-routing will use new parameters)

5. **Managing Layers**:
   - Tap the layers icon in the app bar
   - Toggle POI types on/off
   - Next POI fetch will respect enabled layers

## File Structure

```
kingtrux/
├── pubspec.yaml
├── README.md
├── lib/
│   ├── main.dart              # App entry point
│   ├── app.dart               # Main app with Material theme and Provider
│   ├── config.dart            # API configuration
│   ├── models/
│   │   ├── truck_profile.dart # Truck specifications model
│   │   ├── poi.dart           # Point of Interest model
│   │   ├── route_result.dart  # Route result model
│   │   └── weather_point.dart # Weather data model
│   ├── services/
│   │   ├── location_service.dart        # Geolocator wrapper
│   │   ├── here_routing_service.dart    # HERE API v8 routing
│   │   ├── overpass_poi_service.dart    # OSM Overpass POI fetching
│   │   └── weather_service.dart         # OpenWeather API
│   ├── state/
│   │   └── app_state.dart     # ChangeNotifier state management
│   └── ui/
│       ├── map_screen.dart    # Main map screen
│       └── widgets/
│           ├── layer_sheet.dart          # POI layer toggle sheet
│           ├── truck_profile_sheet.dart  # Truck config sheet
│           └── route_summary_card.dart   # Route info card
```

## Technical Details

- **Flutter SDK**: >=3.4.0 <4.0.0
- **State Management**: Provider with ChangeNotifier
- **Error Handling**: All API calls include proper error handling with descriptive messages
- **Performance**: Async/await throughout, efficient marker rendering
- **Platform Support**: Android and iOS

## License

MIT
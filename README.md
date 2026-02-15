# KINGTRUX - Professional Truck GPS Application

A Flutter-based mobile application for truck drivers with advanced routing, POI discovery, and weather integration.

## Features
- **Real-time GPS tracking** using Google Maps Flutter SDK
- **Truck-specific route planning** with HERE Routing API v8
  - Configurable truck profile (height, weight, width, length, axles, hazmat)
  - Route optimization considering truck restrictions
- **Points of Interest (POI) discovery** via OpenStreetMap Overpass API
  - Fuel stations
  - Rest areas
- **Real-time weather updates** at current location using OpenWeather API
- **Interactive map interface** with route visualization
- **Location-based services** with comprehensive permission handling

## Technical Stack
- **Framework**: Flutter 3.4+ / Dart
- **State Management**: Provider
- **Mapping**: Google Maps Flutter SDK
- **APIs**:
  - Google Maps API (for mapping)
  - HERE Routing API v8 (for truck routing)
  - OpenStreetMap Overpass API (for POI queries)
  - OpenWeather API (for weather data)

## Prerequisites

### Flutter Installation
1. Install Flutter SDK (3.4.0 or higher): https://docs.flutter.dev/get-started/install
2. Verify installation: `flutter doctor`
3. Install platform-specific tools:
   - **Android**: Android Studio, Android SDK (API 21+)
   - **iOS**: Xcode 15+, CocoaPods

### API Keys Required
You'll need to obtain API keys from:
1. **Google Maps API**: https://console.cloud.google.com/
   - Enable "Maps SDK for Android" and "Maps SDK for iOS"
2. **HERE API**: https://developer.here.com/
   - Sign up and create a project to get API key
3. **OpenWeather API**: https://openweathermap.org/api
   - Free tier available

## Setup Instructions

### 1. Clone the Repository
```bash
git clone https://github.com/dukens11-create/kingtrux.git
cd kingtrux
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Configure API Keys

#### For Development (Using --dart-define)
Copy the example environment file:
```bash
cp .env.example .env
```

Edit `.env` with your actual API keys, then run:
```bash
flutter run \
  --dart-define=HERE_API_KEY=your_here_api_key \
  --dart-define=OPENWEATHER_API_KEY=your_openweather_api_key
```

#### Google Maps Platform Configuration

**Android** (`android/app/src/main/AndroidManifest.xml`):
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_ANDROID_API_KEY"/>
```

**iOS** (`ios/Runner/Info.plist`):
```xml
<key>GMSApiKey</key>
<string>YOUR_GOOGLE_MAPS_IOS_API_KEY</string>
```

## Running the Application

### Development Mode
```bash
# Android
flutter run --dart-define=HERE_API_KEY=xxx --dart-define=OPENWEATHER_API_KEY=xxx

# iOS
flutter run -d ios --dart-define=HERE_API_KEY=xxx --dart-define=OPENWEATHER_API_KEY=xxx
```

### Build Release
```bash
# Android APK
flutter build apk --release \
  --dart-define=HERE_API_KEY=xxx \
  --dart-define=OPENWEATHER_API_KEY=xxx

# iOS
flutter build ios --release \
  --dart-define=HERE_API_KEY=xxx \
  --dart-define=OPENWEATHER_API_KEY=xxx
```

## Usage Guide

1. **Start the app** - Your current location will be automatically detected
2. **View weather** - Current weather conditions display at the top
3. **Set destination** - Long-press anywhere on the map to set destination
4. **Configure truck** - Tap the tune icon (⚙️) to set truck profile
5. **Calculate route** - Route is automatically calculated after setting destination
6. **Load POIs** - Tap "Load POIs Near Me" to discover nearby fuel stations and rest areas
7. **Toggle layers** - Tap the layers icon to enable/disable POI categories
8. **Clear route** - Tap the X button on the route card to clear destination

## Project Structure
```
kingtrux/
├── android/              # Android platform configuration
├── ios/                  # iOS platform configuration
├── lib/
│   ├── main.dart         # App entry point
│   ├── app.dart          # Root widget with Provider setup
│   ├── config.dart       # API configuration
│   ├── models/           # Data models
│   │   ├── poi.dart
│   │   ├── route_result.dart
│   │   ├── truck_profile.dart
│   │   └── weather_point.dart
│   ├── services/         # API service integrations
│   │   ├── location_service.dart
│   │   ├── here_routing_service.dart
│   │   ├── overpass_poi_service.dart
│   │   └── weather_service.dart
│   ├── state/            # State management
│   │   └── app_state.dart
│   └── ui/               # UI components
│       ├── map_screen.dart
│       └── widgets/
│           ├── layer_sheet.dart
│           ├── route_summary_card.dart
│           └── truck_profile_sheet.dart
├── test/                 # Unit tests
├── pubspec.yaml          # Flutter dependencies
├── .env.example          # Example environment file
└── README.md             # This file
```

## Dependencies
Key packages used (see `pubspec.yaml` for complete list):
- `google_maps_flutter` - Google Maps integration
- `geolocator` - Location services
- `http` - API communication
- `provider` - State management
- `flutter_polyline_points` - Route polyline rendering
- `uuid` - Unique ID generation

## Troubleshooting

### Location Permission Issues
- **Android**: Ensure location permissions are granted in app settings
- **iOS**: Check that location usage descriptions are in Info.plist

### Map Not Displaying
- Verify Google Maps API key is correctly configured in platform files
- Ensure Maps SDK is enabled in Google Cloud Console
- Check that billing is enabled for Google Cloud project

### Route Calculation Fails
- Verify HERE_API_KEY is passed via --dart-define
- Check network connectivity
- Ensure origin and destination are valid coordinates

### Build Errors
- Run `flutter clean` and `flutter pub get`
- Verify Flutter version: `flutter --version`
- Check platform-specific requirements with `flutter doctor`

## Contributing
Contributions are welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Make your changes with clear commit messages
4. Submit a pull request

## License
This project is licensed under the MIT License.

## Support
For issues and questions:
- Open an issue on GitHub
- Check existing issues for solutions

---
**Note**: This is a mobile application built with Flutter. It requires a physical device or emulator to run.
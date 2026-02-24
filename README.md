# KINGTRUX - Professional Truck GPS Application

A Flutter-based mobile application for truck drivers with advanced routing, POI discovery, and weather integration.

## Features
- **Real-time GPS tracking** using Google Maps Flutter SDK
- **Truck Profile** — configure your vehicle dimensions and restrictions:
  - Height, width, length, weight, axle count, and hazmat flag
  - Imperial (ft / short tons) and metric (m / t) display units
  - **Persists locally on device** (no account or API keys required)
  - Will be used for HERE truck routing once HERE keys are configured
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
1. Install Flutter SDK (3.27.0 or higher): https://docs.flutter.dev/get-started/install
2. Verify installation: `flutter doctor`
3. Install platform-specific tools:
   - **Android**: Android Studio, Android SDK (API 21+), **JDK 17** (required)
   - **iOS**: Xcode 15+, CocoaPods

### Android Toolchain Requirements

Android builds require **JDK 17** (Java 17). Using an older JDK (e.g., JDK 8 or 11)
causes Kotlin compilation errors in the Flutter Gradle plugin (e.g. `Unresolved reference:
filePermissions`).

| Component | Required version |
|-----------|-----------------|
| JDK | **17** (Temurin / OpenJDK) |
| Gradle | 8.7 |
| Android Gradle Plugin (AGP) | 8.3.0 |
| Kotlin Gradle Plugin | 1.9.25 |
| Android SDK compile / target | 34 |

Install JDK 17 via [Eclipse Temurin](https://adoptium.net/) or your OS package manager:
```bash
# macOS (Homebrew)
brew install temurin@17

# Ubuntu / Debian
sudo apt-get install -y temurin-17-jdk
```

Make sure `JAVA_HOME` points to JDK 17 before running `flutter build apk`.

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

## Truck Profile

The **Truck Profile** stores your vehicle's physical dimensions and load characteristics locally on your device. No account or API key is required.

| Field | Description | Range |
|-------|-------------|-------|
| Height | Overall vehicle height | 2.5–4.8 m (8.2–15.7 ft) |
| Width | Overall vehicle width | 2.0–3.0 m (6.6–9.8 ft) |
| Length | Overall vehicle length | 6.0–30.0 m (19.7–98.4 ft) |
| Weight | Gross vehicle weight | 5–45 metric tons (5.5–49.6 short tons) |
| Axles | Total axle count | 2–8 |
| Hazmat | Carrying hazardous materials | on/off |

### How to use

1. Tap the **truck icon** (🚛) in the FAB cluster on the main map screen.
2. Adjust sliders and toggles. Switch between **Metric** and **Imperial** display units at any time — values are stored internally in metric.
3. Tap **Save Profile** — the profile is persisted to device storage and takes effect immediately.

### Future HERE routing integration

Once HERE API keys are configured, the saved profile will automatically be passed to the HERE Routing API v8 to calculate truck-compliant routes that respect height/weight clearances, hazmat restrictions, and road-class limits.

## UI Preview Gallery

The app ships a built-in **UI Preview Gallery** that renders key components in
both light and dark themes — no API keys required.

### Opening the preview

The preview screen is only available in **debug / profile** builds.

| Method | Steps |
|--------|-------|
| Long-press gesture | Long-press the **"KINGTRUX"** title in the app bar. |

> The long-press gesture is compiled away in release builds (`kDebugMode`
> guard), so normal users never see it.

### Toggling light / dark theme

Once inside the preview, tap the **sun / moon icon** (light_mode / dark_mode) in the top-right
corner of the app bar to switch between light and dark themes.

### What's shown

| Section | Description |
|---------|-------------|
| Map Screen Shell | Full layout with weather pill overlay; map widget replaced by a placeholder so no Google Maps API key is needed. |
| Route Card – Empty State | The card as seen before a route is calculated. |
| Route Card – With Route | Pre-populated distance / duration values. |
| Route Card – Loading State | Spinner shown while a route is being fetched. |
| Layer Sheet (POI Toggles) | Switch list tiles for Fuel and Rest Area layers. |
| Buttons & FAB Cluster | `ElevatedButton`, `OutlinedButton`, `FilledButton`, `FloatingActionButton`, and `FilterChip` samples. |
| Loading / Empty / Error States | Stand-alone status placeholders. |
| Open Sheets | Buttons that open the live Layer Sheet and Truck Profile Sheet modals. |

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
│   │   ├── truck_profile_service.dart
│   │   └── weather_service.dart
│   ├── state/            # State management
│   │   └── app_state.dart
│   └── ui/               # UI components
│       ├── map_screen.dart
│       ├── preview_gallery_page.dart  # Debug-only UI preview
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
- Verify Flutter version: `flutter --version` (requires Flutter 3.27+ / Dart 3.6+)
- Check platform-specific requirements with `flutter doctor`
- **Android JDK**: Ensure JDK 17 is installed and `JAVA_HOME` is set to JDK 17. Using JDK 8/11 causes Kotlin compilation errors (`Unresolved reference: filePermissions`) in the Flutter Gradle plugin.
- **iOS**: The shared Xcode scheme is committed at `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme`. If you see `no schemes available for Runner.xcodeproj`, ensure that file is present and not listed in `.gitignore`.

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
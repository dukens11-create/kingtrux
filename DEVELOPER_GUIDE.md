# KINGTRUX Developer Quick Reference

## Confirmed Working State (2026-03-04 ~9 PM)

All Dart source files, UI widgets, and app features have been restored to the last fully
working version from **2026-03-04 ~9 PM** (commit `ee26578`, after PR #150
"improve-truck-profile-ux" and PR #151 "add-user-document-creation"). The Kotlin Gradle
Plugin is pinned to **2.1.0** (matching the working state). The machine-specific
`org.gradle.java.home` Windows path has been kept out of `gradle.properties` as it
breaks CI.

### Expected UI Features

After a clean rebuild you should see the following in the app:

| Feature | Location | Description |
|---------|----------|-------------|
| **Truck map** | Full screen | Google Maps tile view centred on the device location |
| **Top app bar** | Top | KINGTRUX logo/title with settings, preview, and sign-out actions |
| **Search bar** | Top bar action | Tapping the search icon opens the "Where to?" destination sheet |
| **Toll / POI selection** | Bottom toolbar | Toll-avoidance toggle and POI layer/browse buttons in BottomAppBar |
| **Truck profile prompt** | Bottom card | "Using default truck profile" banner — tap to open profile sheet |
| **Bottom navigation toolbar** | Bottom | BottomAppBar with My Location, Set Destination, Truck Profile, Layers, Route Options buttons |
| **"Start Navigation" button** | Bottom card (after route set) | Begins turn-by-turn navigation |

### Feature Validation Checklist

Use this checklist after merging and rebuilding to confirm the app is working correctly:

- [ ] Map tiles visible once location is acquired
- [ ] Top app bar shows KINGTRUX title with settings and sign-out icons
- [ ] Tapping the search icon opens the "Where to?" destination sheet
- [ ] Long-pressing the map sets a destination and triggers route calculation
- [ ] Route polyline appears on the map after calculation
- [ ] "Start Navigation" button appears in the route card after a route is set
- [ ] "Using default truck profile" banner visible until profile is configured
- [ ] Tapping the truck profile button in the BottomAppBar opens the profile sheet
- [ ] POI markers appear after tapping the layers/POI button
- [ ] Toll avoidance toggle re-routes correctly when changed
- [ ] Bottom toolbar buttons work: My Location, Set Destination, Truck Profile, Layers, Route Options

---

## Post-Merge/Post-Pull Cache Cleanup

After pulling or merging changes that modify `pubspec.yaml`, `android/build.gradle`,
`android/settings.gradle`, `android/gradle.properties`, or the Gradle wrapper, run the
following commands to clear stale caches and avoid spurious build errors:

```bash
# 1. Remove Dart/Flutter package cache for this project
flutter clean

# 2. Re-fetch all pub dependencies
flutter pub get

# 3. (Android) Invalidate the Gradle build cache
cd android && ./gradlew --stop && ./gradlew clean && cd ..
```

If you still see Kotlin or AGP version mismatch errors, also delete the Gradle user-home
wrapper cache:

```bash
# macOS / Linux
rm -rf ~/.gradle/caches
rm -rf ~/.gradle/wrapper/dists

# Windows (PowerShell)
Remove-Item -Recurse -Force "$env:USERPROFILE\.gradle\caches"
Remove-Item -Recurse -Force "$env:USERPROFILE\.gradle\wrapper\dists"
```

Then re-run `flutter pub get` and rebuild.

> **Note:** Do **not** commit a `org.gradle.java.home` entry in
> `android/gradle.properties`. That property is machine-specific and will break CI
> (which sets `JAVA_HOME` itself via the `actions/setup-java` step).

## Build Instructions

### Android debug APK (local)

```bash
flutter pub get
flutter build apk --debug \
  --dart-define=HERE_API_KEY=<your_key> \
  --dart-define=OPENWEATHER_API_KEY=<your_key> \
  --dart-define=GOOGLE_MAPS_ANDROID_API_KEY=<your_key>
```

### Android release APK (local)

```bash
flutter pub get
flutter build apk --release \
  --dart-define=HERE_API_KEY=<your_key> \
  --dart-define=OPENWEATHER_API_KEY=<your_key> \
  --dart-define=GOOGLE_MAPS_ANDROID_API_KEY=<your_key>
```

The built APK is at `build/app/outputs/flutter-apk/app-release.apk`.



### Required Environment Variables
```bash
# Run with API keys
flutter run \
  --dart-define=HERE_API_KEY=your_key \
  --dart-define=OPENWEATHER_API_KEY=your_key
```

## Google Maps Platform Setup

### Android
The Google Maps Android API key is injected at **two** points:

1. **AndroidManifest.xml** (used by the native Google Maps SDK):  
   The source file contains the placeholder `YOUR_GOOGLE_MAPS_API_KEY_HERE`.  
   The CI workflow replaces it with the real key via `sed` before the build.

2. **Dart `--dart-define`** (used for runtime diagnostics):  
   The key is also passed as `--dart-define=GOOGLE_MAPS_ANDROID_API_KEY=<key>`.  
   If omitted, the app shows a `_MapsApiKeyWarningBanner` overlay explaining the issue.

**Step-by-step (first-time setup):**

1. Go to [Google Cloud Console](https://console.cloud.google.com/) →
   **APIs & Services → Library**, search for **Maps SDK for Android**, and
   click **Enable**.
2. Go to **APIs & Services → Credentials** → **Create Credentials → API key**.
3. Restrict the key:
   - Under *Application restrictions*, choose **Android apps**.
   - Add a restriction entry:
     - **Package name**: `com.kingtrux.app`
     - **SHA-1 certificate fingerprint** (debug keystore):
       ```bash
       keytool -list -v \
         -keystore ~/.android/debug.keystore \
         -alias androiddebugkey \
         -storepass android -keypass android | grep SHA1
       ```
     - Add a second entry for your **release keystore** SHA-1 when preparing a
       production build.
   - Under *API restrictions*, choose **Restrict key** and select
     **Maps SDK for Android**.
4. Copy the key value for use below.

**Local development:**
```bash
flutter run \
  --dart-define=GOOGLE_MAPS_ANDROID_API_KEY=your_android_key \
  --dart-define=HERE_API_KEY=your_key \
  --dart-define=OPENWEATHER_API_KEY=your_key
```

### iOS
The iOS Google Maps SDK reads the key from `Info.plist` (via `GMSServices.provideAPIKey`).

1. Open `ios/Runner/Info.plist`.
2. Locate (or add) the `GMSApiKey` entry:
   ```xml
   <key>GMSApiKey</key>
   <string>YOUR_GOOGLE_MAPS_API_KEY_HERE</string>
   ```
3. Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your real **iOS** Maps SDK key obtained from
   [Google Cloud Console](https://console.cloud.google.com/) → APIs & Services → Credentials.
   Make sure **Maps SDK for iOS** is enabled.

> **Important:** iOS and Android use *separate* API keys. Restrict each key to its respective
> platform (iOS apps / Android apps) in the Google Cloud Console to prevent unauthorized use.

> **Do not commit your real key.** `ios/Runner/Info.plist` is in source control with the
> placeholder value. Replace it only in your local working copy or in a CI environment variable
> that patches the file before building.



## GitHub Actions CI Setup

The `android-build.yml` workflow requires the following secrets to produce a
fully-functional APK. Add them under **Settings → Secrets and variables →
Actions → New repository secret** in the GitHub UI.

| Secret | Required | Purpose |
|--------|----------|---------|
| `HERE_API_KEY` | ✅ Yes | HERE Routing API v8 – routing and search |
| `GOOGLE_MAPS_ANDROID_API_KEY` | ✅ Yes | Google Maps Android SDK – map tiles |
| `OPENWEATHER_API_KEY` | ⬜ Optional | OpenWeather API – weather overlay (weather data is hidden when unset) |
| `REVENUECAT_ANDROID_API_KEY` | ⬜ Optional | RevenueCat – in-app subscriptions (paywall shows a descriptive error when unset) |

The workflow injects these at build time:
- `HERE_API_KEY`, `OPENWEATHER_API_KEY`, and `REVENUECAT_ANDROID_API_KEY` are
  passed to Flutter via `--dart-define`.
- `GOOGLE_MAPS_ANDROID_API_KEY` replaces the `YOUR_GOOGLE_MAPS_API_KEY_HERE`
  placeholder in `android/app/src/main/AndroidManifest.xml` using `sed` before
  the build step. The actual key is **never committed to the repository**.

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
final route = await service.getTruckRoute(
  originLat: 37.7749,
  originLng: -122.4194,
  destLat: 37.3382,
  destLng: -121.8863,
  truckProfile: TruckProfile.defaultProfile(),
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
final weather = await service.getCurrentWeather(
  lat: 37.7749,
  lng: -122.4194,
);
```

## UI Components

### MapScreen
Main screen with Google Maps integration.
- **Set Destination button** (flag icon in FAB cluster) — activates destination-setting mode; tap the map to set destination and auto-route
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

### Map & Location
- [ ] Location permission granted
- [ ] GPS location obtained and map centred on device
- [ ] Map tiles load correctly (no blank tiles / grey screen)

### UI Layout (restored from 2026-03-04 working version)
- [ ] Top AppBar visible: KINGTRUX title, settings, and sign-out icons
- [ ] Search icon in AppBar opens "Where to?" destination sheet
- [ ] BottomAppBar visible with navigation toolbar buttons

### Navigation & Routing
- [ ] Long-press on map sets destination and triggers route calculation
- [ ] Route polyline displayed on the map after calculation
- [ ] "Start Navigation" button appears in bottom card after route is set
- [ ] Turn-by-turn navigation works via NavigationScreen

### Truck Profile
- [ ] "Using default truck profile" prompt visible in bottom card
- [ ] Tapping the prompt opens the TruckProfileSheet
- [ ] Saving custom profile dismisses the prompt

### POI & Toll
- [ ] "Find Nearby POIs" button loads POI markers within 15 km
- [ ] POI markers show info window on tap
- [ ] Toll/Toll-Free toggle re-routes correctly
- [ ] Layer toggles show/hide POI categories

### General
- [ ] Weather displayed correctly
- [ ] Map centering (follow mode) works
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
- **Android**: Pass `--dart-define=GOOGLE_MAPS_ANDROID_API_KEY=<key>` when running locally.  
  In CI, ensure the `GOOGLE_MAPS_ANDROID_API_KEY` repository secret is set.  
  A warning banner appears in the app when the key is missing or still the placeholder value.
- **iOS**: Replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` in `ios/Runner/Info.plist` with your iOS key.  
  See the *Google Maps Platform Setup → iOS* section above for step-by-step instructions.

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

---

## Truck Stop Brand Logos

### Asset location

All brand logo PNGs live in `assets/logos/` and are declared as a directory
bundle in `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/logos/
```

### Required filenames

| Brand | File |
|-------|------|
| Pilot / Flying J | `pilot.png` |
| Love's | `loves.png` |
| TA (TravelCenters of America) | `ta.png` |
| Petro | `petro.png` |
| Roady's | `roadys.png` |
| Sapp Bros | `sapp_bros.png` |
| Road Ranger | `road_ranger.png` |
| Kwik Trip / KwikStar | `kwik_trip.png` |
| Maverik | `maverik.png` |
| Casey's | `caseys.png` |
| Shell | `shell.png` |
| BP | `bp.png` |
| Total / TotalEnergies | `total.png` |
| Petro Canada | `petro_canada.png` |
| Esso | `esso.png` |

Placeholder colored PNGs are committed so the project builds and tests pass
out-of-the-box.  Replace them with official artwork (subject to brand usage
rights) at any time — no code changes required.

### How to add a new brand

1. **Add the PNG** to `assets/logos/<brand_slug>.png`.

2. **Extend the enum** in `lib/models/truck_stop_brand.dart`:
   ```dart
   enum TruckStopBrand {
     // …existing values…
     myNewBrand,
   }
   ```

3. **Add a display name** in the `TruckStopBrandLabel.displayName` switch.

4. **Add match terms** in the `TruckStopBrandLabel.matchTerms` switch.  All
   terms must already be normalized (lowercase, non-alphanumeric stripped).

5. **Map the asset path** in `truckStopBrandAssetPath()` in
   `lib/ui/widgets/truck_stop_brand_logo.dart`:
   ```dart
   case TruckStopBrand.myNewBrand:
     return 'assets/logos/my_new_brand.png';
   ```

6. **Run the tests** to verify detection works:
   ```bash
   flutter test test/truck_stop_brand_test.dart
   flutter test test/truck_stop_brand_logo_test.dart
   ```

### Where logos appear

| Location | Detail |
|----------|--------|
| **Map markers** | Truck stop POI markers show the brand logo in a circular icon; falls back to the default cyan pin when brand is unknown or marker generation fails. |
| **POI list / cards** | `_PoiListTile` in `poi_hub_sheet.dart` renders a 40 × 40 `TruckStopBrandLogo` as the list-tile leading widget for `PoiType.truckStop` entries. |

### Widget reference

`TruckStopBrandLogo` (`lib/ui/widgets/truck_stop_brand_logo.dart`)

```dart
TruckStopBrandLogo(
  brand: TruckStopBrand.pilot,
  size: 40,   // optional, defaults to 40
)
```

When the asset is unavailable (brand without a PNG, or image load error) the
widget automatically falls back to a generic truck icon in a circular
`primaryContainer` background.

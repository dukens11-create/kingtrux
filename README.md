# KINGTRUX - Professional Truck GPS Application

A Flutter-based mobile application for truck drivers with advanced routing, POI discovery, and weather integration.

## Features
- **Multi-provider Authentication** via Firebase Auth:
  - Email/Password (create account, sign in, password reset)
  - Phone number with SMS OTP
  - Google sign-in
  - Apple sign-in (iOS)
- **Real-time GPS tracking** using Google Maps Flutter SDK
- **Truck Profile** — configure your vehicle dimensions and restrictions:
  - Height, width, length, weight, axle count, and hazmat flag
  - Imperial (ft / short tons) and metric (m / t) display units
  - **Persists locally on device** (no account or API keys required)
  - Will be used for HERE truck routing once HERE keys are configured
- **Truck-specific route planning** with HERE Routing API v8
  - Configurable truck profile (height, weight, width, length, axles, hazmat)
  - Route optimization considering truck restrictions
  - **Toll vs Toll-Free selection** — driver toggle with estimated toll cost display
- **Points of Interest (POI) discovery** via OpenStreetMap Overpass API
  - Fuel stations
  - Rest areas
- **Real-time weather updates** at current location using OpenWeather API
- **Interactive map interface** with route visualization
- **Location-based services** with comprehensive permission handling

## Technical Stack
- **Framework**: Flutter 3.4+ / Dart
- **State Management**: Provider
- **Authentication**: Firebase Auth (Email/Password, Phone, Google, Apple)
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
3. **HERE Navigate SDK** (for turn-by-turn navigation): https://developer.here.com/
   - See [HERE_NAVIGATE_SETUP.md](HERE_NAVIGATE_SETUP.md) for detailed instructions
4. **OpenWeather API**: https://openweathermap.org/api
   - Free tier available
5. **RevenueCat**: https://app.revenuecat.com/
   - Free tier available; needed for in-app subscriptions

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
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_ID=your_here_navigate_id \
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_SECRET=your_here_navigate_secret \
  --dart-define=OPENWEATHER_API_KEY=your_openweather_api_key \
  --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx
```

#### Google Maps Platform Configuration

**Android** (`android/app/src/main/AndroidManifest.xml`):

The source file contains a placeholder. **Do not replace it manually** — it is injected by the CI
workflow from the `GOOGLE_MAPS_ANDROID_API_KEY` repository secret via `sed`. For local development,
pass the key via `--dart-define`:
```bash
flutter run --dart-define=GOOGLE_MAPS_ANDROID_API_KEY=your_android_key ...
```

The manifest entry (kept as placeholder in source control):
```xml
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="YOUR_GOOGLE_MAPS_API_KEY_HERE"/>
```

**iOS** (`ios/Runner/Info.plist`):

The source file contains a placeholder value for `GMSApiKey`. Replace it **only in your local
working copy** (do not commit the real key):
```xml
<key>GMSApiKey</key>
<string>YOUR_GOOGLE_MAPS_API_KEY_HERE</string>
```

Steps:
1. Go to [Google Cloud Console](https://console.cloud.google.com/) → **APIs & Services → Credentials**.
2. Create a new API key, enable **Maps SDK for iOS**, and restrict it to your app's bundle ID.
3. Open `ios/Runner/Info.plist` and replace `YOUR_GOOGLE_MAPS_API_KEY_HERE` with your key.
4. The key is read by `AppDelegate.swift` and passed to `GMSServices.provideAPIKey`.

> iOS and Android require **separate** API keys. Restrict each key to the respective platform in
> the Google Cloud Console.

## Running the Application

### Development Mode
```bash
# Android
flutter run \
  --dart-define=HERE_API_KEY=xxx \
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_ID=yyy \
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_SECRET=zzz \
  --dart-define=OPENWEATHER_API_KEY=www \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx

# iOS
flutter run -d ios \
  --dart-define=HERE_API_KEY=xxx \
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_ID=yyy \
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_SECRET=zzz \
  --dart-define=OPENWEATHER_API_KEY=www \
  --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx
```

### Running on Web (Chrome)

The `web/` directory in this repository contains the Flutter web platform
scaffolding required to run the app in Chrome — no `flutter create .` is
needed.

#### 1. Add your Google Maps Web API key

`web/index.html` contains a placeholder (`YOUR_GOOGLE_MAPS_WEB_API_KEY`) for
the Google Maps JavaScript API script tag.  **Do not commit a real key** —
inject it locally via `sed` (same pattern used for the Android key):

```bash
# Replace the placeholder in your local working copy (do not commit this change)
sed -i "s|YOUR_GOOGLE_MAPS_WEB_API_KEY|$GOOGLE_MAPS_WEB_API_KEY|g" web/index.html
```

Obtain a key at [Google Cloud Console](https://console.cloud.google.com/) →
**APIs & Services → Credentials** with the **Maps JavaScript API** enabled.
Restrict the key to your web origin (e.g. `http://localhost:*` for dev).

#### 2. Run in Chrome

```bash
flutter run -d chrome \
  --dart-define=HERE_API_KEY=xxx \
  --dart-define=OPENWEATHER_API_KEY=www
```

#### 3. Build a release web bundle

```bash
# Inject the key first (CI step or local — never commit the real key)
sed -i "s|YOUR_GOOGLE_MAPS_WEB_API_KEY|$GOOGLE_MAPS_WEB_API_KEY|g" web/index.html

flutter build web --release \
  --dart-define=HERE_API_KEY=xxx \
  --dart-define=OPENWEATHER_API_KEY=www
```

The output is placed in `build/web/`.

> **Platform limitations on web:** RevenueCat (`purchases_flutter`) and Apple
> Sign-In (`sign_in_with_apple`) do not support the web platform; those
> features will be unavailable when running in Chrome.  All other core
> features (mapping, routing, weather, Firebase Auth) are web-compatible.

### Build Release
```bash
# Android APK
flutter build apk --release \
  --dart-define=HERE_API_KEY=xxx \
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_ID=yyy \
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_SECRET=zzz \
  --dart-define=OPENWEATHER_API_KEY=www \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxx

# iOS
flutter build ios --release \
  --dart-define=HERE_API_KEY=xxx \
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_ID=yyy \
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_SECRET=zzz \
  --dart-define=OPENWEATHER_API_KEY=www \
  --dart-define=REVENUECAT_IOS_API_KEY=appl_xxx
```

## In-App Subscriptions (RevenueCat)

KINGTRUX Pro is gated behind a subscription paywall powered by [RevenueCat](https://www.revenuecat.com/).

### 1. Create a RevenueCat project

1. Sign up / log in at https://app.revenuecat.com/
2. Create a new **Project** (e.g. `KINGTRUX`).
3. Add your **iOS App** (Apple App Store) and **Android App** (Google Play Store) to the project.
4. Copy the **Public SDK key** for each platform.

### 2. Set SDK keys via --dart-define

> RevenueCat Public SDK keys are **safe to ship in the binary** — they are
> not secrets. Do not hard-code them in source; pass them as build-time
> constants so different environments (dev, staging, prod) can use different
> projects.

```bash
# Development
flutter run \
  --dart-define=REVENUECAT_IOS_API_KEY=appl_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx \
  --dart-define=REVENUECAT_ANDROID_API_KEY=goog_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

# CI / CD (set as masked environment variables in your pipeline)
flutter build apk --release \
  --dart-define=REVENUECAT_IOS_API_KEY=$REVENUECAT_IOS_API_KEY \
  --dart-define=REVENUECAT_ANDROID_API_KEY=$REVENUECAT_ANDROID_API_KEY
```

#### GitHub Actions — adding repository secrets

The CI workflows read the keys from [GitHub repository secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets). To add them:

1. Open your repository on GitHub.com.
2. Go to **Settings → Secrets and variables → Actions**.
3. Click **New repository secret** and add each of the following:

   | Secret name | Value |
   |---|---|
   | `HERE_API_KEY` | Your HERE Routing API key (required for routing/search) |
   | `GOOGLE_MAPS_ANDROID_API_KEY` | Your Google Maps Android API key (required for map tiles) |
   | `GOOGLE_MAPS_WEB_API_KEY` | Your Google Maps Web API key (required for map tiles on web) |
   | `OPENWEATHER_API_KEY` | Your OpenWeather API key (optional, for weather data) |
   | `REVENUECAT_IOS_API_KEY` | Your RevenueCat iOS public SDK key (starts with `appl_`) |
   | `REVENUECAT_ANDROID_API_KEY` | Your RevenueCat Android public SDK key (starts with `goog_`) |

4. The CI workflow (`android-build.yml`) automatically injects these secrets at build time on every run. `HERE_API_KEY`, `OPENWEATHER_API_KEY`, and `REVENUECAT_ANDROID_API_KEY` are passed to Flutter via `--dart-define`. `GOOGLE_MAPS_ANDROID_API_KEY` replaces the placeholder in `AndroidManifest.xml` before the build, and `GOOGLE_MAPS_WEB_API_KEY` replaces the placeholder in `web/index.html` — the actual keys are **never committed to the repository**.

If no key is set, the app shows a descriptive error on the paywall instead of crashing.

### 3. Configure products & offering in RevenueCat

1. In your app stores, create two subscription products:
   - **Monthly**: product ID `kingtrux_pro_monthly`  (e.g. $9.99/month)
   - **Yearly**: product ID `kingtrux_pro_yearly` (e.g. $99.99/year)
2. In the RevenueCat dashboard, create an **Entitlement** with identifier `pro` and attach both products.
3. Create an **Offering** with identifier `default` containing a package for each product (use the `Annual` and `Monthly` package types).

### 4. Local testing

- **iOS**: Use [StoreKit testing](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode) in Xcode with a `.storekit` config file, or test in the Sandbox environment with a Sandbox Apple ID.
- **Android**: Use [Google Play licensing testing](https://developer.android.com/google/play/billing/test) with a test account added to the Play Console.
- **RevenueCat sandbox**: Both platforms send sandbox receipts to RevenueCat automatically when running a debug/test build.

### Updating Terms & Privacy URLs

Placeholder URLs are defined in `lib/config.dart`:
```dart
static const String termsUrl   = 'https://kingtrux.com/terms';
static const String privacyUrl = 'https://kingtrux.com/privacy';
```
Replace these with your actual policy pages. Integrate `url_launcher` to open
them in the browser (it is not included by default to minimise dependencies).

## Firebase Authentication Setup

KINGTRUX uses Firebase Authentication for multi-provider user sign-in (Email/Password, Phone SMS OTP, Google, and Apple). The app compiles and runs with the placeholder configuration files included in this repository, but authentication **will not work** until you replace the placeholders with real Firebase credentials.

### 1. Create a Firebase project

1. Go to the [Firebase Console](https://console.firebase.google.com/).
2. Click **Add project** and follow the prompts.
3. In your project dashboard, open **Authentication → Sign-in method** and enable:
   - **Email/Password**
   - **Phone**
   - **Google**
   - **Apple** (iOS only; requires Apple Developer Program membership)

### 2. Android setup

1. In the Firebase Console, click **Add app → Android**.
2. Enter the package name: `com.example.kingtrux` (or your custom bundle ID).
3. Download **google-services.json** and place it at `android/app/google-services.json`,
   replacing the placeholder file already there.
   > **Never commit a real google-services.json to version control.**
   > Add it as a CI secret and inject it at build time (see below).

The `build.gradle` files are already configured to apply the `google-services` plugin.

### 3. iOS setup

1. In the Firebase Console, click **Add app → iOS**.
2. Enter the bundle ID: `com.example.kingtrux` (or your custom bundle ID).
3. Download **GoogleService-Info.plist** and place it at
   `ios/Runner/GoogleService-Info.plist`, replacing the placeholder file.
   > **Never commit a real GoogleService-Info.plist to version control.**
   > Add it as a CI secret and inject it at build time (see below).
4. In Xcode, open `ios/Runner.xcworkspace`:
   - Select the **Runner** target → **Signing & Capabilities**.
   - Click **+ Capability** and add **Sign in with Apple**.
   - Ensure the **Bundle Identifier** matches your Firebase iOS app.

### 4. Web setup

1. In the Firebase Console, click **Add app → Web** (`</>`).
2. Register the app (no Firebase Hosting required for local dev).
3. Copy the API key shown and replace the `YOUR_WEB_FIREBASE_API_KEY` placeholder
   in `lib/firebase_options.dart` (the other values for this project are already
   filled in):

```dart
static const FirebaseOptions web = FirebaseOptions(
  apiKey: 'YOUR_WEB_FIREBASE_API_KEY',   // ← replace this one value
  appId: '1:802226888759:web:4a64ff7011e28876c8dfb2',
  messagingSenderId: '802226888759',
  projectId: 'kingtrux-387ae',
  storageBucket: 'kingtrux-387ae.firebasestorage.app',
  authDomain: 'kingtrux-387ae.firebaseapp.com',
);
```

4. Run the app in Chrome:

```bash
flutter run -d chrome
```

> The `web` Firebase options are already wired into `DefaultFirebaseOptions.currentPlatform`
> so no additional code changes are needed once the placeholder values are replaced.

5. **Phone sign-in on web** uses a reCAPTCHA challenge (handled automatically by the
   Firebase Auth SDK). For it to work:
   - Go to **Firebase Console → Authentication → Settings → Authorized domains** and add
     your deployment domain (e.g. `localhost` for local dev, your Hosting / custom domain
     for production).
   - `localhost` is added by default; add any additional domains before deploying.
   - Phone authentication requires the **Blaze (pay-as-you-go)** Firebase plan for
     production usage beyond the free-tier quota.

### 5. Update `lib/firebase_options.dart`

Replace the placeholder constants in `lib/firebase_options.dart` with the real
values from the Firebase Console (or simply run `flutterfire configure` after
installing the FlutterFire CLI):

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

This regenerates `lib/firebase_options.dart` automatically (including the `web` entry).

### 6. Injecting secrets in CI

Add the following GitHub repository secrets (Settings → Secrets → Actions):

| Secret name | Value |
|---|---|
| `GOOGLE_SERVICES_JSON` | Base64-encoded contents of `google-services.json` |
| `GOOGLE_SERVICE_INFO_PLIST` | Base64-encoded contents of `GoogleService-Info.plist` |
| `WEB_FIREBASE_API_KEY` | Firebase Web API key (from Firebase Console → Project settings → Your apps → Web app) |

Then add injection steps to your CI workflows **before** the build step:

**Android** (`android-build.yml`):
```yaml
- name: Inject google-services.json
  env:
    GOOGLE_SERVICES_JSON: ${{ secrets.GOOGLE_SERVICES_JSON }}
  run: |
    echo "$GOOGLE_SERVICES_JSON" | base64 --decode > android/app/google-services.json
```

**iOS** (`ci.yml`):
```yaml
- name: Inject GoogleService-Info.plist
  env:
    GOOGLE_SERVICE_INFO_PLIST: ${{ secrets.GOOGLE_SERVICE_INFO_PLIST }}
  run: |
    echo "$GOOGLE_SERVICE_INFO_PLIST" | base64 --decode > ios/Runner/GoogleService-Info.plist
```

**Web** (`ci.yml`): The web-build job already injects `WEB_FIREBASE_API_KEY` into
`lib/firebase_options.dart` via `sed` before building. No additional steps are needed
beyond setting the secret.

> **Where secrets/config live:** `lib/firebase_options.dart` holds non-secret
> project identifiers (appId, projectId, authDomain, etc.) and a
> `YOUR_WEB_FIREBASE_API_KEY` placeholder that is replaced at CI build time.
> `android/app/google-services.json` and `ios/Runner/GoogleService-Info.plist`
> contain placeholder values and are replaced by CI secrets at build time.
> Real credentials are never committed to version control.

---

## Firebase Web Modules

`web/firebase-init.js` provides a ready-to-use **Firebase JS SDK v11 modular** initialization
for web-only JavaScript code. It re-uses the same project configuration as the Flutter/Dart layer
(`lib/firebase_options.dart`) but exposes native Firebase JS SDK handles for situations where you
need to interact with Firebase directly from JavaScript (e.g., custom service workers, static web
pages, or scripts that run outside the Flutter engine).

> **Flutter app note:** The Flutter layer initialises Firebase through FlutterFire
> (`lib/firebase_options.dart`). Do **not** load `firebase-init.js` from `web/index.html` as that
> would conflict with FlutterFire's own initialization. Import this module only from standalone JS
> scripts that run independently of the Flutter app.

### Exports

| Export | Type | Description |
|--------|------|-------------|
| `app` | `FirebaseApp` | Initialized Firebase app instance |
| `analytics` | `Analytics \| null` | Analytics instance, or `null` when unsupported |
| `auth` | `Auth` | Firebase Authentication service |
| `db` | `Firestore` | Cloud Firestore database service |
| `storage` | `FirebaseStorage` | Firebase Storage service |

### Usage

```js
// Import only what you need (tree-shaking friendly)
import { auth, db, storage } from './firebase-init.js';

// Auth
import { signInWithEmailAndPassword } from
  'https://www.gstatic.com/firebasejs/11.3.1/firebase-auth.js';
await signInWithEmailAndPassword(auth, email, password);

// Firestore
import { doc, getDoc } from
  'https://www.gstatic.com/firebasejs/11.3.1/firebase-firestore.js';
const snap = await getDoc(doc(db, 'collection', 'docId'));

// Storage
import { ref, getDownloadURL } from
  'https://www.gstatic.com/firebasejs/11.3.1/firebase-storage.js';
const url = await getDownloadURL(ref(storage, 'path/to/file'));

// Analytics (always check for null – it is null in unsupported environments)
import { logEvent } from
  'https://www.gstatic.com/firebasejs/11.3.1/firebase-analytics.js';
import { analytics } from './firebase-init.js';
if (analytics) logEvent(analytics, 'page_view');
```

### Configuration placeholders

`web/firebase-init.js` contains two placeholders that must be replaced before
Firebase services will authenticate requests:

| Placeholder | How to replace |
|---|---|
| `YOUR_WEB_FIREBASE_API_KEY` | Firebase Console → Project settings → Your apps → Web app → `apiKey`. Already injected by the CI `WEB_FIREBASE_API_KEY` secret. |
| `YOUR_WEB_FIREBASE_MEASUREMENT_ID` | Firebase Console → Project settings → Your apps → Web app → `measurementId`. Add a `WEB_FIREBASE_MEASUREMENT_ID` CI secret and a `sed` step mirroring the existing `WEB_FIREBASE_API_KEY` injection. |

### npm dependency

`web/package.json` declares `firebase ^11.3.1` as a dependency. If you set up a
bundler (e.g., Vite, Webpack) for the web directory, run `npm install` inside
`web/` to install the package locally instead of loading it from the CDN.

---

KINGTRUX shows the posted road speed limit and the driver's GPS speed at all times as a compact on-screen overlay (bottom-left of the map).

### Speed state color coding

| State | Condition | Banner colour | Voice alert |
|-------|-----------|--------------|-------------|
| **Overspeeding** | Driver speed > limit + 2 mph | 🔴 Red (critical) | ✅ Yes |
| **Underspeeding** | Driver speed < limit − threshold | 🟡 Amber (warning) | ✅ Yes |
| **Correct speed** | Driver speed within range | *(no banner – SpeedDisplay overlay turns green)* | ❌ No |

### Configuration

The **underspeed threshold** (default **10 mph**) can be changed programmatically via `AppState.setUnderspeedThreshold(double thresholdMph)`.  The value is persisted to device storage under the SharedPreferences key `speed_underspeed_threshold_mph`.

### How it works

1. A background GPS stream (`distanceFilter: 5 m`) updates `AppState.currentSpeedMph` from the device's GPS speed (m/s → mph).
2. The posted road speed limit is fetched from OpenStreetMap via the Overpass API (`maxspeed` tag on nearby ways within 50 m).  Queries are throttled: a new request is only sent after the driver has moved > 200 m from the last query position.
3. When the speed state transitions (e.g., correct → overspeeding) a colour-coded `AlertBanner` is shown and, for overspeed/underspeed, a TTS voice alert is triggered.
4. Alerts fire instantly on threshold crossing; they do not repeat until the state changes again.



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

### HERE Routing integration

The saved profile is automatically passed to the HERE Routing API v8 every time
a route is calculated. The following parameters are applied:

| TruckProfile field | HERE API parameter | Unit |
|--------------------|--------------------|------|
| `heightMeters` | `truck[height]` | meters |
| `widthMeters` | `truck[width]` | meters |
| `lengthMeters` | `truck[length]` | meters |
| `weightTons` | `truck[grossWeight]` | kilograms (×1 000) |
| `axles` | `truck[axleCount]` | count |
| `hazmat: true` | `truck[shippedHazardousGoods]` | `explosive` |

Routes respect height/weight clearances, hazmat restrictions, and road-class
limits. A HERE API key (`HERE_API_KEY`) must be configured — see
[HERE_NAVIGATE_SETUP.md](HERE_NAVIGATE_SETUP.md).

If required profile fields are zero or invalid, the app surfaces an actionable
error before making any network request (no crash or silent fallback).

## Toll vs Toll-Free Route Selection

Truck drivers can choose between routes that use toll roads and routes that
avoid them entirely.

### How to use

1. A **Toll / Toll-Free** toggle is displayed in the route card at the bottom of
   the map screen.
2. Tap **Toll** to allow toll roads (default). When the HERE API returns cost
   data, an **Est. tolls: $X.XX** estimate is shown below the route duration.
3. Tap **Toll-Free** to request a route that avoids all toll roads.  A green
   **✓ Toll-Free Route** badge is shown on the route card to confirm the
   preference is active.
4. Changing the preference while a route is already displayed automatically
   recalculates the route with the new setting.

### Global / persistent preference

The selected preference is persisted to device storage via `SharedPreferences`.
The app restores the preference on next launch so drivers do not have to
re-select it every trip.

### HERE API integration

| Preference | HERE API parameter added | `return` field |
|------------|--------------------------|----------------|
| **Toll** (any) | *(none)* | `polyline,summary,actions,tolls` |
| **Toll-Free** | `avoid[features]=tollRoad` | `polyline,summary,actions` |

The toll cost estimate is parsed from the `sections[].tolls[].fares[].convertedPrice`
field in the HERE Routing API v8 response.



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
├── web/                  # Web platform configuration (Chrome / Flutter web)
│   ├── index.html        # Entry HTML with Google Maps JS API script tag
│   ├── manifest.json     # PWA manifest
│   ├── favicon.png       # Browser tab icon
│   └── icons/            # PWA / Apple touch icons (192 & 512 px)
├── lib/
│   ├── main.dart         # App entry point
│   ├── app.dart          # Root widget with Provider setup
│   ├── config.dart       # API configuration
│   ├── models/           # Data models
│   │   ├── navigation_maneuver.dart  # Turn-by-turn maneuver step
│   │   ├── poi.dart
│   │   ├── route_result.dart
│   │   ├── truck_profile.dart
│   │   └── weather_point.dart
│   ├── services/         # API service integrations
│   │   ├── location_service.dart
│   │   ├── here_routing_service.dart
│   │   ├── navigation_session_service.dart  # GPS + maneuver tracking
│   │   ├── overpass_poi_service.dart
│   │   ├── revenue_cat_service.dart  # RevenueCat SDK wrapper
│   │   ├── truck_profile_service.dart
│   │   └── weather_service.dart
│   ├── state/            # State management
│   │   └── app_state.dart
│   └── ui/               # UI components
│       ├── map_screen.dart
│       ├── navigation_screen.dart      # Turn-by-turn navigation UI
│       ├── paywall_screen.dart         # KINGTRUX Pro subscription paywall
│       ├── preview_gallery_page.dart  # Debug-only UI preview
│       └── widgets/
│           ├── layer_sheet.dart
│           ├── route_summary_card.dart
│           └── truck_profile_sheet.dart
├── HERE_NAVIGATE_SETUP.md  # HERE Navigate SDK integration guide
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
- `flutter_tts` - Text-to-speech for voice navigation guidance
- `purchases_flutter` - RevenueCat in-app subscription SDK
- `url_launcher` - Open Terms/Privacy URLs in the browser
- `firebase_core` / `firebase_auth` - Firebase Authentication
- `google_sign_in` - Google sign-in integration
- `sign_in_with_apple` - Apple sign-in integration (iOS)

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
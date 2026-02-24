# HERE Navigate SDK – Setup Guide

This document describes how to configure credentials and platform dependencies
for HERE Navigate SDK integration in KINGTRUX.

---

## 1. Credentials

KINGTRUX uses two separate HERE credential sets:

| Variable | Purpose |
|---|---|
| `HERE_API_KEY` | HERE Routing REST API v8 (route calculation) |
| `HERE_NAVIGATE_ACCESS_KEY_ID` | HERE Navigate SDK – Access Key ID |
| `HERE_NAVIGATE_ACCESS_KEY_SECRET` | HERE Navigate SDK – Access Key Secret |

### Obtaining credentials

1. Sign up / log in at <https://developer.here.com/>.
2. Create a project and generate an **REST API key** → use as `HERE_API_KEY`.
3. In the same project, create an **Access Key** (OAuth 2.0) →
   use the *Key ID* as `HERE_NAVIGATE_ACCESS_KEY_ID` and the
   *Key Secret* as `HERE_NAVIGATE_ACCESS_KEY_SECRET`.

> **Never commit credentials.** Use the `--dart-define` mechanism described
> below.

---

## 2. Passing credentials at build / run time

All credentials are injected via Dart's `--dart-define` mechanism, which maps
to `String.fromEnvironment(...)` in `lib/config.dart`.

### Local development

```bash
flutter run \
  --dart-define=HERE_API_KEY=YOUR_ROUTING_KEY \
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_ID=YOUR_SDK_KEY_ID \
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_SECRET=YOUR_SDK_SECRET \
  --dart-define=OPENWEATHER_API_KEY=YOUR_WEATHER_KEY
```

### Release builds

```bash
flutter build apk --release \
  --dart-define=HERE_API_KEY=YOUR_ROUTING_KEY \
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_ID=YOUR_SDK_KEY_ID \
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_SECRET=YOUR_SDK_SECRET

flutter build ios --release --no-codesign \
  --dart-define=HERE_API_KEY=YOUR_ROUTING_KEY \
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_ID=YOUR_SDK_KEY_ID \
  --dart-define=HERE_NAVIGATE_ACCESS_KEY_SECRET=YOUR_SDK_SECRET
```

---

## 3. GitHub Actions

Store credentials as repository / environment secrets and pass them via
`--dart-define`:

```yaml
# .github/workflows/ci.yml  (relevant snippet)
- name: Build Android APK
  env:
    HERE_API_KEY: ${{ secrets.HERE_API_KEY }}
    HERE_NAVIGATE_ACCESS_KEY_ID: ${{ secrets.HERE_NAVIGATE_ACCESS_KEY_ID }}
    HERE_NAVIGATE_ACCESS_KEY_SECRET: ${{ secrets.HERE_NAVIGATE_ACCESS_KEY_SECRET }}
  run: |
    flutter build apk --debug \
      --dart-define=HERE_API_KEY=$HERE_API_KEY \
      --dart-define=HERE_NAVIGATE_ACCESS_KEY_ID=$HERE_NAVIGATE_ACCESS_KEY_ID \
      --dart-define=HERE_NAVIGATE_ACCESS_KEY_SECRET=$HERE_NAVIGATE_ACCESS_KEY_SECRET
```

### Failing the build when credentials are missing

Add a validation step before the build:

```yaml
- name: Validate HERE credentials
  run: |
    if [ -z "${{ secrets.HERE_API_KEY }}" ]; then
      echo "::error::HERE_API_KEY secret is not set. Add it in Settings → Secrets."
      exit 1
    fi
    if [ -z "${{ secrets.HERE_NAVIGATE_ACCESS_KEY_ID }}" ]; then
      echo "::error::HERE_NAVIGATE_ACCESS_KEY_ID secret is not set."
      exit 1
    fi
```

---

## 4. Codemagic

In your `codemagic.yaml` environment section:

```yaml
environment:
  vars:
    HERE_API_KEY: $HERE_API_KEY
    HERE_NAVIGATE_ACCESS_KEY_ID: $HERE_NAVIGATE_ACCESS_KEY_ID
    HERE_NAVIGATE_ACCESS_KEY_SECRET: $HERE_NAVIGATE_ACCESS_KEY_SECRET
  # Store actual values in Codemagic's encrypted Environment Variables UI.

scripts:
  - name: Build Android
    script: |
      flutter build apk --release \
        --dart-define=HERE_API_KEY=$HERE_API_KEY \
        --dart-define=HERE_NAVIGATE_ACCESS_KEY_ID=$HERE_NAVIGATE_ACCESS_KEY_ID \
        --dart-define=HERE_NAVIGATE_ACCESS_KEY_SECRET=$HERE_NAVIGATE_ACCESS_KEY_SECRET
```

---

## 5. Native SDK integration (next steps)

The current implementation uses the HERE Routing REST API for maneuver data
and `geolocator` for position tracking. The `NavigationSessionService`
(`lib/services/navigation_session_service.dart`) is designed to be a drop-in
replacement once the native HERE Navigate SDK is wired in.

### Android

1. Add the HERE Maven repository to `android/build.gradle`:

```groovy
allprojects {
    repositories {
        // ... existing repos ...
        maven { url 'https://repository.here.com/artifactory/here-sdks/' }
    }
}
```

2. Add the dependency to `android/app/build.gradle`:

```groovy
dependencies {
    implementation 'com.here.sdk:explore-edition:4.20.0'
}
```

3. Initialize the SDK in `android/app/src/main/kotlin/…/MainActivity.kt`:

```kotlin
import com.here.sdk.core.engine.SDKNativeEngine
import com.here.sdk.core.engine.SDKOptions

override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    val options = SDKOptions(
        accessKeyId = BuildConfig.HERE_NAVIGATE_ACCESS_KEY_ID,
        accessKeySecret = BuildConfig.HERE_NAVIGATE_ACCESS_KEY_SECRET,
    )
    try {
        SDKNativeEngine.makeSharedInstance(this, options)
    } catch (e: Exception) {
        throw RuntimeException("HERE SDK init failed: ${e.message}", e)
    }
}
```

Pass credentials via `buildConfigField` in `build.gradle`:

```groovy
android {
    defaultConfig {
        buildConfigField "String", "HERE_NAVIGATE_ACCESS_KEY_ID",
            "\"${project.findProperty('HERE_NAVIGATE_ACCESS_KEY_ID') ?: ''}\""
        buildConfigField "String", "HERE_NAVIGATE_ACCESS_KEY_SECRET",
            "\"${project.findProperty('HERE_NAVIGATE_ACCESS_KEY_SECRET') ?: ''}\""
    }
}
```

Pass at build time with `./gradlew assembleDebug -PHERE_NAVIGATE_ACCESS_KEY_ID=…`.

### iOS

1. Add the HERE pod spec source to `ios/Podfile`:

```ruby
source 'https://github.com/heremaps/here-ios-sdk-specs.git'
source 'https://cdn.cocoapods.org/'
```

2. Add the pod:

```ruby
pod 'heresdk', '4.20.0.1'
```

3. Initialize the SDK in `ios/Runner/AppDelegate.swift`:

```swift
import heresdk

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let options = SDKOptions(
            accessKeyId: Bundle.main.infoDictionary?["HERE_NAVIGATE_ACCESS_KEY_ID"] as? String ?? "",
            accessKeySecret: Bundle.main.infoDictionary?["HERE_NAVIGATE_ACCESS_KEY_SECRET"] as? String ?? ""
        )
        do {
            try SDKInitializer.initializeIfNecessary(options: options)
        } catch {
            fatalError("HERE SDK init failed: \(error)")
        }
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

Pass credentials via an `.xcconfig` or a `User-Defined` build setting
referencing an environment variable.

---

## 6. Required platform permissions

### Android (`android/app/src/main/AndroidManifest.xml`)

Already added:

```xml
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_LOCATION"/>
```

### iOS (`ios/Runner/Info.plist`)

Already added:

```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>…</string>
<key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
<string>…</string>
<key>UIBackgroundModes</key>
<array>
    <string>location</string>
</array>
```

---

## 7. Voice guidance

Voice prompts are emitted through `AppState.voiceGuidanceEnabled` and piped
to `flutter_tts`. The default language is the device's system locale.
Multi-language selection UI (en-US, en-CA, fr-CA, es-US) is tracked in a
follow-up PR.

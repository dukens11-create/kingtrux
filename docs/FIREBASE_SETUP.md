# Firebase Setup Guide

This document describes how to configure Firebase for the **KingTrux** app so
that crowdsourced weigh-station status reports are stored in and served from
**Cloud Firestore**.

---

## Prerequisites

1. A **Google account** with access to the [Firebase Console](https://console.firebase.google.com).
2. The **Firebase CLI** installed (`npm install -g firebase-tools`).
3. The **FlutterFire CLI** installed (`dart pub global activate flutterfire_cli`).
4. The repository cloned locally.

---

## 1. Create or Select a Firebase Project

1. Open [https://console.firebase.google.com](https://console.firebase.google.com).
2. Click **Add project** (or select an existing project named `kingtrux-387ae`).
3. Follow the wizard; you may disable Google Analytics if you don't need it.

---

## 2. Register the Apps with Firebase

### Android

1. In the Firebase Console → **Project Settings** → **Your apps**, click the
   Android icon.
2. Set **Android package name** to `com.kingtrux.app`.
3. Download `google-services.json` and place it at:
   ```
   android/app/google-services.json
   ```
   **Do not commit this file** – it is listed in `.gitignore`.

### iOS

1. In the same **Your apps** screen, click the iOS icon.
2. Set **iOS bundle ID** to `com.kingtrux.app` (or match `iosBundleId` in
   `lib/firebase_options.dart`).
3. Download `GoogleService-Info.plist` and place it at:
   ```
   ios/Runner/GoogleService-Info.plist
   ```
   Open `ios/Runner.xcworkspace` in Xcode → drag the plist into the
   **Runner** target's file tree if it isn't already there.
   **Do not commit this file** – it is listed in `.gitignore`.

### Regenerating `firebase_options.dart`

If you need to regenerate the Dart options file after adding platforms:

```bash
flutterfire configure --project=kingtrux-387ae
```

This regenerates `lib/firebase_options.dart` with the correct credentials for
every registered platform.

> **Security note:** `lib/firebase_options.dart` is committed to the repository
> with placeholder values (`YOUR_ANDROID_FIREBASE_API_KEY`,
> `YOUR_IOS_FIREBASE_API_KEY`, `YOUR_WEB_FIREBASE_API_KEY`) instead of real
> API keys.  Real keys must never be committed in source code.
>
> **CI injection:** GitHub Actions workflows replace these placeholders at build
> time using the `ANDROID_FIREBASE_API_KEY`, `IOS_FIREBASE_API_KEY`, and
> `WEB_FIREBASE_API_KEY` repository secrets (see *Injecting secrets in CI*
> in `README.md` for details).
>
> **Local development:** After running `flutterfire configure`, immediately
> move the generated file out of the repo (or revert it with
> `git checkout lib/firebase_options.dart`) and use `--dart-define` flags or a
> local `.env` file to supply the keys without committing them.
>
> **Key rotation & restriction:** Firebase API keys for client apps cannot be
> fully hidden — they are ultimately embedded in the binary.  The correct
> security posture is to **restrict** each key rather than relying solely on
> secrecy:
> 1. Open [Google Cloud Console → APIs & Services → Credentials](https://console.cloud.google.com/apis/credentials).
> 2. Select the API key, then under **Application restrictions** set
>    *Android apps* / *iOS apps* / *HTTP referrers* as appropriate for each
>    platform key.
> 3. Under **API restrictions**, limit each key to only the Firebase/Google APIs
>    it needs (e.g., Firebase, Cloud Firestore, Identity Platform).
>
> If a key has already been exposed (e.g., committed to a public repository),
> also delete and regenerate it in the Firebase Console → Project settings →
> Your apps, and update the corresponding GitHub Secret.

---

## 3. Enable Cloud Firestore

1. In the Firebase Console sidebar, click **Firestore Database**.
2. Click **Create database**.
3. Choose **Production mode** (recommended) then select the nearest region.
4. Click **Done**.

---

## 4. Firestore Security Rules

Replace the default rules with the following to allow **any authenticated
user** (including anonymous sessions) to write reports and **anyone** to read
them:

```firestore
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Weigh-station crowdsourced status reports
    match /weigh_station_reports/{docId} {
      // Anyone can read (public crowdsource data).
      allow read: if true;

      // Authenticated users (including anonymous) may create new reports.
      // Updates and deletes are disallowed to keep reports immutable.
      allow create: if request.auth != null
        && request.resource.data.keys().hasAll(['stationId', 'status', 'timestamp'])
        && request.resource.data.stationId is string
        && request.resource.data.status in [
             'open_bypass', 'open_going_through',
             'monitoring', 'closed', 'unknown'
           ];
      allow update, delete: if false;
    }

    // Deny access to all other collections by default.
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### Applying the Rules

```bash
firebase deploy --only firestore:rules
```

---

## 5. Enable Anonymous Authentication

The app uses **anonymous sign-in** to attach a stable (but privacy-safe) user
ID to each status report without requiring the driver to create an account.

1. Firebase Console → **Authentication** → **Sign-in method**.
2. Enable **Anonymous**.
3. Click **Save**.

---

## 6. Injecting `google-services.json` in CI (GitHub Actions)

`google-services.json` must **never** be committed to the repository.  CI
workflows inject it at build time from a GitHub Actions secret.

### Required secrets

| Secret name                    | Required? | Description |
|-------------------------------|-----------|-------------|
| `ANDROID_GOOGLE_SERVICES_JSON` | Optional  | Base64-encoded (preferred) or raw JSON contents of `google-services.json` |
| `ANDROID_FIREBASE_API_KEY`     | Optional  | Firebase Android API key (replaces `YOUR_ANDROID_FIREBASE_API_KEY` placeholder) |

> **Fallback behavior:** If `ANDROID_GOOGLE_SERVICES_JSON` is not set (e.g. on
> fork PRs that cannot access repository secrets), the build continues with
> `--dart-define=FIREBASE_ENABLED=false`.  Firebase is not initialized and all
> Firestore-backed features gracefully no-op.  No secret content is ever printed
> to the log.

### Creating the secret

1. In the Firebase Console → **Project Settings** → **Your apps** → Android app,
   download `google-services.json`.
2. Base64-encode it locally (no line wrapping) — **this is the preferred format**:
   ```bash
   # macOS
   base64 -i android/app/google-services.json | tr -d '\n'
   # Linux
   base64 -w 0 android/app/google-services.json
   ```
   > **Raw JSON also works.** If you paste the raw JSON content directly as the
   > secret value, the workflow will detect and accept it automatically.
3. In the GitHub repository, go to **Settings → Secrets and variables → Actions**.
4. Click **New repository secret**.
5. Name: `ANDROID_GOOGLE_SERVICES_JSON`  
   Value: the base64 string from step 2 (or raw JSON if preferred).
6. Click **Add secret**.

### What the workflow does

Before every Android build step the workflow:

1. Checks whether `ANDROID_GOOGLE_SERVICES_JSON` is set.
   - **If set:** decodes (base64 or raw JSON), validates with `python -m json.tool`,
     writes to `android/app/google-services.json` and
     `android/app/src/release/google-services.json`, then sets
     `FIREBASE_ENABLED=true` in the environment.
   - **If absent:** logs an informational message and sets `FIREBASE_ENABLED=false`.
     No error is raised; the build continues without Firebase.
2. Never prints secret contents to the log.
3. Passes `--dart-define=FIREBASE_ENABLED=$FIREBASE_ENABLED` to every
   `flutter build` invocation so the Dart code matches the Gradle configuration.

```yaml
- name: Inject google-services.json
  env:
    ANDROID_GOOGLE_SERVICES_JSON: ${{ secrets.ANDROID_GOOGLE_SERVICES_JSON }}
  run: |
    if [ -z "$ANDROID_GOOGLE_SERVICES_JSON" ]; then
      echo "Secret not set; building without Firebase (FIREBASE_ENABLED=false)."
      echo "FIREBASE_ENABLED=false" >> "$GITHUB_ENV"
    else
      DECODED=$(printf '%s' "$ANDROID_GOOGLE_SERVICES_JSON" | base64 --decode 2>/dev/null || true)
      if printf '%s' "$DECODED" | python -m json.tool > /dev/null 2>&1; then
        JSON_CONTENT="$DECODED"
      elif printf '%s' "$ANDROID_GOOGLE_SERVICES_JSON" | python -m json.tool > /dev/null 2>&1; then
        JSON_CONTENT="$ANDROID_GOOGLE_SERVICES_JSON"
      else
        echo "::error::ANDROID_GOOGLE_SERVICES_JSON is neither valid base64-encoded JSON nor valid raw JSON."
        exit 1
      fi
      mkdir -p android/app android/app/src/release
      printf '%s' "$JSON_CONTENT" > android/app/google-services.json
      printf '%s' "$JSON_CONTENT" > android/app/src/release/google-services.json
      echo "FIREBASE_ENABLED=true" >> "$GITHUB_ENV"
    fi
```

Both files are written at runtime and are never stored in Git (both paths are
listed in `.gitignore`).

---

## 7. Building Without Firebase (Local or Fork PRs)

The app supports building and running without Firebase by passing
`--dart-define=FIREBASE_ENABLED=false` at build time.

### How it works

| Layer | What happens when `FIREBASE_ENABLED=false` |
|-------|--------------------------------------------|
| **Gradle** | `android/app/build.gradle` checks for `google-services.json`; if absent the `com.google.gms.google-services` plugin is **not** applied, so Gradle does not fail. |
| **Dart/Flutter** | `Config.firebaseEnabled` resolves to `false`; `main.dart` skips `Firebase.initializeApp`. |
| **Firestore** | `FirestoreWeighStationService` wraps all calls in `try-catch`; any exceptions return empty maps / `false`. All weigh-station crowdsource features are silently disabled. |
| **UI** | The Account icon (requires Firebase Auth) is hidden when `Firebase.apps.isEmpty`. |

### Local build without Firebase

```bash
flutter build apk --debug --dart-define=FIREBASE_ENABLED=false
flutter build appbundle --release --dart-define=FIREBASE_ENABLED=false
```

### Local build with Firebase

1. Place `android/app/google-services.json` (downloaded from Firebase Console).
2. Run:
   ```bash
   flutter build appbundle --release --dart-define=FIREBASE_ENABLED=true
   ```

| Collection              | Field       | Type      | Description                              |
|-------------------------|-------------|-----------|------------------------------------------|
| `weigh_station_reports` | `stationId` | `string`  | Matches `WeighStation.id`                |
|                         | `status`    | `string`  | One of the values listed in §4           |
|                         | `timestamp` | Timestamp | Server timestamp (`FieldValue.serverTimestamp`) |
|                         | `userId`    | `string?` | Firebase anonymous UID (may be absent)   |

---

## 9. Local Development Without Real Config

For unit tests and CI pipelines that do not have a real Firebase project, the
`FirestoreWeighStationService` catches all Firestore exceptions and returns
empty results — the app continues to function using the static station baseline
with `Unknown` statuses.

To run tests that exercise the Firestore code path, use the
[Firebase Local Emulator Suite](https://firebase.google.com/docs/emulator-suite):

```bash
firebase emulators:start --only firestore
```

Then set `FIRESTORE_EMULATOR_HOST=localhost:8080` before running Flutter tests.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---------|-------|-----|
| CI fails with "neither valid base64-encoded JSON nor valid raw JSON" | Secret value is corrupted or truncated | Re-encode with `base64 -w 0 google-services.json` and update the secret |
| Build fails with "Google Services plugin requires…" locally | Missing `google-services.json` | Download from Firebase Console or build with `--dart-define=FIREBASE_ENABLED=false` |
| Firebase features disabled unexpectedly | `FIREBASE_ENABLED=false` passed or secret absent in CI | Set `ANDROID_GOOGLE_SERVICES_JSON` secret (see §6) |
| Status always shows Unknown | Firestore rules deny reads, or Auth not enabled | Check rules and Anonymous Auth |
| Reports not persisted | Anonymous Auth disabled | Enable in Firebase Console → Authentication |
| Wrong platform config | `firebase_options.dart` out of date | Run `flutterfire configure` again |

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

> **Note:** The build workflow (`android-build.yml`) and the CI workflow (`ci.yml`)
> will both **fail with a clear error** if this secret is absent or contains
> an invalid value.  This prevents silent, confusing Gradle failures deep inside the build.

### What the workflow does

Before every Android build step the workflow:

1. Checks that `ANDROID_GOOGLE_SERVICES_JSON` is set; fails immediately with a
   descriptive error if not.
2. Auto-detects whether the value is base64-encoded or raw JSON and decodes
   accordingly — no change to the secret is needed if the format is already raw JSON.
3. Writes the config to **both** locations searched by the
   `com.google.gms.google-services` Gradle plugin:
   - `android/app/google-services.json`
   - `android/app/src/release/google-services.json`
4. Validates the written file with `python -m json.tool`; fails with a clear
   error if the result is not valid JSON.
5. Never prints secret contents to the log.

```yaml
- name: Inject google-services.json
  env:
    ANDROID_GOOGLE_SERVICES_JSON: ${{ secrets.ANDROID_GOOGLE_SERVICES_JSON }}
  run: |
    if [ -z "$ANDROID_GOOGLE_SERVICES_JSON" ]; then
      echo "::error::Secret ANDROID_GOOGLE_SERVICES_JSON is not set."
      exit 1
    fi
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
```

Both files are written at runtime and are never stored in Git (both paths are
listed in `.gitignore`).

---

## 7. Building Without Firebase Config Files (Local Only)

The app is designed to build and run gracefully without `google-services.json`
or `GoogleService-Info.plist` — it falls back to showing station status as
**Unknown** and silently skips Firestore reads/writes.

However, the Android Gradle build *requires* `google-services.json` to be
present when the `com.google.gms.google-services` plugin is applied.  To build
without Firebase on Android, comment out the plugin line in
`android/app/build.gradle`:

```groovy
// id "com.google.gms.google-services"
```

---

## 8. Firestore Collection & Document Schema

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
| CI fails with "Secret ANDROID_GOOGLE_SERVICES_JSON is not set" | Secret not added to repo | Follow §6 to create the `ANDROID_GOOGLE_SERVICES_JSON` secret |
| CI fails with "neither valid base64-encoded JSON nor valid raw JSON" | Secret value is corrupted or truncated | Re-encode with `base64 -w 0 google-services.json` and update the secret |
| Build fails with "Google Services plugin requires…" | Missing `google-services.json` locally | Download from Firebase Console and place at `android/app/google-services.json` |
| Status always shows Unknown | Firestore rules deny reads, or Auth not enabled | Check rules and Anonymous Auth |
| Reports not persisted | Anonymous Auth disabled | Enable in Firebase Console → Authentication |
| Wrong platform config | `firebase_options.dart` out of date | Run `flutterfire configure` again |

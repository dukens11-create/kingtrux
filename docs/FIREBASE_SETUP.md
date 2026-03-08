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

## 6. Building Without Firebase Config Files

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

## 7. Firestore Collection & Document Schema

| Collection              | Field       | Type      | Description                              |
|-------------------------|-------------|-----------|------------------------------------------|
| `weigh_station_reports` | `stationId` | `string`  | Matches `WeighStation.id`                |
|                         | `status`    | `string`  | One of the values listed in §4           |
|                         | `timestamp` | Timestamp | Server timestamp (`FieldValue.serverTimestamp`) |
|                         | `userId`    | `string?` | Firebase anonymous UID (may be absent)   |

---

## 8. Local Development Without Real Config

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
| Build fails with "Google Services plugin requires…" | Missing `google-services.json` | Add the file or comment out the plugin |
| Status always shows Unknown | Firestore rules deny reads, or Auth not enabled | Check rules and Anonymous Auth |
| Reports not persisted | Anonymous Auth disabled | Enable in Firebase Console → Authentication |
| Wrong platform config | `firebase_options.dart` out of date | Run `flutterfire configure` again |

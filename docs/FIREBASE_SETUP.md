# Firebase Setup for Android CI

This document explains how to configure the `GOOGLE_SERVICES_JSON` repository
secret so that Android CI builds can use Firebase features.

## How it works

The Google Services Gradle plugin (`com.google.gms.google-services`) is applied
**conditionally** in `android/app/build.gradle`:

```groovy
if (file("google-services.json").exists()) {
    apply plugin: "com.google.gms.google-services"
}
```

This means:

- **When the secret is set**: `google-services.json` is written before the
  Gradle build runs → Firebase plugin activates → Firebase features work.
- **When the secret is absent** (e.g., PR builds, fork builds, Codemagic
  without the secret configured): `google-services.json` is not written → the
  plugin is skipped → the build succeeds with `FIREBASE_ENABLED=false` passed
  as a `--dart-define`.

## Setting the secret

### Step 1 — Download `google-services.json`

1. Open [Firebase Console](https://console.firebase.google.com/).
2. Go to **Project settings → Your apps → Android → com.kingtrux.app**.
3. Click **Download google-services.json**.

### Step 2 — Encode the file (choose one format)

**Option A — base64 (recommended)**

```bash
base64 -w 0 google-services.json
# On macOS:
base64 google-services.json | tr -d '\n'
```

Copy the output (a long single-line string — base64 output begins with various
characters depending on the file content).

**Option B — raw JSON**

You can also paste the raw contents of `google-services.json` directly as the
secret value. The injection script auto-detects which format was used.

### Step 3 — Add the repository secret

1. In your GitHub repository go to **Settings → Secrets and variables → Actions**.
2. Click **New repository secret**.
3. Name: `GOOGLE_SERVICES_JSON`
4. Value: the base64 string or raw JSON from Step 2.
5. Click **Add secret**.

## Secret format auto-detection

The workflow injection script detects the format automatically:

```bash
if echo "$GOOGLE_SERVICES_JSON" | grep -q '^{'; then
  # raw JSON — write directly
  echo "$GOOGLE_SERVICES_JSON" > android/app/google-services.json
else
  # base64 — decode first
  echo "$GOOGLE_SERVICES_JSON" | base64 --decode > android/app/google-services.json
fi
```

If neither format is valid (e.g., the secret is corrupted), the workflow prints
an actionable error message and fails immediately.

## Verification

After injection the workflow logs the file size (without exposing the contents):

```
google-services.json written (2048 bytes).
```

If the file is smaller than 10 bytes the workflow fails with:

```
ERROR: google-services.json is unexpectedly small — decode may have failed.
```

## Security notes

- `android/app/google-services.json` is listed in `.gitignore` and must
  **never** be committed to the repository.
- The raw contents of the secret are **never printed** in CI logs.
- Use `android/app/google-services.json.sample` as a template when setting up
  a new Firebase project.

# Contributing to KINGTRUX

Thank you for your interest in contributing to KINGTRUX! This guide covers how to set up your development environment and submit changes.

## Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (>=3.4.0)
- Android Studio or Xcode for mobile development
- Git

## Getting Started

1. Fork the repository and clone it locally.
2. Install dependencies:
   ```bash
   flutter pub get
   ```
3. Set up API keys using `--dart-define` at build/run time:
   ```bash
   flutter run \
     --dart-define=HERE_API_KEY=your_here_key \
     --dart-define=OPENWEATHER_API_KEY=your_openweather_key
   ```
4. For Android, add your Google Maps API key to `android/app/src/main/AndroidManifest.xml`.

## Running Tests

```bash
flutter test
```

## Code Style

- Follow the [Dart style guide](https://dart.dev/guides/language/effective-dart/style).
- Run the linter before submitting: `flutter analyze`.
- Keep widgets small and focused.
- Document public APIs with doc comments.

## Submitting Changes

1. Create a feature branch: `git checkout -b feature/my-feature`.
2. Make your changes and add tests where applicable.
3. Ensure all tests pass and the linter is clean.
4. Commit with a clear message describing what changed and why.
5. Open a pull request against `main` with a description of your changes.

## Reporting Issues

Please open a GitHub Issue and include:
- Steps to reproduce
- Expected vs. actual behavior
- Flutter version (`flutter --version`)
- Target platform (Android/iOS)

## Code of Conduct

This project follows a [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold it.

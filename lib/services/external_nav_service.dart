import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

import '../utils/external_navigation.dart';

/// Provides helpers for launching external turn-by-turn navigation apps.
///
/// Supports Google Maps (always available as a web fallback), Sygic Truck,
/// and Waze.  Each method first tries the native app URI scheme; if the app
/// is not installed it falls back to the Google Maps HTTPS URL so the user
/// always gets *some* navigation experience.
///
/// Caller responsibilities
/// -----------------------
/// - Wrap calls in try/catch and surface errors to the user if desired.
/// - On Android 11+, `AndroidManifest.xml` must include a `<queries>` element
///   listing the schemes used here so that `canLaunchUrl` works correctly.
class ExternalNavService {
  ExternalNavService._();

  // ── Google Maps ───────────────────────────────────────────────────────────

  /// Launches Google Maps turn-by-turn navigation to [destLat],[destLng].
  ///
  /// Uses the `google.navigation:` native URI on Android / iOS when the app
  /// is installed; falls back to the universal HTTPS Maps URL otherwise.
  ///
  /// Returns `true` if a URL was launched successfully.
  static Future<bool> openGoogleMaps({
    required double destLat,
    required double destLng,
  }) async {
    // Native app URI (Android + iOS Google Maps)
    final nativeUri = Uri.parse(
      'google.navigation:q=$destLat,$destLng&mode=d',
    );
    if (await canLaunchUrl(nativeUri)) {
      return launchUrl(nativeUri);
    }

    // Universal HTTPS fallback (opens in browser or Google Maps PWA)
    final webUri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        'destination': '$destLat,$destLng',
        'travelmode': 'driving',
      },
    );
    return launchUrl(webUri, mode: LaunchMode.externalApplication);
  }

  // ── Sygic Truck ───────────────────────────────────────────────────────────

  /// Launches Sygic Truck navigation to [destLat],[destLng] if installed.
  ///
  /// Returns `true` if launched, `false` if Sygic Truck is not installed.
  static Future<bool> openSygicTruck({
    required double destLat,
    required double destLng,
  }) async {
    // Sygic uses the `com.sygic.aura://` scheme.
    final uri = Uri.parse(
      'com.sygic.aura://coordinate|$destLng|$destLat|drive',
    );
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri);
    }
    return false;
  }

  // ── Waze ──────────────────────────────────────────────────────────────────

  /// Launches Waze navigation to [destLat],[destLng] if installed.
  ///
  /// Returns `true` if launched, `false` if Waze is not installed.
  static Future<bool> openWaze({
    required double destLat,
    required double destLng,
  }) async {
    final uri = Uri.parse(
      'waze://?ll=$destLat,$destLng&navigate=yes',
    );
    if (await canLaunchUrl(uri)) {
      return launchUrl(uri);
    }
    return false;
  }

  // ── Combined helper ───────────────────────────────────────────────────────

  /// Returns which external navigation apps are available on this device.
  ///
  /// The result is a list of [ExternalNavApp] values that can be used to
  /// populate a "Open in…" picker for the user.
  ///
  /// Google Maps is always included (via HTTPS fallback even when not
  /// installed natively).
  static Future<List<ExternalNavApp>> availableApps() async {
    final apps = <ExternalNavApp>[ExternalNavApp.googleMaps];

    final sygicUri = Uri.parse('com.sygic.aura://');
    if (await canLaunchUrl(sygicUri)) {
      apps.add(ExternalNavApp.sygicTruck);
    }

    final wazeUri = Uri.parse('waze://');
    if (await canLaunchUrl(wazeUri)) {
      apps.add(ExternalNavApp.waze);
    }

    return apps;
  }

  /// Launches the given [app] with the destination coordinates.
  ///
  /// Returns `true` if launched successfully.
  static Future<bool> launch({
    required ExternalNavApp app,
    required double destLat,
    required double destLng,
  }) {
    switch (app) {
      case ExternalNavApp.googleMaps:
        return openGoogleMaps(
          destLat: destLat,
          destLng: destLng,
        );
      case ExternalNavApp.sygicTruck:
        return openSygicTruck(destLat: destLat, destLng: destLng);
      case ExternalNavApp.waze:
        return openWaze(destLat: destLat, destLng: destLng);
    }
  }

  // ── System-chooser route handoff ─────────────────────────────────────────

  /// Hands off the full route to an external navigation app using the
  /// platform system chooser.
  ///
  /// **Android** – launches a Google Maps directions URL via
  /// [LaunchMode.externalApplication], which triggers the Android intent
  /// chooser so the user can pick Google Maps, Waze, or any other installed
  /// navigation app.
  ///
  /// **iOS** – first tries the native `maps://` scheme (Apple Maps); falls
  /// back to the Google Maps HTTPS URL if Apple Maps is not available.
  ///
  /// When [waypoints] is non-empty, all intermediate stops are included in
  /// the Google Maps URL in order (A→B→C).  Apple Maps does not support
  /// multi-stop routes via URL scheme, so only the final destination is sent
  /// on iOS.
  ///
  /// [originLat]/[originLng] are the driver's current GPS coordinates.
  /// When provided they are passed as the route origin so the external app
  /// starts from the same position as the in-app route.
  ///
  /// Returns `true` if a URL was launched successfully.
  static Future<bool> navigateWithRoute({
    required double destLat,
    required double destLng,
    double? originLat,
    double? originLng,
    List<({double lat, double lng})> waypoints = const [],
  }) async {
    // On iOS prefer Apple Maps (native maps:// scheme).
    if (!kIsWeb && Platform.isIOS) {
      final appleUri = ExternalNavigationUrl.appleMaps(
        destLat: destLat,
        destLng: destLng,
      );
      if (await canLaunchUrl(appleUri)) {
        return launchUrl(appleUri, mode: LaunchMode.externalApplication);
      }
    }

    // Android (and iOS fallback): Google Maps HTTPS URL.
    // LaunchMode.externalApplication on Android triggers the system intent
    // chooser, allowing the user to pick among installed navigation apps.
    final googleUri = ExternalNavigationUrl.googleMaps(
      destLat: destLat,
      destLng: destLng,
      originLat: originLat,
      originLng: originLng,
      waypoints: waypoints,
    );
    return launchUrl(googleUri, mode: LaunchMode.externalApplication);
  }
}

/// External navigation apps that [ExternalNavService] can launch.
enum ExternalNavApp {
  googleMaps,
  sygicTruck,
  waze;

  /// Human-readable display name shown in the "Open in…" picker.
  String get displayName {
    switch (this) {
      case ExternalNavApp.googleMaps:
        return 'Google Maps';
      case ExternalNavApp.sygicTruck:
        return 'Sygic Truck';
      case ExternalNavApp.waze:
        return 'Waze';
    }
  }
}

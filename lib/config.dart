/// Configuration constants for KINGTRUX application
class Config {
  /// HERE API key from environment variable (used for HERE Routing REST API v8).
  ///
  /// Pass at build/run time:
  ///   flutter run --dart-define=HERE_API_KEY=your_key
  ///
  /// Build fails with a runtime error (not compile-time) when this is empty.
  static const String hereApiKey = String.fromEnvironment('HERE_API_KEY', defaultValue: '');
  
  /// OpenWeather API key from environment variable
  static const String openWeatherApiKey = String.fromEnvironment('OPENWEATHER_API_KEY', defaultValue: '');
  
  /// HERE Navigate SDK – Access Key ID.
  ///
  /// Required when integrating the native HERE Navigate SDK (see
  /// HERE_NAVIGATE_SETUP.md). Pass at build/run time:
  ///   flutter run --dart-define=HERE_NAVIGATE_ACCESS_KEY_ID=your_key_id
  ///
  /// When empty the SDK init is skipped and the REST-API fallback is used.
  static const String hereNavigateAccessKeyId =
      String.fromEnvironment('HERE_NAVIGATE_ACCESS_KEY_ID', defaultValue: '');

  /// HERE Navigate SDK – Access Key Secret.
  ///
  /// Required when integrating the native HERE Navigate SDK.
  /// Pass at build/run time:
  ///   flutter run --dart-define=HERE_NAVIGATE_ACCESS_KEY_SECRET=your_secret
  static const String hereNavigateAccessKeySecret =
      String.fromEnvironment('HERE_NAVIGATE_ACCESS_KEY_SECRET', defaultValue: '');

  /// Overpass API base URL for OSM POI queries
  static const String overpassApiUrl = 'https://overpass-api.de/api/interpreter';
  
  /// HERE Routing API v8 base URL
  static const String hereRoutingBaseUrl = 'https://router.hereapi.com/v8';

  // ---------------------------------------------------------------------------
  // RevenueCat SDK keys
  // Pass via --dart-define at build/run time. See README for setup instructions.
  // ---------------------------------------------------------------------------

  /// RevenueCat public SDK key for iOS (Apple App Store).
  /// Obtain from the RevenueCat dashboard → Project → Apple → Public SDK key.
  static const String revenueCatIosApiKey =
      String.fromEnvironment('REVENUECAT_IOS_API_KEY', defaultValue: '');

  /// RevenueCat public SDK key for Android (Google Play).
  /// Obtain from the RevenueCat dashboard → Project → Google → Public SDK key.
  static const String revenueCatAndroidApiKey =
      String.fromEnvironment('REVENUECAT_ANDROID_API_KEY', defaultValue: '');

  // ---------------------------------------------------------------------------
  // In-app product identifiers (must match RevenueCat / App Store / Google Play)
  // ---------------------------------------------------------------------------

  /// Monthly subscription product ID.
  static const String productMonthly = 'kingtrux_pro_monthly';

  /// Yearly subscription product ID.
  static const String productYearly = 'kingtrux_pro_yearly';

  /// RevenueCat offering identifier.
  static const String offeringId = 'default';

  // ---------------------------------------------------------------------------
  // Paywall copy – Terms & Privacy URLs
  // TODO: Replace placeholder URLs with your real policy pages.
  // ---------------------------------------------------------------------------

  /// Terms of Service URL shown on the paywall.
  static const String termsUrl = 'https://kingtrux.com/terms';

  /// Privacy Policy URL shown on the paywall.
  static const String privacyUrl = 'https://kingtrux.com/privacy';
}

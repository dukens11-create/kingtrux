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
}

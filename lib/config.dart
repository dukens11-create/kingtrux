/// Configuration constants for the KINGTRUX application
class Config {
  Config._();

  /// HERE API key (set via --dart-define=HERE_API_KEY=xxx)
  static const String hereApiKey =
      String.fromEnvironment('HERE_API_KEY', defaultValue: '');

  /// OpenWeather API key (set via --dart-define=OPENWEATHER_API_KEY=xxx)
  static const String openWeatherApiKey =
      String.fromEnvironment('OPENWEATHER_API_KEY', defaultValue: '');

  /// Overpass API URL for fetching OpenStreetMap POIs
  static const String overpassApiUrl = 'https://overpass-api.de/api/interpreter';

  /// HERE Routing API v8 base URL
  static const String hereRoutingBaseUrl =
      'https://router.hereapi.com/v8/routes';
}

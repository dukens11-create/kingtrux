/// Configuration constants for KINGTRUX application
class Config {
  /// HERE API key from environment variable
  static const String hereApiKey = String.fromEnvironment('HERE_API_KEY', defaultValue: '');
  
  /// OpenWeather API key from environment variable
  static const String openWeatherApiKey = String.fromEnvironment('OPENWEATHER_API_KEY', defaultValue: '');
  
  /// Overpass API base URL for OSM POI queries
  static const String overpassApiUrl = 'https://overpass-api.de/api/interpreter';
  
  /// HERE Routing API v8 base URL
  static const String hereRoutingBaseUrl = 'https://router.hereapi.com/v8';
}

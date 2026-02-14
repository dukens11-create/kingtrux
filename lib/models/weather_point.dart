/// Weather information at a specific location
class WeatherPoint {
  /// Latitude
  final double lat;
  
  /// Longitude
  final double lng;
  
  /// Weather summary/description
  final String summary;
  
  /// Temperature in Celsius
  final double temperatureCelsius;
  
  /// Wind speed in m/s
  final double windSpeedMs;

  const WeatherPoint({
    required this.lat,
    required this.lng,
    required this.summary,
    required this.temperatureCelsius,
    required this.windSpeedMs,
  });
}

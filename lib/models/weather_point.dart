/// Weather point data
class WeatherPoint {
  final double lat;
  final double lng;
  final String summary;
  final double temperatureCelsius;
  final double windSpeedMs;

  const WeatherPoint({
    required this.lat,
    required this.lng,
    required this.summary,
    required this.temperatureCelsius,
    required this.windSpeedMs,
  });
}

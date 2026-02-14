import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/weather_point.dart';

/// Service for fetching weather data from OpenWeather API
class WeatherService {
  /// Fetch current weather at a location
  Future<WeatherPoint> fetchCurrentWeather({
    required double lat,
    required double lng,
  }) async {
    if (Config.openWeatherApiKey.isEmpty) {
      throw Exception('OpenWeather API key not configured');
    }

    final uri = Uri.parse('https://api.openweathermap.org/data/2.5/weather')
        .replace(queryParameters: {
      'lat': lat.toString(),
      'lon': lng.toString(),
      'appid': Config.openWeatherApiKey,
      'units': 'metric', // Metric units for temperature in Celsius
    });

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('OpenWeather API request failed with status ${response.statusCode}');
    }

    final data = json.decode(response.body);

    final weatherList = data['weather'] as List?;
    final summary = weatherList != null && weatherList.isNotEmpty
        ? (weatherList[0]['description'] as String? ?? 'Unknown')
        : 'Unknown';

    final main = data['main'] as Map<String, dynamic>?;
    final temp = (main?['temp'] as num?)?.toDouble() ?? 0.0;

    final wind = data['wind'] as Map<String, dynamic>?;
    final windSpeed = (wind?['speed'] as num?)?.toDouble() ?? 0.0;

    return WeatherPoint(
      lat: lat,
      lng: lng,
      summary: summary,
      temperatureCelsius: temp,
      windSpeedMs: windSpeed,
    );
  }
}

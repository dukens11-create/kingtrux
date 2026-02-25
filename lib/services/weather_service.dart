import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/weather_point.dart';
import '../models/weather_forecast.dart';

/// Service for fetching weather data from OpenWeather API
class WeatherService {
  /// Fetch current weather at a location
  /// Returns temperature in Celsius, weather summary, and wind speed in m/s
  Future<WeatherPoint> getCurrentWeather({
    required double lat,
    required double lng,
  }) async {
    if (Config.openWeatherApiKey.isEmpty) {
      throw Exception('OpenWeather API key not configured. Please set OPENWEATHER_API_KEY environment variable.');
    }

    final url = Uri.parse('https://api.openweathermap.org/data/2.5/weather').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lng.toString(),
        'appid': Config.openWeatherApiKey,
        'units': 'metric', // Use metric units
      },
    );

    final response = await http.get(url).timeout(
      const Duration(seconds: 30),
      onTimeout: () => throw Exception('OpenWeather API request timed out after 30 seconds'),
    );

    if (response.statusCode != 200) {
      throw Exception('OpenWeather API error: ${response.statusCode} - ${response.body}');
    }

    final data = json.decode(response.body);

    final weather = data['weather'] as List;
    final main = data['main'];
    final wind = data['wind'];

    if (weather.isEmpty) {
      throw Exception('No weather data available');
    }

    return WeatherPoint(
      lat: lat,
      lng: lng,
      summary: weather[0]['description'] ?? 'Unknown',
      temperatureCelsius: (main['temp'] as num).toDouble(),
      windSpeedMs: (wind['speed'] as num).toDouble(),
    );
  }

  /// Fetch hourly + daily forecast using the OpenWeather One Call API 3.0.
  ///
  /// Returns [null] when the API key is not configured so callers can display
  /// nothing rather than crashing.  Network / API errors are re-thrown so the
  /// caller can decide whether to surface an error state.
  Future<WeatherForecast?> getForecast({
    required double lat,
    required double lng,
  }) async {
    if (Config.openWeatherApiKey.isEmpty) {
      return null;
    }

    final url =
        Uri.parse('https://api.openweathermap.org/data/3.0/onecall').replace(
      queryParameters: {
        'lat': lat.toString(),
        'lon': lng.toString(),
        'appid': Config.openWeatherApiKey,
        'units': 'metric',
        'exclude': 'minutely,alerts',
      },
    );

    final response = await http.get(url).timeout(
      const Duration(seconds: 30),
      onTimeout: () =>
          throw Exception('OpenWeather One Call request timed out after 30 seconds'),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'OpenWeather One Call error: ${response.statusCode} - ${response.body}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    return WeatherForecast.fromJson(data);
  }
}

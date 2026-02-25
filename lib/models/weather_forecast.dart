/// A single hourly forecast slot returned by the OpenWeather One Call API.
class HourlyForecast {
  /// Unix timestamp (UTC) for this hour.
  final DateTime time;

  /// Temperature in Celsius.
  final double temperatureCelsius;

  /// Short weather summary (e.g. "light rain").
  final String summary;

  /// Wind speed in m/s (optional – may be absent on some API plans).
  final double? windSpeedMs;

  const HourlyForecast({
    required this.time,
    required this.temperatureCelsius,
    required this.summary,
    this.windSpeedMs,
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    final weatherList = json['weather'] as List<dynamic>? ?? [];
    final desc = weatherList.isNotEmpty
        ? (weatherList[0] as Map<String, dynamic>)['description'] as String? ?? ''
        : '';
    return HourlyForecast(
      time: DateTime.fromMillisecondsSinceEpoch(
          (json['dt'] as int) * 1000,
          isUtc: true),
      temperatureCelsius: (json['temp'] as num).toDouble(),
      summary: desc,
      windSpeedMs: json['wind_speed'] != null
          ? (json['wind_speed'] as num).toDouble()
          : null,
    );
  }
}

/// A single daily forecast slot returned by the OpenWeather One Call API.
class DailyForecast {
  /// Unix timestamp (UTC) for this day (noon).
  final DateTime time;

  /// Daytime high temperature in Celsius.
  final double highCelsius;

  /// Overnight low temperature in Celsius.
  final double lowCelsius;

  /// Short weather summary (e.g. "moderate rain").
  final String summary;

  const DailyForecast({
    required this.time,
    required this.highCelsius,
    required this.lowCelsius,
    required this.summary,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    final weatherList = json['weather'] as List<dynamic>? ?? [];
    final desc = weatherList.isNotEmpty
        ? (weatherList[0] as Map<String, dynamic>)['description'] as String? ?? ''
        : '';
    final temp = json['temp'] as Map<String, dynamic>;
    return DailyForecast(
      time: DateTime.fromMillisecondsSinceEpoch(
          (json['dt'] as int) * 1000,
          isUtc: true),
      highCelsius: (temp['max'] as num).toDouble(),
      lowCelsius: (temp['min'] as num).toDouble(),
      summary: desc,
    );
  }
}

/// Combined hourly + daily forecast for the navigation overlay.
class WeatherForecast {
  /// Hourly slots: "Now" + next ~3 hours (4 entries).
  final List<HourlyForecast> hourly;

  /// Daily slots: "Today" + next ~2 days (3 entries).
  final List<DailyForecast> daily;

  const WeatherForecast({required this.hourly, required this.daily});

  factory WeatherForecast.fromJson(Map<String, dynamic> json) {
    final rawHourly = (json['hourly'] as List<dynamic>? ?? [])
        .take(4)
        .map((e) => HourlyForecast.fromJson(e as Map<String, dynamic>))
        .toList();
    final rawDaily = (json['daily'] as List<dynamic>? ?? [])
        .take(3)
        .map((e) => DailyForecast.fromJson(e as Map<String, dynamic>))
        .toList();
    return WeatherForecast(hourly: rawHourly, daily: rawDaily);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/weather_forecast.dart';

void main() {
  // ---------------------------------------------------------------------------
  // HourlyForecast
  // ---------------------------------------------------------------------------
  group('HourlyForecast.fromJson', () {
    test('parses temperature, summary and wind speed', () {
      final json = {
        'dt': 1700000000,
        'temp': 14.5,
        'weather': [
          {'description': 'light rain'},
        ],
        'wind_speed': 3.2,
      };

      final h = HourlyForecast.fromJson(json);

      expect(h.temperatureCelsius, 14.5);
      expect(h.summary, 'light rain');
      expect(h.windSpeedMs, closeTo(3.2, 0.001));
      expect(
        h.time,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
      );
    });

    test('returns null windSpeedMs when field absent', () {
      final json = {
        'dt': 1700000000,
        'temp': 20.0,
        'weather': [
          {'description': 'clear sky'},
        ],
      };

      final h = HourlyForecast.fromJson(json);
      expect(h.windSpeedMs, isNull);
    });

    test('uses empty summary when weather list is empty', () {
      final json = {
        'dt': 1700000000,
        'temp': 5.0,
        'weather': <dynamic>[],
      };

      final h = HourlyForecast.fromJson(json);
      expect(h.summary, '');
    });
  });

  // ---------------------------------------------------------------------------
  // DailyForecast
  // ---------------------------------------------------------------------------
  group('DailyForecast.fromJson', () {
    test('parses high, low and summary', () {
      final json = {
        'dt': 1700000000,
        'temp': {'max': 22.0, 'min': 8.5},
        'weather': [
          {'description': 'moderate rain'},
        ],
      };

      final d = DailyForecast.fromJson(json);

      expect(d.highCelsius, 22.0);
      expect(d.lowCelsius, 8.5);
      expect(d.summary, 'moderate rain');
      expect(
        d.time,
        DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000, isUtc: true),
      );
    });

    test('handles missing weather description gracefully', () {
      final json = {
        'dt': 1700000000,
        'temp': {'max': 18.0, 'min': 6.0},
        'weather': [
          <String, dynamic>{},
        ],
      };

      final d = DailyForecast.fromJson(json);
      expect(d.summary, '');
    });
  });

  // ---------------------------------------------------------------------------
  // WeatherForecast
  // ---------------------------------------------------------------------------
  group('WeatherForecast.fromJson', () {
    final Map<String, dynamic> sampleJson = {
      'hourly': List.generate(
        8,
        (i) => {
          'dt': 1700000000 + i * 3600,
          'temp': 10.0 + i,
          'weather': [
            {'description': 'cloudy'},
          ],
          'wind_speed': 2.0,
        },
      ),
      'daily': List.generate(
        7,
        (i) => {
          'dt': 1700000000 + i * 86400,
          'temp': {'max': 20.0 + i, 'min': 8.0 + i},
          'weather': [
            {'description': 'sunny'},
          ],
        },
      ),
    };

    test('takes only first 4 hourly entries', () {
      final f = WeatherForecast.fromJson(sampleJson);
      expect(f.hourly.length, 4);
    });

    test('takes only first 3 daily entries', () {
      final f = WeatherForecast.fromJson(sampleJson);
      expect(f.daily.length, 3);
    });

    test('maps hourly temperatures in order', () {
      final f = WeatherForecast.fromJson(sampleJson);
      expect(f.hourly[0].temperatureCelsius, 10.0);
      expect(f.hourly[1].temperatureCelsius, 11.0);
      expect(f.hourly[3].temperatureCelsius, 13.0);
    });

    test('maps daily highs/lows in order', () {
      final f = WeatherForecast.fromJson(sampleJson);
      expect(f.daily[0].highCelsius, 20.0);
      expect(f.daily[1].lowCelsius, 9.0);
    });

    test('handles empty hourly and daily arrays', () {
      final f = WeatherForecast.fromJson({'hourly': [], 'daily': []});
      expect(f.hourly, isEmpty);
      expect(f.daily, isEmpty);
    });

    test('handles missing hourly and daily keys', () {
      final f = WeatherForecast.fromJson({});
      expect(f.hourly, isEmpty);
      expect(f.daily, isEmpty);
    });
  });
}

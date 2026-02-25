import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/alert_event.dart';
import 'package:kingtrux/services/trip_eta_service.dart';
import 'package:kingtrux/services/timezone_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // TripEtaService
  // ---------------------------------------------------------------------------
  group('TripEtaService.calculateEta', () {
    test('adds remaining seconds to now (UTC)', () {
      final now = DateTime.utc(2025, 6, 15, 12, 0, 0);
      final eta = TripEtaService.calculateEta(now, 3600);
      expect(eta, DateTime.utc(2025, 6, 15, 13, 0, 0));
    });

    test('zero remaining seconds returns now', () {
      final now = DateTime.utc(2025, 6, 15, 12, 0, 0);
      final eta = TripEtaService.calculateEta(now, 0);
      expect(eta, now);
    });

    test('handles multi-hour trips', () {
      final now = DateTime.utc(2025, 1, 10, 8, 0, 0);
      final eta = TripEtaService.calculateEta(now, 4 * 3600 + 30 * 60);
      expect(eta, DateTime.utc(2025, 1, 10, 12, 30, 0));
    });

    test('normalises non-UTC input to UTC before adding', () {
      // Providing a local DateTime: calculateEta calls .toUtc() internally.
      final local = DateTime(2025, 6, 15, 8, 0, 0); // local
      final eta = TripEtaService.calculateEta(local, 3600);
      expect(eta.isUtc, isTrue);
      // Result should be local.toUtc() + 1 h
      expect(eta, local.toUtc().add(const Duration(hours: 1)));
    });
  });

  group('TripEtaService.formatDuration', () {
    test('zero seconds → "0 min"', () {
      expect(TripEtaService.formatDuration(0), '0 min');
    });

    test('negative seconds → "0 min"', () {
      expect(TripEtaService.formatDuration(-60), '0 min');
    });

    test('less than one hour → minutes only', () {
      expect(TripEtaService.formatDuration(45 * 60), '45m');
    });

    test('exactly one hour → "1h"', () {
      expect(TripEtaService.formatDuration(3600), '1h');
    });

    test('hours and minutes', () {
      expect(TripEtaService.formatDuration(3 * 3600 + 22 * 60), '3h 22m');
    });

    test('exactly one minute', () {
      expect(TripEtaService.formatDuration(60), '1m');
    });
  });

  group('TripEtaService.formatWallClock', () {
    test('midnight formats as 12:00 AM', () {
      expect(
        TripEtaService.formatWallClock(DateTime(2025, 1, 1, 0, 0)),
        '12:00 AM',
      );
    });

    test('noon formats as 12:00 PM', () {
      expect(
        TripEtaService.formatWallClock(DateTime(2025, 1, 1, 12, 0)),
        '12:00 PM',
      );
    });

    test('3:22 PM', () {
      expect(
        TripEtaService.formatWallClock(DateTime(2025, 6, 15, 15, 22)),
        '3:22 PM',
      );
    });

    test('single-digit minute is zero-padded', () {
      expect(
        TripEtaService.formatWallClock(DateTime(2025, 6, 15, 9, 5)),
        '9:05 AM',
      );
    });
  });

  group('TripEtaService.estimateSecondsForDistance', () {
    test('65 mph over 65 miles ≈ 3600 seconds', () {
      final meters = 65.0 * 1609.344;
      final secs = TripEtaService.estimateSecondsForDistance(meters, 65.0);
      expect(secs, closeTo(3600, 2)); // within 2 seconds
    });

    test('zero distance returns 0', () {
      expect(TripEtaService.estimateSecondsForDistance(0, 65.0), 0);
    });

    test('zero speed returns 0', () {
      expect(TripEtaService.estimateSecondsForDistance(1000, 0), 0);
    });

    test('negative speed returns 0', () {
      expect(TripEtaService.estimateSecondsForDistance(1000, -10), 0);
    });

    test('higher speed produces shorter time', () {
      const meters = 100000.0;
      final slow = TripEtaService.estimateSecondsForDistance(meters, 55.0);
      final fast = TripEtaService.estimateSecondsForDistance(meters, 75.0);
      expect(fast, lessThan(slow));
    });
  });

  // ---------------------------------------------------------------------------
  // TimeZoneService
  // ---------------------------------------------------------------------------
  group('TimeZoneService.getAbbreviation', () {
    // Use a date firmly in summer DST (July).
    final summer = DateTime.utc(2025, 7, 15, 12, 0);
    // Use a date firmly in winter standard time (January).
    final winter = DateTime.utc(2025, 1, 15, 12, 0);

    test('Texas → CDT in summer', () {
      expect(TimeZoneService.getAbbreviation('TX', summer), 'CDT');
    });

    test('Texas → CST in winter', () {
      expect(TimeZoneService.getAbbreviation('TX', winter), 'CST');
    });

    test('New York → EDT in summer', () {
      expect(TimeZoneService.getAbbreviation('NY', summer), 'EDT');
    });

    test('New York → EST in winter', () {
      expect(TimeZoneService.getAbbreviation('NY', winter), 'EST');
    });

    test('California → PDT in summer', () {
      expect(TimeZoneService.getAbbreviation('CA', summer), 'PDT');
    });

    test('California → PST in winter', () {
      expect(TimeZoneService.getAbbreviation('CA', winter), 'PST');
    });

    test('Hawaii → HST year-round (no DST)', () {
      expect(TimeZoneService.getAbbreviation('HI', summer), 'HST');
      expect(TimeZoneService.getAbbreviation('HI', winter), 'HST');
    });

    test('case-insensitive: lowercase "tx"', () {
      expect(TimeZoneService.getAbbreviation('tx', summer), 'CDT');
    });

    test('unknown state code returns null', () {
      expect(TimeZoneService.getAbbreviation('ZZ', summer), isNull);
    });

    test('empty string returns null', () {
      expect(TimeZoneService.getAbbreviation('', summer), isNull);
    });
  });

  group('TimeZoneService.getUtcOffset', () {
    final summer = DateTime.utc(2025, 7, 15, 12, 0);
    final winter = DateTime.utc(2025, 1, 15, 12, 0);

    test('Eastern summer offset is -4h', () {
      expect(
        TimeZoneService.getUtcOffset('NY', summer),
        const Duration(hours: -4),
      );
    });

    test('Eastern winter offset is -5h', () {
      expect(
        TimeZoneService.getUtcOffset('NY', winter),
        const Duration(hours: -5),
      );
    });

    test('Central summer offset is -5h', () {
      expect(
        TimeZoneService.getUtcOffset('TX', summer),
        const Duration(hours: -5),
      );
    });

    test('Mountain summer offset is -6h', () {
      expect(
        TimeZoneService.getUtcOffset('CO', summer),
        const Duration(hours: -6),
      );
    });

    test('Pacific summer offset is -7h', () {
      expect(
        TimeZoneService.getUtcOffset('CA', summer),
        const Duration(hours: -7),
      );
    });

    test('Hawaii offset is -10h year-round', () {
      expect(
        TimeZoneService.getUtcOffset('HI', summer),
        const Duration(hours: -10),
      );
      expect(
        TimeZoneService.getUtcOffset('HI', winter),
        const Duration(hours: -10),
      );
    });

    test('Alaska DST offset is -8h', () {
      expect(
        TimeZoneService.getUtcOffset('AK', summer),
        const Duration(hours: -8),
      );
    });

    test('unknown state returns null', () {
      expect(TimeZoneService.getUtcOffset('ZZ', summer), isNull);
    });
  });

  group('TimeZoneService.isDst', () {
    test('July is DST', () {
      expect(TimeZoneService.isDst(DateTime.utc(2025, 7, 15)), isTrue);
    });

    test('January is not DST', () {
      expect(TimeZoneService.isDst(DateTime.utc(2025, 1, 15)), isFalse);
    });

    test('December is not DST', () {
      expect(TimeZoneService.isDst(DateTime.utc(2025, 12, 15)), isFalse);
    });

    test('April is DST', () {
      expect(TimeZoneService.isDst(DateTime.utc(2025, 4, 15)), isTrue);
    });

    test('November 1 before transition is DST', () {
      // First Sunday in November 2025 is Nov 2; Nov 1 is before the change.
      expect(TimeZoneService.isDst(DateTime.utc(2025, 11, 1, 0)), isTrue);
    });
  });

  group('TimeZoneService.toStateLocalTime', () {
    test('converts UTC to Eastern summer (UTC-4)', () {
      final utc = DateTime.utc(2025, 7, 15, 16, 0); // 4:00 PM UTC
      final summer = DateTime.utc(2025, 7, 15, 12, 0);
      final local = TimeZoneService.toStateLocalTime('NY', utc, summer);
      // Expected: 16:00 + (-4h) = 12:00 PM
      expect(local, isNotNull);
      expect(local!.hour, 12);
      expect(local.minute, 0);
    });

    test('returns null for unknown state', () {
      final utc = DateTime.utc(2025, 7, 15, 16, 0);
      expect(
        TimeZoneService.toStateLocalTime('ZZ', utc, utc),
        isNull,
      );
    });
  });

  group('TimeZoneService coverage: all 50 states + DC', () {
    const allStates = [
      'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
      'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
      'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
      'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
      'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
      'DC',
    ];
    final summer = DateTime.utc(2025, 7, 15, 12, 0);

    test('every state has a time zone region', () {
      for (final code in allStates) {
        expect(
          TimeZoneService.stateRegions.containsKey(code),
          isTrue,
          reason: '$code should be in stateRegions',
        );
      }
    });

    test('getAbbreviation returns non-null for every state', () {
      for (final code in allStates) {
        expect(
          TimeZoneService.getAbbreviation(code, summer),
          isNotNull,
          reason: '$code should have a TZ abbreviation',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // AlertType includes timeZoneCrossing
  // ---------------------------------------------------------------------------
  group('AlertType.timeZoneCrossing', () {
    test('enum value exists', () {
      expect(AlertType.values, contains(AlertType.timeZoneCrossing));
    });

    test('can construct an AlertEvent with timeZoneCrossing type', () {
      final alert = AlertEvent(
        id: 'tz_test',
        type: AlertType.timeZoneCrossing,
        title: 'Time Zone Change',
        message: 'Entering CDT',
        timestamp: DateTime.now(),
      );
      expect(alert.type, AlertType.timeZoneCrossing);
      expect(alert.title, 'Time Zone Change');
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/weigh_station.dart';
import 'package:kingtrux/services/weigh_station_monitor.dart';
import 'package:kingtrux/services/weigh_station_settings_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // WeighStationStatus enum
  // ---------------------------------------------------------------------------
  group('WeighStationStatus', () {
    test('firestoreValue round-trips via weighStationStatusFromFirestore', () {
      for (final s in WeighStationStatus.values) {
        final decoded = weighStationStatusFromFirestore(s.firestoreValue);
        expect(decoded, s,
            reason: 'Expected ${s.name} but got ${decoded.name}');
      }
    });

    test('unknown Firestore value maps to WeighStationStatus.unknown', () {
      expect(
        weighStationStatusFromFirestore('some_garbage'),
        WeighStationStatus.unknown,
      );
      expect(weighStationStatusFromFirestore(null), WeighStationStatus.unknown);
    });

    test('label is non-empty for all statuses', () {
      for (final s in WeighStationStatus.values) {
        expect(s.label, isNotEmpty);
      }
    });

    test('color is a valid Color for all statuses', () {
      for (final s in WeighStationStatus.values) {
        expect(s.color, isA<Color>());
      }
    });

    test('isActive is true only for enforcing statuses', () {
      expect(WeighStationStatus.openBypass.isActive, isTrue);
      expect(WeighStationStatus.openGoingThrough.isActive, isTrue);
      expect(WeighStationStatus.monitoring.isActive, isTrue);
      expect(WeighStationStatus.closed.isActive, isFalse);
      expect(WeighStationStatus.unknown.isActive, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // WeighStation model
  // ---------------------------------------------------------------------------
  group('WeighStation', () {
    const base = WeighStation(
      id: 'ws_test_1',
      name: 'Test Station',
      lat: 40.0,
      lng: -90.0,
      country: 'US',
      stateOrProvince: 'IL',
      highway: 'I-70',
    );

    test('equality is based on id', () {
      const other = WeighStation(
        id: 'ws_test_1',
        name: 'Other Name',
        lat: 0.0,
        lng: 0.0,
        country: 'CA',
      );
      expect(base, equals(other));
    });

    test('different ids are not equal', () {
      const other = WeighStation(
        id: 'ws_test_2',
        name: 'Test Station',
        lat: 40.0,
        lng: -90.0,
        country: 'US',
      );
      expect(base, isNot(equals(other)));
    });

    test('hashCode matches for equal objects', () {
      const same = WeighStation(
        id: 'ws_test_1',
        name: 'Something else',
        lat: 0,
        lng: 0,
        country: 'CA',
      );
      expect(base.hashCode, equals(same.hashCode));
    });

    test('distanceFromMeters returns 0 at same coordinates', () {
      final dist = base.distanceFromMeters(40.0, -90.0);
      expect(dist, closeTo(0.0, 0.01));
    });

    test('distanceFromMeters returns positive value for different point', () {
      // ~111 km per degree of latitude
      final dist = base.distanceFromMeters(41.0, -90.0);
      expect(dist, greaterThan(100000));
      expect(dist, lessThan(120000));
    });

    // ── Freshness ────────────────────────────────────────────────────────────

    test('isStale is true when statusUpdatedAt is null', () {
      expect(base.isStale, isTrue);
    });

    test('isStale is true when statusUpdatedAt is older than 60 minutes', () {
      final stale = base.copyWith(
        statusUpdatedAt:
            DateTime.now().subtract(const Duration(minutes: 61)),
        status: WeighStationStatus.openBypass,
      );
      expect(stale.isStale, isTrue);
    });

    test('isStale is false when statusUpdatedAt is recent', () {
      final fresh = base.copyWith(
        statusUpdatedAt:
            DateTime.now().subtract(const Duration(minutes: 30)),
        status: WeighStationStatus.openBypass,
      );
      expect(fresh.isStale, isFalse);
    });

    test('effectiveStatus returns unknown when stale', () {
      final stale = base.copyWith(
        statusUpdatedAt:
            DateTime.now().subtract(const Duration(minutes: 61)),
        status: WeighStationStatus.openBypass,
      );
      expect(stale.effectiveStatus, WeighStationStatus.unknown);
    });

    test('effectiveStatus returns stored status when fresh', () {
      final fresh = base.copyWith(
        statusUpdatedAt: DateTime.now(),
        status: WeighStationStatus.monitoring,
      );
      expect(fresh.effectiveStatus, WeighStationStatus.monitoring);
    });

    test('statusLabel reflects effectiveStatus (stale → Unknown)', () {
      final stale = base.copyWith(
        statusUpdatedAt:
            DateTime.now().subtract(const Duration(minutes: 90)),
        status: WeighStationStatus.closed,
      );
      expect(stale.statusLabel, 'Unknown');
    });

    test('copyWith overrides specified fields only', () {
      final updated = base.copyWith(
        status: WeighStationStatus.closed,
        statusUpdatedAt: DateTime.utc(2025, 1, 1),
        source: 'Crowdsourced',
      );
      expect(updated.id, base.id);
      expect(updated.name, base.name);
      expect(updated.status, WeighStationStatus.closed);
      expect(updated.source, 'Crowdsourced');
    });
  });

  // ---------------------------------------------------------------------------
  // WeighStationMonitor
  // ---------------------------------------------------------------------------
  group('WeighStationMonitor', () {
    late WeighStationMonitor monitor;

    setUp(() {
      monitor = WeighStationMonitor();
    });

    WeighStation _station({
      String id = 'ws_1',
      double lat = 40.0,
      double lng = -90.0,
      WeighStationStatus status = WeighStationStatus.unknown,
      DateTime? updatedAt,
    }) =>
        WeighStation(
          id: id,
          name: 'Test',
          lat: lat,
          lng: lng,
          country: 'US',
          status: status,
          statusUpdatedAt: updatedAt,
        );

    test('fires onNearbyStation when within threshold', () {
      WeighStation? fired;
      monitor.onNearbyStation = (s, _) => fired = s;

      monitor.update(
        lat: 40.0,
        lng: -90.0,
        stations: [_station()],
      );

      expect(fired, isNotNull);
    });

    test('does not fire when station is beyond threshold', () {
      var fired = false;
      monitor.onNearbyStation = (_, __) => fired = true;

      // 1 degree ≈ 111 km >> 1609 m default threshold
      monitor.update(
        lat: 41.0,
        lng: -90.0,
        stations: [_station()],
      );

      expect(fired, isFalse);
    });

    test('does not fire when enabled=false', () {
      var fired = false;
      monitor.onNearbyStation = (_, __) => fired = true;

      monitor.update(
        lat: 40.0,
        lng: -90.0,
        stations: [_station()],
        enabled: false,
      );

      expect(fired, isFalse);
    });

    test('fires alert at most once per station per session', () {
      var count = 0;
      monitor.onNearbyStation = (_, __) => count++;

      final s = _station();
      monitor.update(lat: 40.0, lng: -90.0, stations: [s]);
      monitor.update(lat: 40.0, lng: -90.0, stations: [s]);

      expect(count, 1);
    });

    test('reset allows alert to fire again', () {
      var count = 0;
      monitor.onNearbyStation = (_, __) => count++;

      final s = _station();
      monitor.update(lat: 40.0, lng: -90.0, stations: [s]);
      monitor.reset();
      monitor.update(lat: 40.0, lng: -90.0, stations: [s]);

      expect(count, 2);
    });

    test('does not alert for closed station', () {
      var fired = false;
      monitor.onNearbyStation = (_, __) => fired = true;

      monitor.update(
        lat: 40.0,
        lng: -90.0,
        stations: [_station(status: WeighStationStatus.closed)],
      );

      expect(fired, isFalse);
    });

    test('alerts for active statuses (fresh reports)', () {
      final activeStatuses = [
        WeighStationStatus.openBypass,
        WeighStationStatus.openGoingThrough,
        WeighStationStatus.monitoring,
      ];
      for (final status in activeStatuses) {
        monitor.reset();
        var fired = false;
        monitor.onNearbyStation = (_, __) => fired = true;

        monitor.update(
          lat: 40.0,
          lng: -90.0,
          stations: [
            _station(
              id: status.name,
              status: status,
              updatedAt: DateTime.now(),
            ),
          ],
        );

        expect(fired, isTrue,
            reason: 'Expected alert for ${status.name}');
      }
    });

    // ── Submission prompt (150-foot threshold) ────────────────────────────────

    test('fires onSubmissionPrompt when within 45.72 m', () {
      WeighStation? prompted;
      monitor.onSubmissionPrompt = (s) => prompted = s;

      monitor.update(
        lat: 40.0,
        lng: -90.0,
        stations: [_station()],
        submissionEnabled: true,
      );

      expect(prompted, isNotNull);
    });

    test('does not fire onSubmissionPrompt beyond 45.72 m', () {
      var prompted = false;
      monitor.onSubmissionPrompt = (_) => prompted = true;

      // Place station ~100 m away
      const deltaLat = 100.0 / 111000.0; // ~100 m in degrees
      monitor.update(
        lat: 40.0,
        lng: -90.0,
        stations: [_station(lat: 40.0 + deltaLat)],
        submissionEnabled: true,
      );

      expect(prompted, isFalse);
    });

    test('fires submission prompt at most once per station', () {
      var count = 0;
      monitor.onSubmissionPrompt = (_) => count++;

      final s = _station();
      monitor.update(
          lat: 40.0, lng: -90.0, stations: [s], submissionEnabled: true);
      monitor.update(
          lat: 40.0, lng: -90.0, stations: [s], submissionEnabled: true);

      expect(count, 1);
    });

    test('does not fire submission prompt when submissionEnabled=false', () {
      var prompted = false;
      monitor.onSubmissionPrompt = (_) => prompted = true;

      monitor.update(
        lat: 40.0,
        lng: -90.0,
        stations: [_station()],
        submissionEnabled: false,
      );

      expect(prompted, isFalse);
    });

    test('reset clears prompted set so prompt fires again', () {
      var count = 0;
      monitor.onSubmissionPrompt = (_) => count++;

      final s = _station();
      monitor.update(
          lat: 40.0, lng: -90.0, stations: [s], submissionEnabled: true);
      monitor.reset();
      monitor.update(
          lat: 40.0, lng: -90.0, stations: [s], submissionEnabled: true);

      expect(count, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // WeighStationSettings + WeighStationSettingsService
  // ---------------------------------------------------------------------------
  group('WeighStationSettings', () {
    test('defaults are correct', () {
      const settings = WeighStationSettings();
      expect(settings.showOnMap, isFalse);
      expect(settings.enableAlerts, isFalse);
      expect(settings.alertDistanceMeters,
          WeighStationMonitor.defaultThresholdMeters);
      expect(settings.alertOnUnknownStatus, isFalse);
      expect(settings.enableTts, isFalse);
      expect(settings.enableSubmissionPrompts, isFalse);
    });

    test('copyWith overrides only specified fields', () {
      const settings = WeighStationSettings();
      final updated = settings.copyWith(
        enableAlerts: true,
        enableSubmissionPrompts: true,
      );
      expect(updated.enableAlerts, isTrue);
      expect(updated.enableSubmissionPrompts, isTrue);
      expect(updated.enableTts, isFalse); // unchanged
    });
  });

  group('WeighStationSettingsService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns defaults when nothing persisted', () async {
      final service = WeighStationSettingsService();
      final settings = await service.load();
      expect(settings.showOnMap, isFalse);
      expect(settings.enableAlerts, isFalse);
      expect(settings.enableSubmissionPrompts, isFalse);
    });

    test('save and load round-trips all fields including showOnMap',
        () async {
      final service = WeighStationSettingsService();
      const toSave = WeighStationSettings(
        showOnMap: true,
        enableAlerts: false,
        alertDistanceMeters: 804.7,
        alertOnUnknownStatus: false,
        enableTts: false,
        enableSubmissionPrompts: false,
      );
      await service.save(toSave);
      final loaded = await service.load();
      expect(loaded.showOnMap, isTrue);
      expect(loaded.enableAlerts, isFalse);
      expect(loaded.alertDistanceMeters, closeTo(804.7, 0.01));
      expect(loaded.alertOnUnknownStatus, isFalse);
      expect(loaded.enableTts, isFalse);
      expect(loaded.enableSubmissionPrompts, isFalse);
    });
  });
}

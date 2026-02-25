import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/commercial_speed_settings.dart';
import 'package:kingtrux/services/commercial_speed_monitor.dart';
import 'package:kingtrux/services/speed_settings_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Unit conversions
  // ---------------------------------------------------------------------------
  group('CommercialSpeedSettings unit conversions', () {
    test('mphToMs converts correctly', () {
      expect(CommercialSpeedSettings.mphToMs(60.0), closeTo(26.8224, 0.001));
    });

    test('msToMph is inverse of mphToMs', () {
      const mph = 65.0;
      expect(
        CommercialSpeedSettings.msToMph(CommercialSpeedSettings.mphToMs(mph)),
        closeTo(mph, 0.001),
      );
    });

    test('kmhToMs converts correctly', () {
      expect(CommercialSpeedSettings.kmhToMs(100.0), closeTo(27.778, 0.001));
    });

    test('msToKmh is inverse of kmhToMs', () {
      const kmh = 100.0;
      expect(
        CommercialSpeedSettings.msToKmh(CommercialSpeedSettings.kmhToMs(kmh)),
        closeTo(kmh, 0.001),
      );
    });

    test('maxSpeedDisplay returns mph value when unit is mph', () {
      final s = CommercialSpeedSettings(
        enabled: true,
        maxSpeedMs: CommercialSpeedSettings.mphToMs(65.0),
        unit: SpeedUnit.mph,
      );
      expect(s.maxSpeedDisplay, closeTo(65.0, 0.001));
    });

    test('maxSpeedDisplay returns km/h value when unit is kmh', () {
      final s = CommercialSpeedSettings(
        enabled: true,
        maxSpeedMs: CommercialSpeedSettings.kmhToMs(100.0),
        unit: SpeedUnit.kmh,
      );
      expect(s.maxSpeedDisplay, closeTo(100.0, 0.001));
    });

    test('unitLabel returns "mph" for mph unit', () {
      final s = CommercialSpeedSettings.defaults();
      expect(s.unitLabel, 'mph');
    });

    test('unitLabel returns "km/h" for kmh unit', () {
      final s = CommercialSpeedSettings(
        enabled: false,
        maxSpeedMs: 30.0,
        unit: SpeedUnit.kmh,
      );
      expect(s.unitLabel, 'km/h');
    });

    test('defaults use mph and 65 mph threshold', () {
      final d = CommercialSpeedSettings.defaults();
      expect(d.unit, SpeedUnit.mph);
      expect(d.maxSpeedDisplay, closeTo(65.0, 0.001));
      expect(d.enabled, isFalse);
    });

    test('copyWith overrides only specified fields', () {
      final original = CommercialSpeedSettings.defaults();
      final copy = original.copyWith(enabled: true);
      expect(copy.enabled, isTrue);
      expect(copy.unit, original.unit);
      expect(copy.maxSpeedMs, original.maxSpeedMs);
    });
  });

  // ---------------------------------------------------------------------------
  // CommercialSpeedMonitor – overspeed detection and cooldown
  // ---------------------------------------------------------------------------
  group('CommercialSpeedMonitor', () {
    late CommercialSpeedMonitor monitor;

    setUp(() {
      monitor = CommercialSpeedMonitor(cooldownSeconds: 60);
    });

    const maxMs = 29.0576; // ≈ 65 mph

    test('no alert when not navigating', () {
      var fired = false;
      monitor.onOverspeed = (_, __) => fired = true;

      monitor.check(35.0, maxSpeedMs: maxMs, isNavigating: false);

      expect(fired, isFalse);
    });

    test('fires immediately on first overspeed while navigating', () {
      double? receivedSpeed;
      monitor.onOverspeed = (s, _) => receivedSpeed = s;

      monitor.check(35.0, maxSpeedMs: maxMs, isNavigating: true);

      expect(receivedSpeed, 35.0);
    });

    test('does not fire when speed is at or below threshold', () {
      var fired = false;
      monitor.onOverspeed = (_, __) => fired = true;

      monitor.check(maxMs, maxSpeedMs: maxMs, isNavigating: true);

      expect(fired, isFalse);
    });

    test('repeated overspeed does not re-fire within cooldown', () {
      var count = 0;
      monitor.onOverspeed = (_, __) => count++;

      monitor.check(35.0, maxSpeedMs: maxMs, isNavigating: true); // fires
      monitor.check(36.0, maxSpeedMs: maxMs, isNavigating: true); // suppressed

      expect(count, 1);
    });

    test('cooldown resets when speed drops below then exceeds threshold', () {
      var count = 0;
      monitor.onOverspeed = (_, __) => count++;

      monitor.check(35.0, maxSpeedMs: maxMs, isNavigating: true); // fires
      monitor.check(20.0, maxSpeedMs: maxMs, isNavigating: true); // under
      monitor.check(35.0, maxSpeedMs: maxMs, isNavigating: true); // fires again

      expect(count, 2);
    });

    test('no alert when not navigating even after previous overspeed', () {
      var count = 0;
      monitor.onOverspeed = (_, __) => count++;

      monitor.check(35.0, maxSpeedMs: maxMs, isNavigating: true); // fires
      monitor.check(20.0, maxSpeedMs: maxMs, isNavigating: false); // not navigating
      // Drops below threshold while not navigating → _wasOverspeed reset
      monitor.check(35.0, maxSpeedMs: maxMs, isNavigating: false); // not nav – no fire

      expect(count, 1);
    });

    test('fires after navigating resumes following speed drop', () {
      var count = 0;
      monitor.onOverspeed = (_, __) => count++;

      monitor.check(35.0, maxSpeedMs: maxMs, isNavigating: true); // fires
      monitor.check(20.0, maxSpeedMs: maxMs, isNavigating: false); // drops
      monitor.check(35.0, maxSpeedMs: maxMs, isNavigating: true); // fires again

      expect(count, 2);
    });

    test('reset clears state so first crossing fires again', () {
      var count = 0;
      monitor.onOverspeed = (_, __) => count++;

      monitor.check(35.0, maxSpeedMs: maxMs, isNavigating: true); // fires
      monitor.reset();
      monitor.check(35.0, maxSpeedMs: maxMs, isNavigating: true); // fires again

      expect(count, 2);
    });

    test('cooldown fires again after elapsed time', () {
      // Use a very short cooldown for this test.
      final shortMonitor = CommercialSpeedMonitor(cooldownSeconds: 0);
      var count = 0;
      shortMonitor.onOverspeed = (_, __) => count++;

      shortMonitor.check(35.0, maxSpeedMs: maxMs, isNavigating: true);
      shortMonitor.check(35.0, maxSpeedMs: maxMs, isNavigating: true);

      expect(count, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // SpeedSettingsService – commercial settings persistence round-trip
  // ---------------------------------------------------------------------------
  group('SpeedSettingsService commercial settings', () {
    late SpeedSettingsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = SpeedSettingsService();
    });

    test('returns defaults when nothing is persisted', () async {
      final settings = await service.loadCommercialSettings();
      final defaults = CommercialSpeedSettings.defaults();
      expect(settings.enabled, defaults.enabled);
      expect(settings.maxSpeedMs, closeTo(defaults.maxSpeedMs, 0.001));
      expect(settings.unit, defaults.unit);
    });

    test('saves and loads enabled flag', () async {
      final toSave = CommercialSpeedSettings(
        enabled: true,
        maxSpeedMs: CommercialSpeedSettings.mphToMs(65.0),
        unit: SpeedUnit.mph,
      );
      await service.saveCommercialSettings(toSave);
      final loaded = await service.loadCommercialSettings();
      expect(loaded.enabled, isTrue);
    });

    test('saves and loads max speed', () async {
      final ms = CommercialSpeedSettings.mphToMs(55.0);
      final toSave = CommercialSpeedSettings(
        enabled: false,
        maxSpeedMs: ms,
        unit: SpeedUnit.mph,
      );
      await service.saveCommercialSettings(toSave);
      final loaded = await service.loadCommercialSettings();
      expect(loaded.maxSpeedMs, closeTo(ms, 0.001));
    });

    test('saves and loads kmh unit', () async {
      final toSave = CommercialSpeedSettings(
        enabled: true,
        maxSpeedMs: CommercialSpeedSettings.kmhToMs(100.0),
        unit: SpeedUnit.kmh,
      );
      await service.saveCommercialSettings(toSave);
      final loaded = await service.loadCommercialSettings();
      expect(loaded.unit, SpeedUnit.kmh);
    });

    test('full round-trip preserves all fields', () async {
      final toSave = CommercialSpeedSettings(
        enabled: true,
        maxSpeedMs: CommercialSpeedSettings.kmhToMs(120.0),
        unit: SpeedUnit.kmh,
      );
      await service.saveCommercialSettings(toSave);
      final loaded = await service.loadCommercialSettings();
      expect(loaded.enabled, toSave.enabled);
      expect(loaded.maxSpeedMs, closeTo(toSave.maxSpeedMs, 0.001));
      expect(loaded.unit, toSave.unit);
    });

    test('overwrite replaces previous commercial settings', () async {
      await service.saveCommercialSettings(CommercialSpeedSettings(
        enabled: false,
        maxSpeedMs: CommercialSpeedSettings.mphToMs(60.0),
        unit: SpeedUnit.mph,
      ));
      final updated = CommercialSpeedSettings(
        enabled: true,
        maxSpeedMs: CommercialSpeedSettings.mphToMs(70.0),
        unit: SpeedUnit.mph,
      );
      await service.saveCommercialSettings(updated);
      final loaded = await service.loadCommercialSettings();
      expect(loaded.enabled, isTrue);
      expect(loaded.maxSpeedMs, closeTo(CommercialSpeedSettings.mphToMs(70.0), 0.001));
    });
  });
}

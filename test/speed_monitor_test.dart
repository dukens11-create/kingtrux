import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/services/speed_monitor.dart';
import 'package:kingtrux/services/speed_settings_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // SpeedMonitor
  // ---------------------------------------------------------------------------
  group('SpeedMonitor', () {
    late SpeedMonitor monitor;

    setUp(() {
      monitor = SpeedMonitor();
    });

    test('first update seeds state silently (no callback)', () {
      var fired = false;
      monitor.onStateChange = (_, __, ___) => fired = true;

      monitor.update(50.0, 55.0); // correct speed

      expect(fired, isFalse);
    });

    test('overspeed fires when speed exceeds limit + margin', () {
      SpeedAlertState? receivedState;
      monitor.onStateChange = (state, _, __) => receivedState = state;

      monitor.update(50.0, 55.0); // seeds as correct
      monitor.update(58.5, 55.0); // 58.5 > 55 + 2 → overSpeed

      expect(receivedState, SpeedAlertState.overSpeed);
    });

    test('underspeed fires when speed is below limit - margin', () {
      SpeedAlertState? receivedState;
      monitor.onStateChange = (state, _, __) => receivedState = state;

      monitor.update(50.0, 55.0); // seeds as correct
      monitor.update(44.0, 55.0); // 44 < 55 - 10 → underSpeed

      expect(receivedState, SpeedAlertState.underSpeed);
    });

    test('correct speed does not fire when already correct', () {
      var count = 0;
      monitor.onStateChange = (_, __, ___) => count++;

      monitor.update(50.0, 55.0); // seeds
      monitor.update(53.0, 55.0); // still correct

      expect(count, 0);
    });

    test('correct fires when recovering from overspeed', () {
      SpeedAlertState? receivedState;
      monitor.onStateChange = (state, _, __) => receivedState = state;

      monitor.update(58.5, 55.0); // seeds as overSpeed
      monitor.update(54.0, 55.0); // correct → fires

      expect(receivedState, SpeedAlertState.correct);
    });

    test('correct fires when recovering from underspeed', () {
      SpeedAlertState? receivedState;
      monitor.onStateChange = (state, _, __) => receivedState = state;

      monitor.update(40.0, 55.0); // seeds as underSpeed
      monitor.update(50.0, 55.0); // correct → fires

      expect(receivedState, SpeedAlertState.correct);
    });

    test('callback receives correct speed and limit values', () {
      double? cbSpeed;
      double? cbLimit;
      monitor.onStateChange = (_, s, l) {
        cbSpeed = s;
        cbLimit = l;
      };

      monitor.update(50.0, 55.0); // seeds
      monitor.update(60.0, 55.0); // overSpeed

      expect(cbSpeed, 60.0);
      expect(cbLimit, 55.0);
    });

    test('does not fire on subsequent updates with same state', () {
      var count = 0;
      monitor.onStateChange = (_, __, ___) => count++;

      monitor.update(60.0, 55.0); // seeds as overSpeed
      monitor.update(61.0, 55.0); // still overSpeed
      monitor.update(62.0, 55.0); // still overSpeed

      expect(count, 0);
    });

    test('reset allows re-seeding silently', () {
      var count = 0;
      monitor.onStateChange = (_, __, ___) => count++;

      monitor.update(60.0, 55.0); // seeds as overSpeed
      monitor.reset();
      monitor.update(60.0, 55.0); // re-seeds silently
      monitor.update(54.0, 55.0); // transition: overSpeed → correct → fires

      expect(count, 1);
    });

    test('speed exactly at limit + margin is NOT overspeeding', () {
      SpeedAlertState? receivedState;
      monitor.onStateChange = (state, _, __) => receivedState = state;

      monitor.update(50.0, 55.0); // seeds as correct
      monitor.update(57.0, 55.0); // 57 == 55 + 2 → still correct

      expect(receivedState, isNull);
    });

    test('speed just above limit + margin IS overspeeding', () {
      SpeedAlertState? receivedState;
      monitor.onStateChange = (state, _, __) => receivedState = state;

      monitor.update(50.0, 55.0); // seeds as correct
      monitor.update(57.1, 55.0); // 57.1 > 55 + 2 → overSpeed

      expect(receivedState, SpeedAlertState.overSpeed);
    });

    test('custom underspeedMarginMph is respected', () {
      monitor.underspeedMarginMph = 5.0;
      SpeedAlertState? receivedState;
      monitor.onStateChange = (state, _, __) => receivedState = state;

      monitor.update(50.0, 55.0); // seeds as correct
      monitor.update(49.0, 55.0); // 49 < 55 - 5 → underSpeed

      expect(receivedState, SpeedAlertState.underSpeed);
    });

    test('default margins match SpeedMonitor constants', () {
      expect(monitor.overspeedMarginMph, SpeedMonitor.defaultOverspeedMarginMph);
      expect(
          monitor.underspeedMarginMph, SpeedMonitor.defaultUnderspeedMarginMph);
    });
  });

  // ---------------------------------------------------------------------------
  // SpeedSettingsService
  // ---------------------------------------------------------------------------
  group('SpeedSettingsService', () {
    late SpeedSettingsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = SpeedSettingsService();
    });

    test('returns default when nothing is persisted', () async {
      final threshold = await service.loadUnderspeedThreshold();
      expect(threshold, SpeedSettingsService.defaultUnderspeedThresholdMph);
    });

    test('saves and loads threshold', () async {
      await service.saveUnderspeedThreshold(15.0);
      final loaded = await service.loadUnderspeedThreshold();
      expect(loaded, 15.0);
    });

    test('overwrite replaces previous value', () async {
      await service.saveUnderspeedThreshold(8.0);
      await service.saveUnderspeedThreshold(5.0);
      final loaded = await service.loadUnderspeedThreshold();
      expect(loaded, 5.0);
    });

    test('zero threshold is valid', () async {
      await service.saveUnderspeedThreshold(0.0);
      final loaded = await service.loadUnderspeedThreshold();
      expect(loaded, 0.0);
    });
  });
}

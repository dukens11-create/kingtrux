import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/alert_event.dart';
import 'package:kingtrux/state/app_state.dart';
import 'package:kingtrux/services/voice_settings_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // AlertEvent model
  // ---------------------------------------------------------------------------
  group('AlertEvent', () {
    test('constructs with required fields and correct defaults', () {
      final ts = DateTime.utc(2025, 1, 1, 12, 0);
      final event = AlertEvent(
        id: 'test_1',
        type: AlertType.reroute,
        title: 'Rerouting',
        message: 'A new route has been calculated.',
        timestamp: ts,
      );

      expect(event.id, 'test_1');
      expect(event.type, AlertType.reroute);
      expect(event.title, 'Rerouting');
      expect(event.severity, AlertSeverity.info);
      expect(event.speakable, isFalse);
      expect(event.timestamp, ts);
    });

    test('critical speakable alert stores all fields', () {
      final ts = DateTime(2025, 6, 15, 8, 30);
      final event = AlertEvent(
        id: 'crit_1',
        type: AlertType.offRoute,
        title: 'Off Route',
        message: 'Recalculating…',
        severity: AlertSeverity.critical,
        timestamp: ts,
        speakable: true,
      );

      expect(event.severity, AlertSeverity.critical);
      expect(event.speakable, isTrue);
      expect(event.timestamp, ts);
    });
  });

  // ---------------------------------------------------------------------------
  // AppState alert queue
  // ---------------------------------------------------------------------------
  group('AppState alert queue', () {
    late AppState state;

    setUp(() {
      state = AppState();
    });

    tearDown(() {
      state.dispose();
    });

    test('starts empty', () {
      expect(state.currentAlert, isNull);
      expect(state.alertQueue, isEmpty);
    });

    test('addAlert enqueues the alert', () {
      final alert = AlertEvent(
        id: 'a1',
        type: AlertType.navigationStarted,
        title: 'Navigation Started',
        message: 'Guidance is active.',
        timestamp: DateTime.now(),
      );
      state.addAlert(alert);

      expect(state.currentAlert, isNotNull);
      expect(state.currentAlert!.id, 'a1');
      expect(state.alertQueue.length, 1);
    });

    test('addAlert enqueues multiple alerts in order', () {
      final a1 = AlertEvent(
        id: 'first',
        type: AlertType.navigationStarted,
        title: 'Nav Started',
        message: '',
        timestamp: DateTime.now(),
      );
      final a2 = AlertEvent(
        id: 'second',
        type: AlertType.reroute,
        title: 'Reroute',
        message: '',
        timestamp: DateTime.now(),
      );

      state.addAlert(a1);
      state.addAlert(a2);

      expect(state.alertQueue.length, 2);
      expect(state.currentAlert!.id, 'first');
    });

    test('dismissCurrentAlert removes the front alert', () {
      state.addAlert(AlertEvent(
        id: 'x',
        type: AlertType.generic,
        title: 'X',
        message: '',
        timestamp: DateTime.now(),
      ));
      state.addAlert(AlertEvent(
        id: 'y',
        type: AlertType.generic,
        title: 'Y',
        message: '',
        timestamp: DateTime.now(),
      ));

      state.dismissCurrentAlert();

      expect(state.alertQueue.length, 1);
      expect(state.currentAlert!.id, 'y');
    });

    test('dismissCurrentAlert on empty queue is a no-op', () {
      expect(() => state.dismissCurrentAlert(), returnsNormally);
      expect(state.currentAlert, isNull);
    });

    test('alertQueue is unmodifiable', () {
      state.addAlert(AlertEvent(
        id: 'z',
        type: AlertType.generic,
        title: 'Z',
        message: '',
        timestamp: DateTime.now(),
      ));

      expect(
        () => state.alertQueue.add(AlertEvent(
          id: 'bad',
          type: AlertType.generic,
          title: '',
          message: '',
          timestamp: DateTime.now(),
        )),
        throwsUnsupportedError,
      );
    });

    test('notifyListeners is called when alert is added', () {
      var notified = false;
      state.addListener(() => notified = true);

      state.addAlert(AlertEvent(
        id: 'n1',
        type: AlertType.generic,
        title: 'N',
        message: '',
        timestamp: DateTime.now(),
      ));

      expect(notified, isTrue);
    });

    test('notifyListeners is called when alert is dismissed', () {
      state.addAlert(AlertEvent(
        id: 'n2',
        type: AlertType.generic,
        title: 'N',
        message: '',
        timestamp: DateTime.now(),
      ));

      var notified = false;
      state.addListener(() => notified = true);
      state.dismissCurrentAlert();

      expect(notified, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // VoiceSettingsService persistence
  // ---------------------------------------------------------------------------
  group('VoiceSettingsService', () {
    late VoiceSettingsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = VoiceSettingsService();
    });

    test('load returns defaults when nothing is persisted', () async {
      final settings = await service.load();
      expect(settings.enabled, isTrue);
      expect(settings.language, 'en-US');
    });

    test('saveEnabled persists the enabled flag', () async {
      await service.saveEnabled(false);
      final settings = await service.load();
      expect(settings.enabled, isFalse);
    });

    test('saveLanguage persists the language', () async {
      await service.saveLanguage('fr-CA');
      final settings = await service.load();
      expect(settings.language, 'fr-CA');
    });

    test('load falls back to en-US for unsupported language', () async {
      SharedPreferences.setMockInitialValues({
        'voice_guidance_language': 'de-DE',
      });
      final settings = await service.load();
      expect(settings.language, 'en-US');
    });

    test('round-trips enabled=true and language=es-US', () async {
      await service.saveEnabled(true);
      await service.saveLanguage('es-US');
      final settings = await service.load();
      expect(settings.enabled, isTrue);
      expect(settings.language, 'es-US');
    });
  });
}

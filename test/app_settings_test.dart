import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/app_settings.dart';
import 'package:kingtrux/models/alert_event.dart';
import 'package:kingtrux/state/app_state.dart';

void main() {
  // ---------------------------------------------------------------------------
  // VoiceLanguage enum
  // ---------------------------------------------------------------------------
  group('VoiceLanguage', () {
    test('fromTag returns correct enum values', () {
      expect(VoiceLanguage.fromTag('en-US'), VoiceLanguage.enUS);
      expect(VoiceLanguage.fromTag('en-CA'), VoiceLanguage.enCA);
      expect(VoiceLanguage.fromTag('fr-CA'), VoiceLanguage.frCA);
      expect(VoiceLanguage.fromTag('es-US'), VoiceLanguage.esUS);
    });

    test('fromTag returns enUS for unknown tag', () {
      expect(VoiceLanguage.fromTag('de-DE'), VoiceLanguage.enUS);
    });

    test('localeTag round-trips through fromTag', () {
      for (final lang in VoiceLanguage.values) {
        expect(VoiceLanguage.fromTag(lang.localeTag), lang);
      }
    });

    test('all values have non-empty displayName', () {
      for (final lang in VoiceLanguage.values) {
        expect(lang.displayName, isNotEmpty);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // AppSettings serialization
  // ---------------------------------------------------------------------------
  group('AppSettings serialization', () {
    test('defaults() returns voiceEnabled=true and en-US', () {
      final s = AppSettings.defaults();
      expect(s.voiceEnabled, isTrue);
      expect(s.voiceLanguage, VoiceLanguage.enUS);
    });

    test('toJson produces correct keys and values', () {
      const s = AppSettings(voiceEnabled: false, voiceLanguage: VoiceLanguage.frCA);
      final json = s.toJson();
      expect(json['voiceEnabled'], false);
      expect(json['voiceLanguage'], 'fr-CA');
    });

    test('fromJson reconstructs identical object', () {
      const original = AppSettings(
        voiceEnabled: false,
        voiceLanguage: VoiceLanguage.esUS,
      );
      final restored = AppSettings.fromJson(original.toJson());
      expect(restored.voiceEnabled, original.voiceEnabled);
      expect(restored.voiceLanguage, original.voiceLanguage);
    });

    test('round-trips through JSON string', () {
      const s = AppSettings(voiceEnabled: true, voiceLanguage: VoiceLanguage.enCA);
      final restored = AppSettings.fromJson(
        jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>,
      );
      expect(restored.voiceEnabled, s.voiceEnabled);
      expect(restored.voiceLanguage, s.voiceLanguage);
    });

    test('fromJson falls back to defaults for missing keys', () {
      final s = AppSettings.fromJson({});
      expect(s.voiceEnabled, isTrue);
      expect(s.voiceLanguage, VoiceLanguage.enUS);
    });

    test('copyWith only updates specified fields', () {
      const original = AppSettings(
        voiceEnabled: true,
        voiceLanguage: VoiceLanguage.frCA,
      );
      final updated = original.copyWith(voiceEnabled: false);
      expect(updated.voiceEnabled, false);
      expect(updated.voiceLanguage, VoiceLanguage.frCA); // unchanged
    });
  });

  // ---------------------------------------------------------------------------
  // AlertEvent model
  // ---------------------------------------------------------------------------
  group('AlertEvent', () {
    test('fields are stored correctly', () {
      final ts = DateTime(2025, 1, 15, 10, 0);
      final alert = AlertEvent(
        type: AlertType.offRoute,
        severity: AlertSeverity.warning,
        title: 'Off route',
        message: 'Recalculating…',
        timestamp: ts,
        speakable: true,
      );
      expect(alert.type, AlertType.offRoute);
      expect(alert.severity, AlertSeverity.warning);
      expect(alert.title, 'Off route');
      expect(alert.message, 'Recalculating…');
      expect(alert.timestamp, ts);
      expect(alert.speakable, isTrue);
    });

    test('speakable defaults to false', () {
      final alert = AlertEvent(
        type: AlertType.navigationStarted,
        severity: AlertSeverity.info,
        title: 'Started',
        message: '',
        timestamp: DateTime.now(),
      );
      expect(alert.speakable, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // AppState alert queue
  // ---------------------------------------------------------------------------
  group('AppState alert queue', () {
    AlertEvent _makeAlert(AlertType type) => AlertEvent(
          type: type,
          severity: AlertSeverity.info,
          title: type.name,
          message: '',
          timestamp: DateTime.now(),
        );

    test('currentAlert is null when queue is empty', () {
      final state = AppState();
      expect(state.currentAlert, isNull);
      state.dispose();
    });

    test('pushAlert makes alert available as currentAlert', () {
      final state = AppState();
      final alert = _makeAlert(AlertType.navigationStarted);
      state.pushAlert(alert);
      expect(state.currentAlert, alert);
      state.dispose();
    });

    test('dismissCurrentAlert removes the front alert', () {
      final state = AppState();
      state.pushAlert(_makeAlert(AlertType.navigationStarted));
      state.pushAlert(_makeAlert(AlertType.navigationStopped));

      expect(state.currentAlert?.type, AlertType.navigationStarted);
      state.dismissCurrentAlert();
      expect(state.currentAlert?.type, AlertType.navigationStopped);
      state.dismissCurrentAlert();
      expect(state.currentAlert, isNull);
      state.dispose();
    });

    test('dismissCurrentAlert on empty queue does not throw', () {
      final state = AppState();
      expect(() => state.dismissCurrentAlert(), returnsNormally);
      state.dispose();
    });

    test('alerts are queued in FIFO order', () {
      final state = AppState();
      final types = [
        AlertType.navigationStarted,
        AlertType.reroute,
        AlertType.offRoute,
      ];
      for (final t in types) {
        state.pushAlert(_makeAlert(t));
      }
      for (final t in types) {
        expect(state.currentAlert?.type, t);
        state.dismissCurrentAlert();
      }
      expect(state.currentAlert, isNull);
      state.dispose();
    });

    test('pushAlert notifies listeners', () {
      final state = AppState();
      var notified = false;
      state.addListener(() => notified = true);
      state.pushAlert(_makeAlert(AlertType.locationDisabled));
      expect(notified, isTrue);
      state.dispose();
    });

    test('dismissCurrentAlert notifies listeners', () {
      final state = AppState();
      state.pushAlert(_makeAlert(AlertType.navigationStarted));
      var notified = false;
      state.addListener(() => notified = true);
      state.dismissCurrentAlert();
      expect(notified, isTrue);
      state.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // AppState settings integration
  // ---------------------------------------------------------------------------
  group('AppState settings integration', () {
    test('default settings are applied without calling init()', () {
      final state = AppState();
      expect(state.settings.voiceEnabled, isTrue);
      expect(state.settings.voiceLanguage, VoiceLanguage.enUS);
      state.dispose();
    });

    test('voiceGuidanceEnabled getter reflects settings', () {
      final state = AppState();
      expect(state.voiceGuidanceEnabled, isTrue);
      state.toggleVoiceGuidance();
      expect(state.voiceGuidanceEnabled, isFalse);
      state.dispose();
    });

    test('voiceLanguage getter reflects settings locale tag', () {
      final state = AppState();
      state.setVoiceLanguage('fr-CA');
      expect(state.voiceLanguage, 'fr-CA');
      expect(state.settings.voiceLanguage, VoiceLanguage.frCA);
      state.dispose();
    });

    test('updateSettings replaces the entire settings object', () {
      final state = AppState();
      const newSettings = AppSettings(
        voiceEnabled: false,
        voiceLanguage: VoiceLanguage.esUS,
      );
      state.updateSettings(newSettings);
      expect(state.settings.voiceEnabled, isFalse);
      expect(state.settings.voiceLanguage, VoiceLanguage.esUS);
      state.dispose();
    });
  });
}

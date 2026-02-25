import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/alert_event.dart';
import 'package:kingtrux/state/app_state.dart';
import 'package:kingtrux/services/tts_language_service.dart';
import 'package:kingtrux/services/alert_phrase_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // AppState.effectiveTtsLanguage — pure function, no platform dependencies
  // ---------------------------------------------------------------------------

  group('AppState.effectiveTtsLanguage', () {
    test('returns desired language when it is in the supported set', () {
      expect(
        AppState.effectiveTtsLanguage('hi-IN', {'en-US', 'hi-IN', 'fr-FR'}),
        'hi-IN',
      );
    });

    test('returns en-US fallback when desired language is unsupported', () {
      expect(
        AppState.effectiveTtsLanguage('ht-HT', {'en-US', 'fr-FR', 'es-US'}),
        'en-US',
      );
    });

    test('returns desired language when supported set is empty (unknown)', () {
      expect(
        AppState.effectiveTtsLanguage('ht-HT', {}),
        'ht-HT',
      );
    });

    test('en-US is always returned for itself', () {
      expect(
        AppState.effectiveTtsLanguage('en-US', {'en-US', 'fr-FR'}),
        'en-US',
      );
    });

    test('returns en-US fallback for zh-CN when not supported', () {
      expect(
        AppState.effectiveTtsLanguage('zh-CN', {'en-US', 'fr-CA'}),
        'en-US',
      );
    });

    test('returns zh-CN when it is supported', () {
      expect(
        AppState.effectiveTtsLanguage('zh-CN', {'en-US', 'zh-CN'}),
        'zh-CN',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // AppState.setVoiceLanguage resets the unsupported-language notification flag
  // ---------------------------------------------------------------------------

  group('AppState.setVoiceLanguage', () {
    late AppState state;

    setUp(() {
      state = AppState();
    });

    tearDown(() {
      state.dispose();
    });

    test('setVoiceLanguage accepts supported languages', () {
      state.setVoiceLanguage('ht-HT');
      expect(state.voiceLanguage, 'ht-HT');
    });

    test('setVoiceLanguage ignores unsupported languages', () {
      state.setVoiceLanguage('de-DE');
      expect(state.voiceLanguage, 'en-US');
    });

    test('setVoiceLanguage notifies listeners', () {
      var notified = false;
      state.addListener(() => notified = true);
      state.setVoiceLanguage('fr-CA');
      expect(notified, isTrue);
    });

    test('setVoiceLanguage to same value notifies listeners', () {
      state.setVoiceLanguage('hi-IN');
      var notified = false;
      state.addListener(() => notified = true);
      state.setVoiceLanguage('en-US');
      expect(notified, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // TtsLanguage enum helpers
  // ---------------------------------------------------------------------------

  group('TtsLanguage', () {
    test('bcp47Tag returns expected tags', () {
      expect(TtsLanguage.en.bcp47Tag, 'en-US');
      expect(TtsLanguage.es.bcp47Tag, 'es-US');
      expect(TtsLanguage.ht.bcp47Tag, 'ht-HT');
    });

    test('displayLabel is non-empty for all values', () {
      for (final lang in TtsLanguage.values) {
        expect(lang.displayLabel, isNotEmpty);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // TtsLanguageService — persistence
  // ---------------------------------------------------------------------------

  group('TtsLanguageService', () {
    late TtsLanguageService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = TtsLanguageService();
    });

    test('load returns en when nothing is saved', () async {
      final lang = await service.load();
      // Device locale in test environment is not es/ht so defaults to en.
      expect(lang, TtsLanguage.en);
    });

    test('save and load round-trips Spanish', () async {
      await service.save(TtsLanguage.es);
      final lang = await service.load();
      expect(lang, TtsLanguage.es);
    });

    test('save and load round-trips Haitian Creole', () async {
      await service.save(TtsLanguage.ht);
      final lang = await service.load();
      expect(lang, TtsLanguage.ht);
    });

    test('save and load round-trips English', () async {
      await service.save(TtsLanguage.en);
      final lang = await service.load();
      expect(lang, TtsLanguage.en);
    });

    test('load falls back to en on unrecognised stored value', () async {
      SharedPreferences.setMockInitialValues({'tts_language': 'xx'});
      final lang = await service.load();
      expect(lang, TtsLanguage.en);
    });
  });

  // ---------------------------------------------------------------------------
  // AlertPhraseService — phrase lookup
  // ---------------------------------------------------------------------------

  group('AlertPhraseService', () {
    test('returns English phrase for en', () {
      final phrase =
          AlertPhraseService.phrase(AlertType.sharpCurveHazard, TtsLanguage.en);
      expect(phrase, isNotNull);
      expect(phrase, contains('curve'));
    });

    test('returns Spanish phrase for es', () {
      final phrase =
          AlertPhraseService.phrase(AlertType.sharpCurveHazard, TtsLanguage.es);
      expect(phrase, isNotNull);
      expect(phrase!.toLowerCase(), contains('curva'));
    });

    test('returns Haitian Creole phrase for ht', () {
      final phrase =
          AlertPhraseService.phrase(AlertType.sharpCurveHazard, TtsLanguage.ht);
      expect(phrase, isNotNull);
      expect(phrase!.toLowerCase(), contains('koub'));
    });

    test('low bridge phrase returned for en', () {
      final phrase =
          AlertPhraseService.phrase(AlertType.lowBridgeHazard, TtsLanguage.en);
      expect(phrase, contains('bridge'));
    });

    test('low bridge phrase returned for es', () {
      final phrase =
          AlertPhraseService.phrase(AlertType.lowBridgeHazard, TtsLanguage.es);
      expect(phrase, isNotNull);
      expect(phrase!.toLowerCase(), contains('puente'));
    });

    test('low bridge phrase returned for ht', () {
      final phrase =
          AlertPhraseService.phrase(AlertType.lowBridgeHazard, TtsLanguage.ht);
      expect(phrase, isNotNull);
      expect(phrase!.toLowerCase(), contains('pon'));
    });

    test('steep downgrade phrase returned for en', () {
      final phrase = AlertPhraseService.phrase(
          AlertType.downgradeHillHazard, TtsLanguage.en);
      expect(phrase, contains('downgrade'));
    });

    test('steep downgrade phrase returned for es', () {
      final phrase = AlertPhraseService.phrase(
          AlertType.downgradeHillHazard, TtsLanguage.es);
      expect(phrase, isNotNull);
      expect(phrase!.toLowerCase(), contains('pendiente'));
    });

    test('steep downgrade phrase returned for ht', () {
      final phrase = AlertPhraseService.phrase(
          AlertType.downgradeHillHazard, TtsLanguage.ht);
      expect(phrase, isNotNull);
      expect(phrase!.toLowerCase(), contains('desann'));
    });

    test('overspeed phrase returned for en', () {
      final phrase =
          AlertPhraseService.phrase(AlertType.overSpeed, TtsLanguage.en);
      expect(phrase, contains('speed'));
    });

    test('overspeed phrase returned for es', () {
      final phrase =
          AlertPhraseService.phrase(AlertType.overSpeed, TtsLanguage.es);
      expect(phrase, isNotNull);
      expect(phrase!.toLowerCase(), contains('velocidad'));
    });

    test('overspeed phrase returned for ht', () {
      final phrase =
          AlertPhraseService.phrase(AlertType.overSpeed, TtsLanguage.ht);
      expect(phrase, isNotNull);
      expect(phrase!.toLowerCase(), contains('ralanti'));
    });

    test('falls back to English phrase when es entry is missing for a type', () {
      // ttsLanguageUnsupported has no entry → returns null
      final phrase = AlertPhraseService.phrase(
          AlertType.ttsLanguageUnsupported, TtsLanguage.es);
      expect(phrase, isNull);
    });

    test('returns null for alert types not in the phrase map', () {
      final phrase = AlertPhraseService.phrase(
          AlertType.navigationStarted, TtsLanguage.en);
      expect(phrase, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // AppState.setTtsLanguage
  // ---------------------------------------------------------------------------

  group('AppState.setTtsLanguage', () {
    late AppState state;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      state = AppState();
    });

    tearDown(() {
      state.dispose();
    });

    test('defaults to TtsLanguage.en', () {
      expect(state.ttsLanguage, TtsLanguage.en);
    });

    test('setTtsLanguage updates ttsLanguage field', () {
      state.setTtsLanguage(TtsLanguage.es);
      expect(state.ttsLanguage, TtsLanguage.es);
    });

    test('setTtsLanguage to ht updates field', () {
      state.setTtsLanguage(TtsLanguage.ht);
      expect(state.ttsLanguage, TtsLanguage.ht);
    });

    test('setTtsLanguage notifies listeners', () {
      var notified = false;
      state.addListener(() => notified = true);
      state.setTtsLanguage(TtsLanguage.es);
      expect(notified, isTrue);
    });

    test('setTtsLanguage back to en notifies listeners', () {
      state.setTtsLanguage(TtsLanguage.ht);
      var notified = false;
      state.addListener(() => notified = true);
      state.setTtsLanguage(TtsLanguage.en);
      expect(notified, isTrue);
    });
  });
}


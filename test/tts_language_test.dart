import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/state/app_state.dart';

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
}

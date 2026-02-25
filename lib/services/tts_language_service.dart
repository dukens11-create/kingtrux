import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';

/// The three spoken-alert languages supported by KINGTRUX.
///
/// Maps to BCP-47 tags via [bcp47Tag].  When a device's TTS engine does not
/// support [ht] (Haitian Creole), the app automatically falls back to [en].
enum TtsLanguage {
  /// English (default).
  en,

  /// Spanish.
  es,

  /// Haitian Creole.
  ht,
}

extension TtsLanguageX on TtsLanguage {
  /// BCP-47 locale tag passed to the TTS engine for this language.
  String get bcp47Tag {
    switch (this) {
      case TtsLanguage.en:
        return 'en-US';
      case TtsLanguage.es:
        return 'es-US';
      case TtsLanguage.ht:
        return 'ht-HT';
    }
  }

  /// Human-readable display label shown in the settings UI.
  String get displayLabel {
    switch (this) {
      case TtsLanguage.en:
        return 'English';
      case TtsLanguage.es:
        return 'Español (Spanish)';
      case TtsLanguage.ht:
        return 'Kreyòl Ayisyen (Haitian Creole)';
    }
  }
}

/// Persists the user's chosen [TtsLanguage] to device storage.
///
/// When no value has been saved the device's system locale is examined: if it
/// matches Spanish (`es`) or Haitian Creole (`ht`) that language is used;
/// otherwise English is the default.
class TtsLanguageService {
  static const _key = 'tts_language';

  /// Load the persisted [TtsLanguage].
  ///
  /// Returns the device-locale default when no value has been saved, and falls
  /// back to [TtsLanguage.en] when the persisted value is unrecognised.
  Future<TtsLanguage> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw != null) {
        return TtsLanguage.values.firstWhere(
          (l) => l.name == raw,
          orElse: () => TtsLanguage.en,
        );
      }
    } catch (_) {}
    return _defaultFromLocale();
  }

  /// Persist [language] to device storage.
  Future<void> save(TtsLanguage language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, language.name);
  }

  /// Infer the best default from the device locale.
  ///
  /// Returns [TtsLanguage.es] for `es-*` locales, [TtsLanguage.ht] for `ht-*`
  /// locales, and [TtsLanguage.en] for everything else.
  static TtsLanguage _defaultFromLocale() {
    try {
      final locale = ui.PlatformDispatcher.instance.locale;
      final lang = locale.languageCode;
      if (lang == 'es') return TtsLanguage.es;
      if (lang == 'ht') return TtsLanguage.ht;
    } catch (_) {}
    return TtsLanguage.en;
  }
}

import 'package:shared_preferences/shared_preferences.dart';

/// Persists voice guidance settings (enabled flag and language) to device
/// storage via [SharedPreferences].
class VoiceSettingsService {
  static const _keyEnabled = 'voice_guidance_enabled';
  static const _keyLanguage = 'voice_guidance_language';

  /// BCP-47 language tags supported by KINGTRUX.
  static const List<String> _supportedLanguages = [
    'en-US',
    'en-CA',
    'fr-CA',
    'es-US',
  ];

  /// Load persisted voice settings.
  ///
  /// Returns defaults (enabled = true, language = 'en-US') when no saved
  /// values are found. An unsupported persisted language falls back to 'en-US'.
  Future<({bool enabled, String language})> load() async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool(_keyEnabled) ?? true;
    final language = prefs.getString(_keyLanguage) ?? 'en-US';
    final validLanguage =
        _supportedLanguages.contains(language) ? language : 'en-US';
    return (enabled: enabled, language: validLanguage);
  }

  /// Persist the voice guidance enabled flag.
  Future<void> saveEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, enabled);
  }

  /// Persist the selected voice language.
  Future<void> saveLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, language);
  }
}

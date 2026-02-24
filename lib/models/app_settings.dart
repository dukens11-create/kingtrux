/// Supported BCP-47 voice guidance locales.
enum VoiceLanguage {
  enUS('en-US', 'English (US)'),
  enCA('en-CA', 'English (Canada)'),
  frCA('fr-CA', 'Français (Canada)'),
  esUS('es-US', 'Español (US)');

  const VoiceLanguage(this.localeTag, this.displayName);

  /// BCP-47 locale tag.
  final String localeTag;

  /// Human-readable display name.
  final String displayName;

  /// Parse from a BCP-47 locale tag; returns [enUS] on unknown input.
  static VoiceLanguage fromTag(String tag) {
    return VoiceLanguage.values.firstWhere(
      (l) => l.localeTag == tag,
      orElse: () => VoiceLanguage.enUS,
    );
  }
}

/// Persisted application settings.
class AppSettings {
  /// Whether voice guidance is enabled.
  final bool voiceEnabled;

  /// Language used for voice guidance TTS.
  final VoiceLanguage voiceLanguage;

  const AppSettings({
    this.voiceEnabled = true,
    this.voiceLanguage = VoiceLanguage.enUS,
  });

  /// Returns the default settings instance.
  factory AppSettings.defaults() => const AppSettings();

  /// Deserialize from a JSON map.
  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      voiceEnabled: json['voiceEnabled'] as bool? ?? true,
      voiceLanguage: VoiceLanguage.fromTag(
        json['voiceLanguage'] as String? ?? 'en-US',
      ),
    );
  }

  /// Serialize to a JSON map.
  Map<String, dynamic> toJson() => {
        'voiceEnabled': voiceEnabled,
        'voiceLanguage': voiceLanguage.localeTag,
      };

  /// Return a copy with updated fields.
  AppSettings copyWith({
    bool? voiceEnabled,
    VoiceLanguage? voiceLanguage,
  }) {
    return AppSettings(
      voiceEnabled: voiceEnabled ?? this.voiceEnabled,
      voiceLanguage: voiceLanguage ?? this.voiceLanguage,
    );
  }
}

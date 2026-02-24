import '../models/app_settings.dart';

/// Abstract hook for voice guidance.
///
/// Implementations can delegate to Flutter TTS, the HERE Navigate voice
/// engine, or any other audio back-end. The [NoopVoiceGuidanceController]
/// provides a silent no-op default when no TTS engine is configured.
abstract class VoiceGuidanceController {
  /// Speak [text] using the language and enabled state from [settings].
  Future<void> speak(String text, AppSettings settings);

  /// Stop any ongoing speech immediately.
  Future<void> stop();
}

/// Silent no-op implementation used when no TTS engine is available.
class NoopVoiceGuidanceController implements VoiceGuidanceController {
  const NoopVoiceGuidanceController();

  @override
  Future<void> speak(String text, AppSettings settings) async {}

  @override
  Future<void> stop() async {}
}

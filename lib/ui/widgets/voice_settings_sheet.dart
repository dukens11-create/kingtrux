import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for configuring voice guidance settings.
///
/// Allows the driver to toggle voice guidance on/off and select a language
/// from [AppState.supportedVoiceLanguages].
class VoiceSettingsSheet extends StatelessWidget {
  const VoiceSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceMD,
              AppTheme.spaceSM,
              AppTheme.spaceMD,
              AppTheme.spaceMD,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    Icon(Icons.record_voice_over_rounded,
                        color: cs.primary, size: 28),
                    const SizedBox(width: AppTheme.spaceSM),
                    Text('Voice Guidance', style: tt.headlineSmall),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceMD),

                // Voice on/off toggle
                SwitchListTile(
                  secondary: Icon(
                    state.voiceGuidanceEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: cs.primary,
                  ),
                  title: const Text('Voice Guidance'),
                  subtitle: Text(
                    state.voiceGuidanceEnabled ? 'Enabled' : 'Disabled',
                  ),
                  value: state.voiceGuidanceEnabled,
                  onChanged: (_) {
                    HapticFeedback.selectionClick();
                    state.toggleVoiceGuidance();
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                const Divider(height: AppTheme.spaceLG),

                // Language selection
                Text('Guidance Language', style: tt.titleSmall),
                const SizedBox(height: AppTheme.spaceSM),

                ...AppState.supportedVoiceLanguages.map((lang) {
                  final isSelected = state.voiceLanguage == lang;
                  return RadioListTile<String>(
                    title: Text(_languageLabel(lang)),
                    subtitle: Text(lang),
                    value: lang,
                    groupValue: state.voiceLanguage,
                    onChanged: state.voiceGuidanceEnabled
                        ? (v) {
                            if (v != null) {
                              HapticFeedback.selectionClick();
                              state.setVoiceLanguage(v);
                            }
                          }
                        : null,
                    secondary: isSelected
                        ? Icon(Icons.check_circle_rounded, color: cs.primary)
                        : const Icon(Icons.radio_button_unchecked_rounded),
                    contentPadding: EdgeInsets.zero,
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Returns a human-readable label for a BCP-47 language tag.
  static String _languageLabel(String bcp47) {
    switch (bcp47) {
      case 'en-US':
        return 'English (US)';
      case 'en-CA':
        return 'English (Canada)';
      case 'fr-CA':
        return 'Français (Canada)';
      case 'es-US':
        return 'Español (US)';
      default:
        return bcp47;
    }
  }
}

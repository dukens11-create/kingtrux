import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../../services/night_mode_service.dart';
import '../theme/app_theme.dart';
import 'commercial_speed_settings_sheet.dart';

/// Bottom sheet for configuring voice guidance settings.
///
/// Allows the driver to toggle voice guidance on/off and select the
/// guidance language from the supported locales.
class VoiceSettingsSheet extends StatelessWidget {
  const VoiceSettingsSheet({super.key});

  static const Map<String, String> _languageLabels = {
    'en-US': 'English (US)',
    'en-CA': 'English (Canada)',
    'fr-CA': 'Français (Canada)',
    'es-US': 'Español (US)',
    'hi-IN': 'हिंदी (Hindi)',
    'ht-HT': 'Kreyòl Ayisyen (Haitian Creole)',
    'zh-CN': '中文 (Chinese Mandarin)',
  };

  static const Map<NightModeOption, String> _nightModeLabels = {
    NightModeOption.auto: 'Auto',
    NightModeOption.alwaysOn: 'Always On',
    NightModeOption.alwaysOff: 'Always Off',
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Consumer<AppState>(
      builder: (context, state, _) {
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
                    Text('Voice Settings', style: tt.headlineSmall),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSM),
                const Divider(),

                // Voice guidance toggle
                SwitchListTile(
                  secondary: Icon(
                    state.voiceGuidanceEnabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: state.voiceGuidanceEnabled
                        ? cs.primary
                        : cs.outline,
                  ),
                  title: const Text('Voice Guidance'),
                  subtitle: const Text('Spoken turn-by-turn instructions'),
                  value: state.voiceGuidanceEnabled,
                  onChanged: (_) {
                    HapticFeedback.selectionClick();
                    state.toggleVoiceGuidance();
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                const Divider(),
                const SizedBox(height: AppTheme.spaceXS),

                // Language selection
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Guidance Language', style: tt.bodyMedium),
                          Text(
                            'Language used for spoken instructions',
                            style: tt.bodySmall
                                ?.copyWith(color: cs.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                    DropdownButton<String>(
                      value: state.voiceLanguage,
                      underline: const SizedBox(),
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusMD),
                      items: AppState.supportedVoiceLanguages
                          .map(
                            (lang) => DropdownMenuItem(
                              value: lang,
                              child: Text(
                                _languageLabels[lang] ?? lang,
                                style: tt.bodyMedium,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: state.voiceGuidanceEnabled
                          ? (lang) {
                              if (lang != null) {
                                HapticFeedback.selectionClick();
                                state.setVoiceLanguage(lang);
                              }
                            }
                          : null,
                    ),
                  ],
                ),

                if (!state.voiceGuidanceEnabled) ...[
                  const SizedBox(height: AppTheme.spaceXS),
                  Text(
                    'Enable voice guidance to change language.',
                    style: tt.bodySmall
                        ?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],

                const SizedBox(height: AppTheme.spaceSM),
                const Divider(),

                // Night mode option
                Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: AppTheme.spaceXS),
                  child: Row(
                    children: [
                      Icon(Icons.nightlight_round, color: cs.primary),
                      const SizedBox(width: AppTheme.spaceSM),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Night Mode', style: tt.bodyMedium),
                            Text(
                              'Dims UI and map for night driving',
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                SegmentedButton<NightModeOption>(
                  segments: NightModeOption.values
                      .map(
                        (o) => ButtonSegment(
                          value: o,
                          label: Text(_nightModeLabels[o]!),
                        ),
                      )
                      .toList(),
                  selected: {state.nightModeOption},
                  onSelectionChanged: (selected) {
                    HapticFeedback.selectionClick();
                    state.setNightModeOption(selected.first);
                  },
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                ),

                const SizedBox(height: AppTheme.spaceSM),
                const Divider(),

                // Commercial speed alert shortcut
                ListTile(
                  leading: Icon(Icons.speed_rounded, color: cs.primary),
                  title: const Text('Commercial Speed Limit'),
                  subtitle: Text(
                    state.commercialSpeedSettings.enabled
                        ? 'Alert at ${state.commercialSpeedSettings.maxSpeedDisplay.toStringAsFixed(0)} ${state.commercialSpeedSettings.unitLabel}'
                        : 'Disabled',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) =>
                          const CommercialSpeedSettingsSheet(),
                    );
                  },
                ),

                const SizedBox(height: AppTheme.spaceMD),
              ],
            ),
          ),
        );
      },
    );
  }
}

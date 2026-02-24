import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/app_settings.dart';
import '../state/app_state.dart';
import 'theme/app_theme.dart';

/// A dedicated screen for managing app-wide settings.
///
/// Currently exposes:
/// - Voice guidance toggle (on/off)
/// - Voice language selection (en-US, en-CA, fr-CA, es-US)
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          return ListView(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            children: [
              // ── Voice guidance section ──────────────────────────────────
              Text(
                'Voice Guidance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppTheme.spaceSM),
              Card(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.record_voice_over_rounded),
                      title: const Text('Voice guidance'),
                      subtitle: const Text('Speak turn-by-turn instructions'),
                      value: state.settings.voiceEnabled,
                      onChanged: (_) => state.toggleVoiceGuidance(),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spaceMD,
                        AppTheme.spaceXS,
                        AppTheme.spaceMD,
                        AppTheme.spaceMD,
                      ),
                      child: DropdownButtonFormField<VoiceLanguage>(
                        decoration: const InputDecoration(
                          labelText: 'Voice language',
                          prefixIcon: Icon(Icons.language_rounded),
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: AppTheme.spaceMD,
                            vertical: AppTheme.spaceSM,
                          ),
                        ),
                        value: state.settings.voiceLanguage,
                        items: VoiceLanguage.values
                            .map(
                              (lang) => DropdownMenuItem(
                                value: lang,
                                child: Text(lang.displayName),
                              ),
                            )
                            .toList(),
                        onChanged: state.settings.voiceEnabled
                            ? (lang) {
                                if (lang != null) {
                                  state.setVoiceLanguage(lang.localeTag);
                                }
                              }
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

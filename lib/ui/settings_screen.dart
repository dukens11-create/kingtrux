import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
import '../services/weigh_station_settings_service.dart';
import '../services/weigh_station_monitor.dart';
import '../state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/voice_settings_sheet.dart';
import 'widgets/theme_settings_sheet.dart';

/// Full-page Settings screen accessible from the [MapScreen] AppBar.
///
/// Groups all configurable preferences in one place:
/// - Voice guidance settings
/// - Map style / color theme
/// - Distance units (metric / imperial)
/// - Weigh Station alerts and map overlay
/// - Send feedback
/// - Privacy Policy & Terms of Service
///
/// ## Adding your URLs
/// Update [Config.feedbackUrl], [Config.privacyUrl], and [Config.termsUrl]
/// with your real endpoints before publishing.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  // Distance constants (metres) used for alert-distance presets.
  // Derived from _metersPerMile to ensure consistency.
  static const double _metersPerMile = 1609.344;
  static const double _feetPerMile = 5280.0;
  static const double _halfMileMeters = _metersPerMile * 0.5; // ~804.7 m
  static const double _twoMilesMeters = _metersPerMile * 2.0; // ~3218.7 m
  static const double _fiveMilesMeters = _metersPerMile * 5.0; // ~8046.7 m

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: const BackButton(),
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          final cs = Theme.of(context).colorScheme;
          final tt = Theme.of(context).textTheme;
          final ws = state.weighStationSettings;
          return ListView(
            children: [
              // ── Voice ─────────────────────────────────────────────────────
              _SectionHeader(label: 'Navigation', cs: cs, tt: tt),
              ListTile(
                leading: Icon(Icons.record_voice_over_rounded, color: cs.primary),
                title: const Text('Voice Settings'),
                subtitle: Text(
                  state.voiceGuidanceEnabled
                      ? 'Guidance enabled · ${state.voiceLanguage}'
                      : 'Voice guidance disabled',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  HapticFeedback.selectionClick();
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const VoiceSettingsSheet(),
                  );
                },
              ),

              // ── Distance units ────────────────────────────────────────────
              ListTile(
                leading: Icon(Icons.speed_rounded, color: cs.primary),
                title: const Text('Distance Units'),
                subtitle: Text(state.useMetricUnits ? 'Kilometres' : 'Miles'),
                trailing: Switch(
                  value: state.useMetricUnits,
                  onChanged: (_) {
                    HapticFeedback.selectionClick();
                    state.toggleMetricUnits();
                  },
                ),
              ),

              const Divider(),

              // ── Weigh Stations ────────────────────────────────────────────
              _SectionHeader(label: 'Weigh Stations', cs: cs, tt: tt),
              SwitchListTile(
                secondary: Icon(
                  Icons.local_police_rounded,
                  color: cs.primary,
                ),
                title: const Text('Show on Map'),
                subtitle: const Text(
                  'Display weigh station markers on the map',
                ),
                value: ws.showOnMap,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  state.setWeighStationSettings(
                    ws.copyWith(showOnMap: value),
                  );
                },
              ),
              SwitchListTile(
                secondary: Icon(
                  Icons.notifications_active_rounded,
                  color: cs.primary,
                ),
                title: const Text('Proximity Alerts'),
                subtitle: const Text(
                  'Alert when approaching a weigh station',
                ),
                value: ws.enableAlerts,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  state.setWeighStationSettings(
                    ws.copyWith(enableAlerts: value),
                  );
                },
              ),

              const Divider(),

              // ── Appearance ────────────────────────────────────────────────
              _SectionHeader(label: 'Appearance', cs: cs, tt: tt),
              ListTile(
                leading: Icon(Icons.palette_rounded, color: cs.primary),
                title: const Text('Map Color Theme'),
                subtitle: const Text('Choose a preset or custom accent color'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  HapticFeedback.selectionClick();
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const ThemeSettingsSheet(),
                  );
                },
              ),

              const Divider(),

              // ── Weigh Station Alerts ──────────────────────────────────────
              _SectionHeader(label: 'Weigh Station Alerts', cs: cs, tt: tt),

              // Master enable / disable
              SwitchListTile(
                secondary: Icon(Icons.scale_rounded, color: cs.primary),
                title: const Text('Enable Proximity Alerts'),
                subtitle: const Text(
                  'Notify when approaching a weigh / inspection station',
                ),
                value: state.weighStationSettings.enableAlerts,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  state.setWeighStationSettings(
                    state.weighStationSettings
                        .copyWith(enableAlerts: value),
                  );
                },
              ),

              // Alert distance (only shown when alerts enabled)
              if (state.weighStationSettings.enableAlerts) ...[
                ListTile(
                  leading: Icon(
                    Icons.social_distance_rounded,
                    color: cs.primary,
                  ),
                  title: const Text('Alert Distance'),
                  subtitle: Text(
                    _alertDistanceLabel(
                      state.weighStationSettings.alertDistanceMeters,
                    ),
                  ),
                  trailing: DropdownButton<double>(
                    value: _nearestPreset(
                      state.weighStationSettings.alertDistanceMeters,
                    ),
                    underline: const SizedBox(),
                    items: const [
                      DropdownMenuItem(
                        value: _halfMileMeters,
                        child: Text('~0.5 mi'),
                      ),
                      DropdownMenuItem(
                        value: WeighStationMonitor.defaultThresholdMeters,
                        child: Text('~1 mi'),
                      ),
                      DropdownMenuItem(
                        value: _twoMilesMeters,
                        child: Text('~2 mi'),
                      ),
                      DropdownMenuItem(
                        value: _fiveMilesMeters,
                        child: Text('~5 mi'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      HapticFeedback.selectionClick();
                      state.setWeighStationSettings(
                        state.weighStationSettings
                            .copyWith(alertDistanceMeters: value),
                      );
                    },
                  ),
                ),

                // Alert when status unknown
                SwitchListTile(
                  secondary: Icon(
                    Icons.help_outline_rounded,
                    color: cs.primary,
                  ),
                  title: const Text('Alert on Unknown Status'),
                  subtitle: const Text(
                    'Notify even when enforcement status is unavailable',
                  ),
                  value: state.weighStationSettings.alertOnUnknownStatus,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    state.setWeighStationSettings(
                      state.weighStationSettings
                          .copyWith(alertOnUnknownStatus: value),
                    );
                  },
                ),

                // TTS
                SwitchListTile(
                  secondary: Icon(
                    Icons.volume_up_rounded,
                    color: cs.primary,
                  ),
                  title: const Text('Speak Alerts'),
                  subtitle: const Text(
                    'Announce weigh stations aloud via text-to-speech',
                  ),
                  value: state.weighStationSettings.enableTts,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    state.setWeighStationSettings(
                      state.weighStationSettings
                          .copyWith(enableTts: value),
                    );
                  },
                ),

                // Crowdsourcing prompts
                SwitchListTile(
                  secondary: Icon(
                    Icons.groups_rounded,
                    color: cs.primary,
                  ),
                  title: const Text('Status Submission Prompts'),
                  subtitle: const Text(
                    'Ask to report station status when within 150 ft',
                  ),
                  value:
                      state.weighStationSettings.enableSubmissionPrompts,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    state.setWeighStationSettings(
                      state.weighStationSettings
                          .copyWith(enableSubmissionPrompts: value),
                    );
                  },
                ),
              ],

              const Divider(),

              // ── Feedback & support ────────────────────────────────────────
              _SectionHeader(label: 'Support', cs: cs, tt: tt),
              ListTile(
                leading: Icon(Icons.feedback_rounded, color: cs.primary),
                title: const Text('Send Feedback'),
                subtitle: const Text('Report a bug or suggest a feature'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => _launchUrl(context, Config.feedbackUrl),
              ),

              const Divider(),

              // ── Legal ──────────────────────────────────────────────────────
              _SectionHeader(label: 'Legal', cs: cs, tt: tt),
              ListTile(
                leading: Icon(Icons.privacy_tip_rounded, color: cs.primary),
                title: const Text('Privacy Policy'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => _launchUrl(context, Config.privacyUrl),
              ),
              ListTile(
                leading: Icon(Icons.gavel_rounded, color: cs.primary),
                title: const Text('Terms of Service'),
                trailing: const Icon(Icons.open_in_new_rounded, size: 18),
                onTap: () => _launchUrl(context, Config.termsUrl),
              ),
              ListTile(
                leading: Icon(Icons.map_rounded, color: cs.primary),
                title: const Text('Map Data'),
                subtitle: const Text(
                  'Map tiles © Google Maps. '
                  'POI data © OpenStreetMap contributors (ODbL).',
                ),
              ),

              const SizedBox(height: AppTheme.spaceLG),
            ],
          );
        },
      ),
    );
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    HapticFeedback.selectionClick();
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open $url')),
        );
      }
    }
  }

  /// Human-readable alert distance label.
  static String _alertDistanceLabel(double meters) {
    final mi = meters / _metersPerMile;
    final km = meters / 1000;
    if (mi < 1) return '${(mi * _feetPerMile).round()} ft  (${km.toStringAsFixed(1)} km)';
    return '${mi.toStringAsFixed(1)} mi  (${km.toStringAsFixed(1)} km)';
  }

  /// Snap [meters] to the nearest preset distance option.
  static double _nearestPreset(double meters) {
    const presets = [
      _halfMileMeters,
      WeighStationMonitor.defaultThresholdMeters,
      _twoMilesMeters,
      _fiveMilesMeters,
    ];
    return presets.reduce(
      (a, b) => (a - meters).abs() < (b - meters).abs() ? a : b,
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.label,
    required this.cs,
    required this.tt,
  });

  final String label;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTheme.spaceMD,
        AppTheme.spaceMD,
        AppTheme.spaceMD,
        AppTheme.spaceXS,
      ),
      child: Text(
        label.toUpperCase(),
        style: tt.labelSmall?.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

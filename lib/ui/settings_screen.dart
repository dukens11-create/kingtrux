import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config.dart';
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
                value: ws.alertsEnabled,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  state.setWeighStationSettings(
                    ws.copyWith(alertsEnabled: value),
                  );
                },
              ),
              if (ws.alertsEnabled)
                ListTile(
                  leading: Icon(
                    Icons.social_distance_rounded,
                    color: cs.primary,
                  ),
                  title: const Text('Alert Distance'),
                  subtitle: Text(
                    _formatThreshold(ws.alertThresholdMeters,
                        state.useMetricUnits),
                  ),
                  trailing: DropdownButton<double>(
                    value: _nearestOption(ws.alertThresholdMeters),
                    underline: const SizedBox.shrink(),
                    items: _thresholdOptions(state.useMetricUnits),
                    onChanged: (value) {
                      if (value == null) return;
                      HapticFeedback.selectionClick();
                      state.setWeighStationSettings(
                        ws.copyWith(alertThresholdMeters: value),
                      );
                    },
                  ),
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

  /// Available alert distance options in metres.
  static const _thresholdValues = [1609.0, 3219.0, 4828.0, 8047.0, 16093.0];

  /// Returns the closest option to [current] in [_thresholdValues].
  static double _nearestOption(double current) {
    return _thresholdValues.reduce(
      (a, b) => (a - current).abs() < (b - current).abs() ? a : b,
    );
  }

  static String _formatThreshold(double meters, bool metric) {
    if (metric) {
      final km = (meters / 1000).toStringAsFixed(1);
      return '$km km';
    } else {
      final mi = (meters / 1609.34).toStringAsFixed(1);
      return '$mi mi';
    }
  }

  static List<DropdownMenuItem<double>> _thresholdOptions(bool metric) {
    return _thresholdValues
        .map(
          (v) => DropdownMenuItem(
            value: v,
            child: Text(_formatThreshold(v, metric)),
          ),
        )
        .toList();
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

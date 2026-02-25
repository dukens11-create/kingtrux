import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Bottom sheet allowing drivers to control which road-sign alert types are
/// enabled and how they are notified (visual + optional TTS).
class RoadSignAlertSettingsSheet extends StatelessWidget {
  const RoadSignAlertSettingsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final hs = state.hazardSettings;
        final cs = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        return SafeArea(
          child: SingleChildScrollView(
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
                // Header
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: cs.tertiary),
                    const SizedBox(width: AppTheme.spaceSM),
                    Text(
                      'Road Sign Alerts',
                      style: tt.headlineSmall,
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceXS),
                Text(
                  'Choose which signs trigger alerts during navigation.',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                ),
                const Divider(height: AppTheme.spaceLG),

                // ── Notification mode ──────────────────────────────────────
                Text('Notification Mode', style: tt.titleSmall),
                SwitchListTile(
                  secondary: Icon(Icons.record_voice_over_rounded,
                      color: cs.primary),
                  title: const Text('Spoken Alerts (TTS)'),
                  subtitle: const Text(
                      'Read alerts aloud when voice guidance is on'),
                  value: hs.enableHazardTts,
                  onChanged: (v) {
                    HapticFeedback.selectionClick();
                    state.setHazardSettings(
                        hs.copyWith(enableHazardTts: v));
                  },
                  contentPadding: EdgeInsets.zero,
                ),
                const Divider(height: AppTheme.spaceLG),

                // ── Road sign types ────────────────────────────────────────
                Text('Alert Types', style: tt.titleSmall),
                const SizedBox(height: AppTheme.spaceXS),

                _SignTile(
                  icon: Icons.local_shipping_rounded,
                  title: 'Truck Crossing',
                  value: hs.enableTruckCrossingWarnings,
                  onChanged: (v) => state.setHazardSettings(
                      hs.copyWith(enableTruckCrossingWarnings: v)),
                ),
                _SignTile(
                  icon: Icons.pets_rounded,
                  title: 'Wild Animal Crossing',
                  subtitle: 'Deer, cattle, moose, etc.',
                  value: hs.enableWildAnimalCrossingWarnings,
                  onChanged: (v) => state.setHazardSettings(
                      hs.copyWith(enableWildAnimalCrossingWarnings: v)),
                ),
                _SignTile(
                  icon: Icons.school_rounded,
                  title: 'School Zone / Crosswalk',
                  value: hs.enableSchoolZoneWarnings,
                  onChanged: (v) => state.setHazardSettings(
                      hs.copyWith(enableSchoolZoneWarnings: v)),
                ),
                _SignTile(
                  icon: Icons.stop_circle_outlined,
                  title: 'Stop Sign',
                  value: hs.enableStopSignWarnings,
                  onChanged: (v) => state.setHazardSettings(
                      hs.copyWith(enableStopSignWarnings: v)),
                ),
                _SignTile(
                  icon: Icons.train_rounded,
                  title: 'Railroad / Train Crossing',
                  value: hs.enableRailroadCrossingWarnings,
                  onChanged: (v) => state.setHazardSettings(
                      hs.copyWith(enableRailroadCrossingWarnings: v)),
                ),
                _SignTile(
                  icon: Icons.trending_down_rounded,
                  title: 'Steep Grade / Hill',
                  value: hs.enableDowngradeHillWarnings,
                  onChanged: (v) => state.setHazardSettings(
                      hs.copyWith(enableDowngradeHillWarnings: v)),
                ),
                _SignTile(
                  icon: Icons.turn_sharp_left_rounded,
                  title: 'Sharp Curve',
                  value: hs.enableSharpCurveWarnings,
                  onChanged: (v) => state.setHazardSettings(
                      hs.copyWith(enableSharpCurveWarnings: v)),
                ),
                _SignTile(
                  icon: Icons.water_rounded,
                  title: 'Slippery Road',
                  value: hs.enableSlipperyRoadWarnings,
                  onChanged: (v) => state.setHazardSettings(
                      hs.copyWith(enableSlipperyRoadWarnings: v)),
                ),
                _SignTile(
                  icon: Icons.merge_rounded,
                  title: 'Merging Traffic',
                  value: hs.enableMergingTrafficWarnings,
                  onChanged: (v) => state.setHazardSettings(
                      hs.copyWith(enableMergingTrafficWarnings: v)),
                ),
                _SignTile(
                  icon: Icons.landslide_rounded,
                  title: 'Falling Rocks',
                  value: hs.enableFallingRocksWarnings,
                  onChanged: (v) => state.setHazardSettings(
                      hs.copyWith(enableFallingRocksWarnings: v)),
                ),
                _SignTile(
                  icon: Icons.width_normal_rounded,
                  title: 'Narrow Bridge',
                  value: hs.enableNarrowBridgeWarnings,
                  onChanged: (v) => state.setHazardSettings(
                      hs.copyWith(enableNarrowBridgeWarnings: v)),
                ),
                _SignTile(
                  icon: Icons.height_rounded,
                  title: 'Low Bridge / Height Restriction',
                  value: hs.enableLowBridgeWarnings,
                  onChanged: (v) => state.setHazardSettings(
                      hs.copyWith(enableLowBridgeWarnings: v)),
                ),
                _SignTile(
                  icon: Icons.construction_rounded,
                  title: 'Work Zone',
                  value: hs.enableWorkZoneWarnings,
                  onChanged: (v) => state.setHazardSettings(
                      hs.copyWith(enableWorkZoneWarnings: v)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SignTile extends StatelessWidget {
  const _SignTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SwitchListTile(
      secondary: Icon(icon, color: cs.primary),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      value: value,
      onChanged: (v) {
        HapticFeedback.selectionClick();
        onChanged(v);
      },
      contentPadding: EdgeInsets.zero,
    );
  }
}

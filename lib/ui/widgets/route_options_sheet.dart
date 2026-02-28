import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/toll_preference.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import 'truck_profile_sheet.dart';

/// Bottom sheet that exposes truck-first route options:
/// - Avoid tolls (maps to existing [TollPreference])
/// - Avoid ferries
/// - Avoid unpaved / dirt roads
/// - Hazmat status (read from truck profile, links to Truck Profile sheet)
///
/// Preferences are persisted between sessions automatically.
class RouteOptionsSheet extends StatelessWidget {
  const RouteOptionsSheet({super.key});

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
                // ── Title ───────────────────────────────────────────────────
                Row(
                  children: [
                    Icon(Icons.tune_rounded, color: cs.primary, size: 28),
                    const SizedBox(width: AppTheme.spaceSM),
                    Text('Route Options', style: tt.headlineSmall),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSM),
                const Divider(),

                // ── Avoid tolls ─────────────────────────────────────────────
                SwitchListTile(
                  secondary: Icon(Icons.toll_rounded,
                      color: state.tollPreference == TollPreference.tollFree
                          ? cs.primary
                          : cs.outline),
                  title: const Text('Avoid Tolls'),
                  subtitle: const Text('Request routes without toll roads'),
                  value: state.tollPreference == TollPreference.tollFree,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    state.setTollPreference(
                      value ? TollPreference.tollFree : TollPreference.any,
                    );
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                // ── Avoid ferries ───────────────────────────────────────────
                SwitchListTile(
                  secondary: Icon(Icons.directions_boat_rounded,
                      color:
                          state.avoidFerries ? cs.primary : cs.outline),
                  title: const Text('Avoid Ferries'),
                  subtitle: const Text('Exclude ferry crossings from route'),
                  value: state.avoidFerries,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    state.setAvoidFerries(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                // ── Avoid unpaved ───────────────────────────────────────────
                SwitchListTile(
                  secondary: Icon(Icons.terrain_rounded,
                      color:
                          state.avoidUnpaved ? cs.primary : cs.outline),
                  title: const Text('Avoid Unpaved Roads'),
                  subtitle: const Text('Exclude dirt and gravel roads'),
                  value: state.avoidUnpaved,
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    state.setAvoidUnpaved(value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                const Divider(),

                // ── Hazmat (mirrors truck profile) ──────────────────────────
                ListTile(
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: state.truckProfile.hazmat
                        ? cs.error
                        : cs.outline,
                  ),
                  title: const Text('Hazmat'),
                  subtitle: Text(
                    state.truckProfile.hazmat
                        ? 'Hazardous materials declared — routing restricted roads'
                        : 'No hazardous materials declared',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  contentPadding: EdgeInsets.zero,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const TruckProfileSheet(),
                    );
                  },
                ),

                const SizedBox(height: AppTheme.spaceSM),
              ],
            ),
          ),
        );
      },
    );
  }
}

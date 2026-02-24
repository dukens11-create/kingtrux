import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/navigation_maneuver.dart';
import '../state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/alert_banner.dart';
import 'widgets/voice_settings_sheet.dart';

/// Full-screen turn-by-turn navigation UI.
///
/// Displayed while [AppState.isNavigating] is true. Shows:
///   - A prominent next-maneuver banner at the top
///   - A scrollable list of all remaining maneuvers
///   - Voice-guidance toggle and "End Navigation" action in the app bar
class NavigationScreen extends StatelessWidget {
  const NavigationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        // Auto-pop when navigation ends (arrival or manual stop).
        if (!state.isNavigating) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          });
        }

        final cs = Theme.of(context).colorScheme;

        return Scaffold(
          backgroundColor: cs.surface,
          appBar: _buildAppBar(context, state, cs),
          body: Column(
            children: [
              // ── Alert banner (off-route, reroute, etc.) ───────────────────
              const AlertBanner(),

              // ── Next-maneuver banner ──────────────────────────────────────
              _NextManeuverBanner(
                maneuver: state.currentManeuver,
                remainingDistanceMeters: state.remainingDistanceMeters,
                remainingDurationSeconds: state.remainingDurationSeconds,
              ),

              // ── Remaining maneuvers list ──────────────────────────────────
              Expanded(
                child: state.remainingManeuvers.isEmpty
                    ? _buildEmptyState(context, cs)
                    : _ManeuverList(maneuvers: state.remainingManeuvers),
              ),

              // ── End navigation button ─────────────────────────────────────
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(AppTheme.spaceMD),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: cs.error,
                        foregroundColor: cs.onError,
                        padding: const EdgeInsets.symmetric(
                          vertical: AppTheme.spaceSM + AppTheme.spaceXS,
                        ),
                      ),
                      onPressed: () async {
                        HapticFeedback.mediumImpact();
                        await state.stopNavigation();
                        if (context.mounted &&
                            Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('End Navigation'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // AppBar
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppState state,
    ColorScheme cs,
  ) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: cs.primaryContainer,
      foregroundColor: cs.onPrimaryContainer,
      title: Row(
        children: [
          Icon(Icons.navigation_rounded, color: cs.primary, size: 22),
          const SizedBox(width: AppTheme.spaceSM),
          const Text('Navigation'),
        ],
      ),
      actions: [
        // Voice settings
        Tooltip(
          message: 'Voice settings',
          child: IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              HapticFeedback.selectionClick();
              showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ChangeNotifierProvider.value(
                  value: state,
                  child: const VoiceSettingsSheet(),
                ),
              );
            },
          ),
        ),
        // Voice guidance toggle
        Tooltip(
          message: state.voiceGuidanceEnabled
              ? 'Mute voice guidance'
              : 'Unmute voice guidance',
          child: IconButton(
            icon: Icon(
              state.voiceGuidanceEnabled
                  ? Icons.volume_up_rounded
                  : Icons.volume_off_rounded,
            ),
            onPressed: () {
              HapticFeedback.selectionClick();
              state.toggleVoiceGuidance();
            },
          ),
        ),
        const SizedBox(width: AppTheme.spaceXS),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state (no maneuvers — e.g., straight shot to destination)
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(BuildContext context, ColorScheme cs) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline_rounded,
              size: 64, color: cs.primary),
          const SizedBox(height: AppTheme.spaceMD),
          Text(
            'Head to your destination',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Next-maneuver banner
// ---------------------------------------------------------------------------

class _NextManeuverBanner extends StatelessWidget {
  const _NextManeuverBanner({
    required this.maneuver,
    required this.remainingDistanceMeters,
    required this.remainingDurationSeconds,
  });
  final NavigationManeuver? maneuver;
  final double remainingDistanceMeters;
  final int remainingDurationSeconds;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (maneuver == null) {
      return const SizedBox.shrink();
    }

    final m = maneuver!;
    return Container(
      width: double.infinity,
      color: cs.primaryContainer,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceMD,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Next maneuver ────────────────────────────────────────────────
          Row(
            children: [
              _ManeuverIcon(action: m.action, direction: m.direction, size: 40),
              const SizedBox(width: AppTheme.spaceMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.instruction,
                      style: tt.titleLarge?.copyWith(
                        color: cs.onPrimaryContainer,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (m.distanceMeters > 0) ...[
                      const SizedBox(height: AppTheme.spaceXS),
                      Text(
                        _formatDistance(m.distanceMeters),
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onPrimaryContainer.withAlpha(178),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          // ── Total remaining ──────────────────────────────────────────────
          if (remainingDistanceMeters > 0 || remainingDurationSeconds > 0) ...[
            const SizedBox(height: AppTheme.spaceSM),
            Divider(
              height: 1,
              color: cs.onPrimaryContainer.withAlpha(50),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Row(
              children: [
                Icon(
                  Icons.outlined_flag_rounded,
                  size: 14,
                  color: cs.onPrimaryContainer.withAlpha(178),
                ),
                const SizedBox(width: AppTheme.spaceXS),
                Text(
                  'Remaining: ${_formatDistance(remainingDistanceMeters)}'
                  ' · ${_formatDuration(remainingDurationSeconds)}',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onPrimaryContainer.withAlpha(178),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 min';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    if (minutes > 0) return '${minutes}m';
    return '<1 min';
  }
}

// ---------------------------------------------------------------------------
// Remaining maneuvers list
// ---------------------------------------------------------------------------

class _ManeuverList extends StatelessWidget {
  const _ManeuverList({required this.maneuvers});
  final List<NavigationManeuver> maneuvers;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSM),
      itemCount: maneuvers.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 64),
      itemBuilder: (context, index) {
        final m = maneuvers[index];
        final isFirst = index == 0;
        final cs = Theme.of(context).colorScheme;
        return ListTile(
          leading: _ManeuverIcon(
            action: m.action,
            direction: m.direction,
            size: 28,
            highlighted: isFirst,
          ),
          title: Text(
            m.instruction.isEmpty ? m.action : m.instruction,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight:
                      isFirst ? FontWeight.w600 : FontWeight.normal,
                  color: cs.onSurface,
                ),
          ),
          trailing: m.distanceMeters > 0
              ? Text(
                  _formatDistance(m.distanceMeters),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                )
              : null,
        );
      },
    );
  }

  String _formatDistance(double meters) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }
    return '${meters.toStringAsFixed(0)} m';
  }
}

// ---------------------------------------------------------------------------
// Maneuver direction icon
// ---------------------------------------------------------------------------

class _ManeuverIcon extends StatelessWidget {
  const _ManeuverIcon({
    required this.action,
    required this.size,
    this.direction,
    this.highlighted = false,
  });

  final String action;
  final String? direction;
  final double size;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = highlighted ? cs.primary : cs.onSurfaceVariant;
    return Icon(_icon, size: size, color: color);
  }

  IconData get _icon {
    switch (action.toLowerCase()) {
      case 'depart':
        return Icons.start_rounded;
      case 'arrive':
        return Icons.flag_rounded;
      case 'uturn':
        return Icons.u_turn_left_rounded;
      case 'merge':
        return Icons.merge_rounded;
      case 'exit':
      case 'exithighway':
        return Icons.exit_to_app_rounded;
      case 'fork':
      case 'ramp':
      case 'rampturn':
        return Icons.fork_right_rounded;
      case 'turn':
      case 'keep':
      default:
        return _turnIcon;
    }
  }

  IconData get _turnIcon {
    switch ((direction ?? '').toLowerCase()) {
      case 'left':
      case 'sharpleft':
      case 'slightleft':
        return Icons.turn_left_rounded;
      case 'right':
      case 'sharpright':
      case 'slightright':
        return Icons.turn_right_rounded;
      default:
        return Icons.straight_rounded;
    }
  }
}

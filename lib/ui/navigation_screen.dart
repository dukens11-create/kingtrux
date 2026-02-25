import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/navigation_maneuver.dart';
import '../models/weather_forecast.dart';
import '../services/trip_eta_service.dart';
import '../state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/compass_indicator.dart';

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
          body: Stack(
            children: [
              Column(
                children: [
                  // ── Next-maneuver banner ────────────────────────────────────
                  _NextManeuverBanner(
                    maneuver: state.currentManeuver,
                    remainingDistanceMeters: state.remainingDistanceMeters,
                    remainingDurationSeconds: state.remainingDurationSeconds,
                  ),

                  // ── Trip ETA strip ──────────────────────────────────────────
                  _TripEtaStrip(
                    remainingDurationSeconds: state.remainingDurationSeconds,
                    etaUtc: state.tripEtaUtc,
                    etaAtDestination: state.tripEtaAtDestination,
                    destinationTimeZoneName: state.destinationTimeZoneName,
                    currentTimeZoneName: state.currentTimeZoneName,
                  ),

                  // ── Remaining maneuvers list ────────────────────────────────
                  Expanded(
                    child: state.remainingManeuvers.isEmpty
                        ? _buildEmptyState(context, cs)
                        : _ManeuverList(maneuvers: state.remainingManeuvers),
                  ),

                  // ── End navigation button ───────────────────────────────────
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

              // ── Compass indicator (bottom-left overlay) ─────────────────
              const Positioned(
                left: AppTheme.spaceMD,
                bottom: 96,
                child: CompassIndicator(),
              ),

              // ── State truck speed limit badge (bottom-left, above compass) ─
              if (state.currentUsState != null)
                Positioned(
                  left: AppTheme.spaceMD,
                  bottom: 148,
                  child: _StateTruckSpeedBadge(
                    stateCode: state.currentUsState!,
                    limitMph: state.stateTruckSpeedLimitMph,
                  ),
                ),

              // ── Weather forecast overlay (bottom-right) ──────────────────
              Positioned(
                right: AppTheme.spaceMD,
                bottom: 96,
                child: _ForecastPanel(
                  forecast: state.navigationForecast,
                  isLoading: state.isLoadingForecast,
                  error: state.forecastError,
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
// Trip ETA strip
// ---------------------------------------------------------------------------

/// A compact horizontal strip shown below the next-maneuver banner during
/// active navigation. Displays:
///   - Remaining drive time
///   - ETA at the destination (destination time zone)
///   - Current wall-clock time (device local time or current-state TZ label)
class _TripEtaStrip extends StatelessWidget {
  const _TripEtaStrip({
    required this.remainingDurationSeconds,
    required this.etaUtc,
    required this.etaAtDestination,
    required this.destinationTimeZoneName,
    required this.currentTimeZoneName,
  });

  final int remainingDurationSeconds;
  final DateTime? etaUtc;
  final DateTime? etaAtDestination;
  final String? destinationTimeZoneName;
  final String? currentTimeZoneName;

  @override
  Widget build(BuildContext context) {
    // Only render when there is meaningful data.
    if (remainingDurationSeconds <= 0 && etaUtc == null) {
      return const SizedBox.shrink();
    }

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final durationLabel =
        TripEtaService.formatDuration(remainingDurationSeconds);

    // Arrival time: prefer destination-tz-converted ETA; fall back to UTC
    // converted to device local time.
    final arrivalDt = etaAtDestination ?? etaUtc?.toLocal();
    final arrivalLabel =
        arrivalDt != null ? TripEtaService.formatWallClock(arrivalDt) : '–';
    final arrivalTzLabel = etaAtDestination != null
        ? (destinationTimeZoneName ?? '')
        : 'local';

    // Current local time on the device.
    final nowLocal = DateTime.now();
    final nowLabel = TripEtaService.formatWallClock(nowLocal);
    final nowTzLabel = currentTimeZoneName ?? 'local';

    return Container(
      color: cs.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceXS + 2,
      ),
      child: Row(
        children: [
          // ── Remaining drive time ───────────────────────────────────────
          _EtaCell(
            icon: Icons.timer_outlined,
            value: durationLabel,
            label: 'remaining',
            tt: tt,
            cs: cs,
          ),
          const _EtaDivider(),
          // ── Arrival (ETA) ──────────────────────────────────────────────
          _EtaCell(
            icon: Icons.flag_rounded,
            value: '$arrivalLabel ${arrivalTzLabel.isNotEmpty ? arrivalTzLabel : ''}'
                .trim(),
            label: 'arrival',
            tt: tt,
            cs: cs,
          ),
          const _EtaDivider(),
          // ── Current time ───────────────────────────────────────────────
          _EtaCell(
            icon: Icons.access_time_rounded,
            value: '$nowLabel $nowTzLabel'.trim(),
            label: 'now',
            tt: tt,
            cs: cs,
          ),
        ],
      ),
    );
  }
}

class _EtaCell extends StatelessWidget {
  const _EtaCell({
    required this.icon,
    required this.value,
    required this.label,
    required this.tt,
    required this.cs,
  });

  final IconData icon;
  final String value;
  final String label;
  final TextTheme tt;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: cs.onSurfaceVariant),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value,
                style: tt.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: cs.onSurface,
                  fontSize: 12,
                ),
              ),
              Text(
                label,
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EtaDivider extends StatelessWidget {
  const _EtaDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Theme.of(context).colorScheme.outlineVariant,
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXS),
    );
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
// Weather forecast overlay panel
// ---------------------------------------------------------------------------

class _ForecastPanel extends StatelessWidget {
  const _ForecastPanel({
    required this.forecast,
    required this.isLoading,
    required this.error,
  });

  final WeatherForecast? forecast;
  final bool isLoading;
  final String? error;

  @override
  Widget build(BuildContext context) {
    // No API key or forecast not yet available → show nothing while loading.
    if (isLoading && forecast == null) {
      return const SizedBox.shrink();
    }

    // If there was an error and no data, show nothing (graceful degradation).
    if (error != null && forecast == null) {
      return const SizedBox.shrink();
    }

    // No forecast (e.g. API key absent) → render nothing.
    if (forecast == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 160),
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface.withAlpha(230),
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(40),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceSM,
          vertical: AppTheme.spaceXS + 2,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Hourly row ────────────────────────────────────────────────
            if (forecast!.hourly.isNotEmpty) ...[
              Text(
                'Hourly',
                style: tt.labelLarge?.copyWith(
                  color: cs.primary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: forecast!.hourly
                    .map((h) => _HourlyChip(entry: h))
                    .toList(),
              ),
              const SizedBox(height: AppTheme.spaceXS),
            ],

            // ── Daily row ─────────────────────────────────────────────────
            if (forecast!.daily.isNotEmpty) ...[
              Text(
                'Daily',
                style: tt.labelLarge?.copyWith(
                  color: cs.primary,
                  fontSize: 10,
                ),
              ),
              const SizedBox(height: 2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: forecast!.daily
                    .map((d) => _DailyRow(entry: d))
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _HourlyChip extends StatelessWidget {
  const _HourlyChip({required this.entry});
  final HourlyForecast entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now().toUtc();
    final isNow = entry.time.difference(now).abs().inMinutes < 30;
    final label = isNow
        ? 'Now'
        : '${entry.time.toLocal().hour.toString().padLeft(2, '0')}h';

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 9,
            ),
          ),
          Text(
            '${entry.temperatureCelsius.round()}°',
            style: tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _DailyRow extends StatelessWidget {
  const _DailyRow({required this.entry});
  final DailyForecast entry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final entryLocal = entry.time.toLocal();
    final isToday = entryLocal.year == now.year &&
        entryLocal.month == now.month &&
        entryLocal.day == now.day;
    final dayLabel = isToday
        ? 'Today'
        : _weekdayShort(entryLocal.weekday);

    return Padding(
      padding: const EdgeInsets.only(bottom: 1),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 36,
            child: Text(
              dayLabel,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontSize: 9,
              ),
            ),
          ),
          Text(
            '${entry.highCelsius.round()}°/${entry.lowCelsius.round()}°',
            style: tt.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  String _weekdayShort(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[(weekday - 1) % 7];
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

// ---------------------------------------------------------------------------
// State truck speed limit badge
// ---------------------------------------------------------------------------

/// A compact badge displayed during navigation showing the legal commercial
/// truck speed limit for the current US state.
class _StateTruckSpeedBadge extends StatelessWidget {
  const _StateTruckSpeedBadge({
    required this.stateCode,
    required this.limitMph,
  });

  final String stateCode;
  final double? limitMph;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final limitLabel = limitMph != null
        ? '${limitMph!.toStringAsFixed(0)}'
        : '–';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: Colors.red.shade700, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(40),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXS + 2,
        vertical: AppTheme.spaceXS,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'TRUCK',
            style: tt.labelSmall?.copyWith(
              fontSize: 7,
              color: Colors.black87,
              letterSpacing: 0.5,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            limitLabel,
            style: tt.labelLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.1,
            ),
          ),
          Text(
            'mph  $stateCode',
            style: tt.labelSmall?.copyWith(
              fontSize: 7,
              color: Colors.black87,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

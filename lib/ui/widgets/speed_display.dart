import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// An on-screen overlay that displays the posted road speed limit and the
/// driver's real-time GPS speed side by side.
///
/// The speed readout is color-coded:
///  - **Red** when overspeeding (driver > limit + 2 mph)
///  - **Amber/yellow** when underspeeding (driver < limit − threshold)
///  - **Green** when speed is within the acceptable range
///
/// Only renders when both a GPS fix and a known speed limit are available.
/// The speed limit panel is always shown once a GPS fix is acquired, even
/// while the Overpass query is still in flight (displays "–" for limit).
class SpeedDisplay extends StatelessWidget {
  const SpeedDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        // No GPS fix yet – hide entirely.
        if (state.myLat == null) return const SizedBox.shrink();
        return _SpeedDisplayContent(state: state);
      },
    );
  }
}

class _SpeedDisplayContent extends StatelessWidget {
  const _SpeedDisplayContent({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final speedMph = state.currentSpeedMph;
    final limitMph = state.roadSpeedLimitMph;

    // Show the commercial badge whenever state limits are enabled – even when
    // the truck limit is not yet known (displays "–") so the user can see that
    // the feature is active and waiting for a GPS state fix.
    final stateLimitsEnabled = state.commercialSpeedSettings.enableStateLimits;
    final truckLimitMph = state.stateTruckSpeedLimitMph;
    final showTruckBadge = stateLimitsEnabled;

    final Color speedColor;
    if (limitMph == null) {
      speedColor = Colors.grey.shade700;
    } else if (speedMph > limitMph + SpeedMonitorThresholds.overspeedMargin) {
      speedColor = Colors.red.shade700;
    } else if (speedMph < limitMph - state.underspeedThresholdMph) {
      speedColor = Colors.amber.shade800;
    } else {
      speedColor = const Color(0xFF2E7D32); // green-800
    }

    return Card(
      elevation: AppTheme.elevationCard,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceXS + 2,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Speed limit sign(s) ───────────────────────────────────────
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _SpeedLimitSign(limitMph: limitMph),
                    if (showTruckBadge) ...[
                      const SizedBox(height: 6),
                      _TruckLimitBadge(
                        limitMph: truckLimitMph,
                        stateCode: state.currentUsState,
                      ),
                    ],
                  ],
                ),
                const SizedBox(width: AppTheme.spaceSM),
                // ── Divider ───────────────────────────────────────────────────
                Container(
                  width: 1,
                  height: 40,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(width: AppTheme.spaceSM),
                // ── Driver speed ──────────────────────────────────────────────
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      speedMph.toStringAsFixed(0),
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: speedColor,
                      ),
                    ),
                    Text(
                      'mph',
                      style: tt.labelSmall?.copyWith(color: speedColor),
                    ),
                  ],
                ),
              ],
            ),
            // ── Debug diagnostics (only in debug builds) ──────────────────
            if (kDebugMode) ...[
              const SizedBox(height: 4),
              Text(
                'state:${state.currentUsState ?? '?'} '
                'road:${state.roadSpeedLimitMph?.toStringAsFixed(0) ?? '?'} '
                'truck:${state.stateTruckSpeedLimitMph?.toStringAsFixed(0) ?? '?'}',
                style: tt.labelSmall?.copyWith(
                  fontSize: 8,
                  color: Colors.grey.shade500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Standard US SPEED LIMIT sign – white rounded rectangle, black border,
/// "SPEED" / "LIMIT" stacked above the large numeric limit.
class _SpeedLimitSign extends StatelessWidget {
  const _SpeedLimitSign({required this.limitMph});

  final double? limitMph;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final label = limitMph != null ? limitMph!.toStringAsFixed(0) : '–';

    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.black, width: 2.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SPEED',
            style: tt.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: 1.0,
              height: 1.1,
            ),
          ),
          Text(
            'LIMIT',
            style: tt.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: 1.0,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: Colors.black,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small badge shown under the road limit sign for commercial/truck limit.
///
/// When [limitMph] is `null` the badge shows "–" (with optional
/// [stateCode]) to communicate that the feature is enabled but the state-
/// specific limit is not yet known.
class _TruckLimitBadge extends StatelessWidget {
  const _TruckLimitBadge({required this.limitMph, this.stateCode});

  final double? limitMph;
  final String? stateCode;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final limitLabel = limitMph != null ? limitMph!.toStringAsFixed(0) : '–';
    final suffix = (limitMph == null && stateCode != null) ? ' ($stateCode)' : '';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade400, width: 1),
      ),
      child: Text(
        '$limitLabel$suffix',
        style: tt.labelMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: limitMph != null ? Colors.black : Colors.grey.shade600,
        ),
      ),
    );
  }
}

/// Constants shared between [SpeedDisplay] and [AppState] speed logic.
abstract class SpeedMonitorThresholds {
  /// Miles per hour above the posted limit before overspeeding is declared.
  static const double overspeedMargin = 2.0;
}
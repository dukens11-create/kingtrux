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

    final Color speedColor;
    if (limitMph == null) {
      speedColor = Colors.grey.shade700;
    } else if (speedMph > limitMph + SpeedMonitorThresholds.overspeedMargin) {
      speedColor = Colors.red.shade700;
    } else if (speedMph <
        limitMph - state.underspeedThresholdMph) {
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Speed limit sign ──────────────────────────────────────────
            _SpeedLimitSign(limitMph: limitMph),
            const SizedBox(width: AppTheme.spaceSM),
            // ── Divider ───────────────────────────────────────────────────
            Container(
              width: 1,
              height: 36,
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
      ),
    );
  }
}

/// Circular badge styled like a US speed-limit sign.
class _SpeedLimitSign extends StatelessWidget {
  const _SpeedLimitSign({required this.limitMph});

  final double? limitMph;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final label =
        limitMph != null ? limitMph!.toStringAsFixed(0) : '–';
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        border: Border.all(color: Colors.red.shade700, width: 2.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'LMT',
            style: tt.labelSmall?.copyWith(
              fontSize: 7,
              color: Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
          Text(
            label,
            style: tt.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Constants shared between [SpeedDisplay] and [AppState] speed logic.
abstract class SpeedMonitorThresholds {
  /// Miles per hour above the posted limit before overspeeding is declared.
  static const double overspeedMargin = 2.0;
}

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
                Builder(
                  builder: (context) {
                    final signW = _signWidth(MediaQuery.sizeOf(context).width);
                    return Container(
                      width: 1,
                      height: signW * 1.25,
                      color: Colors.grey.shade300,
                    );
                  },
                ),
                const SizedBox(width: AppTheme.spaceSM),
                // ── Driver speed ──────────────────────────────────────────────
                Builder(
                  builder: (context) {
                    final signW =
                        _signWidth(MediaQuery.sizeOf(context).width);
                    final driverNumSize =
                        (signW * 0.42).clamp(40.0, 72.0);
                    final driverMphSize =
                        (signW * 0.14).clamp(12.0, 20.0);
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          speedMph.toStringAsFixed(0),
                          style: TextStyle(
                            fontSize: driverNumSize,
                            fontWeight: FontWeight.bold,
                            color: speedColor,
                            height: 1.0,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border:
                                Border.all(color: Colors.black, width: 1),
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            'mph',
                            style: TextStyle(
                              fontSize: driverMphSize,
                              color: speedColor,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
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

/// Returns the responsive width for the speed limit sign, clamped to a safe
/// range so it looks proportionate on phones of all sizes.
double _signWidth(double screenWidth) =>
    (screenWidth * 0.28).clamp(110.0, 170.0);

/// Standard US SPEED LIMIT sign – white rounded rectangle, black border,
/// "SPEED" / "LIMIT" stacked above the large numeric limit.
class _SpeedLimitSign extends StatelessWidget {
  const _SpeedLimitSign({required this.limitMph});

  final double? limitMph;

  @override
  Widget build(BuildContext context) {
    final label = limitMph != null ? limitMph!.toStringAsFixed(0) : '–';
    final screenWidth = MediaQuery.sizeOf(context).width;

    // Responsive size constants – scale with screen width but stay within
    // a safe range so the sign is clearly readable on small devices without
    // overflowing on larger ones.
    final signW = _signWidth(screenWidth);
    final borderW = (signW * 0.035).clamp(2.5, 5.0);
    final hPad = (signW * 0.09).clamp(8.0, 16.0);
    final vPad = (signW * 0.09).clamp(8.0, 14.0);
    final radius = (signW * 0.09).clamp(6.0, 14.0);
    final headerSize = (signW * 0.14).clamp(11.0, 20.0);
    final numSize = (signW * 0.55).clamp(44.0, 82.0);
    final innerSpacing = (signW * 0.04).clamp(2.0, 8.0);

    return Container(
      width: signW,
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.black, width: borderW),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'SPEED',
            style: TextStyle(
              fontSize: headerSize,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: 1.0,
              height: 1.1,
            ),
          ),
          Text(
            'LIMIT',
            style: TextStyle(
              fontSize: headerSize,
              fontWeight: FontWeight.w800,
              color: Colors.black,
              letterSpacing: 1.0,
              height: 1.1,
            ),
          ),
          SizedBox(height: innerSpacing),
          Text(
            label,
            style: TextStyle(
              fontSize: numSize,
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
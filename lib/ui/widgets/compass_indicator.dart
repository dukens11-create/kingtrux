import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// A compact compass indicator widget that shows the driver's current heading.
///
/// Displays:
///   - A rotating navigation arrow pointing in the direction of travel.
///   - A cardinal/intercardinal direction label (N, NE, E, SE, S, SW, W, NW).
///
/// Hidden when no heading data is available yet.
class CompassIndicator extends StatelessWidget {
  const CompassIndicator({super.key});

  /// Converts a heading in degrees (0–360) to the nearest cardinal or
  /// intercardinal direction label.
  ///
  /// 0° / 360° → N, 45° → NE, 90° → E, 135° → SE, 180° → S,
  /// 225° → SW, 270° → W, 315° → NW.
  static String headingToCardinal(double heading) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final normalized = heading % 360;
    final index = ((normalized + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final heading = state.currentHeading;
        if (heading == null) return const SizedBox.shrink();

        final cardinal = headingToCardinal(heading);
        final cs = Theme.of(context).colorScheme;

        return Card(
          elevation: AppTheme.elevationSheet,
          margin: EdgeInsets.zero,
          shape: const CircleBorder(),
          color: cs.surfaceContainerHigh,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Tooltip(
              message: 'Heading: ${heading.toStringAsFixed(0)}° $cardinal',
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Transform.rotate(
                    angle: heading * math.pi / 180,
                    child: Icon(
                      Icons.navigation_rounded,
                      color: cs.primary,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    cardinal,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: cs.onSurface,
                          fontSize: 11,
                        ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

import 'package:flutter/material.dart';

/// Returns an icon appropriate for the maneuver [action] and [direction].
///
/// Shared between [ManeuverBanner] and [StepsListSheet].
IconData maneuverIconForAction(String action, String? direction) {
  switch (action) {
    case 'depart':
      return Icons.navigation_rounded;
    case 'arrive':
      return Icons.flag_rounded;
    case 'turn':
      switch (direction) {
        case 'left':
          return Icons.turn_left_rounded;
        case 'right':
          return Icons.turn_right_rounded;
        case 'uTurn':
        case 'sharpLeft':
          return Icons.u_turn_left_rounded;
        case 'sharpRight':
          return Icons.u_turn_right_rounded;
        default:
          return Icons.straight_rounded;
      }
    case 'keep':
      switch (direction) {
        case 'left':
          return Icons.fork_left_rounded;
        case 'right':
          return Icons.fork_right_rounded;
        default:
          return Icons.straight_rounded;
      }
    case 'merge':
      return Icons.merge_rounded;
    case 'uTurn':
      return direction == 'right'
          ? Icons.u_turn_right_rounded
          : Icons.u_turn_left_rounded;
    case 'roundabout':
      return Icons.roundabout_left_rounded;
    default:
      return Icons.arrow_upward_rounded;
  }
}

/// Format [meters] as a navigation-style distance string.
///
/// Uses feet when under 0.2 mi; miles otherwise.
String formatManeuverDistance(double meters) {
  final miles = meters * 0.000621371;
  if (miles < 0.2) {
    final feet = (meters * 3.28084).round();
    return '$feet ft';
  }
  return '${miles.toStringAsFixed(1)} mi';
}

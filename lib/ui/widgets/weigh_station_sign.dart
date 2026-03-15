import 'package:flutter/material.dart';

/// A highway-style weigh station sign widget.
///
/// Renders a teal/green rounded rectangle with a white double-border effect
/// and a centered bold white "W".  When [showLabel] is `true` the text
/// "Weigh Stations" is displayed beneath the sign box.
///
/// Usage:
/// ```dart
/// // Map marker / compact use – sign only
/// WeighStationSign()
///
/// // Card / list use – sign + label
/// WeighStationSign(showLabel: true)
/// ```
class WeighStationSign extends StatelessWidget {
  const WeighStationSign({
    super.key,
    this.showLabel = false,
    this.size = 36.0,
  });

  /// When `true`, renders "Weigh Stations" text beneath the sign box.
  final bool showLabel;

  /// The logical-pixel height (and approximate width) of the sign box.
  /// Width is derived from [size] with a fixed aspect ratio so the sign
  /// stays proportional.
  final double size;

  // Sign colors matching a standard DOT weigh-station highway sign.
  static const Color _bgColor = Color(0xFF0D7A6C); // teal-green
  static const Color _borderColor = Colors.white;

  @override
  Widget build(BuildContext context) {
    final signWidth = size * 1.25;
    final signHeight = size;
    final borderRadius = size * 0.18;
    final outerBorderWidth = (size * 0.06).clamp(1.5, 3.0);
    final innerBorderWidth = (size * 0.04).clamp(1.0, 2.0);
    final innerInset = outerBorderWidth + innerBorderWidth + (size * 0.04).clamp(1.5, 3.0);
    final fontSize = size * 0.55;

    final sign = Container(
      width: signWidth,
      height: signHeight,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: _borderColor, width: outerBorderWidth),
      ),
      child: Padding(
        padding: EdgeInsets.all(innerInset),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(
              (borderRadius - outerBorderWidth).clamp(2.0, borderRadius),
            ),
            border: Border.all(color: _borderColor, width: innerBorderWidth),
          ),
          child: Center(
            child: Text(
              'W',
              style: TextStyle(
                color: _borderColor,
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );

    if (!showLabel) return sign;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        sign,
        SizedBox(height: size * 0.1),
        Text(
          'Weigh Stations',
          style: TextStyle(
            fontSize: (size * 0.28).clamp(9.0, 13.0),
            fontWeight: FontWeight.w600,
            color: Theme.of(context).colorScheme.onSurface,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

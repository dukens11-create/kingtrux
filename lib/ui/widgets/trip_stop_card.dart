import 'package:flutter/material.dart';
import '../../models/trip_stop.dart';
import '../theme/app_theme.dart';

/// A card that renders a single [TripStop] in a vertical timeline style.
///
/// Shows:
/// - A coloured dot on the vertical route line on the left
/// - A stop-type badge (e.g., "ORIGIN", "OTHER", "DEST")
/// - The stop label / address
/// - Optional time label
/// - Action buttons (Go / Arrived) when [isFirst] or [isLast]
class TripStopCard extends StatelessWidget {
  const TripStopCard({
    super.key,
    required this.stop,
    required this.index,
    required this.totalStops,
    required this.onGoPressed,
    required this.onArrivedPressed,
    this.timeLabel,
  });

  final TripStop stop;
  final int index;
  final int totalStops;
  final VoidCallback onGoPressed;
  final VoidCallback onArrivedPressed;

  /// Optional ETA / depart / arrive label string.
  final String? timeLabel;

  bool get isFirst => index == 0;
  bool get isLast => index == totalStops - 1;

  String get _badge {
    if (isFirst) return 'ORIGIN';
    if (isLast) return 'DEST';
    return 'OTHER';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final dotColor = isFirst
        ? cs.primary
        : isLast
            ? cs.error
            : cs.secondary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Left timeline column ───────────────────────────────────────
          SizedBox(
            width: 32,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Line above the dot (except for first stop)
                if (!isFirst)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: cs.outlineVariant,
                      ),
                    ),
                  ),
                Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: dotColor,
                    border: Border.all(
                      color: cs.surface,
                      width: 2,
                    ),
                  ),
                ),
                // Line below the dot (except for last stop)
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        width: 2,
                        color: cs.outlineVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),

          // ── Card content ───────────────────────────────────────────────
          Expanded(
            child: Card(
              margin: const EdgeInsets.symmetric(vertical: AppTheme.spaceXS),
              child: Padding(
                padding: const EdgeInsets.all(AppTheme.spaceMD),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Badge row
                    Row(
                      children: [
                        _StopBadge(label: _badge, color: dotColor),
                        const Spacer(),
                        if (timeLabel != null)
                          Text(
                            timeLabel!,
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppTheme.spaceXS),

                    // Address / label
                    Text(
                      stop.label ?? 'Stop ${index + 1}',
                      style: tt.titleSmall?.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                    Text(
                      '${stop.lat.toStringAsFixed(4)}, ${stop.lng.toStringAsFixed(4)}',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),

                    // Action buttons
                    if (isFirst || isLast) ...[
                      const SizedBox(height: AppTheme.spaceSM),
                      Row(
                        children: [
                          if (isFirst)
                            FilledButton(
                              onPressed: onGoPressed,
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spaceMD,
                                ),
                              ),
                              child: const Text('Go'),
                            ),
                          if (isFirst) const SizedBox(width: AppTheme.spaceSM),
                          OutlinedButton(
                            onPressed: onArrivedPressed,
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceMD,
                              ),
                            ),
                            child: const Text('Arrived'),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StopBadge extends StatelessWidget {
  const _StopBadge({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSM,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

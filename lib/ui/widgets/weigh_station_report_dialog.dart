import 'package:flutter/material.dart';
import '../../models/weigh_station.dart';

/// Modal dialog prompting the driver to report the current status of a
/// weigh / inspection station.
///
/// Shown automatically when the driver enters the 150-foot (≈ 45.72 m) radius
/// of a station and [WeighStationSettings.enableSubmissionPrompts] is `true`.
///
/// Returns the selected [WeighStationStatus] (excluding [WeighStationStatus.unknown])
/// or `null` when the driver dismisses without selecting.
class WeighStationReportDialog extends StatelessWidget {
  const WeighStationReportDialog({
    super.key,
    required this.station,
  });

  final WeighStation station;

  /// Convenience method: show the dialog and await the driver's selection.
  static Future<WeighStationStatus?> show(
    BuildContext context,
    WeighStation station,
  ) {
    return showDialog<WeighStationStatus>(
      context: context,
      barrierDismissible: true,
      builder: (_) => WeighStationReportDialog(station: station),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Statuses that a driver can actively report (no "Unknown" option).
    const reportable = [
      WeighStationStatus.openBypass,
      WeighStationStatus.openGoingThrough,
      WeighStationStatus.monitoring,
      WeighStationStatus.closed,
    ];

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.scale_rounded, color: cs.primary, size: 22),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Report Station Status',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            station.name,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          if (station.highway != null || station.direction != null) ...[
            const SizedBox(height: 2),
            Text(
              [station.highway, station.direction]
                  .whereType<String>()
                  .join(' · '),
              style: const TextStyle(fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          const Text('What is the current status?'),
          const SizedBox(height: 8),
          ...reportable.map(
            (status) => _StatusOption(
              status: status,
              onTap: () => Navigator.of(context).pop(status),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Skip'),
        ),
      ],
    );
  }
}

class _StatusOption extends StatelessWidget {
  const _StatusOption({required this.status, required this.onTap});

  final WeighStationStatus status;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: status.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(status.label),
          ],
        ),
      ),
    );
  }
}

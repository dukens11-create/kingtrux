import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../models/scale_report.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Bottom sheet that prompts the driver to report the status of a weigh scale
/// after they have passed it.
///
/// Presents four large buttons corresponding to [ScaleStatus] values.
/// The driver may also dismiss the sheet without selecting a status.
class ScaleStatusPromptSheet extends StatelessWidget {
  const ScaleStatusPromptSheet({super.key, required this.poi});

  final Poi poi;

  /// Convenience helper that presents the sheet via [showModalBottomSheet].
  static Future<void> show(BuildContext context, Poi poi) {
    return showModalBottomSheet<void>(
      context: context,
      isDismissible: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => ScaleStatusPromptSheet(poi: poi),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceMD,
          AppTheme.spaceMD,
          AppTheme.spaceMD,
          AppTheme.spaceLG,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              'Weigh Station — What was the status?',
              style: tt.titleMedium,
              textAlign: TextAlign.center,
            ),
            Text(
              poi.name,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceMD),
            _StatusButton(
              label: 'Open (Bypass)',
              color: const Color(0xFF4CAF50),
              icon: Icons.directions_rounded,
              onTap: () => _submit(context, state, ScaleStatus.openBypass),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            _StatusButton(
              label: 'Open (Rolling Across)',
              color: const Color(0xFFFFC107),
              icon: Icons.warning_amber_rounded,
              onTap: () =>
                  _submit(context, state, ScaleStatus.openRollingAcross),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            _StatusButton(
              label: 'Closed',
              color: cs.error,
              icon: Icons.block_rounded,
              onTap: () => _submit(context, state, ScaleStatus.closed),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            _StatusButton(
              label: 'Not sure',
              color: cs.onSurfaceVariant,
              icon: Icons.help_outline_rounded,
              onTap: () => _submit(context, state, ScaleStatus.notSure),
            ),
          ],
        ),
      ),
    );
  }

  void _submit(BuildContext context, AppState state, ScaleStatus status) {
    HapticFeedback.mediumImpact();
    state.submitScaleReport(
      poiId: poi.id,
      poiName: poi.name,
      lat: poi.lat,
      lng: poi.lng,
      status: status,
    );
    Navigator.of(context).pop();
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        onPressed: onTap,
      ),
    );
  }
}

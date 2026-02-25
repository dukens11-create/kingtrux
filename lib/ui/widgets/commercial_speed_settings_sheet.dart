import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/commercial_speed_settings.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for configuring the commercial/truck max-speed alert.
///
/// Allows the driver to:
/// - Enable or disable the commercial overspeed alert.
/// - Select the display unit (mph / km/h).
/// - Enter the maximum allowed truck speed in the chosen unit.
class CommercialSpeedSettingsSheet extends StatefulWidget {
  const CommercialSpeedSettingsSheet({super.key});

  @override
  State<CommercialSpeedSettingsSheet> createState() =>
      _CommercialSpeedSettingsSheetState();
}

class _CommercialSpeedSettingsSheetState
    extends State<CommercialSpeedSettingsSheet> {
  late bool _enabled;
  late SpeedUnit _unit;
  late TextEditingController _speedController;

  @override
  void initState() {
    super.initState();
    final settings = context.read<AppState>().commercialSpeedSettings;
    _enabled = settings.enabled;
    _unit = settings.unit;
    _speedController = TextEditingController(
      text: settings.maxSpeedDisplay.toStringAsFixed(0),
    );
  }

  @override
  void dispose() {
    _speedController.dispose();
    super.dispose();
  }

  double get _parsedSpeedMs {
    final raw = double.tryParse(_speedController.text) ?? 0.0;
    return _unit == SpeedUnit.mph
        ? CommercialSpeedSettings.mphToMs(raw)
        : CommercialSpeedSettings.kmhToMs(raw);
  }

  void _onUnitChanged(SpeedUnit? unit) {
    if (unit == null || unit == _unit) return;
    // Keep the max-speed value consistent when switching units.
    final currentMs = _parsedSpeedMs;
    setState(() {
      _unit = unit;
      final display = unit == SpeedUnit.mph
          ? CommercialSpeedSettings.msToMph(currentMs)
          : CommercialSpeedSettings.msToKmh(currentMs);
      _speedController.text = display.toStringAsFixed(0);
    });
  }

  void _save() {
    final state = context.read<AppState>();
    final speedMs = _parsedSpeedMs;
    if (speedMs <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid speed value.')),
      );
      return;
    }
    state.setCommercialSpeedSettings(
      CommercialSpeedSettings(
        enabled: _enabled,
        maxSpeedMs: speedMs,
        unit: _unit,
      ),
    );
    HapticFeedback.selectionClick();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final unitLabel = _unit == SpeedUnit.mph ? 'mph' : 'km/h';

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          AppTheme.spaceMD,
          AppTheme.spaceSM,
          AppTheme.spaceMD,
          AppTheme.spaceMD + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Row(
              children: [
                Icon(Icons.speed_rounded, color: cs.primary, size: 28),
                const SizedBox(width: AppTheme.spaceSM),
                Text('Commercial Speed Limit', style: tt.headlineSmall),
              ],
            ),
            const SizedBox(height: AppTheme.spaceSM),
            const Divider(),

            // Enable toggle
            SwitchListTile(
              secondary: Icon(
                _enabled
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_off_rounded,
                color: _enabled ? cs.primary : cs.outline,
              ),
              title: const Text('Enable commercial speed alerts'),
              subtitle: const Text(
                  'Alert when exceeding your configured max speed while navigating'),
              value: _enabled,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _enabled = v);
              },
              contentPadding: EdgeInsets.zero,
            ),

            const Divider(),
            const SizedBox(height: AppTheme.spaceXS),

            // Unit selector
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Display unit', style: tt.bodyMedium),
                      Text(
                        'Unit used for speed entry and alerts',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                SegmentedButton<SpeedUnit>(
                  segments: const [
                    ButtonSegment(value: SpeedUnit.mph, label: Text('mph')),
                    ButtonSegment(value: SpeedUnit.kmh, label: Text('km/h')),
                  ],
                  selected: {_unit},
                  onSelectionChanged: (s) => _onUnitChanged(s.first),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spaceMD),

            // Max speed input
            TextField(
              controller: _speedController,
              enabled: _enabled,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: false),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Max speed ($unitLabel)',
                border: const OutlineInputBorder(),
                suffixText: unitLabel,
              ),
              style: tt.bodyLarge,
            ),

            const SizedBox(height: AppTheme.spaceMD),

            // Save button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

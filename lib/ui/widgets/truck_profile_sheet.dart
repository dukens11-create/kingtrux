import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/truck_profile.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for configuring truck profile
class TruckProfileSheet extends StatefulWidget {
  const TruckProfileSheet({super.key});

  @override
  State<TruckProfileSheet> createState() => _TruckProfileSheetState();
}

class _TruckProfileSheetState extends State<TruckProfileSheet> {
  late double _height;
  late double _width;
  late double _length;
  late double _weight;
  late int _axles;
  late bool _hazmat;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppState>().truckProfile;
    _height = profile.heightMeters;
    _width = profile.widthMeters;
    _length = profile.lengthMeters;
    _weight = profile.weightTons;
    _axles = profile.axles;
    _hazmat = profile.hazmat;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
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
            // Title row
            Row(
              children: [
                Icon(Icons.local_shipping_rounded, color: cs.primary, size: 28),
                const SizedBox(width: AppTheme.spaceSM),
                Text('Truck Profile', style: tt.headlineSmall),
              ],
            ),
            const SizedBox(height: AppTheme.spaceMD),

            // Height
            _SliderRow(
              label: 'Height',
              value: _height,
              unit: 'm',
              min: 2.5,
              max: 4.8,
              divisions: 23,
              onChanged: (v) => setState(() => _height = v),
            ),

            // Width
            _SliderRow(
              label: 'Width',
              value: _width,
              unit: 'm',
              min: 2.0,
              max: 3.0,
              divisions: 10,
              onChanged: (v) => setState(() => _width = v),
            ),

            // Length
            _SliderRow(
              label: 'Length',
              value: _length,
              unit: 'm',
              min: 6.0,
              max: 30.0,
              divisions: 24,
              fractionDigits: 1,
              onChanged: (v) => setState(() => _length = v),
            ),

            // Weight
            _SliderRow(
              label: 'Weight',
              value: _weight,
              unit: 'tons',
              min: 5.0,
              max: 45.0,
              divisions: 40,
              fractionDigits: 1,
              onChanged: (v) => setState(() => _weight = v),
            ),

            // Axles
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXS),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Axles', style: tt.bodyMedium),
                  ),
                  DropdownButton<int>(
                    value: _axles,
                    underline: const SizedBox(),
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    items: List.generate(7, (i) => i + 2)
                        .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                        .toList(),
                    onChanged: (value) => setState(() => _axles = value!),
                  ),
                ],
              ),
            ),

            // Hazmat
            SwitchListTile(
              secondary: Icon(
                Icons.warning_amber_rounded,
                color: _hazmat ? cs.error : cs.outline,
              ),
              title: const Text('Hazardous Materials'),
              value: _hazmat,
              onChanged: (value) {
                HapticFeedback.selectionClick();
                setState(() => _hazmat = value);
              },
              contentPadding: EdgeInsets.zero,
            ),

            const SizedBox(height: AppTheme.spaceMD),

            // Save
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: const Text('Save Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _save() {
    HapticFeedback.mediumImpact();
    final profile = TruckProfile(
      heightMeters: _height,
      widthMeters: _width,
      lengthMeters: _length,
      weightTons: _weight,
      axles: _axles,
      hazmat: _hazmat,
    );

    context.read<AppState>().setTruck(profile);
    Navigator.pop(context);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Truck profile updated')),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable labeled slider row
// ---------------------------------------------------------------------------

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.unit,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.fractionDigits = 2,
  });

  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final int fractionDigits;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceXS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: tt.bodyMedium),
              Text(
                '${value.toStringAsFixed(fractionDigits)} $unit',
                style: tt.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: '${value.toStringAsFixed(fractionDigits)} $unit',
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}


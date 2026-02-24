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
  TruckUnit _unit = TruckUnit.metric;

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
    final isImperial = _unit == TruckUnit.imperial;
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
            const SizedBox(height: AppTheme.spaceSM),

            // Current profile summary
            Text(
              _currentSummary(),
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: AppTheme.spaceSM),

            // Units toggle
            SegmentedButton<TruckUnit>(
              segments: const [
                ButtonSegment(
                  value: TruckUnit.metric,
                  label: Text('Metric (m / t)'),
                  icon: Icon(Icons.straighten_rounded),
                ),
                ButtonSegment(
                  value: TruckUnit.imperial,
                  label: Text('Imperial (ft / st)'),
                  icon: Icon(Icons.straighten_rounded),
                ),
              ],
              selected: {_unit},
              onSelectionChanged: (s) => setState(() => _unit = s.first),
            ),
            const SizedBox(height: AppTheme.spaceMD),

            // Height
            _SliderRow(
              label: 'Height',
              helperText: isImperial
                  ? 'Common US height limit: 13\'6\" (varies by state)'
                  : 'Legal max in most EU countries: 4.0 m',
              value: isImperial
                  ? TruckProfile.metersToFeet(_height)
                  : _height,
              unit: isImperial ? 'ft' : 'm',
              min: isImperial ? TruckProfile.metersToFeet(2.5) : 2.5,
              max: isImperial ? TruckProfile.metersToFeet(4.8) : 4.8,
              divisions: 23,
              onChanged: (v) => setState(() => _height =
                  isImperial ? TruckProfile.feetToMeters(v) : v),
            ),

            // Width
            _SliderRow(
              label: 'Width',
              helperText: isImperial
                  ? 'Legal max in most US states: 8.5 ft'
                  : 'Legal max in most EU countries: 2.55 m',
              value: isImperial
                  ? TruckProfile.metersToFeet(_width)
                  : _width,
              unit: isImperial ? 'ft' : 'm',
              min: isImperial ? TruckProfile.metersToFeet(2.0) : 2.0,
              max: isImperial ? TruckProfile.metersToFeet(3.0) : 3.0,
              divisions: 10,
              onChanged: (v) => setState(() => _width =
                  isImperial ? TruckProfile.feetToMeters(v) : v),
            ),

            // Length
            _SliderRow(
              label: 'Length',
              helperText: isImperial
                  ? 'Typical semi: 53 ft trailer + cab'
                  : 'Typical semi: ~21 m total',
              value: isImperial
                  ? TruckProfile.metersToFeet(_length)
                  : _length,
              unit: isImperial ? 'ft' : 'm',
              min: isImperial ? TruckProfile.metersToFeet(6.0) : 6.0,
              max: isImperial ? TruckProfile.metersToFeet(30.0) : 30.0,
              divisions: 24,
              fractionDigits: 1,
              onChanged: (v) => setState(() => _length =
                  isImperial ? TruckProfile.feetToMeters(v) : v),
            ),

            // Weight
            _SliderRow(
              label: 'Weight',
              helperText: isImperial
                  ? 'US federal gross weight limit: 40 short tons'
                  : 'EU gross weight limit: 40 t (44 t intermodal)',
              value: isImperial
                  ? TruckProfile.metricTonsToShortTons(_weight)
                  : _weight,
              unit: isImperial ? 'st' : 't',
              min: isImperial
                  ? TruckProfile.metricTonsToShortTons(5.0)
                  : 5.0,
              max: isImperial
                  ? TruckProfile.metricTonsToShortTons(45.0)
                  : 45.0,
              divisions: 40,
              fractionDigits: 1,
              onChanged: (v) => setState(() => _weight = isImperial
                  ? TruckProfile.shortTonsToMetricTons(v)
                  : v),
            ),

            // Axles
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXS),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Axles', style: tt.bodyMedium),
                        Text(
                          'Total axle count affects weight distribution',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
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
              subtitle: const Text('Enables hazmat routing restrictions'),
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

  String _currentSummary() {
    final profile = TruckProfile(
      heightMeters: _height,
      widthMeters: _width,
      lengthMeters: _length,
      weightTons: _weight,
      axles: _axles,
      hazmat: _hazmat,
    );
    return profile.summary(unit: _unit);
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
      const SnackBar(content: Text('Truck profile saved')),
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
    this.helperText,
  });

  final String label;
  final double value;
  final String unit;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final int fractionDigits;
  final String? helperText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    // Clamp value to [min, max] to handle unit switching rounding.
    final clamped = value.clamp(min, max);
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
                '${clamped.toStringAsFixed(fractionDigits)} $unit',
                style: tt.bodyMedium?.copyWith(
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Slider(
            value: clamped,
            min: min,
            max: max,
            divisions: divisions,
            label: '${clamped.toStringAsFixed(fractionDigits)} $unit',
            onChanged: onChanged,
          ),
          if (helperText != null)
            Padding(
              padding: const EdgeInsets.only(
                left: AppTheme.spaceSM,
                bottom: AppTheme.spaceXS,
              ),
              child: Text(
                helperText!,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
        ],
      ),
    );
  }
}

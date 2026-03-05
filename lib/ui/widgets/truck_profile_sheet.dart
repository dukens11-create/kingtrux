import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/truck_profile.dart';
import '../../services/truck_profile_service.dart';
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

  // Text controllers for US-units inputs
  late final TextEditingController _heightFtCtrl;
  late final TextEditingController _heightInCtrl;
  late final TextEditingController _weightLbsCtrl;

  final _svc = TruckProfileService();

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

    final (ft, ins) = TruckProfile.metersToFeetInches(_height);
    _heightFtCtrl = TextEditingController(text: '$ft');
    _heightInCtrl = TextEditingController(text: '$ins');
    _weightLbsCtrl = TextEditingController(
      text: TruckProfile.metricTonsToPounds(_weight).round().toString(),
    );

    _loadUnit();
  }

  @override
  void dispose() {
    _heightFtCtrl.dispose();
    _heightInCtrl.dispose();
    _weightLbsCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUnit() async {
    final u = await _svc.loadUnit();
    if (mounted) {
      setState(() {
        _unit = u;
        _syncUsControllers();
      });
    }
  }

  /// Sync the US-units text controllers from current metric values.
  void _syncUsControllers() {
    final (ft, ins) = TruckProfile.metersToFeetInches(_height);
    _heightFtCtrl.text = '$ft';
    _heightInCtrl.text = '$ins';
    _weightLbsCtrl.text =
        TruckProfile.metricTonsToPounds(_weight).round().toString();
  }

  void _onUnitChanged(TruckUnit unit) {
    if (unit == TruckUnit.imperial) _syncUsControllers();
    setState(() => _unit = unit);
    _svc.saveUnit(unit).catchError(
      (Object e) => debugPrint('Error saving truck unit: $e'),
    );
  }

  void _onHeightUsChanged() {
    final ft = int.tryParse(_heightFtCtrl.text.trim()) ?? -1;
    final ins = int.tryParse(_heightInCtrl.text.trim()) ?? -1;
    if (ft >= 0 && ins >= 0 && ins < 12) {
      setState(() => _height = TruckProfile.feetInchesToMeters(ft, ins));
    }
  }

  void _onWeightLbsChanged() {
    final lbs = double.tryParse(_weightLbsCtrl.text.trim());
    if (lbs != null && lbs > 0) {
      setState(() => _weight = TruckProfile.poundsToMetricTons(lbs));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isUs = _unit == TruckUnit.imperial;
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
                  label: Text('US (ft·in / lbs)'),
                  icon: Icon(Icons.straighten_rounded),
                ),
              ],
              selected: {_unit},
              onSelectionChanged: (s) => _onUnitChanged(s.first),
            ),
            const SizedBox(height: AppTheme.spaceMD),

            // Height
            if (isUs)
              _UsHeightRow(
                ftCtrl: _heightFtCtrl,
                inCtrl: _heightInCtrl,
                metricEquiv: _height,
                onChanged: _onHeightUsChanged,
              )
            else
              _SliderRow(
                label: 'Height',
                helperText: 'Legal max in most EU countries: 4.0 m',
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
              helperText: isUs
                  ? 'Legal max in most US states: 8.5 ft'
                  : 'Legal max in most EU countries: 2.55 m',
              value: isUs ? TruckProfile.metersToFeet(_width) : _width,
              unit: isUs ? 'ft' : 'm',
              min: isUs ? TruckProfile.metersToFeet(2.0) : 2.0,
              max: isUs ? TruckProfile.metersToFeet(3.0) : 3.0,
              divisions: 10,
              onChanged: (v) => setState(
                () => _width = isUs ? TruckProfile.feetToMeters(v) : v,
              ),
            ),

            // Length
            _SliderRow(
              label: 'Length',
              helperText: isUs
                  ? 'Typical semi: 53 ft trailer + cab'
                  : 'Typical semi: ~21 m total',
              value: isUs ? TruckProfile.metersToFeet(_length) : _length,
              unit: isUs ? 'ft' : 'm',
              min: isUs ? TruckProfile.metersToFeet(6.0) : 6.0,
              max: isUs ? TruckProfile.metersToFeet(30.0) : 30.0,
              divisions: 24,
              fractionDigits: 1,
              onChanged: (v) => setState(
                () => _length = isUs ? TruckProfile.feetToMeters(v) : v,
              ),
            ),

            // Weight
            if (isUs)
              _UsWeightRow(
                lbsCtrl: _weightLbsCtrl,
                metricEquiv: _weight,
                onChanged: _onWeightLbsChanged,
              )
            else
              _SliderRow(
                label: 'Weight',
                helperText: 'EU gross weight limit: 40 t (44 t intermodal)',
                value: _weight,
                unit: 't',
                min: 5.0,
                max: 45.0,
                divisions: 40,
                fractionDigits: 1,
                onChanged: (v) => setState(() => _weight = v),
              ),

            // Axles
            _AxleRow(
              selected: _axles,
              onChanged: (n) => setState(() => _axles = n),
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
    if (_unit == TruckUnit.imperial) {
      final (ft, ins) = TruckProfile.metersToFeetInches(_height);
      final wFt = TruckProfile.metersToFeet(_width).toStringAsFixed(1);
      final lFt = TruckProfile.metersToFeet(_length).toStringAsFixed(1);
      final lbs = TruckProfile.metricTonsToPounds(_weight).round();
      return '${ft}ft ${ins}in H · ${wFt}ft W · ${lFt}ft L · ${lbs}lbs · $_axles axles'
          '${_hazmat ? ' · HAZMAT' : ''}';
    }
    final profile = TruckProfile(
      heightMeters: _height,
      widthMeters: _width,
      lengthMeters: _length,
      weightTons: _weight,
      axles: _axles,
      hazmat: _hazmat,
    );
    return profile.summary();
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
// US-units height input (ft + in) with metric equivalent
// ---------------------------------------------------------------------------

class _UsHeightRow extends StatelessWidget {
  const _UsHeightRow({
    required this.ftCtrl,
    required this.inCtrl,
    required this.metricEquiv,
    required this.onChanged,
  });

  final TextEditingController ftCtrl;
  final TextEditingController inCtrl;
  final double metricEquiv;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceXS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Height', style: tt.bodyMedium),
          const SizedBox(height: AppTheme.spaceXS),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ftCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Feet',
                    suffixText: 'ft',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: TextField(
                  controller: inCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Inches',
                    suffixText: 'in',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => onChanged(),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppTheme.spaceXS,
              left: AppTheme.spaceSM,
            ),
            child: Text(
              '≈ ${metricEquiv.toStringAsFixed(2)} m  ·  '
              "Common US limit: 13'6\"",
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// US-units weight input (lbs) with metric equivalent
// ---------------------------------------------------------------------------

class _UsWeightRow extends StatelessWidget {
  const _UsWeightRow({
    required this.lbsCtrl,
    required this.metricEquiv,
    required this.onChanged,
  });

  final TextEditingController lbsCtrl;
  final double metricEquiv;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceXS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Weight', style: tt.bodyMedium),
          const SizedBox(height: AppTheme.spaceXS),
          TextField(
            controller: lbsCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            decoration: const InputDecoration(
              labelText: 'Gross weight',
              suffixText: 'lbs',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => onChanged(),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: AppTheme.spaceXS,
              left: AppTheme.spaceSM,
            ),
            child: Text(
              '≈ ${metricEquiv.toStringAsFixed(1)} t  ·  '
              'US federal limit: 80,000 lbs',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Axle preset chip row
// ---------------------------------------------------------------------------

class _AxleRow extends StatelessWidget {
  const _AxleRow({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  static const _presets = [2, 3, 4, 5, 6, 7, 8, 9, 10];

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Axles', style: tt.bodyMedium),
          Text(
            'Total axle count affects weight distribution',
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppTheme.spaceXS),
          Wrap(
            spacing: 6.0,
            children: _presets
                .map(
                  (n) => FilterChip(
                    label: Text('$n'),
                    selected: selected == n,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      onChanged(n);
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ),
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

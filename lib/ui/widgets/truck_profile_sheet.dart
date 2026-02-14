import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/truck_profile.dart';
import '../../state/app_state.dart';

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
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Truck Profile',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          
          // Height slider
          Text('Height: ${_height.toStringAsFixed(2)}m'),
          Slider(
            value: _height,
            min: 2.5,
            max: 4.8,
            divisions: 23,
            label: '${_height.toStringAsFixed(2)}m',
            onChanged: (value) => setState(() => _height = value),
          ),
          
          // Width slider
          Text('Width: ${_width.toStringAsFixed(2)}m'),
          Slider(
            value: _width,
            min: 2.0,
            max: 3.0,
            divisions: 10,
            label: '${_width.toStringAsFixed(2)}m',
            onChanged: (value) => setState(() => _width = value),
          ),
          
          // Length slider
          Text('Length: ${_length.toStringAsFixed(1)}m'),
          Slider(
            value: _length,
            min: 6.0,
            max: 30.0,
            divisions: 24,
            label: '${_length.toStringAsFixed(1)}m',
            onChanged: (value) => setState(() => _length = value),
          ),
          
          // Weight slider
          Text('Weight: ${_weight.toStringAsFixed(1)} tons'),
          Slider(
            value: _weight,
            min: 5.0,
            max: 45.0,
            divisions: 40,
            label: '${_weight.toStringAsFixed(1)}t',
            onChanged: (value) => setState(() => _weight = value),
          ),
          
          // Axles dropdown
          Row(
            children: [
              const Text('Axles:'),
              const SizedBox(width: 16),
              DropdownButton<int>(
                value: _axles,
                items: List.generate(7, (i) => i + 2)
                    .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
                    .toList(),
                onChanged: (value) => setState(() => _axles = value!),
              ),
            ],
          ),
          
          // Hazmat switch
          SwitchListTile(
            title: const Text('Hazardous Materials'),
            value: _hazmat,
            onChanged: (value) => setState(() => _hazmat = value),
            contentPadding: EdgeInsets.zero,
          ),
          
          const SizedBox(height: 16),
          
          // Save button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('Save Profile'),
            ),
          ),
        ],
      ),
    );
  }

  void _save() {
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

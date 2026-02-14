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
  late double height;
  late double width;
  late double length;
  late double weight;
  late int axles;
  late bool hazmat;

  @override
  void initState() {
    super.initState();
    final profile = context.read<AppState>().truckProfile;
    height = profile.heightMeters;
    width = profile.widthMeters;
    length = profile.lengthMeters;
    weight = profile.weightTons;
    axles = profile.axles;
    hazmat = profile.hazmat;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Truck Profile',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 24),
            Text('Height: ${height.toStringAsFixed(2)}m'),
            Slider(
              value: height,
              min: 2.5,
              max: 4.8,
              divisions: 46,
              onChanged: (value) => setState(() => height = value),
            ),
            const SizedBox(height: 16),
            Text('Width: ${width.toStringAsFixed(2)}m'),
            Slider(
              value: width,
              min: 2.0,
              max: 3.0,
              divisions: 20,
              onChanged: (value) => setState(() => width = value),
            ),
            const SizedBox(height: 16),
            Text('Length: ${length.toStringAsFixed(1)}m'),
            Slider(
              value: length,
              min: 6.0,
              max: 30.0,
              divisions: 48,
              onChanged: (value) => setState(() => length = value),
            ),
            const SizedBox(height: 16),
            Text('Weight: ${weight.toStringAsFixed(1)} tons'),
            Slider(
              value: weight,
              min: 5.0,
              max: 45.0,
              divisions: 80,
              onChanged: (value) => setState(() => weight = value),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text('Axles: '),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButton<int>(
                    value: axles,
                    isExpanded: true,
                    items: List.generate(7, (i) => i + 2)
                        .map((n) => DropdownMenuItem(
                              value: n,
                              child: Text('$n axles'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => axles = value);
                      }
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('Hazmat'),
              value: hazmat,
              onChanged: (value) => setState(() => hazmat = value),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final newProfile = TruckProfile(
                    heightMeters: height,
                    widthMeters: width,
                    lengthMeters: length,
                    weightTons: weight,
                    axles: axles,
                    hazmat: hazmat,
                  );
                  context.read<AppState>().setTruck(newProfile);
                  Navigator.pop(context);
                },
                child: const Text('Save'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

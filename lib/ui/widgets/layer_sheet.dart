import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../state/app_state.dart';

/// Bottom sheet for managing POI layers
class LayerSheet extends StatelessWidget {
  const LayerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Consumer<AppState>(
        builder: (context, state, child) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'POI Layers',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: const Text('Fuel / Truck Stops'),
                subtitle: const Text('amenity=fuel'),
                value: state.enabledLayers.contains(PoiType.fuel),
                onChanged: (value) {
                  state.toggleLayer(PoiType.fuel, value);
                },
              ),
              SwitchListTile(
                title: const Text('Rest Areas'),
                subtitle: const Text('highway=rest_area'),
                value: state.enabledLayers.contains(PoiType.restArea),
                onChanged: (value) {
                  state.toggleLayer(PoiType.restArea, value);
                },
              ),
              const Divider(),
              const Padding(
                padding: EdgeInsets.all(8.0),
                child: Text(
                  'Note: Additional POI types (scales, gyms, parking) coming soon',
                  style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

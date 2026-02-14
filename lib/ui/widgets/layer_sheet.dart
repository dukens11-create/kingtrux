import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../state/app_state.dart';

/// Bottom sheet for managing POI layer visibility
class LayerSheet extends StatelessWidget {
  const LayerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'POI Layers',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 16),
              
              // Fuel stations
              SwitchListTile(
                title: const Text('Fuel / Truck Stops'),
                subtitle: const Text('amenity=fuel'),
                value: state.enabledPoiLayers.contains(PoiType.fuel),
                onChanged: (value) {
                  state.toggleLayer(PoiType.fuel, value);
                },
                contentPadding: EdgeInsets.zero,
              ),
              
              // Rest areas
              SwitchListTile(
                title: const Text('Rest Areas'),
                subtitle: const Text('highway=rest_area'),
                value: state.enabledPoiLayers.contains(PoiType.restArea),
                onChanged: (value) {
                  state.toggleLayer(PoiType.restArea, value);
                },
                contentPadding: EdgeInsets.zero,
              ),
              
              const SizedBox(height: 8),
              Text(
                'Note: Scales, gyms, and additional parking types will be added in future updates.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

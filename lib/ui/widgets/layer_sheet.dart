import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for managing POI layer visibility
class LayerSheet extends StatelessWidget {
  const LayerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTheme.spaceMD,
              AppTheme.spaceSM,
              AppTheme.spaceMD,
              AppTheme.spaceMD,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'POI Layers',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppTheme.spaceMD),

                // Fuel stations
                SwitchListTile(
                  secondary: Icon(
                    Icons.local_gas_station_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Fuel / Truck Stops'),
                  subtitle: const Text('amenity=fuel'),
                  value: state.enabledPoiLayers.contains(PoiType.fuel),
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    state.toggleLayer(PoiType.fuel, value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                // Rest areas
                SwitchListTile(
                  secondary: Icon(
                    Icons.local_parking_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Rest Areas'),
                  subtitle: const Text('highway=rest_area'),
                  value: state.enabledPoiLayers.contains(PoiType.restArea),
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    state.toggleLayer(PoiType.restArea, value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: AppTheme.spaceXS),
                Text(
                  'Scales, gyms, and additional parking types will be added in future updates.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


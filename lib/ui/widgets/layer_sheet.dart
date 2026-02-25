import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../models/truck_stop_brand.dart';
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

                // Scales
                SwitchListTile(
                  secondary: Icon(
                    Icons.scale_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Scales'),
                  subtitle: const Text('amenity=weighbridge'),
                  value: state.enabledPoiLayers.contains(PoiType.scale),
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    state.toggleLayer(PoiType.scale, value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                // Gyms
                SwitchListTile(
                  secondary: Icon(
                    Icons.fitness_center_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Gyms'),
                  subtitle: const Text('leisure=fitness_centre · amenity=gym'),
                  value: state.enabledPoiLayers.contains(PoiType.gym),
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    state.toggleLayer(PoiType.gym, value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                // Truck Stops
                SwitchListTile(
                  secondary: Icon(
                    Icons.local_shipping_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Major Truck Stops'),
                  subtitle: const Text('highway=services · amenity=truck_stop'),
                  value: state.enabledPoiLayers.contains(PoiType.truckStop),
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    state.toggleLayer(PoiType.truckStop, value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                // Per-brand toggles (visible when Truck Stops layer is on)
                if (state.enabledPoiLayers.contains(PoiType.truckStop)) ...[
                  Padding(
                    padding: const EdgeInsets.only(
                      left: AppTheme.spaceLG,
                      bottom: AppTheme.spaceXS,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: TruckStopBrand.values.map((brand) {
                        return CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            brand.displayName,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          value: state.enabledTruckStopBrands.contains(brand),
                          onChanged: (value) {
                            HapticFeedback.selectionClick();
                            state.toggleTruckStopBrand(brand, value ?? false);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],

                // Parking
                SwitchListTile(
                  secondary: Icon(
                    Icons.drive_eta_rounded,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  title: const Text('Parking'),
                  subtitle: const Text('amenity=parking'),
                  value: state.enabledPoiLayers.contains(PoiType.parking),
                  onChanged: (value) {
                    HapticFeedback.selectionClick();
                    state.toggleLayer(PoiType.parking, value);
                  },
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: AppTheme.spaceMD),

                // Load buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.my_location_rounded, size: 18),
                        label: const Text('Near Me'),
                        onPressed: state.enabledPoiLayers.isEmpty || state.isLoadingPois
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                state.loadPois();
                                Navigator.pop(context);
                              },
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceSM),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.route_rounded, size: 18),
                        label: const Text('Along Route'),
                        onPressed: state.enabledPoiLayers.isEmpty ||
                                state.isLoadingPois ||
                                state.routeResult == null
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                state.loadPoisAlongRoute();
                                Navigator.pop(context);
                              },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Bottom sheet displaying details for a single [Poi] with a favorite toggle.
class PoiDetailSheet extends StatelessWidget {
  const PoiDetailSheet({super.key, required this.poi});

  final Poi poi;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final isFav = state.favoritePois.contains(poi.id);
        final cs = Theme.of(context).colorScheme;

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
                // Header row: icon + name + favorite button
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Icon(
                        poiIcon(poi.type),
                        color: cs.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppTheme.spaceMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            poi.name,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            poiLabel(poi.type),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: cs.primary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
                      icon: Icon(
                        isFav ? Icons.star_rounded : Icons.star_border_rounded,
                        color: isFav ? Colors.amber : cs.onSurfaceVariant,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        state.toggleFavorite(poi.id);
                      },
                    ),
                  ],
                ),

                const Divider(height: AppTheme.spaceLG),

                // OSM tag details
                ..._buildTagRows(context, poi.tags, cs),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildTagRows(
    BuildContext context,
    Map<String, dynamic> tags,
    ColorScheme cs,
  ) {
    final rows = <Widget>[];

    void addRow(IconData icon, String label, String? value) {
      if (value == null || value.isEmpty) return;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXS),
          child: Row(
            children: [
              Icon(icon, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: AppTheme.spaceSM),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: Text(
                  value,
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    addRow(Icons.place_rounded, 'Address',
        tags['addr:full'] as String? ?? tags['addr:street'] as String?);
    addRow(Icons.phone_rounded, 'Phone', tags['phone'] as String?);
    addRow(Icons.language_rounded, 'Website', tags['website'] as String?);
    addRow(Icons.business_rounded, 'Operator', tags['operator'] as String?);
    addRow(Icons.branding_watermark_rounded, 'Brand', tags['brand'] as String?);
    addRow(Icons.access_time_rounded, 'Hours', tags['opening_hours'] as String?);

    if (rows.isEmpty) {
      rows.add(
        Text(
          'No additional details available.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      );
    }

    return rows;
  }

  /// Returns the Material icon for a given [PoiType].
  static IconData poiIcon(PoiType type) {
    switch (type) {
      case PoiType.fuel:
        return Icons.local_gas_station_rounded;
      case PoiType.truckStop:
        return Icons.local_shipping_rounded;
      case PoiType.parking:
        return Icons.local_parking_rounded;
      case PoiType.scale:
        return Icons.scale_rounded;
      case PoiType.restArea:
        return Icons.deck_rounded;
      case PoiType.gym:
        return Icons.fitness_center_rounded;
    }
  }

  /// Returns the human-readable label for a given [PoiType].
  static String poiLabel(PoiType type) {
    switch (type) {
      case PoiType.fuel:
        return 'Fuel Station';
      case PoiType.truckStop:
        return 'Truck Stop';
      case PoiType.parking:
        return 'Parking';
      case PoiType.scale:
        return 'Weigh Scale';
      case PoiType.restArea:
        return 'Rest Area';
      case PoiType.gym:
        return 'Gym';
    }
  }
}

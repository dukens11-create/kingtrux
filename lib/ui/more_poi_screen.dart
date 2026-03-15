import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/poi.dart';
import '../state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/poi_browser_sheet.dart';

/// Full-screen "More" page showing all POI categories, brands, amenities,
/// security options, and dealers as chip-style buttons grouped into sections.
///
/// Items that map to an existing [PoiType] layer enable the layer and open
/// [PoiBrowserSheet] filtered to that type.  Unsupported items show a
/// "Coming soon" [SnackBar].
class MorePoiScreen extends StatelessWidget {
  const MorePoiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          return ListView(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            children: [
              // ── Brands / top categories ──────────────────────────────
              _buildSection(
                context,
                state,
                label: 'Brands & Categories',
                items: [
                  _MoreItem(
                    'Pilot & Flying J',
                    Icons.local_gas_station_rounded,
                    null,
                  ),
                  _MoreItem(
                    'TA & Petro',
                    Icons.local_shipping_rounded,
                    null,
                  ),
                  _MoreItem(
                    "Love's",
                    Icons.local_gas_station_rounded,
                    null,
                  ),
                  _MoreItem(
                    'KwikTrip/KwikStar',
                    Icons.local_gas_station_rounded,
                    null,
                  ),
                  _MoreItem('AM Best', Icons.star_rounded, null),
                  _MoreItem('One9', Icons.local_gas_station_rounded, null),
                  _MoreItem(
                    'Road Ranger',
                    Icons.local_shipping_rounded,
                    null,
                  ),
                  _MoreItem(
                    'Truck Stops',
                    Icons.local_shipping_rounded,
                    PoiType.truckStop,
                  ),
                  _MoreItem(
                    'Fuel',
                    Icons.local_gas_station_rounded,
                    PoiType.fuel,
                  ),
                  _MoreItem('Walmarts', Icons.store_rounded, null),
                  _MoreItem(
                    'Rest Areas',
                    Icons.deck_rounded,
                    PoiType.restArea,
                  ),
                  _MoreItem(
                    'Parking',
                    Icons.local_parking_rounded,
                    PoiType.parking,
                  ),
                  _MoreItem(
                    'Weigh Stations',
                    Icons.scale_rounded,
                    PoiType.scale,
                  ),
                  _MoreItem('Hotels', Icons.hotel_rounded, null),
                  _MoreItem('Scales', Icons.scale_rounded, PoiType.scale),
                  _MoreItem(
                    'Gyms',
                    Icons.fitness_center_rounded,
                    PoiType.gym,
                  ),
                  _MoreItem('Stores', Icons.store_rounded, null),
                  _MoreItem('Restaurants', Icons.restaurant_rounded, null),
                ],
              ),
              const SizedBox(height: AppTheme.spaceMD),

              // ── Truck Services ────────────────────────────────────────
              _buildSection(
                context,
                state,
                label: 'Truck Services',
                items: [
                  _MoreItem(
                    'Truck Washes',
                    Icons.local_car_wash_rounded,
                    null,
                  ),
                  _MoreItem('Repair Shops', Icons.build_rounded, null),
                  _MoreItem('Tire Care', Icons.tire_repair_rounded, null),
                ],
              ),
              const SizedBox(height: AppTheme.spaceMD),

              // ── Amenities ─────────────────────────────────────────────
              _buildSection(
                context,
                state,
                label: 'Amenities',
                items: [
                  _MoreItem(
                    'Overnight Parking',
                    Icons.local_parking_rounded,
                    null,
                  ),
                  _MoreItem('ATM', Icons.atm_rounded, null),
                  _MoreItem(
                    'Laundry',
                    Icons.local_laundry_service_rounded,
                    null,
                  ),
                  _MoreItem('Shower', Icons.shower_rounded, null),
                  _MoreItem('Pet Friendly', Icons.pets_rounded, null),
                  _MoreItem('WiFi', Icons.wifi_rounded, null),
                  _MoreItem(
                    'Onsite Gym',
                    Icons.fitness_center_rounded,
                    PoiType.gym,
                  ),
                  _MoreItem('Fax Scan', Icons.scanner_rounded, null),
                  _MoreItem(
                    'Pre-additized Diesel',
                    Icons.local_gas_station_rounded,
                    null,
                  ),
                  _MoreItem('Winter Diesel', Icons.ac_unit_rounded, null),
                ],
              ),
              const SizedBox(height: AppTheme.spaceMD),

              // ── Security ──────────────────────────────────────────────
              _buildSection(
                context,
                state,
                label: 'Security',
                items: [
                  _MoreItem(
                    'Lighted Parking',
                    Icons.local_parking_rounded,
                    null,
                  ),
                  _MoreItem(
                    'Lighted Bathroom Access',
                    Icons.wc_rounded,
                    null,
                  ),
                  _MoreItem(
                    'Lighted Lounge Area',
                    Icons.chair_rounded,
                    null,
                  ),
                  _MoreItem(
                    'Lighted Shower Facilities (24/7)',
                    Icons.shower_rounded,
                    null,
                  ),
                  _MoreItem(
                    'Lighted Laundry Facilities (24/7)',
                    Icons.local_laundry_service_rounded,
                    null,
                  ),
                  _MoreItem(
                    'Maintenance Available (24/7)',
                    Icons.build_rounded,
                    null,
                  ),
                  _MoreItem(
                    'Security Present Onsite',
                    Icons.security_rounded,
                    null,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceMD),

              // ── Dealers ───────────────────────────────────────────────
              _buildSection(
                context,
                state,
                label: 'Dealers',
                items: [
                  _MoreItem('Speedco', Icons.local_shipping_rounded, null),
                  _MoreItem(
                    'Thermo King',
                    Icons.local_shipping_rounded,
                    null,
                  ),
                  _MoreItem('Volvo', Icons.local_shipping_rounded, null),
                  _MoreItem(
                    'Freightliner',
                    Icons.local_shipping_rounded,
                    null,
                  ),
                  _MoreItem('Kenworth', Icons.local_shipping_rounded, null),
                  _MoreItem(
                    'Peterbilt',
                    Icons.local_shipping_rounded,
                    null,
                  ),
                  _MoreItem(
                    'Utility Trailers',
                    Icons.local_shipping_rounded,
                    null,
                  ),
                  _MoreItem('Carrier', Icons.local_shipping_rounded, null),
                  _MoreItem('Mack', Icons.local_shipping_rounded, null),
                  _MoreItem(
                    'International',
                    Icons.local_shipping_rounded,
                    null,
                  ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceLG),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    AppState state, {
    required String label,
    required List<_MoreItem> items,
  }) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppTheme.spaceSM),
          child: Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
        Wrap(
          spacing: AppTheme.spaceSM,
          runSpacing: AppTheme.spaceSM,
          children: items
              .map(
                (item) => _MoreChip(
                  item: item,
                  onTap: () => _handleItemTap(context, state, item),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  void _handleItemTap(
    BuildContext context,
    AppState state,
    _MoreItem item,
  ) {
    HapticFeedback.selectionClick();
    final poiType = item.poiType;
    if (poiType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${item.label} – Coming soon'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    // Enable the layer and open the POI browser.
    state.toggleLayer(poiType, true);
    state.loadPois();
    // Capture the overlay context before popping so the new sheet can be
    // shown from a valid BuildContext after this screen is dismissed.
    final overlayCtx = Navigator.of(context).overlay!.context;
    Navigator.of(context).pop();
    showModalBottomSheet<void>(
      context: overlayCtx,
      isScrollControlled: true,
      builder: (_) => const PoiBrowserSheet(),
    );
  }
}

// ---------------------------------------------------------------------------
// Data model for a single "More" chip item
// ---------------------------------------------------------------------------

class _MoreItem {
  const _MoreItem(this.label, this.icon, this.poiType);

  final String label;
  final IconData icon;

  /// Non-null when this item maps to an existing [PoiType] layer.
  final PoiType? poiType;
}

// ---------------------------------------------------------------------------
// Individual chip widget
// ---------------------------------------------------------------------------

class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.item, required this.onTap});

  final _MoreItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isSupported = item.poiType != null;

    return ActionChip(
      avatar: Icon(
        item.icon,
        size: 16,
        color: isSupported ? cs.onPrimaryContainer : cs.onSurfaceVariant,
      ),
      label: Text(item.label),
      backgroundColor:
          isSupported ? cs.primaryContainer : cs.surfaceContainerLow,
      labelStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: isSupported ? cs.onPrimaryContainer : cs.onSurfaceVariant,
          ),
      onPressed: onTap,
    );
  }
}

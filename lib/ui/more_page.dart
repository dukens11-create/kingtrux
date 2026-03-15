import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/poi.dart';
import '../state/app_state.dart';
import 'theme/app_theme.dart';
import 'widgets/poi_browser_sheet.dart';

/// Full-screen "More" page accessible from the [PoiHubSheet].
///
/// Displays scrollable sections of chip-style buttons that let the driver
/// quickly access additional POI categories and service filters.
///
/// **Sections:**
/// - Top categories (mirrors the hub but with more entries)
/// - Truck Services (Truck Washes, Repair Shops, Tire Care, …)
/// - Amenities (Overnight Parking, ATM, Laundry, Shower, WiFi, …)
/// - Security (Lighted Parking, …)
/// - Dealers (Volvo, Freightliner, Kenworth, …)
///
/// Tapping a supported item enables the layer and opens [PoiBrowserSheet].
/// Unsupported items show a "Coming soon" [SnackBar].
class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('More'),
        centerTitle: true,
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          return _MorePageBody(state: state);
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body
// ---------------------------------------------------------------------------

class _MorePageBody extends StatelessWidget {
  const _MorePageBody({required this.state});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      children: [
        // Categories section
        _buildSection(
          context,
          title: 'Categories',
          items: _categories(context),
        ),
        const SizedBox(height: AppTheme.spaceLG),

        // Truck Services section
        _buildSection(
          context,
          title: 'Truck Services',
          items: _truckServices(context),
        ),
        const SizedBox(height: AppTheme.spaceLG),

        // Amenities section
        _buildSection(
          context,
          title: 'Amenities',
          items: _amenities(context),
        ),
        const SizedBox(height: AppTheme.spaceLG),

        // Security section
        _buildSection(
          context,
          title: 'Security',
          items: _security(context),
        ),
        const SizedBox(height: AppTheme.spaceLG),

        // Dealers section
        _buildSection(
          context,
          title: 'Dealers',
          items: _dealers(context),
        ),

        // Bottom safe-area buffer
        const SizedBox(height: AppTheme.spaceLG),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Section builder
  // ---------------------------------------------------------------------------

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<_MoreItem> items,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      key: Key('more_section_$title'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: AppTheme.spaceSM),
        Wrap(
          spacing: AppTheme.spaceSM,
          runSpacing: AppTheme.spaceSM,
          children: items
              .map((item) => _MoreChip(item: item))
              .toList(),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Category items (map to existing PoiTypes)
  // ---------------------------------------------------------------------------

  List<_MoreItem> _categories(BuildContext context) => [
        _MoreItem(
          icon: Icons.local_shipping_rounded,
          label: 'Truck Stops',
          onTap: () => _openPoiLayer(context, PoiType.truckStop),
        ),
        _MoreItem(
          icon: Icons.scale_rounded,
          label: 'Weigh Stations',
          onTap: () => _openPoiLayer(context, PoiType.scale),
        ),
        _MoreItem(
          icon: Icons.local_parking_rounded,
          label: 'Parking',
          onTap: () => _openPoiLayer(context, PoiType.parking),
        ),
        _MoreItem(
          icon: Icons.local_gas_station_rounded,
          label: 'Fuel',
          onTap: () => _openPoiLayer(context, PoiType.fuel),
        ),
        _MoreItem(
          icon: Icons.deck_rounded,
          label: 'Rest Areas',
          onTap: () => _openPoiLayer(context, PoiType.restArea),
        ),
        _MoreItem(
          icon: Icons.fitness_center_rounded,
          label: 'Gyms',
          onTap: () => _openPoiLayer(context, PoiType.gym),
        ),
        _MoreItem(
          icon: Icons.store_rounded,
          label: 'Walmarts',
          onTap: () => _showComingSoon(context, 'Walmarts'),
        ),
        _MoreItem(
          icon: Icons.local_car_wash_rounded,
          label: 'Truck Washes',
          onTap: () => _showComingSoon(context, 'Truck Washes'),
        ),
      ];

  // ---------------------------------------------------------------------------
  // Truck Services items
  // ---------------------------------------------------------------------------

  List<_MoreItem> _truckServices(BuildContext context) => [
        _MoreItem(
          icon: Icons.build_rounded,
          label: 'Repair Shops',
          onTap: () => _showComingSoon(context, 'Repair Shops'),
        ),
        _MoreItem(
          icon: Icons.tire_repair_rounded,
          label: 'Tire Care',
          onTap: () => _showComingSoon(context, 'Tire Care'),
        ),
        _MoreItem(
          icon: Icons.local_car_wash_rounded,
          label: 'Truck Washes',
          onTap: () => _showComingSoon(context, 'Truck Washes'),
        ),
        _MoreItem(
          icon: Icons.electric_bolt_rounded,
          label: 'DEF / AdBlue',
          onTap: () => _showComingSoon(context, 'DEF / AdBlue'),
        ),
        _MoreItem(
          icon: Icons.oil_barrel_rounded,
          label: 'Lube',
          onTap: () => _showComingSoon(context, 'Lube'),
        ),
        _MoreItem(
          icon: Icons.car_crash_rounded,
          label: 'Roadside Help',
          onTap: () => _showComingSoon(context, 'Roadside Help'),
        ),
      ];

  // ---------------------------------------------------------------------------
  // Amenities items
  // ---------------------------------------------------------------------------

  List<_MoreItem> _amenities(BuildContext context) => [
        _MoreItem(
          icon: Icons.bed_rounded,
          label: 'Overnight Parking',
          onTap: () => _showComingSoon(context, 'Overnight Parking'),
        ),
        _MoreItem(
          icon: Icons.atm_rounded,
          label: 'ATM',
          onTap: () => _showComingSoon(context, 'ATM'),
        ),
        _MoreItem(
          icon: Icons.local_laundry_service_rounded,
          label: 'Laundry',
          onTap: () => _showComingSoon(context, 'Laundry'),
        ),
        _MoreItem(
          icon: Icons.shower_rounded,
          label: 'Shower',
          onTap: () => _showComingSoon(context, 'Shower'),
        ),
        _MoreItem(
          icon: Icons.pets_rounded,
          label: 'Pet Friendly',
          onTap: () => _showComingSoon(context, 'Pet Friendly'),
        ),
        _MoreItem(
          icon: Icons.wifi_rounded,
          label: 'WiFi',
          onTap: () => _showComingSoon(context, 'WiFi'),
        ),
        _MoreItem(
          icon: Icons.restaurant_rounded,
          label: 'Food',
          onTap: () => _showComingSoon(context, 'Food'),
        ),
        _MoreItem(
          icon: Icons.local_cafe_rounded,
          label: 'Coffee',
          onTap: () => _showComingSoon(context, 'Coffee'),
        ),
      ];

  // ---------------------------------------------------------------------------
  // Security items
  // ---------------------------------------------------------------------------

  List<_MoreItem> _security(BuildContext context) => [
        _MoreItem(
          icon: Icons.light_mode_rounded,
          label: 'Lighted Parking',
          onTap: () => _showComingSoon(context, 'Lighted Parking'),
        ),
        _MoreItem(
          icon: Icons.videocam_rounded,
          label: 'Camera Surveillance',
          onTap: () => _showComingSoon(context, 'Camera Surveillance'),
        ),
        _MoreItem(
          icon: Icons.security_rounded,
          label: 'Security Staff',
          onTap: () => _showComingSoon(context, 'Security Staff'),
        ),
        _MoreItem(
          icon: Icons.fence_rounded,
          label: 'Fenced Lot',
          onTap: () => _showComingSoon(context, 'Fenced Lot'),
        ),
      ];

  // ---------------------------------------------------------------------------
  // Dealers items
  // ---------------------------------------------------------------------------

  List<_MoreItem> _dealers(BuildContext context) => [
        _MoreItem(
          icon: Icons.directions_car_rounded,
          label: 'Volvo',
          onTap: () => _showComingSoon(context, 'Volvo Dealers'),
        ),
        _MoreItem(
          icon: Icons.directions_car_rounded,
          label: 'Freightliner',
          onTap: () => _showComingSoon(context, 'Freightliner Dealers'),
        ),
        _MoreItem(
          icon: Icons.directions_car_rounded,
          label: 'Kenworth',
          onTap: () => _showComingSoon(context, 'Kenworth Dealers'),
        ),
        _MoreItem(
          icon: Icons.directions_car_rounded,
          label: 'Peterbilt',
          onTap: () => _showComingSoon(context, 'Peterbilt Dealers'),
        ),
        _MoreItem(
          icon: Icons.directions_car_rounded,
          label: 'International',
          onTap: () => _showComingSoon(context, 'International Dealers'),
        ),
        _MoreItem(
          icon: Icons.directions_car_rounded,
          label: 'Mack',
          onTap: () => _showComingSoon(context, 'Mack Dealers'),
        ),
        _MoreItem(
          icon: Icons.directions_car_rounded,
          label: 'Western Star',
          onTap: () => _showComingSoon(context, 'Western Star Dealers'),
        ),
        _MoreItem(
          icon: Icons.more_horiz_rounded,
          label: 'All Brands',
          onTap: () => _showComingSoon(context, 'All Truck Brands'),
        ),
      ];

  // ---------------------------------------------------------------------------
  // Action helpers
  // ---------------------------------------------------------------------------

  /// Enables the given [type] layer and opens [PoiBrowserSheet] filtered to it.
  void _openPoiLayer(BuildContext context, PoiType type) {
    HapticFeedback.selectionClick();
    if (!state.enabledPoiLayers.contains(type)) {
      state.toggleLayer(type, true);
    }
    Navigator.of(context).pop();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ChangeNotifierProvider.value(
        value: state,
        child: const PoiBrowserSheet(),
      ),
    );
  }

  /// Shows a "Coming soon" snack bar for unimplemented items.
  void _showComingSoon(BuildContext context, String feature) {
    HapticFeedback.selectionClick();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature – Coming soon'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// More item model
// ---------------------------------------------------------------------------

class _MoreItem {
  const _MoreItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

// ---------------------------------------------------------------------------
// Chip button
// ---------------------------------------------------------------------------

/// A rounded chip-style button with an icon and label, used in [_MorePageBody].
class _MoreChip extends StatelessWidget {
  const _MoreChip({required this.item});

  final _MoreItem item;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        onTap: item.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceSM,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(item.icon, size: 18, color: cs.primary),
              const SizedBox(width: AppTheme.spaceXS),
              Text(
                item.label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

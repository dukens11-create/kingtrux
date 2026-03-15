import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/poi.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Full-screen "More" POI category page.
///
/// Displays all available POI categories organised into sections with
/// chip-style buttons. Tapping a chip either:
/// - Enables the corresponding [PoiType] layer and pops the route, returning
///   the selected [PoiType] as the route result so the caller can open the
///   POI browser pre-filtered to that type, or
/// - Shows a "Coming soon" [SnackBar] for features not yet implemented.
class MorePoiScreen extends StatelessWidget {
  const MorePoiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: const Text('More'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceSM,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Top chip grid ────────────────────────────────────────────
            _SectionChips(
              header: null,
              chips: [
                _PoiChip(
                  label: 'Pilot & Flying J',
                  icon: Icons.local_gas_station_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Pilot & Flying J'),
                ),
                _PoiChip(
                  label: 'TA & Petro',
                  icon: Icons.local_shipping_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'TA & Petro'),
                ),
                _PoiChip(
                  label: "Love's",
                  icon: Icons.local_gas_station_rounded,
                  onTap: (ctx) => _comingSoon(ctx, "Love's"),
                ),
                _PoiChip(
                  label: 'KwikTrip/KwikStar',
                  icon: Icons.local_convenience_store_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'KwikTrip/KwikStar'),
                ),
                _PoiChip(
                  label: 'AM Best',
                  icon: Icons.star_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'AM Best'),
                ),
                _PoiChip(
                  label: 'One9',
                  icon: Icons.local_gas_station_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'One9'),
                ),
                _PoiChip(
                  label: 'Road Ranger',
                  icon: Icons.local_shipping_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Road Ranger'),
                ),
                _PoiChip(
                  label: 'Truck Stops',
                  icon: Icons.local_shipping_rounded,
                  poiType: PoiType.truckStop,
                ),
                _PoiChip(
                  label: 'Fuel',
                  icon: Icons.local_gas_station_rounded,
                  poiType: PoiType.fuel,
                ),
                _PoiChip(
                  label: 'Walmarts',
                  icon: Icons.shopping_cart_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Walmarts'),
                ),
                _PoiChip(
                  label: 'Rest Areas',
                  icon: Icons.deck_rounded,
                  poiType: PoiType.restArea,
                ),
                _PoiChip(
                  label: 'Parking',
                  icon: Icons.local_parking_rounded,
                  poiType: PoiType.parking,
                ),
                _PoiChip(
                  label: 'Weigh Stations',
                  icon: Icons.scale_rounded,
                  poiType: PoiType.scale,
                ),
                _PoiChip(
                  label: 'Hotels',
                  icon: Icons.hotel_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Hotels'),
                ),
                _PoiChip(
                  label: 'Scales',
                  icon: Icons.scale_rounded,
                  poiType: PoiType.scale,
                ),
                _PoiChip(
                  label: 'Gyms',
                  icon: Icons.fitness_center_rounded,
                  poiType: PoiType.gym,
                ),
                _PoiChip(
                  label: 'Stores',
                  icon: Icons.store_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Stores'),
                ),
                _PoiChip(
                  label: 'Restaurants',
                  icon: Icons.restaurant_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Restaurants'),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spaceMD),

            // ── Truck Services ────────────────────────────────────────────
            _SectionChips(
              header: 'Truck Services',
              chips: [
                _PoiChip(
                  label: 'Truck Washes',
                  icon: Icons.local_car_wash_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Truck Washes'),
                ),
                _PoiChip(
                  label: 'Repair Shops',
                  icon: Icons.build_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Repair Shops'),
                ),
                _PoiChip(
                  label: 'Tire Care',
                  icon: Icons.tire_repair_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Tire Care'),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spaceMD),

            // ── Amenities ─────────────────────────────────────────────────
            _SectionChips(
              header: 'Amenities',
              chips: [
                _PoiChip(
                  label: 'Overnight Parking',
                  icon: Icons.nightlight_round,
                  onTap: (ctx) => _comingSoon(ctx, 'Overnight Parking'),
                ),
                _PoiChip(
                  label: 'ATM',
                  icon: Icons.atm_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'ATM'),
                ),
                _PoiChip(
                  label: 'Laundry',
                  icon: Icons.local_laundry_service_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Laundry'),
                ),
                _PoiChip(
                  label: 'Shower',
                  icon: Icons.shower_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Shower'),
                ),
                _PoiChip(
                  label: 'Pet Friendly',
                  icon: Icons.pets_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Pet Friendly'),
                ),
                _PoiChip(
                  label: 'WiFi',
                  icon: Icons.wifi_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'WiFi'),
                ),
                _PoiChip(
                  label: 'Onsite Gym',
                  icon: Icons.fitness_center_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Onsite Gym'),
                ),
                _PoiChip(
                  label: 'Fax / Scan',
                  icon: Icons.print_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Fax / Scan'),
                ),
                _PoiChip(
                  label: 'Pre-additized Diesel',
                  icon: Icons.local_gas_station_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Pre-additized Diesel'),
                ),
                _PoiChip(
                  label: 'Winter Diesel',
                  icon: Icons.ac_unit_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Winter Diesel'),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spaceMD),

            // ── Security ──────────────────────────────────────────────────
            _SectionChips(
              header: 'Security',
              chips: [
                _PoiChip(
                  label: 'Lighted Parking',
                  icon: Icons.lightbulb_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Lighted Parking'),
                ),
                _PoiChip(
                  label: 'Lighted Bathroom Access',
                  icon: Icons.wc_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Lighted Bathroom Access'),
                ),
                _PoiChip(
                  label: 'Lighted Lounge Area',
                  icon: Icons.weekend_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Lighted Lounge Area'),
                ),
                _PoiChip(
                  label: 'Lighted Shower Facilities (24/7)',
                  icon: Icons.shower_rounded,
                  onTap: (ctx) =>
                      _comingSoon(ctx, 'Lighted Shower Facilities (24/7)'),
                ),
                _PoiChip(
                  label: 'Lighted Laundry Facilities (24/7)',
                  icon: Icons.local_laundry_service_rounded,
                  onTap: (ctx) =>
                      _comingSoon(ctx, 'Lighted Laundry Facilities (24/7)'),
                ),
                _PoiChip(
                  label: 'Maintenance Available (24/7)',
                  icon: Icons.build_circle_rounded,
                  onTap: (ctx) =>
                      _comingSoon(ctx, 'Maintenance Available (24/7)'),
                ),
                _PoiChip(
                  label: 'Security Present Onsite',
                  icon: Icons.security_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Security Present Onsite'),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spaceMD),

            // ── Dealers ───────────────────────────────────────────────────
            _SectionChips(
              header: 'Dealers',
              chips: [
                _PoiChip(
                  label: 'Speedco',
                  icon: Icons.speed_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Speedco'),
                ),
                _PoiChip(
                  label: 'Thermo King',
                  icon: Icons.ac_unit_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Thermo King'),
                ),
                _PoiChip(
                  label: 'Volvo',
                  icon: Icons.local_shipping_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Volvo'),
                ),
                _PoiChip(
                  label: 'Freightliner',
                  icon: Icons.local_shipping_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Freightliner'),
                ),
                _PoiChip(
                  label: 'Kenworth',
                  icon: Icons.local_shipping_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Kenworth'),
                ),
                _PoiChip(
                  label: 'Peterbilt',
                  icon: Icons.local_shipping_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Peterbilt'),
                ),
                _PoiChip(
                  label: 'Utility Trailers',
                  icon: Icons.rv_hookup_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Utility Trailers'),
                ),
                _PoiChip(
                  label: 'Carrier',
                  icon: Icons.local_shipping_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Carrier'),
                ),
                _PoiChip(
                  label: 'Mack',
                  icon: Icons.local_shipping_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'Mack'),
                ),
                _PoiChip(
                  label: 'International',
                  icon: Icons.local_shipping_rounded,
                  onTap: (ctx) => _comingSoon(ctx, 'International'),
                ),
              ],
            ),

            const SizedBox(height: AppTheme.spaceLG),
          ],
        ),
      ),
    );
  }

  /// Shows a "Coming soon" snack-bar for features not yet implemented.
  static void _comingSoon(BuildContext context, String feature) {
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
// Section widget
// ---------------------------------------------------------------------------

/// A labelled section with a responsive [Wrap] of [_PoiChipButton] widgets.
class _SectionChips extends StatelessWidget {
  const _SectionChips({
    required this.header,
    required this.chips,
  });

  final String? header;
  final List<_PoiChip> chips;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (header != null) ...[
          Padding(
            padding: const EdgeInsets.only(
              bottom: AppTheme.spaceSM,
              top: AppTheme.spaceXS,
            ),
            child: Text(
              header!.toUpperCase(),
              style: tt.labelLarge?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: AppTheme.spaceSM),
        ],
        Wrap(
          spacing: AppTheme.spaceSM,
          runSpacing: AppTheme.spaceSM,
          children: chips.map((chip) => _PoiChipButton(chip: chip)).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Chip data model
// ---------------------------------------------------------------------------

/// Data class describing a single POI chip button.
class _PoiChip {
  const _PoiChip({
    required this.label,
    required this.icon,
    this.poiType,
    this.onTap,
  }) : assert(
          poiType != null || onTap != null,
          'Either poiType or onTap must be provided',
        );

  final String label;
  final IconData icon;

  /// When non-null, tapping enables this [PoiType] layer, modifies the
  /// [AppState], and pops the route returning this type.
  final PoiType? poiType;

  /// Custom tap handler (used for "Coming soon" items and brand chips).
  final void Function(BuildContext context)? onTap;
}

// ---------------------------------------------------------------------------
// Chip button widget
// ---------------------------------------------------------------------------

/// A rounded-rectangle chip-style button rendered inside the More page.
class _PoiChipButton extends StatelessWidget {
  const _PoiChipButton({required this.chip});

  final _PoiChip chip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppTheme.radiusXL),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radiusXL),
        onTap: () => _handleTap(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppTheme.spaceMD,
            vertical: AppTheme.spaceSM,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(chip.icon, size: 16, color: cs.primary),
              const SizedBox(width: AppTheme.spaceXS),
              Text(
                chip.label,
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurface,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleTap(BuildContext context) {
    if (chip.onTap != null) {
      chip.onTap!(context);
      return;
    }

    final poiType = chip.poiType;
    if (poiType == null) return;

    HapticFeedback.selectionClick();

    // Enable only this layer in AppState (disable others for a focused view).
    final state = context.read<AppState>();
    for (final t in PoiType.values) {
      state.toggleLayer(t, t == poiType);
    }

    // Pop, returning the selected PoiType so the caller can open the POI
    // browser. Using pop<PoiType> avoids any use-after-unmount issues.
    Navigator.of(context).pop<PoiType>(poiType);
  }
}

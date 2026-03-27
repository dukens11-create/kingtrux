import 'package:flutter/material.dart';
import '../../models/truck_stop_brand.dart';

/// Returns the Flutter asset path for [brand]'s bundled logo PNG.
///
/// Returns `null` for brands that do not have a local asset (e.g. [one9],
/// [amBest]).  Callers should fall back to a generic icon in that case.
///
/// Assets live in `assets/logos/` and must be declared under `flutter/assets`
/// in `pubspec.yaml`.
String? truckStopBrandAssetPath(TruckStopBrand brand) {
  switch (brand) {
    case TruckStopBrand.pilot:
    case TruckStopBrand.flyingJ:
      return 'assets/logos/pilot.png';
    case TruckStopBrand.loves:
      return 'assets/logos/loves.png';
    case TruckStopBrand.ta:
      return 'assets/logos/ta.png';
    case TruckStopBrand.petro:
      return 'assets/logos/petro.png';
    case TruckStopBrand.roadys:
      return 'assets/logos/roadys.png';
    case TruckStopBrand.sappBros:
      return 'assets/logos/sapp_bros.png';
    case TruckStopBrand.roadRanger:
      return 'assets/logos/road_ranger.png';
    case TruckStopBrand.kwikTrip:
      return 'assets/logos/kwik_trip.png';
    case TruckStopBrand.maverik:
      return 'assets/logos/maverik.png';
    case TruckStopBrand.caseys:
      return 'assets/logos/caseys.png';
    case TruckStopBrand.shell:
      return 'assets/logos/shell.png';
    case TruckStopBrand.bp:
      return 'assets/logos/bp.png';
    case TruckStopBrand.total:
      return 'assets/logos/total.png';
    case TruckStopBrand.petroCanada:
      return 'assets/logos/petro_canada.png';
    case TruckStopBrand.esso:
      return 'assets/logos/esso.png';
    case TruckStopBrand.one9:
    case TruckStopBrand.amBest:
      return null;
  }
}

/// Renders a brand logo thumbnail for a [TruckStopBrand].
///
/// If the brand has a bundled asset, it is shown inside a circular white
/// container.  If the asset path is `null` (brand without a logo) or the
/// image fails to load, a generic truck-stop icon is shown instead.
///
/// The widget is [size] × [size] logical pixels (default 40 × 40).
class TruckStopBrandLogo extends StatelessWidget {
  const TruckStopBrandLogo({
    super.key,
    required this.brand,
    this.size = 40.0,
  });

  final TruckStopBrand brand;
  final double size;

  @override
  Widget build(BuildContext context) {
    final assetPath = truckStopBrandAssetPath(brand);

    if (assetPath == null) {
      return _FallbackLogo(size: size);
    }

    return ClipOval(
      child: Image.asset(
        assetPath,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _FallbackLogo(size: size),
      ),
    );
  }
}

/// Generic truck-stop icon used when no brand logo is available.
class _FallbackLogo extends StatelessWidget {
  const _FallbackLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primaryContainer,
      ),
      child: Icon(
        Icons.local_shipping_rounded,
        size: size * 0.55,
        color: cs.onPrimaryContainer,
      ),
    );
  }
}

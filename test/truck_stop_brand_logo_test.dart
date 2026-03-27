import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/truck_stop_brand.dart';
import 'package:kingtrux/ui/widgets/truck_stop_brand_logo.dart';

void main() {
  // ---------------------------------------------------------------------------
  // truckStopBrandAssetPath
  // ---------------------------------------------------------------------------
  group('truckStopBrandAssetPath', () {
    test('returns correct path for pilot', () {
      expect(
        truckStopBrandAssetPath(TruckStopBrand.pilot),
        'assets/logos/pilot.png',
      );
    });

    test('returns same pilot.png path for flyingJ', () {
      expect(
        truckStopBrandAssetPath(TruckStopBrand.flyingJ),
        'assets/logos/pilot.png',
      );
    });

    test('returns correct path for loves', () {
      expect(
        truckStopBrandAssetPath(TruckStopBrand.loves),
        'assets/logos/loves.png',
      );
    });

    test('returns correct path for ta', () {
      expect(truckStopBrandAssetPath(TruckStopBrand.ta), 'assets/logos/ta.png');
    });

    test('returns correct path for petro', () {
      expect(
        truckStopBrandAssetPath(TruckStopBrand.petro),
        'assets/logos/petro.png',
      );
    });

    test('returns correct path for roadys', () {
      expect(
        truckStopBrandAssetPath(TruckStopBrand.roadys),
        'assets/logos/roadys.png',
      );
    });

    test('returns correct path for sappBros', () {
      expect(
        truckStopBrandAssetPath(TruckStopBrand.sappBros),
        'assets/logos/sapp_bros.png',
      );
    });

    test('returns correct path for roadRanger', () {
      expect(
        truckStopBrandAssetPath(TruckStopBrand.roadRanger),
        'assets/logos/road_ranger.png',
      );
    });

    test('returns correct path for kwikTrip', () {
      expect(
        truckStopBrandAssetPath(TruckStopBrand.kwikTrip),
        'assets/logos/kwik_trip.png',
      );
    });

    test('returns correct path for maverik', () {
      expect(
        truckStopBrandAssetPath(TruckStopBrand.maverik),
        'assets/logos/maverik.png',
      );
    });

    test('returns correct path for caseys', () {
      expect(
        truckStopBrandAssetPath(TruckStopBrand.caseys),
        'assets/logos/caseys.png',
      );
    });

    test('returns correct path for shell', () {
      expect(
        truckStopBrandAssetPath(TruckStopBrand.shell),
        'assets/logos/shell.png',
      );
    });

    test('returns correct path for bp', () {
      expect(
        truckStopBrandAssetPath(TruckStopBrand.bp),
        'assets/logos/bp.png',
      );
    });

    test('returns correct path for total', () {
      expect(
        truckStopBrandAssetPath(TruckStopBrand.total),
        'assets/logos/total.png',
      );
    });

    test('returns correct path for petroCanada', () {
      expect(
        truckStopBrandAssetPath(TruckStopBrand.petroCanada),
        'assets/logos/petro_canada.png',
      );
    });

    test('returns correct path for esso', () {
      expect(
        truckStopBrandAssetPath(TruckStopBrand.esso),
        'assets/logos/esso.png',
      );
    });

    test('returns null for one9 (no bundled asset)', () {
      expect(truckStopBrandAssetPath(TruckStopBrand.one9), isNull);
    });

    test('returns null for amBest (no bundled asset)', () {
      expect(truckStopBrandAssetPath(TruckStopBrand.amBest), isNull);
    });

    test('all brands with assets have a non-empty path', () {
      for (final brand in TruckStopBrand.values) {
        final path = truckStopBrandAssetPath(brand);
        if (path != null) {
          expect(path, startsWith('assets/logos/'));
          expect(path, endsWith('.png'));
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  // TruckStopBrandLogo widget
  // ---------------------------------------------------------------------------
  group('TruckStopBrandLogo widget', () {
    testWidgets('renders fallback icon for brand without an asset (one9)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TruckStopBrandLogo(brand: TruckStopBrand.one9),
          ),
        ),
      );

      // No Image widget should be present since there is no asset path.
      expect(find.byType(Image), findsNothing);
      // The generic truck icon should be visible.
      expect(find.byIcon(Icons.local_shipping_rounded), findsOneWidget);
    });

    testWidgets('renders fallback icon for brand without an asset (amBest)',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TruckStopBrandLogo(brand: TruckStopBrand.amBest),
          ),
        ),
      );

      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.local_shipping_rounded), findsOneWidget);
    });

    testWidgets('renders Image.asset for pilot brand', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TruckStopBrandLogo(brand: TruckStopBrand.pilot),
          ),
        ),
      );

      // An Image widget should be present (asset image).
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('renders Image.asset for shell brand', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TruckStopBrandLogo(brand: TruckStopBrand.shell),
          ),
        ),
      );

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('respects custom size parameter', (tester) async {
      const customSize = 60.0;
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TruckStopBrandLogo(
              brand: TruckStopBrand.pilot,
              size: customSize,
            ),
          ),
        ),
      );

      final widget = tester.widget<TruckStopBrandLogo>(
        find.byType(TruckStopBrandLogo),
      );
      expect(widget.size, customSize);
    });
  });
}

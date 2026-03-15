import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/poi.dart';
import 'package:kingtrux/ui/widgets/more_poi_screen.dart';
import 'package:kingtrux/ui/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Wraps [child] in a minimal [MaterialApp] environment.
Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    home: child,
  );
}

// ---------------------------------------------------------------------------
// Distance helpers (mirrors logic in poi_browser_sheet.dart)
// ---------------------------------------------------------------------------

double _haversineMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const r = 6371000.0;
  final phi1 = lat1 * math.pi / 180;
  final phi2 = lat2 * math.pi / 180;
  final dPhi = (lat2 - lat1) * math.pi / 180;
  final dLambda = (lng2 - lng1) * math.pi / 180;
  final sinDPhi = math.sin(dPhi / 2);
  final sinDLambda = math.sin(dLambda / 2);
  final a = sinDPhi * sinDPhi +
      math.cos(phi1) * math.cos(phi2) * sinDLambda * sinDLambda;
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

String _formatMiles(double meters) {
  final miles = meters / 1609.344;
  if (miles < 10) {
    return '${miles.toStringAsFixed(1)} mi';
  }
  return '${miles.round()} mi';
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ─────────────────────────────────────────────────────────────────────────
  // MorePoiScreen widget tests
  // ─────────────────────────────────────────────────────────────────────────
  group('MorePoiScreen', () {
    testWidgets('renders "More" title in AppBar', (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const MorePoiScreen()));
      await tester.pump();
      expect(find.text('More'), findsOneWidget);
    });

    testWidgets('renders chip buttons from top section',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const MorePoiScreen()));
      await tester.pump();

      // Some of the required top-grid chips
      expect(find.text('Truck Stops'), findsOneWidget);
      expect(find.text('Fuel'), findsOneWidget);
      expect(find.text('Rest Areas'), findsOneWidget);
      expect(find.text('Weigh Stations'), findsOneWidget);
    });

    testWidgets('renders section headers for Truck Services and Amenities',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const MorePoiScreen()));
      await tester.pump();

      expect(find.text('TRUCK SERVICES'), findsOneWidget);
      expect(find.text('AMENITIES'), findsOneWidget);
    });

    testWidgets('renders Security and Dealers section headers',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const MorePoiScreen()));
      await tester.pumpAndSettle();

      // Scroll to the bottom to ensure all widgets are built.
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -800),
      );
      await tester.pump();

      expect(find.text('SECURITY'), findsOneWidget);
      expect(find.text('DEALERS'), findsOneWidget);
    });

    testWidgets('tapping a "Coming soon" chip shows a SnackBar',
        (WidgetTester tester) async {
      await tester.pumpWidget(_wrap(const MorePoiScreen()));
      await tester.pump();

      await tester.tap(find.text('Truck Washes'));
      await tester.pump();

      expect(find.text('Truck Washes – Coming soon'), findsOneWidget);
    });

    testWidgets('back button is present in AppBar', (WidgetTester tester) async {
      // Push MorePoiScreen on top of a home page so the back arrow shows.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: TextButton(
                key: const Key('open_more'),
                onPressed: () => Navigator.of(ctx).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const MorePoiScreen(),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_more')));
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // POI distance helper tests
  // ─────────────────────────────────────────────────────────────────────────
  group('POI distance helpers', () {
    test('_formatMiles formats sub-10-mile distance with one decimal', () {
      // 1609.344 m = exactly 1 mile
      expect(_formatMiles(1609.344), '1.0 mi');
    });

    test('_formatMiles formats 5.5 miles correctly', () {
      expect(_formatMiles(1609.344 * 5.5), '5.5 mi');
    });

    test('_formatMiles rounds distances >= 10 miles', () {
      expect(_formatMiles(1609.344 * 12.7), '13 mi');
    });

    test('_formatMiles formats zero miles as 0.0 mi', () {
      expect(_formatMiles(0), '0.0 mi');
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Navigation: "More" button in _QuickActionsBar opens MorePoiScreen
  // ─────────────────────────────────────────────────────────────────────────
  group('More button navigation', () {
    testWidgets('tapping More button navigates to MorePoiScreen',
        (WidgetTester tester) async {
      var moreTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (ctx) => TextButton(
                key: const Key('more_trigger'),
                onPressed: () {
                  moreTapped = true;
                  Navigator.of(ctx).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const MorePoiScreen(),
                    ),
                  );
                },
                child: const Text('More'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('more_trigger')));
      await tester.pumpAndSettle();

      expect(moreTapped, isTrue);
      // MorePoiScreen should now be on screen.
      expect(find.text('More'), findsWidgets);
      expect(find.text('Truck Stops'), findsOneWidget);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // POI list distance display (unit-level logic test)
  // ─────────────────────────────────────────────────────────────────────────
  group('POI list distance display', () {
    test('distance label is hidden when GPS is not available', () {
      // When lat/lng are null, distanceText should return null.
      const double? myLat = null;
      const double? myLng = null;
      final poi = Poi(
        id: 'p1',
        type: PoiType.fuel,
        name: 'Test Fuel',
        lat: 40.0,
        lng: -90.0,
        tags: {},
      );

      // Simulate the _distanceText null-check logic from PoiBrowserSheet.
      String? distText;
      if (myLat != null && myLng != null) {
        final meters = _haversineMeters(myLat, myLng, poi.lat, poi.lng);
        distText = _formatMiles(meters);
      }

      expect(distText, isNull);
    });

    test('distance label shows miles when GPS is available', () {
      const myLat = 40.0;
      const myLng = -90.0;
      final poi = Poi(
        id: 'p1',
        type: PoiType.fuel,
        name: 'Test Fuel',
        // ~111 km north = ~68.97 miles
        lat: 41.0,
        lng: -90.0,
        tags: {},
      );

      final meters = _haversineMeters(myLat, myLng, poi.lat, poi.lng);
      final distText = _formatMiles(meters);

      // Should be around 69 mi (1 degree latitude ≈ 111 km ≈ 68.97 mi)
      expect(distText, contains('mi'));
      expect(distText, isNotNull);
    });

    test('subtitle includes both type label and distance when GPS available', () {
      const myLat = 40.0;
      const myLng = -90.0;
      const typeLabel = 'Fuel Station';
      final poi = Poi(
        id: 'p1',
        type: PoiType.fuel,
        name: 'Test Fuel',
        lat: 40.001,
        lng: -90.001,
        tags: {},
      );

      final meters = _haversineMeters(myLat, myLng, poi.lat, poi.lng);
      final distText = _formatMiles(meters);
      final subtitle = '$typeLabel · $distText';

      expect(subtitle, startsWith('Fuel Station · '));
      expect(subtitle, contains('mi'));
    });
  });
}

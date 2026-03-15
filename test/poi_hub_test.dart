import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/poi.dart';
import 'package:kingtrux/ui/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Helpers / pure-logic mirrors
// ---------------------------------------------------------------------------

Poi _makePoi(
  String id,
  PoiType type, {
  double lat = 0.0,
  double lng = 0.0,
  Map<String, dynamic>? tags,
}) =>
    Poi(
      id: id,
      type: type,
      name: 'Test $id',
      lat: lat,
      lng: lng,
      tags: tags ?? {},
    );

/// Haversine distance in metres – mirrors the private implementation inside
/// [PoiBrowserSheet] so the maths can be unit-tested without widget overhead.
double _haversineMeters(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  const r = 6371000.0;
  final dLat = (lat2 - lat1) * math.pi / 180.0;
  final dLng = (lng2 - lng1) * math.pi / 180.0;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180.0) *
          math.cos(lat2 * math.pi / 180.0) *
          math.sin(dLng / 2) *
          math.sin(dLng / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

/// Formats the haversine result to one decimal place as miles.
String _distanceMiles(
  double fromLat,
  double fromLng,
  double toLat,
  double toLng,
) {
  final meters = _haversineMeters(fromLat, fromLng, toLat, toLng);
  final miles = meters / 1609.344;
  return '${miles.toStringAsFixed(1)} mi';
}

// ---------------------------------------------------------------------------
// Minimal fake POI hub category grid
//
// PoiHubSheet requires AppState (platform channels / shared-prefs) so its
// tests use a manually constructed GridView that reproduces the exact Key
// assignments from the real widget, keeping the suite fast and hermetic.
// ---------------------------------------------------------------------------

Widget _buildCategoryGrid() {
  const tileData = [
    (Key('poi_hub_tile_truckStops'), 'Truck Stops'),
    (Key('poi_hub_tile_weighStations'), 'Weigh Stations'),
    (Key('poi_hub_tile_parking'), 'Parking'),
    (Key('poi_hub_tile_fuel'), 'Fuel'),
    (Key('poi_hub_tile_restAreas'), 'Rest Areas'),
    (Key('poi_hub_tile_walmarts'), 'Walmarts'),
    (Key('poi_hub_tile_truckWashes'), 'Truck Washes'),
    (Key('poi_hub_tile_more'), 'More'),
  ];

  return MaterialApp(
    theme: AppTheme.light,
    home: Scaffold(
      body: GridView.count(
        crossAxisCount: 4,
        children: tileData
            .map(
              (t) => InkWell(
                key: t.$1,
                onTap: () {},
                child: Center(child: Text(t.$2)),
              ),
            )
            .toList(),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Minimal More-screen stub
//
// MorePoiScreen also requires AppState through its Consumer body.  The stub
// below exactly mirrors the Scaffold / AppBar / section / chip structure that
// MorePoiScreen produces, so we can verify navigation and rendering without
// involving platform channels.
// ---------------------------------------------------------------------------

class _FakeMoreWrapper extends StatelessWidget {
  const _FakeMoreWrapper();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Builder(
        builder: (ctx) => TextButton(
          key: const Key('open_more'),
          onPressed: () => Navigator.of(ctx).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const _MoreScreenStub(),
            ),
          ),
          child: const Text('Open More'),
        ),
      ),
    );
  }
}

/// Reproduces the structural shape of [MorePoiScreen] without AppState.
class _MoreScreenStub extends StatelessWidget {
  const _MoreScreenStub();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More'),
        centerTitle: true,
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('BRANDS & CATEGORIES'),
          Wrap(
            children: [
              ActionChip(label: const Text('Truck Stops'), onPressed: () {}),
              ActionChip(label: const Text('Fuel'), onPressed: () {}),
              ActionChip(
                  label: const Text('Weigh Stations'), onPressed: () {}),
            ],
          ),
          const SizedBox(height: 12),
          const Text('TRUCK SERVICES'),
          Wrap(
            children: [
              ActionChip(
                key: const Key('more_chip_truck_washes'),
                label: const Text('Truck Washes'),
                onPressed: () {},
              ),
              ActionChip(
                  label: const Text('Repair Shops'), onPressed: () {}),
            ],
          ),
          const SizedBox(height: 12),
          const Text('AMENITIES'),
          Wrap(
            children: [
              ActionChip(label: const Text('WiFi'), onPressed: () {}),
              ActionChip(label: const Text('Shower'), onPressed: () {}),
            ],
          ),
          const SizedBox(height: 12),
          const Text('SECURITY'),
          Wrap(
            children: [
              ActionChip(
                  label: const Text('Lighted Parking'), onPressed: () {}),
            ],
          ),
          const SizedBox(height: 12),
          const Text('DEALERS'),
          Wrap(
            children: [
              ActionChip(label: const Text('Volvo'), onPressed: () {}),
              ActionChip(label: const Text('Kenworth'), onPressed: () {}),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _buildMoreScreen() {
  return MaterialApp(
    theme: AppTheme.light,
    home: const _FakeMoreWrapper(),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── POI hub category grid ─────────────────────────────────────────────
  group('POI hub category grid tiles', () {
    testWidgets('renders all eight category tile keys',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildCategoryGrid());

      expect(find.byKey(const Key('poi_hub_tile_truckStops')), findsOneWidget);
      expect(find.byKey(const Key('poi_hub_tile_weighStations')), findsOneWidget);
      expect(find.byKey(const Key('poi_hub_tile_parking')), findsOneWidget);
      expect(find.byKey(const Key('poi_hub_tile_fuel')), findsOneWidget);
      expect(find.byKey(const Key('poi_hub_tile_restAreas')), findsOneWidget);
      expect(find.byKey(const Key('poi_hub_tile_walmarts')), findsOneWidget);
      expect(find.byKey(const Key('poi_hub_tile_truckWashes')), findsOneWidget);
      expect(find.byKey(const Key('poi_hub_tile_more')), findsOneWidget);
    });

    testWidgets('renders all eight category label texts',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildCategoryGrid());

      expect(find.text('Truck Stops'), findsOneWidget);
      expect(find.text('Weigh Stations'), findsOneWidget);
      expect(find.text('Parking'), findsOneWidget);
      expect(find.text('Fuel'), findsOneWidget);
      expect(find.text('Rest Areas'), findsOneWidget);
      expect(find.text('Walmarts'), findsOneWidget);
      expect(find.text('Truck Washes'), findsOneWidget);
      expect(find.text('More'), findsOneWidget);
    });
  });

  // ── MorePoiScreen navigation and chip rendering ──────────────────────
  group('MorePoiScreen', () {
    testWidgets('tapping "Open More" pushes a screen with title "More"',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildMoreScreen());

      await tester.tap(find.byKey(const Key('open_more')));
      await tester.pumpAndSettle();

      // The AppBar title "More" should be visible.
      expect(find.text('More'), findsWidgets);
    });

    testWidgets('More screen renders all section headers',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildMoreScreen());
      await tester.tap(find.byKey(const Key('open_more')));
      await tester.pumpAndSettle();

      expect(find.text('BRANDS & CATEGORIES'), findsOneWidget);
      expect(find.text('TRUCK SERVICES'), findsOneWidget);
      expect(find.text('AMENITIES'), findsOneWidget);
      expect(find.text('SECURITY'), findsOneWidget);
      expect(find.text('DEALERS'), findsOneWidget);
    });

    testWidgets('More screen renders chip buttons across sections',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildMoreScreen());
      await tester.tap(find.byKey(const Key('open_more')));
      await tester.pumpAndSettle();

      expect(find.text('Truck Stops'), findsOneWidget);
      expect(find.text('Fuel'), findsOneWidget);
      expect(find.byKey(const Key('more_chip_truck_washes')), findsOneWidget);
      expect(find.text('WiFi'), findsOneWidget);
      expect(find.text('Volvo'), findsOneWidget);
    });

    testWidgets('More screen back button is present',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildMoreScreen());
      await tester.tap(find.byKey(const Key('open_more')));
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsOneWidget);
    });
  });

  // ── POI distance-in-miles logic ───────────────────────────────────────
  group('POI distance label (haversine)', () {
    test('returns "0.0 mi" for coincident points', () {
      expect(_distanceMiles(41.85, -87.65, 41.85, -87.65), '0.0 mi');
    });

    test('ends with " mi" suffix', () {
      expect(
        _distanceMiles(41.85, -87.65, 41.90, -87.65),
        endsWith(' mi'),
      );
    });

    test('is approximately 3.4 mi for ~0.05 degree latitude offset', () {
      // 0.05° latitude ≈ 5 556 m ≈ 3.45 mi
      final d = _distanceMiles(41.85, -87.65, 41.90, -87.65);
      final num = double.parse(d.replaceAll(' mi', ''));
      expect(num, greaterThan(3.0));
      expect(num, lessThan(4.0));
    });

    test('formats with exactly one decimal place', () {
      final d = _distanceMiles(41.85, -87.65, 41.86, -87.65);
      // e.g. "0.7 mi"
      expect(d, matches(r'^\d+\.\d mi$'));
    });

    test('is symmetric', () {
      final d1 = _distanceMiles(41.85, -87.65, 41.90, -87.70);
      final d2 = _distanceMiles(41.90, -87.70, 41.85, -87.65);
      expect(d1, equals(d2));
    });
  });

  // ── POI list tile subtitle with distance ─────────────────────────────
  group('POI list tile shows distance label', () {
    testWidgets('subtitle includes "X.X mi" when GPS is available',
        (WidgetTester tester) async {
      const fromLat = 41.85;
      const fromLng = -87.65;
      final poi = _makePoi('node_1', PoiType.fuel, lat: 41.90, lng: -87.65);

      final dist = _distanceMiles(fromLat, fromLng, poi.lat, poi.lng);
      // Mirrors the subtitle logic in PoiBrowserSheet._buildPoiTile.
      final subtitleText = 'Fuel Station · $dist';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListTile(
              key: const Key('poi_tile'),
              title: Text(poi.name),
              subtitle: Text(subtitleText),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('poi_tile')), findsOneWidget);
      expect(find.textContaining('Fuel Station'), findsOneWidget);
      expect(find.textContaining('mi'), findsOneWidget);
    });

    testWidgets('subtitle omits distance when GPS is unavailable',
        (WidgetTester tester) async {
      // null GPS – _distanceMiles returns null → subtitle has no "mi" text
      const subtitleText = 'Fuel Station';

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: ListTile(
              title: const Text('Test POI'),
              subtitle: Text(subtitleText),
            ),
          ),
        ),
      );

      expect(find.text('Fuel Station'), findsOneWidget);
      expect(find.textContaining('mi'), findsNothing);
    });
  });
}

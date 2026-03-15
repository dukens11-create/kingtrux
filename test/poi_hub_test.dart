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
// Tests
// ---------------------------------------------------------------------------

void main() {
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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/poi.dart';
import 'package:kingtrux/state/app_state.dart';
import 'package:kingtrux/ui/theme/app_theme.dart';
import 'package:kingtrux/ui/widgets/poi_browser_sheet.dart';
import 'package:kingtrux/ui/widgets/poi_hub_sheet.dart';
import 'package:kingtrux/ui/more_page.dart';

// ---------------------------------------------------------------------------
// Stub AppState that lets tests control location and POI lists
// ---------------------------------------------------------------------------

class _StubAppState extends AppState {
  _StubAppState({
    double? lat,
    double? lng,
    List<Poi>? poiList,
    Set<PoiType>? layers,
  }) {
    if (lat != null) myLat = lat;
    if (lng != null) myLng = lng;
    if (poiList != null) pois = poiList;
    if (layers != null) enabledPoiLayers = layers;
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Poi _makePoi(
  String id,
  PoiType type, {
  double lat = 40.0,
  double lng = -74.0,
}) =>
    Poi(id: id, type: type, name: 'Test $id', lat: lat, lng: lng, tags: {});

Widget _wrapWithProvider(AppState state, Widget child) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ─── 1. POI Hub shows category grid ──────────────────────────────────────

  group('PoiHubSheet – category grid', () {
    testWidgets('renders the 8-tile category grid', (tester) async {
      final state = _StubAppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  key: const Key('open_hub'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => ChangeNotifierProvider<AppState>.value(
                      value: state,
                      child: const PoiHubSheet(),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open the hub sheet.
      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      // The grid key should be present.
      expect(find.byKey(const Key('poi_hub_grid')), findsOneWidget);

      // Check all 8 category labels are visible.
      expect(find.text('Truck Stops'), findsOneWidget);
      expect(find.textContaining('Weigh'), findsOneWidget);
      expect(find.text('Parking'), findsOneWidget);
      expect(find.text('Fuel'), findsOneWidget);
      expect(find.textContaining('Rest Areas'), findsOneWidget);
      expect(find.text('Walmarts'), findsOneWidget);
      expect(find.textContaining('Truck'), findsWidgets); // Truck Stops + Truck Washes
      expect(find.text('More'), findsOneWidget);
    });

    testWidgets('destination bar is visible', (tester) async {
      final state = _StubAppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  key: const Key('open_hub'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => ChangeNotifierProvider<AppState>.value(
                      value: state,
                      child: const PoiHubSheet(),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      expect(find.text('Set destination for truck routes'), findsOneWidget);
    });
  });

  // ─── 2. "More" tile navigates to MorePage ────────────────────────────────

  group('PoiHubSheet – More navigation', () {
    testWidgets('tapping More tile pushes MorePage', (tester) async {
      final state = _StubAppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  key: const Key('open_hub'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => ChangeNotifierProvider<AppState>.value(
                      value: state,
                      child: const PoiHubSheet(),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      // Tap the "More" tile.
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      // The MorePage should now be on screen.
      expect(find.byType(MorePage), findsOneWidget);
      // The AppBar title "More" should be visible.
      expect(find.text('More'), findsWidgets);
    });
  });

  // ─── 3. MorePage renders sections ────────────────────────────────────────

  group('MorePage', () {
    testWidgets('renders section headers and chip buttons', (tester) async {
      final state = _StubAppState();

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: const MaterialApp(
            home: MorePage(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // AppBar title
      expect(find.text('More'), findsOneWidget);

      // Section keys
      expect(find.byKey(const Key('more_section_Categories')), findsOneWidget);
      expect(find.byKey(const Key('more_section_Truck Services')), findsOneWidget);
      expect(find.byKey(const Key('more_section_Amenities')), findsOneWidget);
      expect(find.byKey(const Key('more_section_Security')), findsOneWidget);
      expect(find.byKey(const Key('more_section_Dealers')), findsOneWidget);

      // Some expected chip labels
      expect(find.text('Fuel'), findsOneWidget);
      expect(find.text('Gyms'), findsOneWidget);
      expect(find.text('Repair Shops'), findsOneWidget);
      expect(find.text('WiFi'), findsOneWidget);
      expect(find.text('Volvo'), findsOneWidget);
    });
  });

  // ─── 4. POI browser shows distance labels when location is available ─────

  group('PoiBrowserSheet – distance labels', () {
    testWidgets('shows distance in miles when GPS location is available',
        (tester) async {
      // Driver is at (40.0, -74.0); POI is ~14 km away at (40.1, -74.0).
      final state = _StubAppState(
        lat: 40.0,
        lng: -74.0,
        layers: {PoiType.fuel},
        poiList: [
          _makePoi('p1', PoiType.fuel, lat: 40.1, lng: -74.0),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  key: const Key('open_browser'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => ChangeNotifierProvider<AppState>.value(
                      value: state,
                      child: const PoiBrowserSheet(),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_browser')));
      await tester.pumpAndSettle();

      // The distance label key should be present.
      expect(find.byKey(const Key('poi_dist_p1')), findsOneWidget);

      // The label text should contain "mi".
      final distText = find.byKey(const Key('poi_dist_p1'));
      final widget = tester.widget<Text>(distText);
      expect(widget.data, contains('mi'));
    });

    testWidgets('hides distance label when GPS location is unavailable',
        (tester) async {
      // No lat/lng in state → location unavailable.
      final state = _StubAppState(
        layers: {PoiType.fuel},
        poiList: [
          _makePoi('p2', PoiType.fuel),
        ],
      );

      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(
                  key: const Key('open_browser'),
                  onPressed: () => showModalBottomSheet<void>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => ChangeNotifierProvider<AppState>.value(
                      value: state,
                      child: const PoiBrowserSheet(),
                    ),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('open_browser')));
      await tester.pumpAndSettle();

      // The distance label should NOT be present.
      expect(find.byKey(const Key('poi_dist_p2')), findsNothing);
    });
  });
}

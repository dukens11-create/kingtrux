import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/poi.dart';
import 'package:kingtrux/models/route_result.dart';
import 'package:kingtrux/state/app_state.dart';
import 'package:kingtrux/ui/widgets/poi_hub_sheet.dart';
import 'package:kingtrux/ui/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Minimal AppState stub that only overrides what PoiHubSheet needs.
// ---------------------------------------------------------------------------

class _StubAppState extends AppState {
  _StubAppState({Set<PoiType>? enabledLayers}) {
    if (enabledLayers != null) enabledPoiLayers = enabledLayers;
  }

  /// Track calls to toggleLayer for assertions.
  final List<(PoiType, bool)> toggleCalls = [];

  /// Track calls to loadPois.
  int loadPoisCallCount = 0;

  /// Whether clearRoute() was called.
  bool clearRouteCalled = false;

  @override
  void toggleLayer(PoiType type, bool enabled) {
    toggleCalls.add((type, enabled));
    super.toggleLayer(type, enabled);
  }

  @override
  Future<void> loadPois({double radiusMeters = 15000}) async {
    loadPoisCallCount++;
    // No-op in tests — avoids network calls.
  }

  @override
  void clearRoute() {
    clearRouteCalled = true;
    routeResult = null;
    notifyListeners();
  }
}

// ---------------------------------------------------------------------------
// A minimal RouteResult for testing the route-summary row.
// ---------------------------------------------------------------------------
const _kFakeRoute = RouteResult(
  polylinePoints: [],
  lengthMeters: 96000,   // ~59.6 mi
  durationSeconds: 5400, // 1h 30m
);

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildSheet({_StubAppState? state}) {
  final appState = state ?? _StubAppState();
  return ChangeNotifierProvider<AppState>.value(
    value: appState,
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
                value: appState,
                child: const PoiHubSheet(),
              ),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
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

  // ---------------------------------------------------------------------------
  // Layout / presence of category grid
  // ---------------------------------------------------------------------------
  group('PoiHubSheet — category grid', () {
    testWidgets('shows all 8 category tile labels',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSheet());
      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      const expectedLabels = [
        'Truck Stops',
        'Weigh Stations',
        'Parking',
        'Fuel',
        'Rest Areas',
        'Walmarts',
        'Truck Washes',
        'More',
      ];

      for (final label in expectedLabels) {
        expect(
          find.text(label),
          findsOneWidget,
          reason: 'Expected label "$label" to appear in the category grid',
        );
      }
    });

    testWidgets('shows the FIND NEARBY section label',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSheet());
      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      expect(find.text('FIND NEARBY'), findsOneWidget);
    });

    testWidgets('shows the search header bar', (WidgetTester tester) async {
      await tester.pumpWidget(_buildSheet());
      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('destination_search_bar')),
        findsOneWidget,
      );
      expect(find.text('Set destination for truck routes'), findsOneWidget);
    });

    testWidgets('shows EXTRAS placeholder section',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSheet());
      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      expect(find.text('EXTRAS'), findsOneWidget);
      expect(find.text('Driver Discounts'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Route summary row
  // ---------------------------------------------------------------------------
  group('PoiHubSheet — route summary row', () {
    testWidgets('route summary row is hidden when no route',
        (WidgetTester tester) async {
      final state = _StubAppState();
      await tester.pumpWidget(_buildSheet(state: state));
      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('poi_hub_route_summary')),
        findsNothing,
      );
    });

    testWidgets('route summary row is visible when route is loaded',
        (WidgetTester tester) async {
      final state = _StubAppState()..routeResult = _kFakeRoute;
      await tester.pumpWidget(_buildSheet(state: state));
      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('poi_hub_route_summary')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('poi_hub_clear_trip_btn')), findsOneWidget);
      expect(find.byKey(const Key('poi_hub_go_btn')), findsOneWidget);
    });

    testWidgets('Clear Trip button calls clearRoute on AppState',
        (WidgetTester tester) async {
      final state = _StubAppState()..routeResult = _kFakeRoute;
      await tester.pumpWidget(_buildSheet(state: state));
      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('poi_hub_clear_trip_btn')));
      await tester.pump();

      expect(state.clearRouteCalled, isTrue);
      expect(state.routeResult, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Weigh Stations tile
  // ---------------------------------------------------------------------------
  group('PoiHubSheet — Weigh Stations tile', () {
    testWidgets(
        'tapping Weigh Stations enables the scale POI layer when it was off',
        (WidgetTester tester) async {
      final state = _StubAppState(enabledLayers: {});

      await tester.pumpWidget(_buildSheet(state: state));
      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('poi_hub_tile_weighStations')),
      );
      await tester.pump();

      // toggleLayer should have been called with (PoiType.scale, true).
      expect(
        state.toggleCalls,
        contains((PoiType.scale, true)),
        reason: 'Expected scale layer to be toggled on',
      );
    });

    testWidgets('tapping Weigh Stations calls loadPois',
        (WidgetTester tester) async {
      final state = _StubAppState(enabledLayers: {});

      await tester.pumpWidget(_buildSheet(state: state));
      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('poi_hub_tile_weighStations')),
      );
      await tester.pump();

      expect(
        state.loadPoisCallCount,
        greaterThan(0),
        reason: 'Expected loadPois to be called after Weigh Stations tap',
      );
    });

    testWidgets(
        'tapping Weigh Stations does not re-enable layer when already on',
        (WidgetTester tester) async {
      final state = _StubAppState(enabledLayers: {PoiType.scale});

      await tester.pumpWidget(_buildSheet(state: state));
      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('poi_hub_tile_weighStations')),
      );
      await tester.pump();

      // Should NOT have called toggleLayer because layer was already enabled.
      expect(
        state.toggleCalls,
        isEmpty,
        reason: 'toggleLayer should not be called when layer is already on',
      );
    });
  });

  // ---------------------------------------------------------------------------
  // "Coming soon" tiles
  // ---------------------------------------------------------------------------
  group('PoiHubSheet — coming-soon tiles', () {
    testWidgets('tapping Walmarts shows a Coming soon snackbar',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSheet());
      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('poi_hub_tile_walmarts')));
      await tester.pump();

      expect(find.text('Walmarts — Coming soon'), findsOneWidget);
    });

    testWidgets('tapping Truck Washes shows a Coming soon snackbar',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildSheet());
      await tester.tap(find.byKey(const Key('open_hub')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('poi_hub_tile_truckWashes')));
      await tester.pump();

      expect(find.text('Truck Washes — Coming soon'), findsOneWidget);
    });
  });
}

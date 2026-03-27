import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/trip_stop.dart';
import 'package:kingtrux/services/destination_persistence_service.dart';
import 'package:kingtrux/state/app_state.dart';
import 'package:kingtrux/ui/widgets/where_to_sheet.dart';
import 'package:kingtrux/ui/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Minimal AppState stub that avoids platform-channel calls.
// ---------------------------------------------------------------------------

class _StubAppState extends AppState {
  /// Tracks calls to buildTruckRoute.
  int buildTruckRouteCallCount = 0;

  @override
  Future<void> buildTruckRoute() async {
    buildTruckRouteCallCount++;
    // No-op in tests — avoids network calls.
  }

  @override
  Future<void> refreshMyLocation() async {
    // No-op — avoids location platform channel.
  }
}

// ---------------------------------------------------------------------------
// Helper to pump WhereToSheet in a test app.
// ---------------------------------------------------------------------------

Widget _buildApp({required _StubAppState state}) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder: (ctx) => TextButton(
            key: const Key('open_sheet'),
            onPressed: () => showModalBottomSheet<void>(
              context: ctx,
              isScrollControlled: true,
              builder: (_) => ChangeNotifierProvider<AppState>.value(
                value: state,
                child: const WhereToSheet(),
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
// Unit tests — AppState routeStops management (no Flutter widgets needed)
// ---------------------------------------------------------------------------

void main() {
  group('AppState — routeStops', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('routeStops is empty on construction', () {
      final state = _StubAppState();
      expect(state.routeStops, isEmpty);
    });

    test('addRouteStop appends a stop', () {
      final state = _StubAppState();
      state.addRouteStop(40.0, -74.0, label: 'NYC');

      expect(state.routeStops.length, 1);
      expect(state.routeStops.first.lat, 40.0);
      expect(state.routeStops.first.lng, -74.0);
      expect(state.routeStops.first.label, 'NYC');
    });

    test('addRouteStop appends multiple stops in order', () {
      final state = _StubAppState();
      state.addRouteStop(40.0, -74.0, label: 'A');
      state.addRouteStop(41.0, -73.0, label: 'B');
      state.addRouteStop(42.0, -72.0, label: 'C');

      expect(state.routeStops.length, 3);
      expect(state.routeStops[0].label, 'A');
      expect(state.routeStops[1].label, 'B');
      expect(state.routeStops[2].label, 'C');
    });

    test('addRouteStop updates destLat/destLng to last stop', () {
      final state = _StubAppState();
      state.addRouteStop(40.0, -74.0, label: 'A');
      state.addRouteStop(41.0, -73.0, label: 'B');

      expect(state.destLat, 41.0);
      expect(state.destLng, -73.0);
    });

    test('removeRouteStop removes stop at given index', () {
      final state = _StubAppState();
      state.addRouteStop(40.0, -74.0, label: 'A');
      state.addRouteStop(41.0, -73.0, label: 'B');
      state.addRouteStop(42.0, -72.0, label: 'C');

      state.removeRouteStop(1); // Remove 'B'

      expect(state.routeStops.length, 2);
      expect(state.routeStops[0].label, 'A');
      expect(state.routeStops[1].label, 'C');
    });

    test('removeRouteStop updates destLat/destLng to new last stop', () {
      final state = _StubAppState();
      state.addRouteStop(40.0, -74.0, label: 'A');
      state.addRouteStop(41.0, -73.0, label: 'B');

      state.removeRouteStop(1); // Remove 'B'; 'A' becomes the last

      expect(state.destLat, 40.0);
      expect(state.destLng, -74.0);
    });

    test('removeRouteStop sets destLat/destLng null when list becomes empty',
        () {
      final state = _StubAppState();
      state.addRouteStop(40.0, -74.0, label: 'A');

      state.removeRouteStop(0);

      expect(state.routeStops, isEmpty);
      expect(state.destLat, isNull);
      expect(state.destLng, isNull);
    });

    test('removeRouteStop is a no-op for an out-of-range index', () {
      final state = _StubAppState();
      state.addRouteStop(40.0, -74.0, label: 'A');

      state.removeRouteStop(5); // out of range
      expect(state.routeStops.length, 1); // unchanged
    });

    test('clearRouteStops empties the list', () {
      final state = _StubAppState();
      state.addRouteStop(40.0, -74.0);
      state.addRouteStop(41.0, -73.0);

      state.clearRouteStops();

      expect(state.routeStops, isEmpty);
    });

    test('setDestination clears routeStops', () {
      final state = _StubAppState();
      state.addRouteStop(40.0, -74.0, label: 'A');
      state.addRouteStop(41.0, -73.0, label: 'B');

      state.setDestination(45.0, -70.0);

      expect(state.routeStops, isEmpty);
      expect(state.destLat, 45.0);
      expect(state.destLng, -70.0);
    });

    test('clearRoute clears routeStops', () {
      final state = _StubAppState();
      state.addRouteStop(40.0, -74.0);

      state.clearRoute();

      expect(state.routeStops, isEmpty);
      expect(state.destLat, isNull);
      expect(state.destLng, isNull);
    });

    test('addRouteStop notifies listeners', () {
      final state = _StubAppState();
      var notified = false;
      state.addListener(() => notified = true);

      state.addRouteStop(40.0, -74.0);

      expect(notified, isTrue);
    });

    test('removeRouteStop notifies listeners', () {
      final state = _StubAppState();
      state.addRouteStop(40.0, -74.0);
      var notified = false;
      state.addListener(() => notified = true);

      state.removeRouteStop(0);

      expect(notified, isTrue);
    });

    test('clearRouteStops notifies listeners', () {
      final state = _StubAppState();
      state.addRouteStop(40.0, -74.0);
      var notified = false;
      state.addListener(() => notified = true);

      state.clearRouteStops();

      expect(notified, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // DestinationPersistenceService — stops persistence
  // ---------------------------------------------------------------------------

  group('DestinationPersistenceService — stops', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadStops returns empty list when nothing is persisted', () async {
      final service = DestinationPersistenceService();
      final stops = await service.loadStops();
      expect(stops, isEmpty);
    });

    test('saveStops then loadStops round-trips the list', () async {
      final service = DestinationPersistenceService();
      final stops = [
        TripStop(id: 's1', label: 'NYC', lat: 40.7128, lng: -74.006, createdAt: DateTime(2025)),
        TripStop(id: 's2', label: 'LA', lat: 34.0522, lng: -118.2437, createdAt: DateTime(2025)),
      ];
      await service.saveStops(stops);

      final loaded = await service.loadStops();
      expect(loaded.length, 2);
      expect(loaded[0].id, 's1');
      expect(loaded[0].label, 'NYC');
      expect(loaded[0].lat, closeTo(40.7128, 1e-9));
      expect(loaded[1].id, 's2');
      expect(loaded[1].lng, closeTo(-118.2437, 1e-9));
    });

    test('clearStops removes persisted stops', () async {
      final service = DestinationPersistenceService();
      await service.saveStops([
        TripStop(id: 's1', lat: 40.0, lng: -74.0, createdAt: DateTime(2025)),
      ]);
      await service.clearStops();
      final loaded = await service.loadStops();
      expect(loaded, isEmpty);
    });

    test('saveStops persists empty list and loadStops returns empty', () async {
      final service = DestinationPersistenceService();
      await service.saveStops([]);
      final loaded = await service.loadStops();
      expect(loaded, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // Widget tests — WhereToSheet
  // ---------------------------------------------------------------------------

  group('WhereToSheet — multi-stop UI', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    testWidgets('shows search field and search button',
        (WidgetTester tester) async {
      final state = _StubAppState();
      await tester.pumpWidget(_buildApp(state: state));
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('where_to_field')), findsOneWidget);
      expect(find.byKey(const Key('where_to_search_btn')), findsOneWidget);
    });

    testWidgets('Build Route button is hidden when no stops',
        (WidgetTester tester) async {
      final state = _StubAppState();
      await tester.pumpWidget(_buildApp(state: state));
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('where_to_build_route_btn')),
        findsNothing,
      );
    });

    testWidgets('shows added stops list after addRouteStop',
        (WidgetTester tester) async {
      final state = _StubAppState();
      // Pre-populate two stops so we can verify they render.
      state.addRouteStop(40.7128, -74.006, label: 'New York');
      state.addRouteStop(34.0522, -118.2437, label: 'Los Angeles');

      await tester.pumpWidget(_buildApp(state: state));
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      expect(find.text('New York'), findsOneWidget);
      expect(find.text('Los Angeles'), findsOneWidget);
    });

    testWidgets('Build Route button appears when stops exist',
        (WidgetTester tester) async {
      final state = _StubAppState();
      state.addRouteStop(40.7128, -74.006, label: 'New York');

      await tester.pumpWidget(_buildApp(state: state));
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('where_to_build_route_btn')),
        findsOneWidget,
      );
    });

    testWidgets('tapping Build Route calls buildTruckRoute and closes sheet',
        (WidgetTester tester) async {
      final state = _StubAppState();
      state.addRouteStop(40.7128, -74.006, label: 'New York');

      await tester.pumpWidget(_buildApp(state: state));
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('where_to_build_route_btn')));
      await tester.pumpAndSettle();

      expect(state.buildTruckRouteCallCount, 1);
      // Sheet should be dismissed.
      expect(find.byKey(const Key('where_to_build_route_btn')), findsNothing);
    });

    testWidgets('tapping remove button removes that stop',
        (WidgetTester tester) async {
      final state = _StubAppState();
      state.addRouteStop(40.0, -74.0, label: 'Stop A');
      state.addRouteStop(41.0, -73.0, label: 'Stop B');

      await tester.pumpWidget(_buildApp(state: state));
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      // Remove the first stop (index 0).
      await tester.tap(find.byKey(const Key('remove_stop_0')));
      await tester.pumpAndSettle();

      expect(state.routeStops.length, 1);
      expect(state.routeStops.first.label, 'Stop B');
      expect(find.text('Stop A'), findsNothing);
    });
  });
}

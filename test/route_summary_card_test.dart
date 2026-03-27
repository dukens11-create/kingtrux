import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/route_result.dart';
import 'package:kingtrux/state/app_state.dart';
import 'package:kingtrux/ui/widgets/route_summary_card.dart';
import 'package:kingtrux/ui/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Minimal AppState stub that avoids platform-channel calls.
// ---------------------------------------------------------------------------

class _StubAppState extends AppState {
  @override
  Future<void> buildTruckRoute() async {}

  @override
  Future<void> refreshMyLocation() async {}
}

// ---------------------------------------------------------------------------
// Minimal RouteResult for testing.
// ---------------------------------------------------------------------------

const _kFakeRoute = RouteResult(
  polylinePoints: [],
  lengthMeters: 96000,   // ~59.6 mi
  durationSeconds: 5400, // 1 h 30 m
);

// ---------------------------------------------------------------------------
// Helper: wrap RouteSummaryCard in a testable app.
// ---------------------------------------------------------------------------

Widget _buildApp({required _StubAppState state}) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: RouteSummaryCard(),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('RouteSummaryCard – Navigate button', () {
    testWidgets('Navigate button is present when route is active',
        (WidgetTester tester) async {
      final state = _StubAppState()
        ..routeResult = _kFakeRoute
        ..destLat = 40.712776
        ..destLng = -74.005974;

      await tester.pumpWidget(_buildApp(state: state));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('navigate_btn')), findsOneWidget);
    });

    testWidgets('Navigate button shows "Navigate" label',
        (WidgetTester tester) async {
      final state = _StubAppState()
        ..routeResult = _kFakeRoute
        ..destLat = 40.712776
        ..destLng = -74.005974;

      await tester.pumpWidget(_buildApp(state: state));
      await tester.pumpAndSettle();

      expect(find.text('Navigate'), findsOneWidget);
    });

    testWidgets('Navigate button is disabled when no destination is set',
        (WidgetTester tester) async {
      final state = _StubAppState()
        ..routeResult = _kFakeRoute;
      // destLat/destLng remain null.

      await tester.pumpWidget(_buildApp(state: state));
      await tester.pumpAndSettle();

      final btn = tester.widget<OutlinedButton>(
        find.byKey(const Key('navigate_btn')),
      );
      expect(btn.onPressed, isNull,
          reason: 'Button must be disabled when no destination is set');
    });

    testWidgets('Navigate button is enabled when destination is set',
        (WidgetTester tester) async {
      final state = _StubAppState()
        ..routeResult = _kFakeRoute
        ..destLat = 41.0
        ..destLng = -75.0;

      await tester.pumpWidget(_buildApp(state: state));
      await tester.pumpAndSettle();

      final btn = tester.widget<OutlinedButton>(
        find.byKey(const Key('navigate_btn')),
      );
      expect(btn.onPressed, isNotNull,
          reason: 'Button must be enabled when a destination is set');
    });
  });
}

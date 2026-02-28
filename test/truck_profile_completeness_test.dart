import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kingtrux/models/truck_profile.dart';
import 'package:kingtrux/models/route_result.dart';
import 'package:kingtrux/state/app_state.dart';
import 'package:kingtrux/ui/widgets/route_warnings_card.dart';

// ---------------------------------------------------------------------------
// Minimal widget helper: wraps a widget with the Provider + MaterialApp needed
// by the route summary components.
// ---------------------------------------------------------------------------
Widget _buildApp(Widget child, {AppState? state}) {
  return ChangeNotifierProvider<AppState>(
    create: (_) => state ?? AppState(),
    child: MaterialApp(home: Scaffold(body: child)),
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // RouteWarningsCard — renders nothing when warnings are empty
  // ---------------------------------------------------------------------------
  group('RouteWarningsCard', () {
    const emptyResult = RouteResult(
      polylinePoints: [],
      lengthMeters: 10000,
      durationSeconds: 600,
    );

    testWidgets('renders nothing when warnings list is empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _buildApp(const RouteWarningsCard(result: emptyResult)),
      );
      await tester.pump();
      // No warning heading should appear.
      expect(find.text('Route Warnings'), findsNothing);
    });

    testWidgets('renders warning items when warnings are present',
        (WidgetTester tester) async {
      const result = RouteResult(
        polylinePoints: [],
        lengthMeters: 10000,
        durationSeconds: 600,
        warnings: ['Low clearance bridge ahead', 'Weight limit: 25 t'],
      );
      await tester.pumpWidget(_buildApp(const RouteWarningsCard(result: result)));
      await tester.pump();

      expect(find.text('Route Warnings'), findsOneWidget);
      expect(find.textContaining('Low clearance'), findsOneWidget);
      expect(find.textContaining('Weight limit'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // TruckProfile completeness indicator — isDefaultProfile
  // ---------------------------------------------------------------------------
  group('TruckProfile.isDefaultProfile', () {
    test('default factory profile is considered default', () {
      expect(TruckProfile.defaultProfile().isDefaultProfile, isTrue);
    });

    test('profile with modified height is NOT considered default', () {
      final custom = TruckProfile.defaultProfile().copyWith(heightMeters: 3.2);
      expect(custom.isDefaultProfile, isFalse);
    });

    test('profile with modified length is NOT considered default', () {
      final custom =
          TruckProfile.defaultProfile().copyWith(lengthMeters: 18.0);
      expect(custom.isDefaultProfile, isFalse);
    });

    test('profile with hazmat true is NOT considered default', () {
      final custom = TruckProfile.defaultProfile().copyWith(hazmat: true);
      expect(custom.isDefaultProfile, isFalse);
    });
  });
}

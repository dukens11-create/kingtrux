import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kingtrux/models/navigation_maneuver.dart';
import 'package:kingtrux/state/app_state.dart';
import 'package:kingtrux/ui/widgets/maneuver_banner.dart';
import 'package:kingtrux/ui/widgets/navigation_utils.dart';
import 'package:kingtrux/ui/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Minimal AppState stub that controls isNavigating / currentManeuver.
// ---------------------------------------------------------------------------

class _StubAppState extends AppState {
  final bool navigating;
  final NavigationManeuver? maneuver;
  final double remainingDist;

  _StubAppState({
    this.navigating = false,
    this.maneuver,
    this.remainingDist = 0,
  });

  @override
  bool get isNavigating => navigating;

  @override
  NavigationManeuver? get currentManeuver => maneuver;

  @override
  double get remainingDistanceMeters => remainingDist;
}

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Widget _buildTestWidget(AppState state) {
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp(
      theme: AppTheme.light,
      home: const Scaffold(
        body: ManeuverBanner(),
      ),
    ),
  );
}

void main() {
  // ---------------------------------------------------------------------------
  // ManeuverBanner – not navigating
  // ---------------------------------------------------------------------------
  group('ManeuverBanner when not navigating', () {
    testWidgets('renders nothing when isNavigating is false',
        (WidgetTester tester) async {
      final state = _StubAppState(navigating: false);

      await tester.pumpWidget(_buildTestWidget(state));

      // SizedBox.shrink should be rendered – no instruction text visible.
      expect(find.text('Turn right onto Main St'), findsNothing);
      state.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // ManeuverBanner – active navigation, step with road info
  // ---------------------------------------------------------------------------
  group('ManeuverBanner when navigating', () {
    testWidgets('renders instruction text when steps exist',
        (WidgetTester tester) async {
      const maneuver = NavigationManeuver(
        instruction: 'Turn right onto Main St',
        distanceMeters: 500,
        durationSeconds: 30,
        action: 'turn',
        direction: 'right',
        lat: 0,
        lng: 0,
      );

      final state = _StubAppState(
        navigating: true,
        maneuver: maneuver,
        remainingDist: 500,
      );

      await tester.pumpWidget(_buildTestWidget(state));

      expect(find.text('Turn right onto Main St'), findsOneWidget);
      state.dispose();
    });

    testWidgets('renders road name and route number when present',
        (WidgetTester tester) async {
      const maneuver = NavigationManeuver(
        instruction: 'Merge onto I-95 N',
        distanceMeters: 1200,
        durationSeconds: 60,
        action: 'merge',
        lat: 0,
        lng: 0,
        roadName: 'Interstate 95',
        routeNumber: 'I-95 N',
      );

      final state = _StubAppState(
        navigating: true,
        maneuver: maneuver,
        remainingDist: 1200,
      );

      await tester.pumpWidget(_buildTestWidget(state));

      expect(find.text('Merge onto I-95 N'), findsOneWidget);
      expect(find.text('I-95 N / Interstate 95'), findsOneWidget);
      state.dispose();
    });

    testWidgets('shows distance in miles for long distance',
        (WidgetTester tester) async {
      const maneuver = NavigationManeuver(
        instruction: 'Head north',
        distanceMeters: 8000,
        durationSeconds: 300,
        action: 'depart',
        lat: 0,
        lng: 0,
      );

      final state = _StubAppState(
        navigating: true,
        maneuver: maneuver,
        remainingDist: 8000,
      );

      await tester.pumpWidget(_buildTestWidget(state));

      // 8000 m ≈ 4.97 mi → displayed as "5.0 mi"
      expect(find.textContaining('mi'), findsOneWidget);
      state.dispose();
    });

    testWidgets('shows distance in feet for short distance',
        (WidgetTester tester) async {
      const maneuver = NavigationManeuver(
        instruction: 'Turn left',
        distanceMeters: 100,
        durationSeconds: 10,
        action: 'turn',
        direction: 'left',
        lat: 0,
        lng: 0,
      );

      final state = _StubAppState(
        navigating: true,
        maneuver: maneuver,
        remainingDist: 100,
      );

      await tester.pumpWidget(_buildTestWidget(state));

      expect(find.textContaining('ft'), findsOneWidget);
      state.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // formatManeuverDistance helper
  // ---------------------------------------------------------------------------
  group('formatManeuverDistance', () {
    test('returns feet for distance < 0.2 miles', () {
      // 100 m ≈ 328 ft
      expect(formatManeuverDistance(100), contains('ft'));
    });

    test('returns miles for distance >= 0.2 miles', () {
      // 1000 m ≈ 0.62 mi
      expect(formatManeuverDistance(1000), contains('mi'));
    });

    test('formats zero distance as 0 ft', () {
      expect(formatManeuverDistance(0), '0 ft');
    });
  });

  // ---------------------------------------------------------------------------
  // maneuverIconForAction helper
  // ---------------------------------------------------------------------------
  group('maneuverIconForAction', () {
    test('returns navigation icon for depart', () {
      expect(maneuverIconForAction('depart', null), Icons.navigation_rounded);
    });

    test('returns flag icon for arrive', () {
      expect(maneuverIconForAction('arrive', null), Icons.flag_rounded);
    });

    test('returns turn-left icon for turn+left', () {
      expect(maneuverIconForAction('turn', 'left'), Icons.turn_left_rounded);
    });

    test('returns turn-right icon for turn+right', () {
      expect(maneuverIconForAction('turn', 'right'), Icons.turn_right_rounded);
    });

    test('returns merge icon for merge action', () {
      expect(maneuverIconForAction('merge', null), Icons.merge_rounded);
    });

    test('returns arrow-up for unknown action', () {
      expect(maneuverIconForAction('unknown', null), Icons.arrow_upward_rounded);
    });
  });
}

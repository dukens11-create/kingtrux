import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/navigation_maneuver.dart';
import 'package:kingtrux/ui/widgets/route_guidance_banner.dart';

void main() {
  // Helper: wrap widget in a minimal MaterialApp for rendering.
  Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  group('RouteGuidanceBanner', () {
    testWidgets('renders instruction text', (WidgetTester tester) async {
      const maneuver = NavigationManeuver(
        instruction: 'Turn right onto I-95',
        distanceMeters: 1200,
        durationSeconds: 45,
        action: 'turn',
        lat: 0,
        lng: 0,
      );

      await tester.pumpWidget(
        _wrap(RouteGuidanceBanner(maneuver: maneuver, onTap: () {})),
      );

      expect(find.text('Turn right onto I-95'), findsOneWidget);
    });

    testWidgets('renders road number and road name when both provided',
        (WidgetTester tester) async {
      const maneuver = NavigationManeuver(
        instruction: 'Merge onto highway',
        distanceMeters: 500,
        durationSeconds: 25,
        action: 'merge',
        lat: 0,
        lng: 0,
        roadName: 'Interstate 95 North',
        roadNumber: 'I-95',
      );

      await tester.pumpWidget(
        _wrap(RouteGuidanceBanner(maneuver: maneuver, onTap: () {})),
      );

      // Road label is "I-95 / Interstate 95 North"
      expect(find.text('I-95 / Interstate 95 North'), findsOneWidget);
    });

    testWidgets('renders only road name when no road number',
        (WidgetTester tester) async {
      const maneuver = NavigationManeuver(
        instruction: 'Turn left',
        distanceMeters: 300,
        durationSeconds: 20,
        action: 'turn',
        lat: 0,
        lng: 0,
        roadName: 'Main Street',
      );

      await tester.pumpWidget(
        _wrap(RouteGuidanceBanner(maneuver: maneuver, onTap: () {})),
      );

      expect(find.text('Main Street'), findsOneWidget);
    });

    testWidgets('shows no road label when neither roadName nor roadNumber set',
        (WidgetTester tester) async {
      const maneuver = NavigationManeuver(
        instruction: 'Head north',
        distanceMeters: 800,
        durationSeconds: 40,
        action: 'depart',
        lat: 0,
        lng: 0,
      );

      await tester.pumpWidget(
        _wrap(RouteGuidanceBanner(maneuver: maneuver, onTap: () {})),
      );

      expect(find.text('Head north'), findsOneWidget);
      // No road label text present.
      expect(find.text(' / '), findsNothing);
    });

    testWidgets('displays formatted distance', (WidgetTester tester) async {
      const maneuver = NavigationManeuver(
        instruction: 'Keep right',
        distanceMeters: 2500,
        durationSeconds: 90,
        action: 'keep',
        lat: 0,
        lng: 0,
      );

      await tester.pumpWidget(
        _wrap(RouteGuidanceBanner(maneuver: maneuver, onTap: () {})),
      );

      expect(find.text('2.5 km'), findsOneWidget);
    });

    testWidgets('calls onTap when tapped', (WidgetTester tester) async {
      var tapped = false;
      const maneuver = NavigationManeuver(
        instruction: 'Turn right',
        distanceMeters: 500,
        durationSeconds: 25,
        action: 'turn',
        lat: 0,
        lng: 0,
      );

      await tester.pumpWidget(
        _wrap(
          RouteGuidanceBanner(
            maneuver: maneuver,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.tap(find.byType(RouteGuidanceBanner));
      expect(tapped, isTrue);
    });
  });
}

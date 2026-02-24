import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kingtrux/state/app_state.dart';
import 'package:kingtrux/ui/paywall_screen.dart';

/// Wraps [PaywallScreen] with the necessary Provider / MaterialApp context.
///
/// NOTE: These tests use a real [AppState] (and therefore a real
/// [RevenueCatService]). When running on non-mobile CI hosts (Linux), the
/// service's [hasKeys] returns `false`, so tests exercise the
/// "keys not configured" path. To test the full purchase flow (offerings
/// loaded, purchase success/failure), add a mock [RevenueCatService] and a
/// [AppState] constructor that accepts it — this is left as a follow-up since
/// the existing test infrastructure in this repo does not yet use mocks.
Widget buildPaywallApp() {
  return ChangeNotifierProvider(
    create: (_) => AppState(),
    child: const MaterialApp(
      home: PaywallScreen(),
    ),
  );
}

void main() {
  group('PaywallScreen Tests', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildPaywallApp());
      // Allow async _loadOfferings to complete.
      await tester.pump();

      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('shows KINGTRUX Pro title', (WidgetTester tester) async {
      await tester.pumpWidget(buildPaywallApp());
      await tester.pump();

      // Title appears in AppBar and in the hero section.
      expect(find.text('KINGTRUX Pro'), findsWidgets);
    });

    testWidgets('shows subtitle copy', (WidgetTester tester) async {
      await tester.pumpWidget(buildPaywallApp());
      await tester.pump();

      expect(
        find.text('Truck GPS built for OTR in USA + Canada.'),
        findsOneWidget,
      );
    });

    testWidgets('shows feature bullet list', (WidgetTester tester) async {
      await tester.pumpWidget(buildPaywallApp());
      await tester.pump();

      // At least one bullet is visible.
      expect(
        find.text(
          'Truck routing with restrictions (height/weight/length/axles/hazmat)',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows pricing line', (WidgetTester tester) async {
      await tester.pumpWidget(buildPaywallApp());
      await tester.pump();

      expect(
        find.textContaining('\$9.99/month', skipOffstage: false),
        findsOneWidget,
      );
    });

    testWidgets('shows Restore purchases button', (WidgetTester tester) async {
      await tester.pumpWidget(buildPaywallApp());
      await tester.pump();

      expect(find.text('Restore purchases'), findsOneWidget);
    });

    testWidgets(
      'shows actionable error banner when SDK keys are not configured',
      (WidgetTester tester) async {
        await tester.pumpWidget(buildPaywallApp());
        await tester.pump();

        // When running outside iOS/Android (e.g. CI Linux host) hasKeys returns
        // false, so the paywall must show a helpful message instead of crashing.
        expect(
          find.textContaining('not configured', skipOffstage: false),
          findsOneWidget,
        );
      },
    );

    testWidgets('shows fine print text', (WidgetTester tester) async {
      await tester.pumpWidget(buildPaywallApp());
      await tester.pump();

      expect(
        find.textContaining(
          'Payment will be charged',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
    });

    testWidgets('shows Terms and Privacy links', (WidgetTester tester) async {
      await tester.pumpWidget(buildPaywallApp());
      await tester.pump();

      expect(
        find.textContaining('Terms of Service', skipOffstage: false),
        findsOneWidget,
      );
      expect(
        find.textContaining('Privacy Policy', skipOffstage: false),
        findsOneWidget,
      );
    });
  });
}

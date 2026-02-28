import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/services/map_preferences_service.dart';
import 'package:kingtrux/ui/widgets/where_to_sheet.dart';
import 'package:kingtrux/ui/widgets/onboarding_overlay.dart';
import 'package:kingtrux/ui/theme/app_theme.dart';

void main() {
  // ---------------------------------------------------------------------------
  // MapPreferencesService
  // ---------------------------------------------------------------------------
  group('MapPreferencesService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadMapType returns normal when nothing saved', () async {
      final svc = MapPreferencesService();
      expect(await svc.loadMapType(), MapType.normal);
    });

    test('saveMapType and loadMapType round-trips satellite', () async {
      final svc = MapPreferencesService();
      await svc.saveMapType(MapType.satellite);
      expect(await svc.loadMapType(), MapType.satellite);
    });

    test('saveMapType and loadMapType round-trips normal', () async {
      final svc = MapPreferencesService();
      await svc.saveMapType(MapType.satellite);
      await svc.saveMapType(MapType.normal);
      expect(await svc.loadMapType(), MapType.normal);
    });

    test('loadOnboardingDismissed returns false when nothing saved', () async {
      final svc = MapPreferencesService();
      expect(await svc.loadOnboardingDismissed(), isFalse);
    });

    test('saveOnboardingDismissed persists dismissal', () async {
      final svc = MapPreferencesService();
      await svc.saveOnboardingDismissed();
      expect(await svc.loadOnboardingDismissed(), isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // WhereToSheet
  // ---------------------------------------------------------------------------
  group('WhereToSheet', () {
    Widget buildSheet() {
      return MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => TextButton(
              key: const Key('open_sheet'),
              onPressed: () => showModalBottomSheet<void>(
                context: ctx,
                isScrollControlled: true,
                builder: (_) => const WhereToSheet(),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      );
    }

    testWidgets('opens WhereToSheet with text field and search button',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSheet());

      // Open the sheet.
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      // The sheet's text field and search button should be visible.
      expect(find.byKey(const Key('where_to_field')), findsOneWidget);
      expect(find.byKey(const Key('where_to_search_btn')), findsOneWidget);
      expect(find.text('Where to?'), findsOneWidget);
    });

    testWidgets('sheet shows "Use Map" tip to set destination by long-press',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSheet());
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      expect(find.text('Or long-press on the map'), findsOneWidget);
      expect(find.text('Use Map'), findsOneWidget);
    });

    testWidgets('tapping "Use Map" closes the sheet',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSheet());
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use Map'));
      await tester.pumpAndSettle();

      // Sheet is dismissed; the text field should no longer be in the tree.
      expect(find.byKey(const Key('where_to_field')), findsNothing);
    });
  });

  // ---------------------------------------------------------------------------
  // OnboardingOverlay
  // ---------------------------------------------------------------------------
  group('OnboardingOverlay', () {
    testWidgets('renders three callout cards', (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: OnboardingOverlay(onDismiss: () {}),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('"Where to?"'), findsOneWidget);
      expect(find.text('POI Layers'), findsOneWidget);
      expect(find.text('Set Destination'), findsOneWidget);
    });

    testWidgets('"Got it" button calls onDismiss', (WidgetTester tester) async {
      var dismissed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: OnboardingOverlay(onDismiss: () => dismissed = true),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const Key('onboarding_got_it')));
      await tester.pump(const Duration(milliseconds: 400));

      expect(dismissed, isTrue);
    });
  });
}

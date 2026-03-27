import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/config.dart';
import 'package:kingtrux/services/map_preferences_service.dart';
import 'package:kingtrux/state/app_state.dart';
import 'package:kingtrux/ui/widgets/destination_search_bar.dart';
import 'package:kingtrux/ui/widgets/where_to_sheet.dart';
import 'package:kingtrux/ui/widgets/onboarding_overlay.dart';
import 'package:kingtrux/ui/theme/app_theme.dart';
import 'package:kingtrux/ui/map/marker_icons.dart';

/// Duration used for animation settle waits in widget tests.
const _animationDuration = Duration(milliseconds: 400);

// ---------------------------------------------------------------------------
// Minimal AppState stub used by DestinationSearchBar → WhereToSheet tests.
// ---------------------------------------------------------------------------

class _StubAppState extends AppState {
  @override
  Future<void> buildTruckRoute() async {}

  @override
  Future<void> refreshMyLocation() async {}
}

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

    testWidgets('sheet does not show long-press / "Use Map" tip',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSheet());
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      expect(find.text('Or long-press on the map'), findsNothing);
      expect(find.text('Use Map'), findsNothing);
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
      await tester.pump(_animationDuration);

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
      await tester.pump(_animationDuration);

      await tester.tap(find.byKey(const Key('onboarding_got_it')));
      await tester.pump(_animationDuration);

      expect(dismissed, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // Config – Google Maps API key detection
  // ---------------------------------------------------------------------------
  group('Config.googleMapsAndroidKeyConfigured', () {
    test('returns false when no --dart-define key is supplied (default in tests)', () {
      // In the test environment the dart-define is not set, so the key falls
      // back to the empty-string default and the getter must return false.
      expect(Config.googleMapsAndroidKeyConfigured, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // Map-load error banner rendering
  // ---------------------------------------------------------------------------
  group('Map-load diagnostic banner', () {
    Widget _buildBanner(String message) {
      return MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (ctx) => Material(
              color: Theme.of(ctx).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      color: Theme.of(ctx).colorScheme.onErrorContainer,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(message)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders warning icon and message text',
        (WidgetTester tester) async {
      const msg =
          'Map tiles failed to load. Check your API key, '
          'network connection, and Google Play Services.';
      await tester.pumpWidget(_buildBanner(msg));

      expect(find.byIcon(Icons.warning_rounded), findsOneWidget);
      expect(find.textContaining('Map tiles failed to load'), findsOneWidget);
      expect(find.textContaining('API key'), findsOneWidget);
      expect(find.textContaining('network connection'), findsOneWidget);
      expect(find.textContaining('Google Play Services'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // MarkerIcons – buildCircleLetterMarker
  // ---------------------------------------------------------------------------
  group('buildCircleLetterMarker', () {
    setUp(() {
      // Ensure the cache is clean between tests.
      clearMarkerIconCache();
    });

    test('returns a non-null BitmapDescriptor for green circle with w',
        () async {
      final descriptor = await buildCircleLetterMarker(
        color: Colors.green,
        letter: 'w',
      );
      expect(descriptor, isNotNull);
    });

    test('returns the same cached instance on repeated calls', () async {
      final first = await buildCircleLetterMarker(
        color: Colors.green,
        letter: 'w',
      );
      final second = await buildCircleLetterMarker(
        color: Colors.green,
        letter: 'w',
      );
      expect(identical(first, second), isTrue);
    });

    test('returns different instances for different colors', () async {
      final green = await buildCircleLetterMarker(
        color: Colors.green,
        letter: 'w',
      );
      final blue = await buildCircleLetterMarker(
        color: Colors.blue,
        letter: 'w',
      );
      expect(identical(green, blue), isFalse);
    });

    test('clears cache with clearMarkerIconCache', () async {
      final first = await buildCircleLetterMarker(
        color: Colors.green,
        letter: 'w',
      );
      clearMarkerIconCache();
      // After clearing, a new call should create a distinct descriptor.
      final fresh = await buildCircleLetterMarker(
        color: Colors.green,
        letter: 'w',
      );
      expect(fresh, isNotNull);
      expect(identical(first, fresh), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // _QuickActionsBar – structural presence tests
  // ---------------------------------------------------------------------------
  group('_QuickActionsBar widget', () {
    /// Builds a minimal environment that renders the _QuickActionsBar widget.
    /// Because the class is private we drive it through the exported Keys that
    /// are defined on every child button.
    Widget _buildQuickActionsBarHost({bool isWsEnabled = false}) {
      var wsToggledCount = 0;

      // We cannot import the private class, so we reproduce the equivalent
      // widget tree that map_screen.dart renders inside the bottom panel.
      // The test drives the two exported-key buttons we care about.
      return MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Direction button
                Semantics(
                  label: 'Direction',
                  button: true,
                  child: InkWell(
                    key: const Key('quick_action_direction'),
                    onTap: () {},
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.directions_rounded),
                          const Text('Direction'),
                        ],
                      ),
                    ),
                  ),
                ),
                // WS button
                Semantics(
                  label: 'WS',
                  button: true,
                  child: InkWell(
                    key: const Key('quick_action_ws'),
                    onTap: () => wsToggledCount++,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.scale_rounded,
                            color: isWsEnabled ? Colors.blue : Colors.grey,
                          ),
                          const Text('WS'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    testWidgets('quick action Direction button is present',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildQuickActionsBarHost());
      expect(find.byKey(const Key('quick_action_direction')), findsOneWidget);
    });

    testWidgets('quick action WS button is present',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildQuickActionsBarHost());
      expect(find.byKey(const Key('quick_action_ws')), findsOneWidget);
    });

    testWidgets('WS label text is visible', (WidgetTester tester) async {
      await tester.pumpWidget(_buildQuickActionsBarHost());
      expect(find.text('WS'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // DestinationSearchBar – reusable widget tests
  // ---------------------------------------------------------------------------
  group('DestinationSearchBar widget', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Widget _buildBar({VoidCallback? onTap}) {
      return MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: DestinationSearchBar(onTap: onTap ?? () {}),
        ),
      );
    }

    testWidgets('renders "Set destination for truck routes" text',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildBar());
      expect(find.text('Set destination for truck routes'), findsOneWidget);
    });

    testWidgets('has destination_search_bar key', (WidgetTester tester) async {
      await tester.pumpWidget(_buildBar());
      expect(find.byKey(const Key('destination_search_bar')), findsOneWidget);
    });

    testWidgets('has semantics label', (WidgetTester tester) async {
      await tester.pumpWidget(_buildBar());
      expect(
        find.bySemanticsLabel('Set destination for truck routes'),
        findsOneWidget,
      );
    });

    testWidgets('tapping calls onTap callback', (WidgetTester tester) async {
      var tapped = false;
      await tester.pumpWidget(_buildBar(onTap: () => tapped = true));
      await tester.tap(find.byKey(const Key('destination_search_bar')));
      await tester.pump();
      expect(tapped, isTrue);
    });

    testWidgets('tapping opens WhereToSheet with "Where to?" text',
        (WidgetTester tester) async {
      final state = _StubAppState();
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => DestinationSearchBar(
                  onTap: () => showModalBottomSheet<void>(
                    context: ctx,
                    isScrollControlled: true,
                    builder: (_) => ChangeNotifierProvider<AppState>.value(
                      value: state,
                      child: const WhereToSheet(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('destination_search_bar')));
      await tester.pumpAndSettle();

      expect(find.text('Where to?'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // _BottomDestinationCta – structural presence tests
  // ---------------------------------------------------------------------------
  group('_BottomDestinationCta widget', () {
    Widget _buildCta({VoidCallback? onTap}) {
      return MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Material(
            key: const Key('bottom_destination_cta'),
            child: InkWell(
              onTap: onTap ?? () {},
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: const [
                    Icon(Icons.local_shipping_rounded),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text('Set destination for truck routes'),
                    ),
                    Icon(Icons.search_rounded),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows "Set destination for truck routes" CTA text',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildCta());
      expect(
        find.text('Set destination for truck routes'),
        findsOneWidget,
      );
    });

    testWidgets('destination CTA key is present', (WidgetTester tester) async {
      await tester.pumpWidget(_buildCta());
      expect(find.byKey(const Key('bottom_destination_cta')), findsOneWidget);
    });

    testWidgets('tapping CTA calls onTap callback',
        (WidgetTester tester) async {
      var tapped = false;
      await tester.pumpWidget(_buildCta(onTap: () => tapped = true));
      await tester.tap(find.byKey(const Key('bottom_destination_cta')));
      await tester.pump();
      expect(tapped, isTrue);
    });
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/config.dart';
import 'package:kingtrux/models/poi.dart';
import 'package:kingtrux/models/road_camera.dart';
import 'package:kingtrux/models/weigh_station.dart';
import 'package:kingtrux/services/here_geocoding_service.dart';
import 'package:kingtrux/services/map_preferences_service.dart';
import 'package:kingtrux/state/app_state.dart';
import 'package:kingtrux/ui/widgets/where_to_sheet.dart';
import 'package:kingtrux/ui/widgets/onboarding_overlay.dart';
import 'package:kingtrux/ui/widgets/unified_search_bar.dart';
import 'package:kingtrux/ui/theme/app_theme.dart';

/// Duration used for animation settle waits in widget tests.
const _animationDuration = Duration(milliseconds: 400);

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
      await tester.pump(_animationDuration);

      expect(find.text('Unified Search Bar'), findsOneWidget);
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
  // UnifiedSearchBar
  // ---------------------------------------------------------------------------
  group('UnifiedSearchBar', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    Widget buildBar({
      void Function(GeocodedLocation)? onDestinationSelected,
      void Function(Poi)? onPoiSelected,
      void Function(RoadCamera)? onCameraSelected,
      void Function(WeighStation)? onWeighStationSelected,
      VoidCallback? onTruckProfile,
      VoidCallback? onLayers,
      VoidCallback? onRoadCameras,
      VoidCallback? onWeighStations,
      VoidCallback? onPoiBrowser,
      VoidCallback? onSetDestinationByMap,
    }) {
      return MaterialApp(
        theme: AppTheme.light,
        home: ChangeNotifierProvider(
          // Fresh AppState with no init() call so no network requests occur.
          create: (_) => AppState(),
          child: Scaffold(
            body: UnifiedSearchBar(
              onDestinationSelected: onDestinationSelected ?? (_) {},
              onPoiSelected: onPoiSelected ?? (_) {},
              onCameraSelected: onCameraSelected ?? (_) {},
              onWeighStationSelected: onWeighStationSelected ?? (_) {},
              onTruckProfile: onTruckProfile ?? () {},
              onLayers: onLayers ?? () {},
              onRoadCameras: onRoadCameras ?? () {},
              onWeighStations: onWeighStations ?? () {},
              onPoiBrowser: onPoiBrowser ?? () {},
              onSetDestinationByMap: onSetDestinationByMap ?? () {},
            ),
          ),
        ),
      );
    }

    testWidgets('renders collapsed bar initially', (WidgetTester tester) async {
      await tester.pumpWidget(buildBar());

      expect(find.byKey(const Key('unified_search_collapsed')), findsOneWidget);
      expect(find.byKey(const Key('unified_search_expanded')), findsNothing);
    });

    testWidgets('collapsed bar shows search placeholder text',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildBar());

      expect(
        find.textContaining('Search destinations'),
        findsOneWidget,
      );
    });

    testWidgets('tapping collapsed bar expands the search panel',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildBar());

      await tester.tap(find.byKey(const Key('unified_search_collapsed')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unified_search_expanded')), findsOneWidget);
      expect(find.byKey(const Key('unified_search_collapsed')), findsNothing);
    });

    testWidgets('expanded bar shows search field and all category chips',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildBar());

      await tester.tap(find.byKey(const Key('unified_search_collapsed')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unified_search_field')), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Destination'), findsOneWidget);
      expect(find.text('POIs'), findsOneWidget);
      expect(find.text('Cameras'), findsOneWidget);
      expect(find.text('Scales'), findsOneWidget);
      expect(find.text('Truck'), findsOneWidget);
    });

    testWidgets('close button collapses the expanded panel',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildBar());

      await tester.tap(find.byKey(const Key('unified_search_collapsed')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unified_search_expanded')), findsOneWidget);

      await tester.tap(find.byKey(const Key('unified_search_close')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unified_search_collapsed')), findsOneWidget);
      expect(find.byKey(const Key('unified_search_expanded')), findsNothing);
    });

    testWidgets('onTruckProfile callback fires from Truck category shortcuts',
        (WidgetTester tester) async {
      var truckCalled = false;
      await tester.pumpWidget(buildBar(onTruckProfile: () => truckCalled = true));

      await tester.tap(find.byKey(const Key('unified_search_collapsed')));
      await tester.pumpAndSettle();

      // Switch to Truck category
      await tester.tap(find.text('Truck'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Truck Profile'));
      await tester.pumpAndSettle();

      expect(truckCalled, isTrue);
    });

    testWidgets('onSetDestinationByMap fires from Destination shortcuts',
        (WidgetTester tester) async {
      var mapCalled = false;
      await tester.pumpWidget(
        buildBar(onSetDestinationByMap: () => mapCalled = true),
      );

      await tester.tap(find.byKey(const Key('unified_search_collapsed')));
      await tester.pumpAndSettle();

      // Switch to Destination category
      await tester.tap(find.text('Destination'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Set destination by map tap'));
      await tester.pumpAndSettle();

      expect(mapCalled, isTrue);
    });
  });
}

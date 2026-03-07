import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kingtrux/models/road_camera.dart';
import 'package:kingtrux/services/road_camera_service.dart';
import 'package:kingtrux/ui/widgets/road_cameras_sheet.dart';
import 'package:kingtrux/state/app_state.dart';
import 'package:kingtrux/ui/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// RoadCamera model
// ---------------------------------------------------------------------------

void main() {
  group('RoadCamera model', () {
    const camera = RoadCamera(
      id: 'test_cam_1',
      name: 'I-95 Northbound',
      lat: 40.0,
      lng: -74.0,
      country: 'US',
      stateOrProvince: 'NJ',
      direction: 'Northbound',
      imageUrl: 'https://example.com/cam1.jpg',
    );

    test('equality is based on id', () {
      const same = RoadCamera(
        id: 'test_cam_1',
        name: 'Different Name',
        lat: 99.0,
        lng: 99.0,
        country: 'CA',
      );
      expect(camera, equals(same));
    });

    test('different ids are not equal', () {
      const other = RoadCamera(
        id: 'test_cam_2',
        name: 'I-95 Northbound',
        lat: 40.0,
        lng: -74.0,
        country: 'US',
      );
      expect(camera, isNot(equals(other)));
    });

    test('hashCode matches for equal objects', () {
      const same = RoadCamera(
        id: 'test_cam_1',
        name: 'Other',
        lat: 0,
        lng: 0,
        country: 'US',
      );
      expect(camera.hashCode, equals(same.hashCode));
    });

    test('distanceFromMeters returns 0 when at same coordinates', () {
      final dist = camera.distanceFromMeters(40.0, -74.0);
      expect(dist, closeTo(0.0, 0.01));
    });

    test('distanceFromMeters returns positive value for different point', () {
      // ~111 km per degree of latitude.
      final dist = camera.distanceFromMeters(41.0, -74.0);
      expect(dist, greaterThan(100000));
      expect(dist, lessThan(120000));
    });

    test('toString includes id, name, and country', () {
      final s = camera.toString();
      expect(s, contains('test_cam_1'));
      expect(s, contains('I-95 Northbound'));
      expect(s, contains('US'));
    });
  });

  // -------------------------------------------------------------------------
  // RoadCameraService – demo data path (no API key configured in tests)
  // -------------------------------------------------------------------------

  group('RoadCameraService demo data', () {
    // In the test environment no API key is configured, so the service always
    // returns demo cameras without making any HTTP calls.

    test('returns demo cameras when no API key is configured', () async {
      final service = RoadCameraService();

      final cameras = await service.fetchCameras(
        centerLat: 40.7128,
        centerLng: -74.0060,
        radiusKm: 5000, // large radius to include all demo cameras
      );

      expect(cameras, isNotEmpty);
      for (final c in cameras) {
        expect(c.id, isNotEmpty);
        expect(c.name, isNotEmpty);
        expect(c.country, anyOf(equals('US'), equals('CA')));
      }
    });

    test('demo cameras are sorted ascending by distance', () async {
      final service = RoadCameraService();

      const userLat = 40.7128;
      const userLng = -74.0060;

      final cameras = await service.fetchCameras(
        centerLat: userLat,
        centerLng: userLng,
        radiusKm: 5000,
      );

      for (var i = 1; i < cameras.length; i++) {
        final dPrev = cameras[i - 1].distanceFromMeters(userLat, userLng);
        final dCurr = cameras[i].distanceFromMeters(userLat, userLng);
        // Allow 1 m rounding tolerance.
        expect(dPrev, lessThanOrEqualTo(dCurr + 1));
      }
    });

    test('US and CA cameras present in demo set', () async {
      final service = RoadCameraService();

      final cameras = await service.fetchCameras(
        centerLat: 40.0,
        centerLng: -96.0,
        radiusKm: 10000,
      );

      expect(cameras.any((c) => c.country == 'US'), isTrue);
      expect(cameras.any((c) => c.country == 'CA'), isTrue);
    });

    test('radiusKm filter excludes distant cameras', () async {
      final service = RoadCameraService();

      // Very small radius centred in the Atlantic Ocean; all demo cameras
      // are on land so none should be within 50 km.
      final cameras = await service.fetchCameras(
        centerLat: 35.0,
        centerLng: -45.0,
        radiusKm: 50,
      );

      expect(cameras, isEmpty);
    });
  });

  // -------------------------------------------------------------------------
  // RoadCamerasSheet widget smoke tests
  // -------------------------------------------------------------------------

  group('RoadCamerasSheet widget', () {
    Widget buildSheet({List<RoadCamera> cameras = const []}) {
      final state = AppState();
      state
        ..myLat = 40.7128
        ..myLng = -74.0060;
      state.roadCameras = cameras;

      return ChangeNotifierProvider<AppState>.value(
        value: state,
        child: MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                key: const Key('open_sheet'),
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => ChangeNotifierProvider<AppState>.value(
                    value: state,
                    child: const RoadCamerasSheet(),
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('renders title and load button', (WidgetTester tester) async {
      await tester.pumpWidget(buildSheet());
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      expect(find.text('Road Cameras'), findsOneWidget);
      expect(find.text('Load Cameras Near Me'), findsOneWidget);
    });

    testWidgets('shows country filter chips', (WidgetTester tester) async {
      await tester.pumpWidget(buildSheet());
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      expect(find.textContaining('USA'), findsOneWidget);
      expect(find.textContaining('Canada'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
    });

    testWidgets('lists camera tiles when cameras are present',
        (WidgetTester tester) async {
      const cameras = [
        RoadCamera(
          id: 'c1',
          name: 'Test Cam NY',
          lat: 40.7,
          lng: -74.0,
          country: 'US',
          stateOrProvince: 'NY',
        ),
        RoadCamera(
          id: 'c2',
          name: 'Test Cam BC',
          lat: 49.3,
          lng: -123.1,
          country: 'CA',
          stateOrProvince: 'BC',
        ),
      ];

      await tester.pumpWidget(buildSheet(cameras: cameras));
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      expect(find.text('Test Cam NY'), findsOneWidget);
      expect(find.text('Test Cam BC'), findsOneWidget);
    });

    testWidgets('search field filters camera list', (WidgetTester tester) async {
      const cameras = [
        RoadCamera(
          id: 'c1',
          name: 'Upstate NY Camera',
          lat: 42.0,
          lng: -76.0,
          country: 'US',
          stateOrProvince: 'NY',
        ),
        RoadCamera(
          id: 'c2',
          name: 'Chicago Express Cam',
          lat: 41.9,
          lng: -87.6,
          country: 'US',
          stateOrProvince: 'IL',
        ),
      ];

      await tester.pumpWidget(buildSheet(cameras: cameras));
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'Upstate');
      await tester.pumpAndSettle();

      expect(find.text('Upstate NY Camera'), findsOneWidget);
      expect(find.text('Chicago Express Cam'), findsNothing);
    });

    testWidgets('shows empty state when no cameras are loaded',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSheet());
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      expect(find.textContaining('No cameras loaded yet'), findsOneWidget);
    });

    testWidgets('shows demo-data notice when API key is not configured',
        (WidgetTester tester) async {
      await tester.pumpWidget(buildSheet());
      await tester.tap(find.byKey(const Key('open_sheet')));
      await tester.pumpAndSettle();

      // The notice is shown when Config.roadCameraApiConfigured is false,
      // which is always the case in the test environment.
      expect(
        find.textContaining('ROAD_CAMERA_511_API_KEY'),
        findsOneWidget,
      );
    });
  });
}

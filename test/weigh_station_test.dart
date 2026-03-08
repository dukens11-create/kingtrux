import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/weigh_station.dart';
import 'package:kingtrux/services/weigh_station_monitor.dart';
import 'package:kingtrux/services/weigh_station_settings_service.dart';
import 'package:kingtrux/services/weigh_station_status_provider.dart';
import 'package:kingtrux/services/weigh_station_service.dart';
import 'package:kingtrux/state/app_state.dart';
import 'package:kingtrux/ui/theme/app_theme.dart';
import 'package:kingtrux/ui/widgets/weigh_station_detail_sheet.dart';

// ---------------------------------------------------------------------------
// WeighStation model
// ---------------------------------------------------------------------------

void main() {
  group('WeighStation model', () {
    const station = WeighStation(
      id: 'ws_test_1',
      name: 'I-80 Weigh Station',
      lat: 41.0,
      lng: -110.0,
      status: WeighStationStatus.open,
      highway: 'I-80',
      stateOrProvince: 'WY',
      direction: 'Eastbound',
    );

    test('equality is based on id', () {
      const same = WeighStation(
        id: 'ws_test_1',
        name: 'Different Name',
        lat: 0.0,
        lng: 0.0,
      );
      expect(station, equals(same));
    });

    test('different ids are not equal', () {
      const other = WeighStation(
        id: 'ws_test_2',
        name: 'I-80 Weigh Station',
        lat: 41.0,
        lng: -110.0,
      );
      expect(station, isNot(equals(other)));
    });

    test('hashCode matches for equal objects', () {
      const same = WeighStation(id: 'ws_test_1', name: 'Other', lat: 0, lng: 0);
      expect(station.hashCode, equals(same.hashCode));
    });

    test('copyWith replaces status', () {
      final updated = station.copyWith(status: WeighStationStatus.closed);
      expect(updated.status, WeighStationStatus.closed);
      expect(updated.id, station.id);
      expect(updated.name, station.name);
      expect(updated.lat, station.lat);
      expect(updated.lng, station.lng);
    });

    test('copyWith without args returns equivalent object', () {
      final copy = station.copyWith();
      expect(copy, equals(station));
      expect(copy.status, station.status);
    });

    test('distanceFromMeters returns 0 when at same coordinates', () {
      final dist = station.distanceFromMeters(41.0, -110.0);
      expect(dist, closeTo(0.0, 0.01));
    });

    test('distanceFromMeters returns positive for different point', () {
      // ~111 km per degree of latitude
      final dist = station.distanceFromMeters(42.0, -110.0);
      expect(dist, greaterThan(100000));
      expect(dist, lessThan(120000));
    });

    test('toString includes id, name, and status', () {
      final s = station.toString();
      expect(s, contains('ws_test_1'));
      expect(s, contains('I-80 Weigh Station'));
      expect(s, contains('open'));
    });

    test('default status is unknown', () {
      const minimal = WeighStation(id: 'x', name: 'X', lat: 0, lng: 0);
      expect(minimal.status, WeighStationStatus.unknown);
    });
  });

  // ---------------------------------------------------------------------------
  // WeighStationStatusProvider
  // ---------------------------------------------------------------------------

  group('DefaultWeighStationStatusProvider', () {
    test('returns unknown when no override configured', () {
      const provider = DefaultWeighStationStatusProvider();
      expect(
        provider.statusFor('any_id'),
        WeighStationStatus.unknown,
      );
    });

    test('returns configured override status', () {
      const provider = DefaultWeighStationStatusProvider(overrides: {
        'ws_1': WeighStationStatus.open,
        'ws_2': WeighStationStatus.closed,
        'ws_3': WeighStationStatus.monitored,
      });
      expect(provider.statusFor('ws_1'), WeighStationStatus.open);
      expect(provider.statusFor('ws_2'), WeighStationStatus.closed);
      expect(provider.statusFor('ws_3'), WeighStationStatus.monitored);
    });

    test('returns unknown for non-overridden ids', () {
      const provider = DefaultWeighStationStatusProvider(overrides: {
        'ws_1': WeighStationStatus.open,
      });
      expect(provider.statusFor('ws_other'), WeighStationStatus.unknown);
    });
  });

  // ---------------------------------------------------------------------------
  // WeighStationMonitor
  // ---------------------------------------------------------------------------

  group('WeighStationMonitor', () {
    const stations = [
      WeighStation(
        id: 'ws_near',
        name: 'Nearby Station',
        lat: 40.001,  // ~111 m from 40.0
        lng: -74.0,
      ),
      WeighStation(
        id: 'ws_far',
        name: 'Far Station',
        lat: 50.0,  // ~1110 km from 40.0
        lng: -74.0,
      ),
    ];

    test('fires onApproaching when station is within threshold', () {
      final monitor = WeighStationMonitor(thresholdMeters: 500);
      WeighStation? alerted;
      monitor.onApproaching = (s, _) => alerted = s;

      monitor.update(lat: 40.0, lng: -74.0, stations: stations);

      expect(alerted?.id, equals('ws_near'));
    });

    test('does not fire for station beyond threshold', () {
      final monitor = WeighStationMonitor(thresholdMeters: 500);
      final alerted = <String>[];
      monitor.onApproaching = (s, _) => alerted.add(s.id);

      monitor.update(lat: 40.0, lng: -74.0, stations: stations);

      expect(alerted, isNot(contains('ws_far')));
    });

    test('does not fire again within cooldown period', () {
      final monitor = WeighStationMonitor(thresholdMeters: 500);
      int count = 0;
      monitor.onApproaching = (_, __) => count++;

      monitor.update(lat: 40.0, lng: -74.0, stations: stations);
      monitor.update(lat: 40.0, lng: -74.0, stations: stations);

      // Only fires once because cooldown prevents re-alert.
      expect(count, equals(1));
    });

    test('reset clears cooldown so alert fires again', () {
      final monitor = WeighStationMonitor(thresholdMeters: 500);
      int count = 0;
      monitor.onApproaching = (_, __) => count++;

      monitor.update(lat: 40.0, lng: -74.0, stations: stations);
      monitor.reset();
      monitor.update(lat: 40.0, lng: -74.0, stations: stations);

      expect(count, equals(2));
    });

    test('does not fire when enabled is false', () {
      final monitor = WeighStationMonitor(thresholdMeters: 500);
      WeighStation? alerted;
      monitor.onApproaching = (s, _) => alerted = s;

      monitor.update(
        lat: 40.0,
        lng: -74.0,
        stations: stations,
        enabled: false,
      );

      expect(alerted, isNull);
    });

    test('default threshold is defaultThresholdMeters', () {
      final monitor = WeighStationMonitor();
      expect(monitor.thresholdMeters, WeighStationMonitor.defaultThresholdMeters);
    });

    test('custom threshold is honoured', () {
      final monitor = WeighStationMonitor(thresholdMeters: 1000);
      expect(monitor.thresholdMeters, 1000);
    });
  });

  // ---------------------------------------------------------------------------
  // WeighStationSettings
  // ---------------------------------------------------------------------------

  group('WeighStationSettings', () {
    test('defaults: showOnMap=true, alertsEnabled=false', () {
      const s = WeighStationSettings();
      expect(s.showOnMap, isTrue);
      expect(s.alertsEnabled, isFalse);
      expect(s.alertThresholdMeters, 4828.0);
    });

    test('copyWith changes only specified fields', () {
      const s = WeighStationSettings(
        showOnMap: true,
        alertsEnabled: false,
        alertThresholdMeters: 3000,
      );
      final s2 = s.copyWith(alertsEnabled: true);
      expect(s2.showOnMap, isTrue);
      expect(s2.alertsEnabled, isTrue);
      expect(s2.alertThresholdMeters, 3000);
    });
  });

  // ---------------------------------------------------------------------------
  // WeighStationSettingsService
  // ---------------------------------------------------------------------------

  group('WeighStationSettingsService', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('load returns defaults when nothing saved', () async {
      final svc = WeighStationSettingsService();
      final settings = await svc.load();
      expect(settings.showOnMap, isTrue);
      expect(settings.alertsEnabled, isFalse);
      expect(settings.alertThresholdMeters, 4828.0);
    });

    test('save and reload preserves values', () async {
      final svc = WeighStationSettingsService();
      const toSave = WeighStationSettings(
        showOnMap: false,
        alertsEnabled: true,
        alertThresholdMeters: 8047.0,
      );
      await svc.save(toSave);
      final loaded = await svc.load();
      expect(loaded.showOnMap, isFalse);
      expect(loaded.alertsEnabled, isTrue);
      expect(loaded.alertThresholdMeters, 8047.0);
    });
  });

  // ---------------------------------------------------------------------------
  // WeighStationService – demo data
  // ---------------------------------------------------------------------------

  group('WeighStationService demo data', () {
    test('returns demo stations near North America coordinates', () async {
      final svc = WeighStationService();
      // CA coordinate – should include at least the CA demo station.
      final stations = await svc.fetchStations(
        centerLat: 40.0,
        centerLng: -120.0,
        radiusKm: 200,
      );
      expect(stations, isNotEmpty);
    });

    test('enriches stations with status from provider', () async {
      final svc = WeighStationService(
        statusProvider: const DefaultWeighStationStatusProvider(overrides: {
          'ws_demo_us_ca_1': WeighStationStatus.open,
        }),
      );
      final stations = await svc.fetchStations(
        centerLat: 40.0,
        centerLng: -120.0,
        radiusKm: 200,
      );
      final ca = stations.where((s) => s.id == 'ws_demo_us_ca_1').toList();
      expect(ca, hasLength(1));
      expect(ca.first.status, WeighStationStatus.open);
    });

    test('returns empty list when far from all demo stations', () async {
      final svc = WeighStationService();
      final stations = await svc.fetchStations(
        centerLat: -33.9,   // Sydney, AU – far from all demo stations
        centerLng: 151.2,
        radiusKm: 100,
      );
      expect(stations, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // WeighStationDetailSheet widget
  // ---------------------------------------------------------------------------

  group('WeighStationDetailSheet', () {
    Widget buildSheet(WeighStation station) {
      return MaterialApp(
        theme: AppTheme.light,
        home: ChangeNotifierProvider(
          create: (_) => AppState(),
          child: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => WeighStationDetailSheet(station: station),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows station name', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      const station = WeighStation(
        id: 'ws_ui_1',
        name: 'Test Weigh Station',
        lat: 40.0,
        lng: -74.0,
        status: WeighStationStatus.open,
      );

      await tester.pumpWidget(buildSheet(station));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Test Weigh Station'), findsOneWidget);
    });

    testWidgets('shows OPEN status for open station', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      const station = WeighStation(
        id: 'ws_ui_2',
        name: 'Open Station',
        lat: 40.0,
        lng: -74.0,
        status: WeighStationStatus.open,
      );

      await tester.pumpWidget(buildSheet(station));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('OPEN'), findsOneWidget);
    });

    testWidgets('shows CLOSED status for closed station', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      const station = WeighStation(
        id: 'ws_ui_3',
        name: 'Closed Station',
        lat: 40.0,
        lng: -74.0,
        status: WeighStationStatus.closed,
      );

      await tester.pumpWidget(buildSheet(station));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('CLOSED'), findsOneWidget);
    });

    testWidgets('shows MONITORED status', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      const station = WeighStation(
        id: 'ws_ui_4',
        name: 'Monitored Station',
        lat: 40.0,
        lng: -74.0,
        status: WeighStationStatus.monitored,
      );

      await tester.pumpWidget(buildSheet(station));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('MONITORED'), findsOneWidget);
    });

    testWidgets('shows unknown status message', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      const station = WeighStation(
        id: 'ws_ui_5',
        name: 'Unknown Station',
        lat: 40.0,
        lng: -74.0,
        status: WeighStationStatus.unknown,
      );

      await tester.pumpWidget(buildSheet(station));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('unknown'), findsOneWidget);
    });

    testWidgets('shows Navigate button', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      const station = WeighStation(
        id: 'ws_ui_6',
        name: 'Nav Station',
        lat: 40.0,
        lng: -74.0,
      );

      await tester.pumpWidget(buildSheet(station));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Navigate'), findsOneWidget);
    });

    testWidgets('shows Weigh Station label', (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      const station = WeighStation(
        id: 'ws_ui_7',
        name: 'Label Station',
        lat: 40.0,
        lng: -74.0,
      );

      await tester.pumpWidget(buildSheet(station));
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('Weigh Station'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // AppState – weigh station state management
  // ---------------------------------------------------------------------------

  group('AppState weigh station', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('initial weighStations is empty', () {
      final state = AppState();
      expect(state.weighStations, isEmpty);
    });

    test('initial weighStationSettings uses defaults', () {
      final state = AppState();
      expect(state.weighStationSettings.showOnMap, isTrue);
      expect(state.weighStationSettings.alertsEnabled, isFalse);
    });

    test('setWeighStationSettings updates state and notifies listeners', () {
      final state = AppState();
      var notified = false;
      state.addListener(() => notified = true);

      state.setWeighStationSettings(
        const WeighStationSettings(
          showOnMap: false,
          alertsEnabled: true,
          alertThresholdMeters: 3000,
        ),
      );

      expect(state.weighStationSettings.showOnMap, isFalse);
      expect(state.weighStationSettings.alertsEnabled, isTrue);
      expect(state.weighStationSettings.alertThresholdMeters, 3000);
      expect(notified, isTrue);
    });
  });
}

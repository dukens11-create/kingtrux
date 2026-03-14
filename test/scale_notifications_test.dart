import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/scale_report.dart';
import 'package:kingtrux/models/alert_event.dart';
import 'package:kingtrux/models/poi.dart';
import 'package:kingtrux/services/scale_report_service.dart';
import 'package:kingtrux/services/scale_monitor.dart';
import 'package:kingtrux/services/scale_pass_monitor.dart';
import 'package:kingtrux/state/app_state.dart';

void main() {
  // ---------------------------------------------------------------------------
  // ScaleReport model
  // ---------------------------------------------------------------------------
  group('ScaleReport model', () {
    test('round-trips through JSON for each status', () {
      for (final status in ScaleStatus.values) {
        final report = ScaleReport(
          poiId: 'poi_1',
          poiName: 'Test Scale',
          status: status,
          lat: 40.0,
          lng: -90.0,
          reportedAt: DateTime.utc(2025, 6, 1, 12, 0),
        );
        final json = report.toJson();
        final decoded = ScaleReport.fromJson(json);

        expect(decoded.poiId, report.poiId);
        expect(decoded.poiName, report.poiName);
        expect(decoded.status, report.status);
        expect(decoded.lat, report.lat);
        expect(decoded.lng, report.lng);
        expect(decoded.reportedAt, report.reportedAt);
      }
    });

    test('fromJson falls back to notSure for unknown status', () {
      final json = {
        'poiId': 'x',
        'poiName': 'Unknown',
        'status': 'unknown_value',
        'lat': 1.0,
        'lng': 2.0,
        'reportedAt': '2025-01-01T00:00:00.000Z',
      };
      final report = ScaleReport.fromJson(json);
      expect(report.status, ScaleStatus.notSure);
    });

    test('fromJson falls back to notSure for old "open" status', () {
      final json = {
        'poiId': 'x',
        'poiName': 'Old Scale',
        'status': 'open',
        'lat': 1.0,
        'lng': 2.0,
        'reportedAt': '2025-01-01T00:00:00.000Z',
      };
      final report = ScaleReport.fromJson(json);
      expect(report.status, ScaleStatus.notSure);
    });

    test('fromJson falls back to notSure for old "monitoring" status', () {
      final json = {
        'poiId': 'x',
        'poiName': 'Old Scale',
        'status': 'monitoring',
        'lat': 1.0,
        'lng': 2.0,
        'reportedAt': '2025-01-01T00:00:00.000Z',
      };
      final report = ScaleReport.fromJson(json);
      expect(report.status, ScaleStatus.notSure);
    });
  });

  // ---------------------------------------------------------------------------
  // ScaleReportService persistence
  // ---------------------------------------------------------------------------
  group('ScaleReportService', () {
    late ScaleReportService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = ScaleReportService();
    });

    test('load returns empty list when nothing is persisted', () async {
      final reports = await service.load();
      expect(reports, isEmpty);
    });

    test('save and load round-trips reports', () async {
      final reports = [
        ScaleReport(
          poiId: 'scale_a',
          poiName: 'Scale A',
          status: ScaleStatus.openBypass,
          lat: 35.0,
          lng: -80.0,
          reportedAt: DateTime.utc(2025, 3, 10, 9, 0),
        ),
        ScaleReport(
          poiId: 'scale_b',
          poiName: 'Scale B',
          status: ScaleStatus.closed,
          lat: 36.0,
          lng: -81.0,
          reportedAt: DateTime.utc(2025, 3, 10, 10, 0),
        ),
      ];

      await service.save(reports);
      final loaded = await service.load();

      expect(loaded.length, 2);
      expect(loaded[0].poiId, 'scale_a');
      expect(loaded[0].status, ScaleStatus.openBypass);
      expect(loaded[1].poiId, 'scale_b');
      expect(loaded[1].status, ScaleStatus.closed);
    });

    test('load returns empty list when data is corrupt', () async {
      SharedPreferences.setMockInitialValues({
        'scale_reports': 'not-valid-json{{{',
      });
      final loaded = await service.load();
      expect(loaded, isEmpty);
    });

    test('overwriting save replaces previous data', () async {
      await service.save([
        ScaleReport(
          poiId: 'a',
          poiName: 'A',
          status: ScaleStatus.openBypass,
          lat: 0,
          lng: 0,
          reportedAt: DateTime.utc(2025, 1, 1),
        ),
      ]);
      await service.save([]);
      final loaded = await service.load();
      expect(loaded, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // ScaleMonitor
  // ---------------------------------------------------------------------------
  group('ScaleMonitor', () {
    late ScaleMonitor monitor;

    setUp(() {
      monitor = ScaleMonitor();
    });

    ScaleReport makeScaleReport({
      String poiId = 'scale_1',
      String poiName = 'Test Scale',
      ScaleStatus status = ScaleStatus.openBypass,
      double lat = 40.0,
      double lng = -90.0,
    }) =>
        ScaleReport(
          poiId: poiId,
          poiName: poiName,
          status: status,
          lat: lat,
          lng: lng,
          reportedAt: DateTime.utc(2025, 1, 1),
        );

    test('fires callback when scale is within threshold', () {
      ScaleReport? fired;
      double? firedDist;
      monitor.onNearbyScale = (r, d) {
        fired = r;
        firedDist = d;
      };

      // Place driver at same location as scale — distance = 0
      monitor.update(
        lat: 40.0,
        lng: -90.0,
        reports: [makeScaleReport()],
      );

      expect(fired, isNotNull);
      expect(fired!.poiId, 'scale_1');
      expect(firedDist, lessThan(ScaleMonitor.nearbyThresholdMeters));
    });

    test('does not fire callback when scale is beyond threshold', () {
      var fired = false;
      monitor.onNearbyScale = (_, __) => fired = true;

      // Place driver far away (~111 km per degree latitude)
      monitor.update(
        lat: 41.0, // 1 degree ≈ 111 km away from scale at 40.0
        lng: -90.0,
        reports: [makeScaleReport()],
      );

      expect(fired, isFalse);
    });

    test('fires each report at most once per session', () {
      var count = 0;
      monitor.onNearbyScale = (_, __) => count++;

      final r = makeScaleReport();
      monitor.update(lat: 40.0, lng: -90.0, reports: [r]);
      monitor.update(lat: 40.0, lng: -90.0, reports: [r]);

      expect(count, 1);
    });

    test('reset clears announced state so alerts fire again', () {
      var count = 0;
      monitor.onNearbyScale = (_, __) => count++;

      final r = makeScaleReport();
      monitor.update(lat: 40.0, lng: -90.0, reports: [r]);
      monitor.reset();
      monitor.update(lat: 40.0, lng: -90.0, reports: [r]);

      expect(count, 2);
    });

    test('distinct reports for same poiId but different reportedAt both fire',
        () {
      var count = 0;
      monitor.onNearbyScale = (_, __) => count++;

      final r1 = ScaleReport(
        poiId: 'scale_1',
        poiName: 'S',
        status: ScaleStatus.openBypass,
        lat: 40.0,
        lng: -90.0,
        reportedAt: DateTime.utc(2025, 1, 1),
      );
      final r2 = ScaleReport(
        poiId: 'scale_1',
        poiName: 'S',
        status: ScaleStatus.closed,
        lat: 40.0,
        lng: -90.0,
        reportedAt: DateTime.utc(2025, 1, 2),
      );

      monitor.update(lat: 40.0, lng: -90.0, reports: [r1, r2]);
      expect(count, 2);
    });
  });

  // ---------------------------------------------------------------------------
  // AppState: submitScaleReport + scaleReportFor
  // ---------------------------------------------------------------------------
  group('AppState scale reports', () {
    late AppState state;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      state = AppState();
    });

    tearDown(() {
      state.dispose();
    });

    test('scaleReports starts empty', () {
      expect(state.scaleReports, isEmpty);
    });

    test('submitScaleReport adds a report', () {
      state.submitScaleReport(
        poiId: 'scale_1',
        poiName: 'I-70 Scale',
        lat: 39.0,
        lng: -95.0,
        status: ScaleStatus.openBypass,
      );

      expect(state.scaleReports.length, 1);
      expect(state.scaleReports.first.poiId, 'scale_1');
      expect(state.scaleReports.first.status, ScaleStatus.openBypass);
    });

    test('submitScaleReport replaces previous report for same poiId', () {
      state.submitScaleReport(
        poiId: 'scale_1',
        poiName: 'I-70 Scale',
        lat: 39.0,
        lng: -95.0,
        status: ScaleStatus.openBypass,
      );
      state.submitScaleReport(
        poiId: 'scale_1',
        poiName: 'I-70 Scale',
        lat: 39.0,
        lng: -95.0,
        status: ScaleStatus.closed,
      );

      expect(state.scaleReports.length, 1);
      expect(state.scaleReports.first.status, ScaleStatus.closed);
    });

    test('submitScaleReport enqueues a scaleActivity alert', () {
      state.submitScaleReport(
        poiId: 'scale_1',
        poiName: 'I-70 Scale',
        lat: 39.0,
        lng: -95.0,
        status: ScaleStatus.notSure,
      );

      expect(state.currentAlert, isNotNull);
      expect(state.currentAlert!.type, AlertType.scaleActivity);
      expect(state.currentAlert!.title, 'Scale Status Reported');
      expect(state.currentAlert!.message, contains('I-70 Scale'));
      expect(state.currentAlert!.message, contains('not sure'));
    });

    test('scaleReportFor returns null when no report exists', () {
      expect(state.scaleReportFor('nonexistent'), isNull);
    });

    test('scaleReportFor returns the most recent report for a poiId', () {
      state.submitScaleReport(
        poiId: 'scale_1',
        poiName: 'Test',
        lat: 1.0,
        lng: 1.0,
        status: ScaleStatus.openBypass,
      );
      state.submitScaleReport(
        poiId: 'scale_1',
        poiName: 'Test',
        lat: 1.0,
        lng: 1.0,
        status: ScaleStatus.closed,
      );

      final report = state.scaleReportFor('scale_1');
      expect(report, isNotNull);
      expect(report!.status, ScaleStatus.closed);
    });

    test('submitScaleReport notifies listeners', () {
      var notified = false;
      state.addListener(() => notified = true);

      state.submitScaleReport(
        poiId: 'scale_x',
        poiName: 'X',
        lat: 0,
        lng: 0,
        status: ScaleStatus.openBypass,
      );

      expect(notified, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // ScalePassMonitor
  // ---------------------------------------------------------------------------
  group('ScalePassMonitor', () {
    late ScalePassMonitor monitor;

    // Helper to create a scale Poi at a given lat/lng.
    Poi makeScalePoi({
      String id = 'scale_1',
      String name = 'Test Scale',
      double lat = 40.0,
      double lng = -90.0,
    }) =>
        Poi(
          id: id,
          type: PoiType.scale,
          name: name,
          lat: lat,
          lng: lng,
          tags: const {},
        );

    setUp(() {
      monitor = ScalePassMonitor(
        armRadiusMeters: 300.0,
        exitRadiusMeters: 700.0,
        cooldownDuration: const Duration(minutes: 45),
      );
    });

    test('does not fire when driver is far from scale', () {
      var fired = false;
      monitor.onScalePassed = (_, __) => fired = true;

      // 1 degree ≈ 111 km — well beyond both radii.
      monitor.update(lat: 41.0, lng: -90.0, scalePois: [makeScalePoi()]);

      expect(fired, isFalse);
    });

    test('arms when driver enters inner radius', () {
      var fired = false;
      monitor.onScalePassed = (_, __) => fired = true;

      // Move close (< 300 m) but stay inside — no "passed" yet.
      monitor.update(lat: 40.0, lng: -90.0, scalePois: [makeScalePoi()]);

      expect(fired, isFalse);
    });

    test('fires passed when driver exits outer radius after being armed', () {
      Poi? firedPoi;
      monitor.onScalePassed = (p, _) => firedPoi = p;

      final poi = makeScalePoi();

      // Step 1: arm (driver within 300 m — same lat/lng → dist ≈ 0).
      monitor.update(lat: 40.0, lng: -90.0, scalePois: [poi]);
      expect(firedPoi, isNull);

      // Step 2: driver moves beyond exit radius (1 degree ≈ 111 km > 700 m).
      monitor.update(lat: 41.0, lng: -90.0, scalePois: [poi]);
      expect(firedPoi, isNotNull);
      expect(firedPoi!.id, 'scale_1');
    });

    test('does not fire again during cooldown', () {
      var count = 0;
      monitor.onScalePassed = (_, __) => count++;

      final poi = makeScalePoi();
      final baseTime = DateTime.utc(2025, 1, 1, 12, 0);

      // Arm → pass at t=0.
      monitor.update(
          lat: 40.0, lng: -90.0, scalePois: [poi], now: baseTime);
      monitor.update(
          lat: 41.0,
          lng: -90.0,
          scalePois: [poi],
          now: baseTime.add(const Duration(seconds: 1)));
      expect(count, 1);

      // Re-arm quickly and attempt to pass again — still in cooldown.
      monitor.update(
          lat: 40.0,
          lng: -90.0,
          scalePois: [poi],
          now: baseTime.add(const Duration(minutes: 5)));
      monitor.update(
          lat: 41.0,
          lng: -90.0,
          scalePois: [poi],
          now: baseTime.add(const Duration(minutes: 6)));
      expect(count, 1); // no second fire
    });

    test('fires again after cooldown expires', () {
      var count = 0;
      monitor.onScalePassed = (_, __) => count++;

      final poi = makeScalePoi();
      final baseTime = DateTime.utc(2025, 1, 1, 12, 0);

      // First pass.
      monitor.update(
          lat: 40.0, lng: -90.0, scalePois: [poi], now: baseTime);
      monitor.update(
          lat: 41.0,
          lng: -90.0,
          scalePois: [poi],
          now: baseTime.add(const Duration(seconds: 1)));
      expect(count, 1);

      // After cooldown (45 min + 1 s), arm and pass again.
      final afterCooldown = baseTime.add(const Duration(minutes: 46));
      monitor.update(lat: 40.0, lng: -90.0, scalePois: [poi], now: afterCooldown);
      monitor.update(
          lat: 41.0,
          lng: -90.0,
          scalePois: [poi],
          now: afterCooldown.add(const Duration(seconds: 1)));
      expect(count, 2);
    });

    test('does not fire without prior arming', () {
      var fired = false;
      monitor.onScalePassed = (_, __) => fired = true;

      final poi = makeScalePoi();
      // Driver starts outside arm radius and moves further away — never armed.
      monitor.update(lat: 40.01, lng: -90.0, scalePois: [poi]);
      // ~1.1 km away at 40.01 — > armRadius of 300 m? Let's go obviously far.
      monitor.update(lat: 41.0, lng: -90.0, scalePois: [poi]);

      expect(fired, isFalse);
    });

    test('handles multiple POIs independently', () {
      final fired = <String>[];
      monitor.onScalePassed = (p, _) => fired.add(p.id);

      final poi1 = makeScalePoi(id: 'scale_1', lat: 40.0, lng: -90.0);
      final poi2 = makeScalePoi(id: 'scale_2', lat: 35.0, lng: -80.0);

      // Arm poi1 only.
      monitor.update(lat: 40.0, lng: -90.0, scalePois: [poi1, poi2]);
      // Pass poi1 (move far from poi1, still far from poi2).
      monitor.update(lat: 41.0, lng: -90.0, scalePois: [poi1, poi2]);

      expect(fired, ['scale_1']);
    });
  });
}


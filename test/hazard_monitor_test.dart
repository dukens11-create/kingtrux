import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/hazard.dart';
import 'package:kingtrux/services/hazard_monitor.dart';
import 'package:kingtrux/services/hazard_settings_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // HazardMonitor – proximity + cooldown
  // ---------------------------------------------------------------------------
  group('HazardMonitor.update', () {
    late HazardMonitor monitor;
    final List<Hazard> fired = [];

    setUp(() {
      monitor = HazardMonitor();
      fired.clear();
      monitor.onHazardApproaching = (h, _) => fired.add(h);
    });

    Hazard _hazard(String id, HazardType type, double lat, double lng) =>
        Hazard(id: id, type: type, lat: lat, lng: lng);

    test('fires when driver is within sharp-curve threshold', () {
      // Place driver exactly at hazard location (distance = 0 < 1609 m).
      final h = _hazard('c1', HazardType.sharpCurve, 37.0, -122.0);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [h]);
      expect(fired, hasLength(1));
      expect(fired.first.id, 'c1');
    });

    test('does not fire when driver is outside the threshold', () {
      // 2° of latitude ≈ 222 km, well beyond every threshold.
      final h = _hazard('c2', HazardType.sharpCurve, 39.0, -122.0);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [h]);
      expect(fired, isEmpty);
    });

    test('fires for low-bridge hazard within threshold (~3218 m)', () {
      // ~0.01° lat ≈ 1111 m < 3218 m.
      final h = _hazard('b1', HazardType.lowBridge, 37.01, -122.0);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [h]);
      expect(fired, hasLength(1));
      expect(fired.first.type, HazardType.lowBridge);
    });

    test('fires for downgrade-hill hazard within threshold (~3218 m)', () {
      final h = _hazard('d1', HazardType.downgradeHill, 37.01, -122.0);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [h]);
      expect(fired, hasLength(1));
      expect(fired.first.type, HazardType.downgradeHill);
    });

    test('cooldown prevents second alert within cooldown window', () {
      final h = _hazard('c3', HazardType.sharpCurve, 37.0, -122.0);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [h]);
      expect(fired, hasLength(1));

      // Second call immediately — cooldown should suppress it.
      monitor.update(lat: 37.0, lng: -122.0, hazards: [h]);
      expect(fired, hasLength(1)); // still only 1
    });

    test('reset clears cooldown so alert fires again', () {
      final h = _hazard('c4', HazardType.sharpCurve, 37.0, -122.0);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [h]);
      expect(fired, hasLength(1));

      monitor.reset();
      monitor.update(lat: 37.0, lng: -122.0, hazards: [h]);
      expect(fired, hasLength(2));
    });

    test('enableSharpCurve=false suppresses sharp-curve alerts', () {
      final h = _hazard('c5', HazardType.sharpCurve, 37.0, -122.0);
      monitor.update(
        lat: 37.0,
        lng: -122.0,
        hazards: [h],
        enableSharpCurve: false,
      );
      expect(fired, isEmpty);
    });

    test('enableLowBridge=false suppresses low-bridge alerts', () {
      final h = _hazard('b2', HazardType.lowBridge, 37.0, -122.0);
      monitor.update(
        lat: 37.0,
        lng: -122.0,
        hazards: [h],
        enableLowBridge: false,
      );
      expect(fired, isEmpty);
    });

    test('enableDowngradeHill=false suppresses downgrade-hill alerts', () {
      final h = _hazard('d2', HazardType.downgradeHill, 37.0, -122.0);
      monitor.update(
        lat: 37.0,
        lng: -122.0,
        hazards: [h],
        enableDowngradeHill: false,
      );
      expect(fired, isEmpty);
    });

    test('fires independently for multiple hazards at different locations', () {
      final h1 = _hazard('h1', HazardType.sharpCurve, 37.0, -122.0);
      final h2 = _hazard('h2', HazardType.lowBridge, 37.005, -122.0);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [h1, h2]);
      expect(fired, hasLength(2));
    });

    test('each hazard has independent cooldown', () {
      final h1 = _hazard('i1', HazardType.sharpCurve, 37.0, -122.0);
      final h2 = _hazard('i2', HazardType.sharpCurve, 37.001, -122.0);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [h1, h2]);
      expect(fired, hasLength(2));

      // Second call: both in cooldown, nothing should fire.
      fired.clear();
      monitor.update(lat: 37.0, lng: -122.0, hazards: [h1, h2]);
      expect(fired, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // HazardMonitor.detectSharpCurves – polyline curvature
  // ---------------------------------------------------------------------------
  group('HazardMonitor.detectSharpCurves', () {
    test('returns empty list for fewer than 3 points', () {
      expect(HazardMonitor.detectSharpCurves([]), isEmpty);
      expect(
        HazardMonitor.detectSharpCurves([[0.0, 0.0], [0.01, 0.0]]),
        isEmpty,
      );
    });

    test('returns empty list for a straight line', () {
      // Three collinear points along a meridian — bearing stays constant.
      final straight = [
        [37.00, -122.0],
        [37.10, -122.0],
        [37.20, -122.0],
      ];
      expect(HazardMonitor.detectSharpCurves(straight), isEmpty);
    });

    test('detects a 90-degree turn', () {
      // Go north then turn east.
      final ninetyDeg = [
        [37.00, -122.00],
        [37.10, -122.00], // segment heading N
        [37.10, -121.90], // segment heading E → 90° turn
      ];
      final curves = HazardMonitor.detectSharpCurves(
        ninetyDeg,
        minSegmentLengthMeters: 1.0, // lower threshold for test geometry
      );
      expect(curves, hasLength(1));
      expect(curves.first.type, HazardType.sharpCurve);
    });

    test('does not detect a gentle curve below the threshold', () {
      // 10° bearing change.
      final dLng = 0.10 * (10 * 3.14159 / 180); // tiny eastward jog
      final gentleCurve = [
        [37.00, -122.00],
        [37.10, -122.00],
        [37.20, -122.00 + dLng],
      ];
      final curves = HazardMonitor.detectSharpCurves(
        gentleCurve,
        angleDegThreshold: 30.0,
        minSegmentLengthMeters: 1.0,
      );
      expect(curves, isEmpty);
    });

    test('de-duplicates adjacent curves within minGapMeters', () {
      // Build a polyline that produces two tight turns very close together.
      // 0.001° ≈ 111 m — both turning points at the same meter scale.
      final tightS = [
        [37.000, -122.000],
        [37.001, -122.000], // seg A ~111 m north
        [37.001, -121.999], // 90° right turn
        [37.002, -121.999], // seg C ~111 m north — another ~90° turn
        [37.002, -122.000],
      ];
      final curves = HazardMonitor.detectSharpCurves(
        tightS,
        minSegmentLengthMeters: 1.0,
        minGapMeters: 500.0, // gap > distance between turns → de-dup
      );
      // Only the first curve should survive after de-duplication.
      expect(curves, hasLength(1));
    });

    test('hazards have unique sequential ids', () {
      final sharpRoute = [
        [37.000, -122.000],
        [37.100, -122.000],
        [37.100, -121.900], // 90° turn
        [37.200, -121.900],
        [37.200, -121.800], // another 90° turn, > 200 m away
      ];
      final curves = HazardMonitor.detectSharpCurves(
        sharpRoute,
        minSegmentLengthMeters: 1.0,
        minGapMeters: 1.0,
      );
      expect(curves.length, greaterThan(1));
      final ids = curves.map((c) => c.id).toSet();
      expect(ids.length, curves.length); // all unique
    });
  });

  // ---------------------------------------------------------------------------
  // HazardSettingsService – persistence
  // ---------------------------------------------------------------------------
  group('HazardSettingsService', () {
    late HazardSettingsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = HazardSettingsService();
    });

    test('load returns all-true defaults when nothing is persisted', () async {
      final s = await service.load();
      expect(s.enableLowBridgeWarnings, isTrue);
      expect(s.enableSharpCurveWarnings, isTrue);
      expect(s.enableDowngradeHillWarnings, isTrue);
      expect(s.enableHazardTts, isTrue);
    });

    test('save and reload round-trips settings correctly', () async {
      const saved = HazardSettings(
        enableLowBridgeWarnings: false,
        enableSharpCurveWarnings: true,
        enableDowngradeHillWarnings: false,
        enableHazardTts: false,
      );
      await service.save(saved);
      final loaded = await service.load();
      expect(loaded.enableLowBridgeWarnings, isFalse);
      expect(loaded.enableSharpCurveWarnings, isTrue);
      expect(loaded.enableDowngradeHillWarnings, isFalse);
      expect(loaded.enableHazardTts, isFalse);
    });

    test('overwriting save replaces previous values', () async {
      await service.save(const HazardSettings(enableHazardTts: false));
      await service.save(const HazardSettings(enableHazardTts: true));
      final loaded = await service.load();
      expect(loaded.enableHazardTts, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // HazardSettings.copyWith
  // ---------------------------------------------------------------------------
  group('HazardSettings.copyWith', () {
    test('overrides only the specified fields', () {
      const original = HazardSettings(
        enableLowBridgeWarnings: true,
        enableSharpCurveWarnings: true,
        enableDowngradeHillWarnings: true,
        enableHazardTts: true,
      );
      final copy = original.copyWith(enableLowBridgeWarnings: false);
      expect(copy.enableLowBridgeWarnings, isFalse);
      expect(copy.enableSharpCurveWarnings, isTrue);
      expect(copy.enableDowngradeHillWarnings, isTrue);
      expect(copy.enableHazardTts, isTrue);
    });
  });
}

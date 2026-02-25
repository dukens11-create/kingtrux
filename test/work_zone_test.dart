import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/hazard.dart';
import 'package:kingtrux/services/hazard_monitor.dart';
import 'package:kingtrux/services/hazard_settings_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // HazardType.workZone – enum value exists
  // ---------------------------------------------------------------------------
  group('HazardType.workZone', () {
    test('workZone is a valid HazardType value', () {
      const values = HazardType.values;
      expect(values, contains(HazardType.workZone));
    });
  });

  // ---------------------------------------------------------------------------
  // HazardMonitor – work zone proximity alerts
  // ---------------------------------------------------------------------------
  group('HazardMonitor work zone alerts', () {
    late HazardMonitor monitor;
    final fired = <Hazard>[];

    setUp(() {
      monitor = HazardMonitor();
      fired.clear();
      monitor.onHazardApproaching = (h, _) => fired.add(h);
    });

    Hazard _workZone(String id, double lat, double lng) =>
        Hazard(id: id, type: HazardType.workZone, lat: lat, lng: lng);

    test('fires when driver is within work-zone threshold (~1 mile)', () {
      // Place driver exactly at work zone (distance = 0 ≤ threshold).
      final wz = _workZone('wz1', 37.0, -122.0);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [wz]);
      expect(fired, hasLength(1));
      expect(fired.first.id, 'wz1');
      expect(fired.first.type, HazardType.workZone);
    });

    test('does not fire when driver is outside the threshold', () {
      // 2° of latitude ≈ 222 km — well beyond every threshold.
      final wz = _workZone('wz2', 39.0, -122.0);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [wz]);
      expect(fired, isEmpty);
    });

    test('cooldown suppresses repeated work-zone alerts', () {
      final wz = _workZone('wz3', 37.0, -122.0);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [wz]);
      expect(fired, hasLength(1));

      monitor.update(lat: 37.0, lng: -122.0, hazards: [wz]);
      expect(fired, hasLength(1)); // still only 1 – cooldown active
    });

    test('reset clears cooldown so alert fires again', () {
      final wz = _workZone('wz4', 37.0, -122.0);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [wz]);
      expect(fired, hasLength(1));

      monitor.reset();
      monitor.update(lat: 37.0, lng: -122.0, hazards: [wz]);
      expect(fired, hasLength(2));
    });

    test('enableWorkZone=false suppresses work-zone alerts', () {
      final wz = _workZone('wz5', 37.0, -122.0);
      monitor.update(
        lat: 37.0,
        lng: -122.0,
        hazards: [wz],
        enableWorkZone: false,
      );
      expect(fired, isEmpty);
    });

    test('other hazard types are unaffected by enableWorkZone flag', () {
      final curve = Hazard(
        id: 'curve1',
        type: HazardType.sharpCurve,
        lat: 37.0,
        lng: -122.0,
      );
      monitor.update(
        lat: 37.0,
        lng: -122.0,
        hazards: [curve],
        enableWorkZone: false, // only work zones suppressed
      );
      expect(fired, hasLength(1));
      expect(fired.first.type, HazardType.sharpCurve);
    });

    test('work-zone threshold is ~1 mile (≈1609 m)', () {
      expect(
        HazardMonitor.workZoneThresholdMeters,
        closeTo(1609.3, 1.0),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // HazardSettings – enableWorkZoneWarnings field
  // ---------------------------------------------------------------------------
  group('HazardSettings.enableWorkZoneWarnings', () {
    test('defaults to true', () {
      const s = HazardSettings();
      expect(s.enableWorkZoneWarnings, isTrue);
    });

    test('can be set to false via constructor', () {
      const s = HazardSettings(enableWorkZoneWarnings: false);
      expect(s.enableWorkZoneWarnings, isFalse);
    });

    test('copyWith overrides only enableWorkZoneWarnings', () {
      const original = HazardSettings(
        enableLowBridgeWarnings: true,
        enableSharpCurveWarnings: true,
        enableDowngradeHillWarnings: true,
        enableWorkZoneWarnings: true,
        enableHazardTts: true,
      );
      final copy = original.copyWith(enableWorkZoneWarnings: false);
      expect(copy.enableWorkZoneWarnings, isFalse);
      expect(copy.enableLowBridgeWarnings, isTrue);
      expect(copy.enableSharpCurveWarnings, isTrue);
      expect(copy.enableDowngradeHillWarnings, isTrue);
      expect(copy.enableHazardTts, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // HazardSettingsService – persistence round-trip including work zone
  // ---------------------------------------------------------------------------
  group('HazardSettingsService work zone persistence', () {
    late HazardSettingsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = HazardSettingsService();
    });

    test('load returns enableWorkZoneWarnings=true when nothing is persisted',
        () async {
      final s = await service.load();
      expect(s.enableWorkZoneWarnings, isTrue);
    });

    test('save and reload round-trips enableWorkZoneWarnings=false', () async {
      const toSave = HazardSettings(enableWorkZoneWarnings: false);
      await service.save(toSave);
      final loaded = await service.load();
      expect(loaded.enableWorkZoneWarnings, isFalse);
    });

    test('overwriting save replaces enableWorkZoneWarnings', () async {
      await service.save(const HazardSettings(enableWorkZoneWarnings: false));
      await service.save(const HazardSettings(enableWorkZoneWarnings: true));
      final loaded = await service.load();
      expect(loaded.enableWorkZoneWarnings, isTrue);
    });
  });
}

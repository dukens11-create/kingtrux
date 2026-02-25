import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/hazard.dart';
import 'package:kingtrux/services/hazard_monitor.dart';
import 'package:kingtrux/services/hazard_settings_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // HazardType enum – new road sign values exist
  // ---------------------------------------------------------------------------
  group('HazardType road sign values', () {
    test('all new road sign types are present in HazardType.values', () {
      const values = HazardType.values;
      expect(values, contains(HazardType.truckCrossing));
      expect(values, contains(HazardType.wildAnimalCrossing));
      expect(values, contains(HazardType.schoolZone));
      expect(values, contains(HazardType.stopSign));
      expect(values, contains(HazardType.railroadCrossing));
      expect(values, contains(HazardType.slipperyRoad));
      expect(values, contains(HazardType.mergingTraffic));
      expect(values, contains(HazardType.fallingRocks));
      expect(values, contains(HazardType.narrowBridge));
    });
  });

  // ---------------------------------------------------------------------------
  // HazardMonitor – proximity alerts for each new sign type
  // ---------------------------------------------------------------------------
  group('HazardMonitor road sign proximity alerts', () {
    late HazardMonitor monitor;
    final fired = <Hazard>[];

    setUp(() {
      monitor = HazardMonitor();
      fired.clear();
      monitor.onHazardApproaching = (h, _) => fired.add(h);
    });

    Hazard _sign(String id, HazardType type) =>
        Hazard(id: id, type: type, lat: 37.0, lng: -122.0);

    for (final type in [
      HazardType.truckCrossing,
      HazardType.wildAnimalCrossing,
      HazardType.schoolZone,
      HazardType.stopSign,
      HazardType.railroadCrossing,
      HazardType.slipperyRoad,
      HazardType.mergingTraffic,
      HazardType.fallingRocks,
      HazardType.narrowBridge,
    ]) {
      test('fires for ${type.name} when driver is at hazard location', () {
        final h = _sign('${type.name}_1', type);
        monitor.update(lat: 37.0, lng: -122.0, hazards: [h]);
        expect(fired, hasLength(1));
        expect(fired.first.type, type);
      });
    }

    test('does not fire truck crossing outside threshold', () {
      final h = Hazard(
          id: 'tc_far', type: HazardType.truckCrossing, lat: 39.0, lng: -122.0);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [h]);
      expect(fired, isEmpty);
    });

    test('cooldown suppresses repeated road sign alerts', () {
      final h = _sign('rr1', HazardType.railroadCrossing);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [h]);
      expect(fired, hasLength(1));

      monitor.update(lat: 37.0, lng: -122.0, hazards: [h]);
      expect(fired, hasLength(1)); // cooldown active
    });

    test('reset clears cooldown so alert fires again', () {
      final h = _sign('sc1', HazardType.schoolZone);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [h]);
      expect(fired, hasLength(1));

      monitor.reset();
      monitor.update(lat: 37.0, lng: -122.0, hazards: [h]);
      expect(fired, hasLength(2));
    });
  });

  // ---------------------------------------------------------------------------
  // HazardMonitor – per-type enable flags for new sign types
  // ---------------------------------------------------------------------------
  group('HazardMonitor road sign enable flags', () {
    late HazardMonitor monitor;
    final fired = <Hazard>[];

    setUp(() {
      monitor = HazardMonitor();
      fired.clear();
      monitor.onHazardApproaching = (h, _) => fired.add(h);
    });

    Hazard _sign(HazardType type) =>
        Hazard(id: 'test', type: type, lat: 37.0, lng: -122.0);

    test('enableTruckCrossing=false suppresses truck crossing alert', () {
      monitor.update(
        lat: 37.0,
        lng: -122.0,
        hazards: [_sign(HazardType.truckCrossing)],
        enableTruckCrossing: false,
      );
      expect(fired, isEmpty);
    });

    test('enableWildAnimalCrossing=false suppresses wild animal alert', () {
      monitor.update(
        lat: 37.0,
        lng: -122.0,
        hazards: [_sign(HazardType.wildAnimalCrossing)],
        enableWildAnimalCrossing: false,
      );
      expect(fired, isEmpty);
    });

    test('enableSchoolZone=false suppresses school zone alert', () {
      monitor.update(
        lat: 37.0,
        lng: -122.0,
        hazards: [_sign(HazardType.schoolZone)],
        enableSchoolZone: false,
      );
      expect(fired, isEmpty);
    });

    test('enableStopSign=false suppresses stop sign alert', () {
      monitor.update(
        lat: 37.0,
        lng: -122.0,
        hazards: [_sign(HazardType.stopSign)],
        enableStopSign: false,
      );
      expect(fired, isEmpty);
    });

    test('enableRailroadCrossing=false suppresses railroad crossing alert', () {
      monitor.update(
        lat: 37.0,
        lng: -122.0,
        hazards: [_sign(HazardType.railroadCrossing)],
        enableRailroadCrossing: false,
      );
      expect(fired, isEmpty);
    });

    test('enableSlipperyRoad=false suppresses slippery road alert', () {
      monitor.update(
        lat: 37.0,
        lng: -122.0,
        hazards: [_sign(HazardType.slipperyRoad)],
        enableSlipperyRoad: false,
      );
      expect(fired, isEmpty);
    });

    test('enableMergingTraffic=false suppresses merging traffic alert', () {
      monitor.update(
        lat: 37.0,
        lng: -122.0,
        hazards: [_sign(HazardType.mergingTraffic)],
        enableMergingTraffic: false,
      );
      expect(fired, isEmpty);
    });

    test('enableFallingRocks=false suppresses falling rocks alert', () {
      monitor.update(
        lat: 37.0,
        lng: -122.0,
        hazards: [_sign(HazardType.fallingRocks)],
        enableFallingRocks: false,
      );
      expect(fired, isEmpty);
    });

    test('enableNarrowBridge=false suppresses narrow bridge alert', () {
      monitor.update(
        lat: 37.0,
        lng: -122.0,
        hazards: [_sign(HazardType.narrowBridge)],
        enableNarrowBridge: false,
      );
      expect(fired, isEmpty);
    });

    test('disabling one type does not suppress other types', () {
      final hazards = [
        Hazard(id: 'tc', type: HazardType.truckCrossing, lat: 37.0, lng: -122.0),
        Hazard(
            id: 'rr',
            type: HazardType.railroadCrossing,
            lat: 37.0,
            lng: -122.0),
      ];
      monitor.update(
        lat: 37.0,
        lng: -122.0,
        hazards: hazards,
        enableTruckCrossing: false,
        enableRailroadCrossing: true,
      );
      expect(fired, hasLength(1));
      expect(fired.first.type, HazardType.railroadCrossing);
    });
  });

  // ---------------------------------------------------------------------------
  // HazardMonitor – thresholds for new sign types
  // ---------------------------------------------------------------------------
  group('HazardMonitor road sign thresholds', () {
    test('stop sign threshold is ~0.25 miles (≈402 m)', () {
      expect(HazardMonitor.stopSignThresholdMeters, closeTo(402.3, 1.0));
    });

    test('school zone threshold is ~0.5 miles (≈804 m)', () {
      expect(HazardMonitor.schoolZoneThresholdMeters, closeTo(804.7, 1.0));
    });

    test('railroad crossing threshold is ~1 mile (≈1609 m)', () {
      expect(
          HazardMonitor.railroadCrossingThresholdMeters, closeTo(1609.3, 1.0));
    });

    test('truck crossing threshold is ~1 mile (≈1609 m)', () {
      expect(HazardMonitor.truckCrossingThresholdMeters, closeTo(1609.3, 1.0));
    });

    test('wild animal crossing threshold is ~1 mile (≈1609 m)', () {
      expect(HazardMonitor.wildAnimalCrossingThresholdMeters,
          closeTo(1609.3, 1.0));
    });

    test('slippery road threshold is ~1 mile (≈1609 m)', () {
      expect(HazardMonitor.slipperyRoadThresholdMeters, closeTo(1609.3, 1.0));
    });

    test('merging traffic threshold is ~1 mile (≈1609 m)', () {
      expect(
          HazardMonitor.mergingTrafficThresholdMeters, closeTo(1609.3, 1.0));
    });

    test('falling rocks threshold is ~1 mile (≈1609 m)', () {
      expect(HazardMonitor.fallingRocksThresholdMeters, closeTo(1609.3, 1.0));
    });

    test('narrow bridge threshold is ~1 mile (≈1609 m)', () {
      expect(HazardMonitor.narrowBridgeThresholdMeters, closeTo(1609.3, 1.0));
    });

    test('stop sign fires within threshold but not outside', () {
      final monitor = HazardMonitor();
      final fired = <Hazard>[];
      monitor.onHazardApproaching = (h, _) => fired.add(h);

      // Place hazard ~300 m away — within stop sign threshold (~402 m).
      // 0.003° lat ≈ 333 m.
      final nearby = Hazard(
          id: 'ss_near', type: HazardType.stopSign, lat: 37.003, lng: -122.0);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [nearby]);
      expect(fired, hasLength(1));

      fired.clear();
      monitor.reset();

      // Place hazard ~600 m away — outside stop sign threshold (~402 m).
      // 0.006° lat ≈ 666 m.
      final far = Hazard(
          id: 'ss_far', type: HazardType.stopSign, lat: 37.006, lng: -122.0);
      monitor.update(lat: 37.0, lng: -122.0, hazards: [far]);
      expect(fired, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // HazardSettings – new road sign fields
  // ---------------------------------------------------------------------------
  group('HazardSettings road sign fields', () {
    test('all new fields default to true', () {
      const s = HazardSettings();
      expect(s.enableTruckCrossingWarnings, isTrue);
      expect(s.enableWildAnimalCrossingWarnings, isTrue);
      expect(s.enableSchoolZoneWarnings, isTrue);
      expect(s.enableStopSignWarnings, isTrue);
      expect(s.enableRailroadCrossingWarnings, isTrue);
      expect(s.enableSlipperyRoadWarnings, isTrue);
      expect(s.enableMergingTrafficWarnings, isTrue);
      expect(s.enableFallingRocksWarnings, isTrue);
      expect(s.enableNarrowBridgeWarnings, isTrue);
    });

    test('copyWith overrides only specified new fields', () {
      const original = HazardSettings();
      final copy = original.copyWith(
        enableRailroadCrossingWarnings: false,
        enableSchoolZoneWarnings: false,
      );
      expect(copy.enableRailroadCrossingWarnings, isFalse);
      expect(copy.enableSchoolZoneWarnings, isFalse);
      expect(copy.enableTruckCrossingWarnings, isTrue);
      expect(copy.enableWildAnimalCrossingWarnings, isTrue);
      expect(copy.enableStopSignWarnings, isTrue);
      expect(copy.enableSlipperyRoadWarnings, isTrue);
      expect(copy.enableMergingTrafficWarnings, isTrue);
      expect(copy.enableFallingRocksWarnings, isTrue);
      expect(copy.enableNarrowBridgeWarnings, isTrue);
      expect(copy.enableHazardTts, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // HazardSettingsService – persistence round-trip for new fields
  // ---------------------------------------------------------------------------
  group('HazardSettingsService road sign persistence', () {
    late HazardSettingsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = HazardSettingsService();
    });

    test('load returns all-true defaults for new fields when nothing persisted',
        () async {
      final s = await service.load();
      expect(s.enableTruckCrossingWarnings, isTrue);
      expect(s.enableWildAnimalCrossingWarnings, isTrue);
      expect(s.enableSchoolZoneWarnings, isTrue);
      expect(s.enableStopSignWarnings, isTrue);
      expect(s.enableRailroadCrossingWarnings, isTrue);
      expect(s.enableSlipperyRoadWarnings, isTrue);
      expect(s.enableMergingTrafficWarnings, isTrue);
      expect(s.enableFallingRocksWarnings, isTrue);
      expect(s.enableNarrowBridgeWarnings, isTrue);
    });

    test('save and reload round-trips all new road sign fields', () async {
      const toSave = HazardSettings(
        enableTruckCrossingWarnings: false,
        enableWildAnimalCrossingWarnings: false,
        enableSchoolZoneWarnings: true,
        enableStopSignWarnings: false,
        enableRailroadCrossingWarnings: true,
        enableSlipperyRoadWarnings: false,
        enableMergingTrafficWarnings: true,
        enableFallingRocksWarnings: false,
        enableNarrowBridgeWarnings: true,
      );
      await service.save(toSave);
      final loaded = await service.load();
      expect(loaded.enableTruckCrossingWarnings, isFalse);
      expect(loaded.enableWildAnimalCrossingWarnings, isFalse);
      expect(loaded.enableSchoolZoneWarnings, isTrue);
      expect(loaded.enableStopSignWarnings, isFalse);
      expect(loaded.enableRailroadCrossingWarnings, isTrue);
      expect(loaded.enableSlipperyRoadWarnings, isFalse);
      expect(loaded.enableMergingTrafficWarnings, isTrue);
      expect(loaded.enableFallingRocksWarnings, isFalse);
      expect(loaded.enableNarrowBridgeWarnings, isTrue);
    });

    test('overwriting save replaces previous road sign values', () async {
      await service.save(
          const HazardSettings(enableRailroadCrossingWarnings: false));
      await service.save(
          const HazardSettings(enableRailroadCrossingWarnings: true));
      final loaded = await service.load();
      expect(loaded.enableRailroadCrossingWarnings, isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/commercial_speed_settings.dart';
import 'package:kingtrux/services/truck_speed_limit_service.dart';
import 'package:kingtrux/services/speed_settings_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // TruckSpeedLimitService – state lookup
  // ---------------------------------------------------------------------------
  group('TruckSpeedLimitService', () {
    late TruckSpeedLimitService service;

    setUp(() {
      service = TruckSpeedLimitService();
    });

    // US state lookups --------------------------------------------------------

    test('returns conservative limit for Texas (70 mph)', () {
      expect(service.limitForState('TX'), 70.0);
    });

    test('returns speed limit for California (55 mph)', () {
      expect(service.limitForState('CA'), 55.0);
    });

    test('returns speed limit for South Dakota (80 mph)', () {
      expect(service.limitForState('SD'), 80.0);
    });

    test('returns speed limit for DC (55 mph)', () {
      expect(service.limitForState('DC'), 55.0);
    });

    test('returns conservative limit for Arizona (65 mph)', () {
      expect(service.limitForState('AZ'), 65.0);
    });

    test('returns conservative limit for Colorado (65 mph)', () {
      expect(service.limitForState('CO'), 65.0);
    });

    test('returns conservative limit for Wyoming (65 mph)', () {
      expect(service.limitForState('WY'), 65.0);
    });

    test('is case-insensitive (lowercase state code)', () {
      expect(service.limitForState('tx'), 70.0);
    });

    test('is case-insensitive (mixed case)', () {
      expect(service.limitForState('Tx'), 70.0);
    });

    test('returns null for an unknown code', () {
      expect(service.limitForState('ZZ'), isNull);
    });

    test('returns null for an empty string', () {
      expect(service.limitForState(''), isNull);
    });

    test('all 50 states plus DC are present', () {
      const allStates = [
        'AL', 'AK', 'AZ', 'AR', 'CA', 'CO', 'CT', 'DE', 'FL', 'GA',
        'HI', 'ID', 'IL', 'IN', 'IA', 'KS', 'KY', 'LA', 'ME', 'MD',
        'MA', 'MI', 'MN', 'MS', 'MO', 'MT', 'NE', 'NV', 'NH', 'NJ',
        'NM', 'NY', 'NC', 'ND', 'OH', 'OK', 'OR', 'PA', 'RI', 'SC',
        'SD', 'TN', 'TX', 'UT', 'VT', 'VA', 'WA', 'WV', 'WI', 'WY',
        'DC',
      ];
      for (final code in allStates) {
        expect(
          service.limitForState(code),
          isNotNull,
          reason: '$code should have a truck speed limit',
        );
      }
    });

    // Canadian province/territory lookups ------------------------------------

    test('returns speed limit for Ontario (62 mph)', () {
      expect(service.limitForState('ON'), 62.0);
    });

    test('returns speed limit for British Columbia (62 mph)', () {
      expect(service.limitForState('BC'), 62.0);
    });

    test('returns speed limit for Alberta (68 mph)', () {
      expect(service.limitForState('AB'), 68.0);
    });

    test('returns speed limit for Quebec (62 mph)', () {
      expect(service.limitForState('QC'), 62.0);
    });

    test('returns speed limit for Nunavut (50 mph)', () {
      expect(service.limitForState('NU'), 50.0);
    });

    test('is case-insensitive for Canadian province codes', () {
      expect(service.limitForState('on'), 62.0);
      expect(service.limitForState('Bc'), 62.0);
    });

    test('all 13 Canadian provinces/territories are present', () {
      const allProvinces = [
        'AB', 'BC', 'MB', 'NB', 'NL', 'NS', 'NT', 'NU',
        'ON', 'PE', 'QC', 'SK', 'YT',
      ];
      for (final code in allProvinces) {
        expect(
          service.limitForState(code),
          isNotNull,
          reason: '$code should have a truck speed limit',
        );
      }
    });

    // Combined map ------------------------------------------------------------

    test('all limits are positive mph values', () {
      for (final entry in TruckSpeedLimitService.allStateLimits.entries) {
        expect(
          entry.value,
          greaterThan(0),
          reason: '${entry.key} limit must be positive',
        );
      }
    });

    test('allStateLimits contains both US states and Canadian provinces', () {
      final map = TruckSpeedLimitService.allStateLimits;
      expect(map.containsKey('TX'), isTrue);
      expect(map.containsKey('ON'), isTrue);
      expect(map.containsKey('BC'), isTrue);
    });

    test('allStateLimits returns an unmodifiable map', () {
      final map = TruckSpeedLimitService.allStateLimits;
      expect(() => (map as dynamic)['XX'] = 60.0, throwsUnsupportedError);
    });

    test('usStateLimits contains only US states', () {
      final map = TruckSpeedLimitService.usStateLimits;
      expect(map.containsKey('TX'), isTrue);
      expect(map.containsKey('ON'), isFalse);
    });

    test('canadaProvinceLimits contains only Canadian provinces', () {
      final map = TruckSpeedLimitService.canadaProvinceLimits;
      expect(map.containsKey('ON'), isTrue);
      expect(map.containsKey('TX'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // CommercialSpeedSettings.enableStateLimits – defaults and copyWith
  // ---------------------------------------------------------------------------
  group('CommercialSpeedSettings.enableStateLimits', () {
    test('defaults to true', () {
      final d = CommercialSpeedSettings.defaults();
      expect(d.enableStateLimits, isTrue);
    });

    test('can be constructed with enableStateLimits=false', () {
      const s = CommercialSpeedSettings(
        enabled: true,
        maxSpeedMs: 29.0576,
        unit: SpeedUnit.mph,
        enableStateLimits: false,
      );
      expect(s.enableStateLimits, isFalse);
    });

    test('copyWith overrides only enableStateLimits', () {
      final original = CommercialSpeedSettings.defaults();
      final copy = original.copyWith(enableStateLimits: false);
      expect(copy.enableStateLimits, isFalse);
      expect(copy.enabled, original.enabled);
      expect(copy.maxSpeedMs, original.maxSpeedMs);
      expect(copy.unit, original.unit);
    });

    test('copyWith preserves enableStateLimits when not specified', () {
      const s = CommercialSpeedSettings(
        enabled: false,
        maxSpeedMs: 29.0576,
        unit: SpeedUnit.mph,
        enableStateLimits: false,
      );
      final copy = s.copyWith(enabled: true);
      expect(copy.enableStateLimits, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // SpeedSettingsService – enableStateLimits persistence round-trip
  // ---------------------------------------------------------------------------
  group('SpeedSettingsService enableStateLimits persistence', () {
    late SpeedSettingsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = SpeedSettingsService();
    });

    test('returns enableStateLimits=true by default', () async {
      final settings = await service.loadCommercialSettings();
      expect(settings.enableStateLimits, isTrue);
    });

    test('saves and loads enableStateLimits=false', () async {
      final toSave = CommercialSpeedSettings(
        enabled: true,
        maxSpeedMs: CommercialSpeedSettings.mphToMs(65.0),
        unit: SpeedUnit.mph,
        enableStateLimits: false,
      );
      await service.saveCommercialSettings(toSave);
      final loaded = await service.loadCommercialSettings();
      expect(loaded.enableStateLimits, isFalse);
    });

    test('full round-trip preserves all fields including enableStateLimits',
        () async {
      final toSave = CommercialSpeedSettings(
        enabled: true,
        maxSpeedMs: CommercialSpeedSettings.mphToMs(70.0),
        unit: SpeedUnit.mph,
        enableStateLimits: false,
      );
      await service.saveCommercialSettings(toSave);
      final loaded = await service.loadCommercialSettings();
      expect(loaded.enabled, isTrue);
      expect(loaded.maxSpeedMs, closeTo(CommercialSpeedSettings.mphToMs(70.0), 0.001));
      expect(loaded.unit, SpeedUnit.mph);
      expect(loaded.enableStateLimits, isFalse);
    });

    test('overwrite replaces enableStateLimits', () async {
      await service.saveCommercialSettings(CommercialSpeedSettings(
        enabled: false,
        maxSpeedMs: CommercialSpeedSettings.mphToMs(65.0),
        unit: SpeedUnit.mph,
        enableStateLimits: false,
      ));
      await service.saveCommercialSettings(CommercialSpeedSettings(
        enabled: false,
        maxSpeedMs: CommercialSpeedSettings.mphToMs(65.0),
        unit: SpeedUnit.mph,
        enableStateLimits: true,
      ));
      final loaded = await service.loadCommercialSettings();
      expect(loaded.enableStateLimits, isTrue);
    });
  });
}

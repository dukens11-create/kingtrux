import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/services/night_mode_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // NightModeSettingsService.isNightByTime
  // ---------------------------------------------------------------------------
  group('NightModeSettingsService.isNightByTime', () {
    test('returns true at 20:00 (start of night window)', () {
      expect(
        NightModeSettingsService.isNightByTime(
            DateTime(2025, 1, 1, 20, 0)),
        isTrue,
      );
    });

    test('returns true at 23:59 (late night)', () {
      expect(
        NightModeSettingsService.isNightByTime(
            DateTime(2025, 1, 1, 23, 59)),
        isTrue,
      );
    });

    test('returns true at 00:00 (midnight)', () {
      expect(
        NightModeSettingsService.isNightByTime(
            DateTime(2025, 1, 1, 0, 0)),
        isTrue,
      );
    });

    test('returns true at 05:59 (end of night window)', () {
      expect(
        NightModeSettingsService.isNightByTime(
            DateTime(2025, 1, 1, 5, 59)),
        isTrue,
      );
    });

    test('returns false at 06:00 (start of day window)', () {
      expect(
        NightModeSettingsService.isNightByTime(
            DateTime(2025, 1, 1, 6, 0)),
        isFalse,
      );
    });

    test('returns false at 12:00 (midday)', () {
      expect(
        NightModeSettingsService.isNightByTime(
            DateTime(2025, 1, 1, 12, 0)),
        isFalse,
      );
    });

    test('returns false at 19:59 (just before night window)', () {
      expect(
        NightModeSettingsService.isNightByTime(
            DateTime(2025, 1, 1, 19, 59)),
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // NightModeSettingsService – persistence
  // ---------------------------------------------------------------------------
  group('NightModeSettingsService persistence', () {
    late NightModeSettingsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = NightModeSettingsService();
    });

    test('load returns auto when nothing is persisted', () async {
      final option = await service.load();
      expect(option, NightModeOption.auto);
    });

    test('save and reload alwaysOn round-trips correctly', () async {
      await service.save(NightModeOption.alwaysOn);
      final loaded = await service.load();
      expect(loaded, NightModeOption.alwaysOn);
    });

    test('save and reload alwaysOff round-trips correctly', () async {
      await service.save(NightModeOption.alwaysOff);
      final loaded = await service.load();
      expect(loaded, NightModeOption.alwaysOff);
    });

    test('save and reload auto round-trips correctly', () async {
      await service.save(NightModeOption.auto);
      final loaded = await service.load();
      expect(loaded, NightModeOption.auto);
    });

    test('overwriting save replaces previous value', () async {
      await service.save(NightModeOption.alwaysOn);
      await service.save(NightModeOption.alwaysOff);
      final loaded = await service.load();
      expect(loaded, NightModeOption.alwaysOff);
    });
  });

  // ---------------------------------------------------------------------------
  // NightModeOption enum
  // ---------------------------------------------------------------------------
  group('NightModeOption', () {
    test('has three values', () {
      expect(NightModeOption.values, hasLength(3));
    });

    test('enum names match expected strings', () {
      expect(NightModeOption.auto.name, 'auto');
      expect(NightModeOption.alwaysOn.name, 'alwaysOn');
      expect(NightModeOption.alwaysOff.name, 'alwaysOff');
    });
  });
}

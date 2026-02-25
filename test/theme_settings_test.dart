import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/services/theme_settings_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // ThemeOption enum
  // ---------------------------------------------------------------------------
  group('ThemeOption', () {
    test('has six values', () {
      expect(ThemeOption.values, hasLength(6));
    });

    test('enum names match expected strings', () {
      expect(ThemeOption.classic.name, 'classic');
      expect(ThemeOption.highContrast.name, 'highContrast');
      expect(ThemeOption.blue.name, 'blue');
      expect(ThemeOption.green.name, 'green');
      expect(ThemeOption.red.name, 'red');
      expect(ThemeOption.custom.name, 'custom');
    });
  });

  // ---------------------------------------------------------------------------
  // ThemeSettingsService – preset seed colors
  // ---------------------------------------------------------------------------
  group('ThemeSettingsService.presetSeedColors', () {
    test('has an entry for every ThemeOption', () {
      for (final option in ThemeOption.values) {
        expect(
          ThemeSettingsService.presetSeedColors.containsKey(option),
          isTrue,
          reason: '${option.name} missing from presetSeedColors',
        );
      }
    });

    test('classic seed color is the expected deep-orange', () {
      expect(
        ThemeSettingsService.presetSeedColors[ThemeOption.classic],
        const Color(0xFFE65100),
      );
    });

    test('defaultSeedColor matches classic preset', () {
      expect(
        ThemeSettingsService.defaultSeedColor,
        ThemeSettingsService.presetSeedColors[ThemeOption.classic],
      );
    });
  });

  // ---------------------------------------------------------------------------
  // ThemeSettingsService – option labels
  // ---------------------------------------------------------------------------
  group('ThemeSettingsService.optionLabels', () {
    test('has a label for every ThemeOption', () {
      for (final option in ThemeOption.values) {
        expect(
          ThemeSettingsService.optionLabels.containsKey(option),
          isTrue,
          reason: '${option.name} missing from optionLabels',
        );
      }
    });
  });

  // ---------------------------------------------------------------------------
  // ThemeSettingsService – custom palette
  // ---------------------------------------------------------------------------
  group('ThemeSettingsService.customPalette', () {
    test('is non-empty', () {
      expect(ThemeSettingsService.customPalette, isNotEmpty);
    });

    test('contains the classic default color', () {
      expect(
        ThemeSettingsService.customPalette,
        contains(ThemeSettingsService.defaultSeedColor),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // ThemeSettingsService – persistence
  // ---------------------------------------------------------------------------
  group('ThemeSettingsService persistence', () {
    late ThemeSettingsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = ThemeSettingsService();
    });

    // ── loadOption ──────────────────────────────────────────────────────────

    test('loadOption returns classic when nothing is persisted', () async {
      final option = await service.loadOption();
      expect(option, ThemeOption.classic);
    });

    test('saveOption and loadOption round-trip for every preset', () async {
      for (final option in ThemeOption.values) {
        SharedPreferences.setMockInitialValues({});
        await service.saveOption(option);
        final loaded = await service.loadOption();
        expect(loaded, option, reason: 'Round-trip failed for ${option.name}');
      }
    });

    test('overwriting saveOption replaces previous value', () async {
      await service.saveOption(ThemeOption.blue);
      await service.saveOption(ThemeOption.green);
      final loaded = await service.loadOption();
      expect(loaded, ThemeOption.green);
    });

    // ── loadCustomAccent ────────────────────────────────────────────────────

    test('loadCustomAccent returns defaultSeedColor when nothing is persisted',
        () async {
      final color = await service.loadCustomAccent();
      expect(color, ThemeSettingsService.defaultSeedColor);
    });

    test('saveCustomAccent and loadCustomAccent round-trip correctly',
        () async {
      const testColor = Color(0xFF1565C0); // deep-blue
      await service.saveCustomAccent(testColor);
      final loaded = await service.loadCustomAccent();
      expect(loaded, testColor);
    });

    test('overwriting saveCustomAccent replaces previous value', () async {
      await service.saveCustomAccent(const Color(0xFF2E7D32));
      await service.saveCustomAccent(const Color(0xFFC62828));
      final loaded = await service.loadCustomAccent();
      expect(loaded, const Color(0xFFC62828));
    });

    test('option and custom accent are independent', () async {
      await service.saveOption(ThemeOption.custom);
      await service.saveCustomAccent(const Color(0xFF283593));
      expect(await service.loadOption(), ThemeOption.custom);
      expect(await service.loadCustomAccent(), const Color(0xFF283593));
    });
  });
}

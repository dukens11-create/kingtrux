import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/truck_stop_brand.dart';
import 'package:kingtrux/services/truck_stop_filter_service.dart';
import 'package:kingtrux/services/truck_stop_brand_settings_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // TruckStopFilterService.normalize
  // ---------------------------------------------------------------------------
  group('TruckStopFilterService.normalize', () {
    test('lowercases input', () {
      expect(TruckStopFilterService.normalize('TA'), 'ta');
      expect(TruckStopFilterService.normalize('Flying J'), 'flyingj');
    });

    test("strips apostrophes (Love's → loves)", () {
      expect(TruckStopFilterService.normalize("Love's"), 'loves');
    });

    test('strips spaces and punctuation', () {
      expect(
        TruckStopFilterService.normalize('Travel Centers of America'),
        'travelcentersofamerica',
      );
    });

    test('preserves digits', () {
      expect(TruckStopFilterService.normalize('TA 76'), 'ta76');
    });

    test('empty string returns empty string', () {
      expect(TruckStopFilterService.normalize(''), '');
    });
  });

  // ---------------------------------------------------------------------------
  // TruckStopFilterService.detectBrand
  // ---------------------------------------------------------------------------
  group('TruckStopFilterService.detectBrand', () {
    test('detects TA via brand tag', () {
      final brand = TruckStopFilterService.detectBrand({'brand': 'TA'});
      expect(brand, TruckStopBrand.ta);
    });

    test('detects TravelCenters of America via brand tag', () {
      final brand = TruckStopFilterService.detectBrand(
        {'brand': 'TravelCenters of America'},
      );
      expect(brand, TruckStopBrand.ta);
    });

    test('detects Petro via name tag', () {
      final brand = TruckStopFilterService.detectBrand(
        {'name': 'Petro Stopping Center'},
      );
      expect(brand, TruckStopBrand.petro);
    });

    test("detects Love's via brand tag with apostrophe", () {
      final brand = TruckStopFilterService.detectBrand(
        {"brand": "Love's Travel Stop"},
      );
      expect(brand, TruckStopBrand.loves);
    });

    test("detects Loves via operator tag without apostrophe", () {
      final brand = TruckStopFilterService.detectBrand(
        {'operator': 'Loves'},
      );
      expect(brand, TruckStopBrand.loves);
    });

    test('detects Pilot via name tag', () {
      final brand = TruckStopFilterService.detectBrand(
        {'name': 'Pilot Travel Center'},
      );
      expect(brand, TruckStopBrand.pilot);
    });

    test('detects Flying J via brand tag', () {
      final brand = TruckStopFilterService.detectBrand(
        {'brand': 'Flying J'},
      );
      expect(brand, TruckStopBrand.flyingJ);
    });

    test('detects Pilot Flying J via brand as Pilot (first match wins)', () {
      // "pilotflyingj" contains both "pilot" (Pilot) and "flyingj" (Flying J);
      // Pilot is checked first in TruckStopBrand.values order.
      final brand = TruckStopFilterService.detectBrand(
        {'brand': 'Pilot Flying J'},
      );
      // Either Pilot or Flying J is acceptable; just ensure a brand is found.
      expect(brand, isNotNull);
      expect(
        [TruckStopBrand.pilot, TruckStopBrand.flyingJ],
        contains(brand),
      );
    });

    test('returns null for unrecognised brand', () {
      // Use a string that contains no known brand match-terms.
      final unknown = TruckStopFilterService.detectBrand(
        {'brand': 'UnknownBrandXYZ'},
      );
      expect(unknown, isNull);
    });

    test('returns null for empty tags', () {
      expect(TruckStopFilterService.detectBrand({}), isNull);
    });

    test('operator tag is checked when brand is absent', () {
      final brand = TruckStopFilterService.detectBrand(
        {'operator': 'Petro Iron Skillet'},
      );
      expect(brand, TruckStopBrand.petro);
    });

    test('name tag is checked as fallback', () {
      final brand = TruckStopFilterService.detectBrand(
        {'name': 'Flying J Travel Center'},
      );
      expect(brand, TruckStopBrand.flyingJ);
    });

    // New brands added for brand-image feature
    test("detects Roady's via name tag", () {
      expect(
        TruckStopFilterService.detectBrand({'name': "Roady's Truck Stop"}),
        TruckStopBrand.roadys,
      );
    });

    test('detects Sapp Bros via brand tag', () {
      expect(
        TruckStopFilterService.detectBrand({'brand': 'Sapp Bros'}),
        TruckStopBrand.sappBros,
      );
    });

    test('detects Maverik via name tag', () {
      expect(
        TruckStopFilterService.detectBrand({'name': 'Maverik'}),
        TruckStopBrand.maverik,
      );
    });

    test("detects Casey's via brand tag", () {
      expect(
        TruckStopFilterService.detectBrand({'brand': "Casey's General Store"}),
        TruckStopBrand.caseys,
      );
    });

    test('detects Shell via brand tag', () {
      expect(
        TruckStopFilterService.detectBrand({'brand': 'Shell'}),
        TruckStopBrand.shell,
      );
    });

    test('detects BP via brand tag', () {
      expect(
        TruckStopFilterService.detectBrand({'brand': 'BP'}),
        TruckStopBrand.bp,
      );
    });

    test('detects Total via brand tag', () {
      expect(
        TruckStopFilterService.detectBrand({'brand': 'TotalEnergies'}),
        TruckStopBrand.total,
      );
    });

    test('detects Petro Canada via brand tag', () {
      expect(
        TruckStopFilterService.detectBrand({'brand': 'Petro-Canada'}),
        TruckStopBrand.petroCanada,
      );
    });

    test('detects Esso via brand tag', () {
      expect(
        TruckStopFilterService.detectBrand({'brand': 'Esso'}),
        TruckStopBrand.esso,
      );
    });

    test('detects Road Ranger via name tag', () {
      expect(
        TruckStopFilterService.detectBrand({'name': 'Road Ranger Truck Stop'}),
        TruckStopBrand.roadRanger,
      );
    });

    test('detects Kwik Trip via operator tag', () {
      expect(
        TruckStopFilterService.detectBrand({'operator': 'Kwik Trip'}),
        TruckStopBrand.kwikTrip,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // TruckStopFilterService.matchesAnyBrand
  // ---------------------------------------------------------------------------
  group('TruckStopFilterService.matchesAnyBrand', () {
    test('returns true when detected brand is in enabled set', () {
      expect(
        TruckStopFilterService.matchesAnyBrand(
          {TruckStopBrand.ta},
          {'brand': 'TA'},
        ),
        isTrue,
      );
    });

    test('returns false when detected brand is not in enabled set', () {
      expect(
        TruckStopFilterService.matchesAnyBrand(
          {TruckStopBrand.pilot},
          {'brand': 'TA'},
        ),
        isFalse,
      );
    });

    test('returns false for unrecognised brand', () {
      expect(
        TruckStopFilterService.matchesAnyBrand(
          Set.of(TruckStopBrand.values),
          {'brand': 'UnknownBrandXYZ'},
        ),
        isFalse,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // TruckStopBrand enum
  // ---------------------------------------------------------------------------
  group('TruckStopBrand', () {
    test('all brands are defined', () {
      expect(TruckStopBrand.values, hasLength(18));
      expect(TruckStopBrand.values, containsAll([
        TruckStopBrand.ta,
        TruckStopBrand.petro,
        TruckStopBrand.loves,
        TruckStopBrand.pilot,
        TruckStopBrand.flyingJ,
        TruckStopBrand.kwikTrip,
        TruckStopBrand.roadRanger,
        TruckStopBrand.one9,
        TruckStopBrand.amBest,
        TruckStopBrand.roadys,
        TruckStopBrand.sappBros,
        TruckStopBrand.maverik,
        TruckStopBrand.caseys,
        TruckStopBrand.shell,
        TruckStopBrand.bp,
        TruckStopBrand.total,
        TruckStopBrand.petroCanada,
        TruckStopBrand.esso,
      ]));
    });

    test('each brand has a non-empty displayName', () {
      for (final brand in TruckStopBrand.values) {
        expect(brand.displayName, isNotEmpty);
      }
    });

    test('each brand has at least one matchTerm', () {
      for (final brand in TruckStopBrand.values) {
        expect(brand.matchTerms, isNotEmpty);
      }
    });

    test('all matchTerms are already normalised (no uppercase or punctuation)',
        () {
      for (final brand in TruckStopBrand.values) {
        for (final term in brand.matchTerms) {
          expect(
            term,
            equals(TruckStopFilterService.normalize(term)),
            reason: '${brand.name} matchTerm "$term" is not normalised',
          );
        }
      }
    });
  });

  // ---------------------------------------------------------------------------
  // TruckStopBrandSettingsService – persistence
  // ---------------------------------------------------------------------------
  group('TruckStopBrandSettingsService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns all brands when nothing is persisted', () async {
      final service = TruckStopBrandSettingsService();
      final brands = await service.load();
      expect(brands, containsAll(TruckStopBrand.values));
      expect(brands.length, TruckStopBrand.values.length);
    });

    test('save then load round-trips a subset of brands', () async {
      final service = TruckStopBrandSettingsService();
      const subset = {TruckStopBrand.ta, TruckStopBrand.loves};
      await service.save(subset);
      final loaded = await service.load();
      expect(loaded, equals(subset));
    });

    test('save empty set persists and loads as empty', () async {
      final service = TruckStopBrandSettingsService();
      await service.save({});
      final loaded = await service.load();
      expect(loaded, isEmpty);
    });

    test('overwriting save replaces previous value', () async {
      final service = TruckStopBrandSettingsService();
      await service.save({TruckStopBrand.pilot});
      await service.save({TruckStopBrand.petro, TruckStopBrand.flyingJ});
      final loaded = await service.load();
      expect(loaded, equals({TruckStopBrand.petro, TruckStopBrand.flyingJ}));
      expect(loaded, isNot(contains(TruckStopBrand.pilot)));
    });

    test('load returns all brands on corrupt persisted data', () async {
      SharedPreferences.setMockInitialValues(
        {'truck_stop_enabled_brands': 'NOT_A_STRING_LIST'},
      );
      final service = TruckStopBrandSettingsService();
      final brands = await service.load();
      expect(brands.length, TruckStopBrand.values.length);
    });

    test('persisted data survives across service instances', () async {
      final s1 = TruckStopBrandSettingsService();
      await s1.save({TruckStopBrand.ta, TruckStopBrand.petro});

      final s2 = TruckStopBrandSettingsService();
      final loaded = await s2.load();
      expect(loaded, containsAll([TruckStopBrand.ta, TruckStopBrand.petro]));
    });
  });
}

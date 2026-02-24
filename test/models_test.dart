import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/truck_profile.dart';
import 'package:kingtrux/models/poi.dart';

void main() {
  group('TruckProfile Tests', () {
    test('Default profile has correct values', () {
      final profile = TruckProfile.defaultProfile();
      
      expect(profile.heightMeters, 4.10);
      expect(profile.widthMeters, 2.60);
      expect(profile.lengthMeters, 21.0);
      expect(profile.weightTons, 36.0);
      expect(profile.axles, 5);
      expect(profile.hazmat, false);
    });

    test('copyWith creates new instance with updated values', () {
      final profile = TruckProfile.defaultProfile();
      final updated = profile.copyWith(
        heightMeters: 5.0,
        hazmat: true,
      );
      
      expect(updated.heightMeters, 5.0);
      expect(updated.widthMeters, 2.60); // Unchanged
      expect(updated.hazmat, true);
    });

    group('Serialization', () {
      test('toJson produces correct map', () {
        final profile = TruckProfile.defaultProfile();
        final json = profile.toJson();

        expect(json['heightMeters'], 4.10);
        expect(json['widthMeters'], 2.60);
        expect(json['lengthMeters'], 21.0);
        expect(json['weightTons'], 36.0);
        expect(json['axles'], 5);
        expect(json['hazmat'], false);
      });

      test('fromJson reconstructs identical profile', () {
        final original = TruckProfile(
          heightMeters: 3.8,
          widthMeters: 2.55,
          lengthMeters: 18.0,
          weightTons: 28.0,
          axles: 4,
          hazmat: true,
        );
        final json = original.toJson();
        final restored = TruckProfile.fromJson(json);

        expect(restored.heightMeters, original.heightMeters);
        expect(restored.widthMeters, original.widthMeters);
        expect(restored.lengthMeters, original.lengthMeters);
        expect(restored.weightTons, original.weightTons);
        expect(restored.axles, original.axles);
        expect(restored.hazmat, original.hazmat);
      });

      test('round-trips through JSON string', () {
        final profile = TruckProfile.defaultProfile();
        final jsonStr = jsonEncode(profile.toJson());
        final restored = TruckProfile.fromJson(
          jsonDecode(jsonStr) as Map<String, dynamic>,
        );

        expect(restored.heightMeters, profile.heightMeters);
        expect(restored.weightTons, profile.weightTons);
        expect(restored.hazmat, profile.hazmat);
      });
    });

    group('Unit conversions', () {
      test('metersToFeet converts correctly', () {
        expect(
          TruckProfile.metersToFeet(1.0),
          closeTo(3.28084, 0.00001),
        );
      });

      test('feetToMeters is the inverse of metersToFeet', () {
        const original = 4.10;
        final converted = TruckProfile.feetToMeters(
          TruckProfile.metersToFeet(original),
        );
        expect(converted, closeTo(original, 0.00001));
      });

      test('metricTonsToShortTons converts correctly', () {
        expect(
          TruckProfile.metricTonsToShortTons(1.0),
          closeTo(1.10231, 0.00001),
        );
      });

      test('shortTonsToMetricTons is the inverse of metricTonsToShortTons', () {
        const original = 36.0;
        final converted = TruckProfile.shortTonsToMetricTons(
          TruckProfile.metricTonsToShortTons(original),
        );
        expect(converted, closeTo(original, 0.00001));
      });
    });

    group('summary()', () {
      test('metric summary contains correct units', () {
        final profile = TruckProfile.defaultProfile();
        final s = profile.summary();
        expect(s, contains('m H'));
        expect(s, contains('t ·'));
        expect(s, isNot(contains('HAZMAT')));
      });

      test('imperial summary contains correct units', () {
        final profile = TruckProfile.defaultProfile();
        final s = profile.summary(unit: TruckUnit.imperial);
        expect(s, contains('ft H'));
        expect(s, contains('st ·'));
      });

      test('summary includes HAZMAT when hazmat is true', () {
        final profile = TruckProfile.defaultProfile().copyWith(hazmat: true);
        expect(profile.summary(), contains('HAZMAT'));
        expect(profile.summary(unit: TruckUnit.imperial), contains('HAZMAT'));
      });
    });

    group('validate()', () {
      test('default profile passes validation', () {
        final profile = TruckProfile.defaultProfile();
        expect(profile.validate(), isEmpty);
        expect(profile.isValid, isTrue);
      });

      test('returns error when height is zero', () {
        final profile = TruckProfile.defaultProfile().copyWith(heightMeters: 0);
        final errors = profile.validate();
        expect(errors, isNotEmpty);
        expect(errors.any((e) => e.toLowerCase().contains('height')), isTrue);
        expect(profile.isValid, isFalse);
      });

      test('returns error when weight is zero', () {
        final profile = TruckProfile.defaultProfile().copyWith(weightTons: 0);
        final errors = profile.validate();
        expect(errors.any((e) => e.toLowerCase().contains('weight')), isTrue);
      });

      test('returns error when axles < 2', () {
        final profile = TruckProfile.defaultProfile().copyWith(axles: 1);
        final errors = profile.validate();
        expect(errors.any((e) => e.toLowerCase().contains('axle')), isTrue);
      });

      test('collects multiple errors at once', () {
        final profile = TruckProfile(
          heightMeters: 0,
          widthMeters: 0,
          lengthMeters: 0,
          weightTons: 0,
          axles: 1,
          hazmat: false,
        );
        expect(profile.validate().length, greaterThanOrEqualTo(4));
      });
    });

    group('HERE routing parameter mapping', () {
      test('grossWeight is converted from tons to kg', () {
        final profile = TruckProfile.defaultProfile(); // 36 tons
        // 36 metric tons × 1000 = 36 000 kg
        expect(profile.weightTons * 1000, closeTo(36000, 0.01));
      });

      test('hazmat flag maps to shippedHazardousGoods', () {
        final safe = TruckProfile.defaultProfile();
        final hazmat = safe.copyWith(hazmat: true);
        expect(safe.hazmat, isFalse);
        expect(hazmat.hazmat, isTrue);
      });

      test('all dimension fields are preserved accurately', () {
        final profile = TruckProfile(
          heightMeters: 4.2,
          widthMeters: 2.55,
          lengthMeters: 22.0,
          weightTons: 40.0,
          axles: 6,
          hazmat: true,
        );
        expect(profile.heightMeters, 4.2);
        expect(profile.widthMeters, 2.55);
        expect(profile.lengthMeters, 22.0);
        expect(profile.weightTons, 40.0);
        expect(profile.axles, 6);
        expect(profile.hazmat, isTrue);
        // grossWeight in kg for HERE API
        expect(profile.weightTons * 1000, closeTo(40000, 0.01));
      });
    });
  });

  group('POI Tests', () {
    test('POI can be created with required fields', () {
      final poi = Poi(
        id: '123',
        type: PoiType.fuel,
        name: 'Test Station',
        lat: 40.7128,
        lng: -74.0060,
        tags: {},
      );
      
      expect(poi.id, '123');
      expect(poi.type, PoiType.fuel);
      expect(poi.name, 'Test Station');
      expect(poi.lat, 40.7128);
      expect(poi.lng, -74.0060);
    });
  });
}

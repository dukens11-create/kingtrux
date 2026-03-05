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

      test('poundsToMetricTons converts 80000 lbs to ~36.3 t', () {
        expect(
          TruckProfile.poundsToMetricTons(80000),
          closeTo(36.287, 0.001),
        );
      });

      test('metricTonsToPounds is the inverse of poundsToMetricTons', () {
        const original = 36.287;
        final converted = TruckProfile.poundsToMetricTons(
          TruckProfile.metricTonsToPounds(original),
        );
        expect(converted, closeTo(original, 0.0001));
      });

      test('metersToFeetInches decomposes 4.1148 m into (13, 6)', () {
        final (ft, ins) = TruckProfile.metersToFeetInches(4.1148);
        expect(ft, 13);
        expect(ins, 6);
      });

      test('feetInchesToMeters converts 13 ft 6 in to ~4.115 m', () {
        expect(
          TruckProfile.feetInchesToMeters(13, 6),
          closeTo(4.115, 0.001),
        );
      });

      test('feetInchesToMeters and metersToFeetInches are inverses', () {
        const meters = 4.1148;
        final (ft, ins) = TruckProfile.metersToFeetInches(meters);
        expect(
          TruckProfile.feetInchesToMeters(ft, ins),
          closeTo(meters, 0.01),
        );
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

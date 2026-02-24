import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/truck_profile.dart';
import 'package:kingtrux/services/here_routing_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // TruckProfile.validate() — field-level validation returning error list
  // ---------------------------------------------------------------------------
  group('TruckProfile.validate()', () {
    test('returns empty list for a fully-populated valid profile', () {
      final profile = TruckProfile.defaultProfile();
      expect(profile.validate(), isEmpty);
    });

    test('returns error when heightMeters is zero', () {
      final profile = TruckProfile.defaultProfile().copyWith(heightMeters: 0);
      final errors = profile.validate();
      expect(errors, isNotEmpty);
      expect(errors.first, contains('Height'));
    });

    test('returns error when widthMeters is zero', () {
      final profile = TruckProfile.defaultProfile().copyWith(widthMeters: 0);
      expect(profile.validate(), isNotEmpty);
    });

    test('returns error when lengthMeters is zero', () {
      final profile = TruckProfile.defaultProfile().copyWith(lengthMeters: 0);
      expect(profile.validate(), isNotEmpty);
    });

    test('returns error when weightTons is zero', () {
      final profile = TruckProfile.defaultProfile().copyWith(weightTons: 0);
      final errors = profile.validate();
      expect(errors, isNotEmpty);
      expect(errors.first, contains('Weight'));
    });

    test('returns error when axles is zero', () {
      final profile = TruckProfile.defaultProfile().copyWith(axles: 0);
      final errors = profile.validate();
      expect(errors, isNotEmpty);
      expect(errors.first, contains('Axle'));
    });

    test('accumulates multiple errors', () {
      final profile = TruckProfile.defaultProfile().copyWith(
        heightMeters: 0,
        weightTons: 0,
        axles: 0,
      );
      expect(profile.validate().length, 3);
    });

    test('rejects negative values', () {
      final profile = TruckProfile.defaultProfile().copyWith(heightMeters: -1);
      expect(profile.validate(), isNotEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // HereRoutingService.validateTruckProfileForRouting()
  // Returns null on success, error string on failure.
  // ---------------------------------------------------------------------------
  group('HereRoutingService.validateTruckProfileForRouting()', () {
    test('returns null for a valid default profile', () {
      expect(
        HereRoutingService.validateTruckProfileForRouting(
          TruckProfile.defaultProfile(),
        ),
        isNull,
      );
    });

    test('returns error string when height is zero', () {
      final profile = TruckProfile.defaultProfile().copyWith(heightMeters: 0);
      expect(
        HereRoutingService.validateTruckProfileForRouting(profile),
        isNotNull,
      );
    });

    test('returns error string when axles < 2', () {
      final profile = TruckProfile.defaultProfile().copyWith(axles: 1);
      expect(
        HereRoutingService.validateTruckProfileForRouting(profile),
        isNotNull,
      );
    });

    test('accepts axles == 2', () {
      final profile = TruckProfile.defaultProfile().copyWith(axles: 2);
      expect(
        HereRoutingService.validateTruckProfileForRouting(profile),
        isNull,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // HereRoutingService.buildHereTruckQueryParams() — TruckProfile → HERE params
  // ---------------------------------------------------------------------------
  group('HereRoutingService.buildHereTruckQueryParams()', () {
    test('height is passed in meters', () {
      final params = HereRoutingService.buildHereTruckQueryParams(
        TruckProfile.defaultProfile(), // 4.10 m
      );
      expect(params['truck[height]'], '4.1');
    });

    test('width is passed in meters', () {
      final params = HereRoutingService.buildHereTruckQueryParams(
        TruckProfile.defaultProfile(), // 2.60 m
      );
      expect(params['truck[width]'], '2.6');
    });

    test('length is passed in meters', () {
      final params = HereRoutingService.buildHereTruckQueryParams(
        TruckProfile.defaultProfile(), // 21.0 m
      );
      expect(params['truck[length]'], '21.0');
    });

    test('weight is converted from metric tons to kilograms', () {
      // 36 metric tons → 36 000 kg
      final params = HereRoutingService.buildHereTruckQueryParams(
        TruckProfile.defaultProfile(), // 36 t
      );
      expect(params['truck[grossWeight]'], (36.0 * 1000).toString());
    });

    test('axle count is passed correctly', () {
      final params = HereRoutingService.buildHereTruckQueryParams(
        TruckProfile.defaultProfile(), // 5 axles
      );
      expect(params['truck[axleCount]'], '5');
    });

    test('hazmat parameter is absent when hazmat is false', () {
      final params = HereRoutingService.buildHereTruckQueryParams(
        TruckProfile.defaultProfile(), // hazmat: false
      );
      expect(params.containsKey('truck[shippedHazardousGoods]'), isFalse);
    });

    test('hazmat parameter is present when hazmat is true', () {
      final params = HereRoutingService.buildHereTruckQueryParams(
        TruckProfile.defaultProfile().copyWith(hazmat: true),
      );
      expect(params['truck[shippedHazardousGoods]'], 'explosive');
    });

    test('custom profile values are correctly mapped', () {
      const profile = TruckProfile(
        heightMeters: 3.8,
        widthMeters: 2.55,
        lengthMeters: 18.0,
        weightTons: 28.0,
        axles: 4,
        hazmat: false,
      );
      final params = HereRoutingService.buildHereTruckQueryParams(profile);

      expect(params['truck[height]'], '3.8');
      expect(params['truck[width]'], '2.55');
      expect(params['truck[length]'], '18.0');
      expect(params['truck[grossWeight]'], (28.0 * 1000).toString());
      expect(params['truck[axleCount]'], '4');
      expect(params.containsKey('truck[shippedHazardousGoods]'), isFalse);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/truck_profile.dart';
import 'package:kingtrux/services/here_routing_service.dart';

void main() {
  group('HereRoutingService.validateTruckProfileForRouting', () {
    test('returns null for a valid default profile', () {
      final profile = TruckProfile.defaultProfile();
      expect(HereRoutingService.validateTruckProfileForRouting(profile), isNull);
    });

    test('returns error when height is zero', () {
      final profile = TruckProfile.defaultProfile().copyWith(heightMeters: 0.0);
      expect(
        HereRoutingService.validateTruckProfileForRouting(profile),
        isNotNull,
      );
    });

    test('returns error when height is negative', () {
      final profile = TruckProfile.defaultProfile().copyWith(heightMeters: -1.0);
      expect(
        HereRoutingService.validateTruckProfileForRouting(profile),
        isNotNull,
      );
    });

    test('returns error when width is zero', () {
      final profile = TruckProfile.defaultProfile().copyWith(widthMeters: 0.0);
      expect(
        HereRoutingService.validateTruckProfileForRouting(profile),
        isNotNull,
      );
    });

    test('returns error when length is zero', () {
      final profile = TruckProfile.defaultProfile().copyWith(lengthMeters: 0.0);
      expect(
        HereRoutingService.validateTruckProfileForRouting(profile),
        isNotNull,
      );
    });

    test('returns error when weight is zero', () {
      final profile = TruckProfile.defaultProfile().copyWith(weightTons: 0.0);
      expect(
        HereRoutingService.validateTruckProfileForRouting(profile),
        isNotNull,
      );
    });

    test('returns error when axles is less than 2', () {
      final profile = TruckProfile.defaultProfile().copyWith(axles: 1);
      expect(
        HereRoutingService.validateTruckProfileForRouting(profile),
        isNotNull,
      );
    });

    test('returns null when axles equals 2', () {
      final profile = TruckProfile.defaultProfile().copyWith(axles: 2);
      expect(HereRoutingService.validateTruckProfileForRouting(profile), isNull);
    });

    test('returns null for a custom valid profile', () {
      const profile = TruckProfile(
        heightMeters: 3.8,
        widthMeters: 2.5,
        lengthMeters: 18.0,
        weightTons: 28.0,
        axles: 4,
        hazmat: true,
      );
      expect(HereRoutingService.validateTruckProfileForRouting(profile), isNull);
    });
  });

  group('HereRoutingService.buildHereTruckQueryParams', () {
    test('includes correct height, width, length', () {
      final profile = TruckProfile.defaultProfile();
      final params = HereRoutingService.buildHereTruckQueryParams(profile);

      expect(params['truck[height]'], profile.heightMeters.toString());
      expect(params['truck[width]'], profile.widthMeters.toString());
      expect(params['truck[length]'], profile.lengthMeters.toString());
    });

    test('converts weight from metric tons to kilograms', () {
      final profile = TruckProfile.defaultProfile(); // 36 tons
      final params = HereRoutingService.buildHereTruckQueryParams(profile);

      expect(params['truck[grossWeight]'], (36.0 * 1000).toString());
    });

    test('includes axle count', () {
      final profile = TruckProfile.defaultProfile(); // 5 axles
      final params = HereRoutingService.buildHereTruckQueryParams(profile);

      expect(params['truck[axleCount]'], '5');
    });

    test('does not include hazardous goods when hazmat is false', () {
      final profile = TruckProfile.defaultProfile(); // hazmat: false
      final params = HereRoutingService.buildHereTruckQueryParams(profile);

      expect(params.containsKey('truck[shippedHazardousGoods]'), isFalse);
    });

    test('includes hazardous goods when hazmat is true', () {
      final profile = TruckProfile.defaultProfile().copyWith(hazmat: true);
      final params = HereRoutingService.buildHereTruckQueryParams(profile);

      expect(params['truck[shippedHazardousGoods]'], 'explosive');
    });

    test('returns correct params for custom profile', () {
      const profile = TruckProfile(
        heightMeters: 4.0,
        widthMeters: 2.5,
        lengthMeters: 18.0,
        weightTons: 32.0,
        axles: 4,
        hazmat: false,
      );
      final params = HereRoutingService.buildHereTruckQueryParams(profile);

      expect(params['truck[height]'], '4.0');
      expect(params['truck[width]'], '2.5');
      expect(params['truck[length]'], '18.0');
      expect(params['truck[grossWeight]'], '32000.0');
      expect(params['truck[axleCount]'], '4');
      expect(params.containsKey('truck[shippedHazardousGoods]'), isFalse);
    });
  });
}

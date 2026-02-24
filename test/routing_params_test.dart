import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/truck_profile.dart';
import 'package:kingtrux/services/here_routing_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // TruckProfile.validate()
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
  // HereRoutingService.buildTruckParams() — TruckProfile → HERE API params
  // ---------------------------------------------------------------------------
  group('HereRoutingService.buildTruckParams()', () {
    test('transportMode is truck', () {
      final params = HereRoutingService.buildTruckParams(
        TruckProfile.defaultProfile(),
      );
      expect(params['transportMode'], 'truck');
    });

    test('return includes polyline, summary, actions', () {
      final params = HereRoutingService.buildTruckParams(
        TruckProfile.defaultProfile(),
      );
      expect(params['return'], contains('polyline'));
      expect(params['return'], contains('summary'));
      expect(params['return'], contains('actions'));
    });

    test('height is passed in meters', () {
      final profile = TruckProfile.defaultProfile(); // 4.10 m
      final params = HereRoutingService.buildTruckParams(profile);
      expect(params['truck[height]'], '4.1');
    });

    test('width is passed in meters', () {
      final profile = TruckProfile.defaultProfile(); // 2.60 m
      final params = HereRoutingService.buildTruckParams(profile);
      expect(params['truck[width]'], '2.6');
    });

    test('length is passed in meters', () {
      final profile = TruckProfile.defaultProfile(); // 21.0 m
      final params = HereRoutingService.buildTruckParams(profile);
      expect(params['truck[length]'], '21.0');
    });

    test('weight is converted from metric tons to kilograms', () {
      // 36 metric tons → 36 000 kg
      final profile = TruckProfile.defaultProfile(); // 36 t
      final params = HereRoutingService.buildTruckParams(profile);
      expect(params['truck[grossWeight]'], '36000');
    });

    test('weight conversion: 1 metric ton → 1000 kg', () {
      final profile = TruckProfile.defaultProfile().copyWith(weightTons: 1.0);
      final params = HereRoutingService.buildTruckParams(profile);
      expect(params['truck[grossWeight]'], '1000');
    });

    test('weight conversion: fractional tons rounded to whole kg', () {
      final profile = TruckProfile.defaultProfile().copyWith(weightTons: 20.5);
      final params = HereRoutingService.buildTruckParams(profile);
      // 20.5 t × 1000 = 20 500 kg
      expect(params['truck[grossWeight]'], '20500');
    });

    test('axle count is passed correctly', () {
      final profile = TruckProfile.defaultProfile(); // 5 axles
      final params = HereRoutingService.buildTruckParams(profile);
      expect(params['truck[axleCount]'], '5');
    });

    test('hazmat parameter is absent when hazmat is false', () {
      final profile = TruckProfile.defaultProfile(); // hazmat: false
      final params = HereRoutingService.buildTruckParams(profile);
      expect(params.containsKey('truck[shippedHazardousGoods]'), isFalse);
    });

    test('hazmat parameter is present when hazmat is true', () {
      final profile = TruckProfile.defaultProfile().copyWith(hazmat: true);
      final params = HereRoutingService.buildTruckParams(profile);
      expect(params['truck[shippedHazardousGoods]'], 'explosive');
    });

    test('custom profile values are correctly mapped', () {
      final profile = TruckProfile(
        heightMeters: 3.8,
        widthMeters: 2.55,
        lengthMeters: 18.0,
        weightTons: 28.0,
        axles: 4,
        hazmat: false,
      );
      final params = HereRoutingService.buildTruckParams(profile);

      expect(params['truck[height]'], '3.8');
      expect(params['truck[width]'], '2.55');
      expect(params['truck[length]'], '18.0');
      expect(params['truck[grossWeight]'], '28000');
      expect(params['truck[axleCount]'], '4');
      expect(params.containsKey('truck[shippedHazardousGoods]'), isFalse);
    });
  });
}

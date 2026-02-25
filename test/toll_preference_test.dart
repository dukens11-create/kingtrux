import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/toll_preference.dart';
import 'package:kingtrux/models/route_result.dart';
import 'package:kingtrux/models/truck_profile.dart';
import 'package:kingtrux/services/here_routing_service.dart';

void main() {
  // ---------------------------------------------------------------------------
  // TollPreference enum
  // ---------------------------------------------------------------------------
  group('TollPreference', () {
    test('has two values: any and tollFree', () {
      expect(TollPreference.values, hasLength(2));
      expect(TollPreference.values, containsAll([TollPreference.any, TollPreference.tollFree]));
    });

    test('enum names match expected strings', () {
      expect(TollPreference.any.name, 'any');
      expect(TollPreference.tollFree.name, 'tollFree');
    });
  });

  // ---------------------------------------------------------------------------
  // RouteResult — toll-related fields
  // ---------------------------------------------------------------------------
  group('RouteResult toll fields', () {
    test('avoidedTolls defaults to false', () {
      const result = RouteResult(
        polylinePoints: [],
        lengthMeters: 1000,
        durationSeconds: 60,
      );
      expect(result.avoidedTolls, isFalse);
    });

    test('estimatedTollCostUsd defaults to null', () {
      const result = RouteResult(
        polylinePoints: [],
        lengthMeters: 1000,
        durationSeconds: 60,
      );
      expect(result.estimatedTollCostUsd, isNull);
    });

    test('avoidedTolls can be set to true', () {
      const result = RouteResult(
        polylinePoints: [],
        lengthMeters: 5000,
        durationSeconds: 300,
        avoidedTolls: true,
      );
      expect(result.avoidedTolls, isTrue);
      expect(result.estimatedTollCostUsd, isNull);
    });

    test('estimatedTollCostUsd can be set to a positive value', () {
      const result = RouteResult(
        polylinePoints: [],
        lengthMeters: 10000,
        durationSeconds: 600,
        avoidedTolls: false,
        estimatedTollCostUsd: 7.50,
      );
      expect(result.estimatedTollCostUsd, 7.50);
      expect(result.avoidedTolls, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // HereRoutingService — avoidTolls query parameter
  // ---------------------------------------------------------------------------
  group('HereRoutingService — buildHereTruckQueryParams (unchanged by avoidTolls)', () {
    test('avoidTolls flag does not affect truck dimension params', () {
      final profile = TruckProfile.defaultProfile();
      final params = HereRoutingService.buildHereTruckQueryParams(profile);
      // Truck params should always be present regardless of toll preference.
      expect(params.containsKey('truck[height]'), isTrue);
      expect(params.containsKey('truck[width]'), isTrue);
      expect(params.containsKey('truck[length]'), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/services/route_options_service.dart';
import 'package:kingtrux/models/route_result.dart';
import 'package:kingtrux/models/truck_profile.dart';

void main() {
  // ---------------------------------------------------------------------------
  // RouteOptionsService — persistence
  // ---------------------------------------------------------------------------
  group('RouteOptionsService — avoidFerries persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadAvoidFerries returns false by default', () async {
      final service = RouteOptionsService();
      expect(await service.loadAvoidFerries(), isFalse);
    });

    test('saveAvoidFerries(true) is reflected by loadAvoidFerries', () async {
      final service = RouteOptionsService();
      await service.saveAvoidFerries(true);
      expect(await service.loadAvoidFerries(), isTrue);
    });

    test('saveAvoidFerries(false) is reflected by loadAvoidFerries', () async {
      final service = RouteOptionsService();
      await service.saveAvoidFerries(true);
      await service.saveAvoidFerries(false);
      expect(await service.loadAvoidFerries(), isFalse);
    });
  });

  group('RouteOptionsService — avoidUnpaved persistence', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loadAvoidUnpaved returns false by default', () async {
      final service = RouteOptionsService();
      expect(await service.loadAvoidUnpaved(), isFalse);
    });

    test('saveAvoidUnpaved(true) is reflected by loadAvoidUnpaved', () async {
      final service = RouteOptionsService();
      await service.saveAvoidUnpaved(true);
      expect(await service.loadAvoidUnpaved(), isTrue);
    });

    test('saveAvoidUnpaved(false) is reflected by loadAvoidUnpaved', () async {
      final service = RouteOptionsService();
      await service.saveAvoidUnpaved(true);
      await service.saveAvoidUnpaved(false);
      expect(await service.loadAvoidUnpaved(), isFalse);
    });

    test('avoidFerries and avoidUnpaved are stored independently', () async {
      final service = RouteOptionsService();
      await service.saveAvoidFerries(true);
      await service.saveAvoidUnpaved(false);
      expect(await service.loadAvoidFerries(), isTrue);
      expect(await service.loadAvoidUnpaved(), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // RouteResult — warnings field
  // ---------------------------------------------------------------------------
  group('RouteResult — warnings field', () {
    test('warnings defaults to empty list', () {
      const result = RouteResult(
        polylinePoints: [],
        lengthMeters: 1000,
        durationSeconds: 60,
      );
      expect(result.warnings, isEmpty);
    });

    test('warnings can be set to a non-empty list', () {
      const result = RouteResult(
        polylinePoints: [],
        lengthMeters: 5000,
        durationSeconds: 300,
        warnings: ['Height restriction on route', 'Weight limit exceeded'],
      );
      expect(result.warnings, hasLength(2));
      expect(result.warnings.first, contains('Height'));
    });
  });

  // ---------------------------------------------------------------------------
  // TruckProfile — isDefaultProfile getter
  // ---------------------------------------------------------------------------
  group('TruckProfile — isDefaultProfile', () {
    test('factory default profile returns true', () {
      final profile = TruckProfile.defaultProfile();
      expect(profile.isDefaultProfile, isTrue);
    });

    test('profile with different height returns false', () {
      final profile = TruckProfile.defaultProfile()
          .copyWith(heightMeters: 3.5);
      expect(profile.isDefaultProfile, isFalse);
    });

    test('profile with different weight returns false', () {
      final profile = TruckProfile.defaultProfile()
          .copyWith(weightTons: 20.0);
      expect(profile.isDefaultProfile, isFalse);
    });

    test('profile with hazmat true returns false', () {
      final profile = TruckProfile.defaultProfile().copyWith(hazmat: true);
      expect(profile.isDefaultProfile, isFalse);
    });
  });
}

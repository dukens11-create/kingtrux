import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/services/destination_persistence_service.dart';

void main() {
  group('DestinationPersistenceService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns null when nothing is persisted', () async {
      final service = DestinationPersistenceService();
      final result = await service.load();
      expect(result, isNull);
    });

    test('save then load round-trips lat/lng', () async {
      const lat = 45.5017;
      const lng = -73.5673;
      final service = DestinationPersistenceService();
      await service.save(lat, lng);
      final result = await service.load();
      expect(result, isNotNull);
      expect(result!.lat, closeTo(lat, 1e-9));
      expect(result.lng, closeTo(lng, 1e-9));
    });

    test('save overwrites previous destination', () async {
      final service = DestinationPersistenceService();
      await service.save(1.0, 2.0);
      await service.save(3.0, 4.0);
      final result = await service.load();
      expect(result!.lat, closeTo(3.0, 1e-9));
      expect(result.lng, closeTo(4.0, 1e-9));
    });

    test('clear removes persisted destination', () async {
      final service = DestinationPersistenceService();
      await service.save(10.0, 20.0);
      await service.clear();
      final result = await service.load();
      expect(result, isNull);
    });

    test('persisted data survives across service instances', () async {
      final s1 = DestinationPersistenceService();
      await s1.save(51.5074, -0.1278);

      final s2 = DestinationPersistenceService();
      final result = await s2.load();
      expect(result, isNotNull);
      expect(result!.lat, closeTo(51.5074, 1e-9));
      expect(result.lng, closeTo(-0.1278, 1e-9));
    });
  });
}

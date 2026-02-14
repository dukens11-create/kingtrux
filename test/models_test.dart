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

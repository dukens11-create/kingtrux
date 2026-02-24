import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/poi.dart';
import 'package:kingtrux/services/favorite_poi_service.dart';

void main() {
  group('FavoritePoiService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns empty set when nothing persisted', () async {
      final service = FavoritePoiService();
      final ids = await service.load();
      expect(ids, isEmpty);
    });

    test('save and load round-trips a set of ids', () async {
      final service = FavoritePoiService();
      const ids = {'node_1', 'way_42', 'node_99'};
      await service.save(ids);
      final loaded = await service.load();
      expect(loaded, equals(ids));
    });

    test('save overwrites previous data', () async {
      final service = FavoritePoiService();
      await service.save({'node_1', 'node_2'});
      await service.save({'node_3'});
      final loaded = await service.load();
      expect(loaded, equals({'node_3'}));
    });

    test('save empty set clears persisted data', () async {
      final service = FavoritePoiService();
      await service.save({'node_1'});
      await service.save({});
      final loaded = await service.load();
      expect(loaded, isEmpty);
    });
  });

  group('POI filtering logic', () {
    final pois = [
      Poi(
        id: '1',
        type: PoiType.fuel,
        name: 'Fuel A',
        lat: 0,
        lng: 0,
        tags: {},
      ),
      Poi(
        id: '2',
        type: PoiType.truckStop,
        name: 'Truck Stop B',
        lat: 0,
        lng: 0,
        tags: {},
      ),
      Poi(
        id: '3',
        type: PoiType.parking,
        name: 'Parking C',
        lat: 0,
        lng: 0,
        tags: {},
      ),
      Poi(
        id: '4',
        type: PoiType.restArea,
        name: 'Rest Area D',
        lat: 0,
        lng: 0,
        tags: {},
      ),
      Poi(
        id: '5',
        type: PoiType.scale,
        name: 'Scale E',
        lat: 0,
        lng: 0,
        tags: {},
      ),
    ];

    List<Poi> filterByTypes(List<Poi> all, Set<PoiType> types) {
      if (types.isEmpty) return all;
      return all.where((p) => types.contains(p.type)).toList();
    }

    test('empty filter returns all POIs', () {
      final result = filterByTypes(pois, {});
      expect(result, hasLength(pois.length));
    });

    test('single category filter returns only matching POIs', () {
      final result = filterByTypes(pois, {PoiType.fuel});
      expect(result, hasLength(1));
      expect(result.first.type, PoiType.fuel);
    });

    test('multiple category filter returns union of matches', () {
      final result = filterByTypes(pois, {PoiType.truckStop, PoiType.parking});
      expect(result, hasLength(2));
      expect(result.map((p) => p.type), containsAll([PoiType.truckStop, PoiType.parking]));
    });

    test('filter with no matching category returns empty list', () {
      final result = filterByTypes(pois, {PoiType.gym});
      expect(result, isEmpty);
    });

    test('all driver-relevant categories are present in PoiType', () {
      expect(PoiType.values, containsAll([
        PoiType.truckStop,
        PoiType.parking,
        PoiType.scale,
        PoiType.restArea,
        PoiType.fuel,
        PoiType.gym,
      ]));
    });
  });

  group('Favourite POI deduplication', () {
    test('toggling same id twice removes it', () async {
      SharedPreferences.setMockInitialValues({});
      final service = FavoritePoiService();
      var ids = await service.load();

      // Add
      ids = {...ids, 'node_10'};
      await service.save(ids);
      expect((await service.load()), contains('node_10'));

      // Remove
      ids = Set.of(ids)..remove('node_10');
      await service.save(ids);
      expect((await service.load()), isNot(contains('node_10')));
    });

    test('duplicate ids are not stored twice', () async {
      SharedPreferences.setMockInitialValues({});
      final service = FavoritePoiService();
      await service.save({'a', 'a', 'b'});
      final loaded = await service.load();
      expect(loaded.length, 2);
    });
  });
}

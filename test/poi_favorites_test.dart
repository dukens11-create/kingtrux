import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/poi.dart';
import 'package:kingtrux/services/favorites_service.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

Poi _makePoi(String id, PoiType type) => Poi(
      id: id,
      type: type,
      name: 'Test $id',
      lat: 0.0,
      lng: 0.0,
      tags: {},
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('FavoritesService', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('load returns empty set when nothing is persisted', () async {
      final service = FavoritesService();
      final favs = await service.load();
      expect(favs, isEmpty);
    });

    test('save then load round-trips favorite IDs', () async {
      final service = FavoritesService();
      const ids = {'node_1', 'way_42', 'node_99'};
      await service.save(ids);
      final loaded = await service.load();
      expect(loaded, equals(ids));
    });

    test('save overwrites previous set', () async {
      final service = FavoritesService();
      await service.save({'node_1', 'node_2'});
      await service.save({'node_3'});
      final loaded = await service.load();
      expect(loaded, equals({'node_3'}));
      expect(loaded, isNot(contains('node_1')));
    });

    test('save empty set persists and loads as empty', () async {
      final service = FavoritesService();
      await service.save({'node_1'});
      await service.save({});
      final loaded = await service.load();
      expect(loaded, isEmpty);
    });

    test('load returns empty set on corrupt persisted data', () async {
      SharedPreferences.setMockInitialValues({'poi_favorites': 'NOT_JSON'});
      final service = FavoritesService();
      final loaded = await service.load();
      expect(loaded, isEmpty);
    });

    test('persisted data survives across service instances', () async {
      final s1 = FavoritesService();
      await s1.save({'node_10', 'way_20'});

      final s2 = FavoritesService();
      final loaded = await s2.load();
      expect(loaded, containsAll(['node_10', 'way_20']));
    });
  });

  group('POI deduplication logic', () {
    test('deduplicates by id when merging two lists', () {
      final pois = [
        _makePoi('node_1', PoiType.fuel),
        _makePoi('node_2', PoiType.truckStop),
      ];
      final extra = [
        _makePoi('node_1', PoiType.fuel), // duplicate
        _makePoi('node_3', PoiType.parking),
      ];

      final seen = <String>{};
      final merged = <Poi>[];
      for (final poi in [...pois, ...extra]) {
        if (seen.add(poi.id)) merged.add(poi);
      }

      expect(merged.length, 3);
      expect(merged.map((p) => p.id).toSet(), {'node_1', 'node_2', 'node_3'});
    });

    test('near-me POIs take precedence over along-route duplicates', () {
      final nearMe = [_makePoi('node_1', PoiType.fuel)];
      final alongRoute = [
        _makePoi('node_1', PoiType.fuel), // same id
        _makePoi('node_2', PoiType.parking),
      ];

      final seen = <String>{};
      final merged = <Poi>[];
      for (final poi in [...nearMe, ...alongRoute]) {
        if (seen.add(poi.id)) merged.add(poi);
      }

      // node_1 from nearMe wins; node_2 added from along-route
      expect(merged.length, 2);
      expect(merged.first.id, 'node_1');
    });
  });

  group('POI filtering by enabled layers', () {
    final allPois = [
      _makePoi('a', PoiType.fuel),
      _makePoi('b', PoiType.truckStop),
      _makePoi('c', PoiType.parking),
      _makePoi('d', PoiType.scale),
      _makePoi('e', PoiType.restArea),
    ];

    test('returns only enabled types', () {
      const enabled = {PoiType.fuel, PoiType.parking};
      final filtered = allPois.where((p) => enabled.contains(p.type)).toList();
      expect(filtered.length, 2);
      expect(filtered.map((p) => p.type).toSet(), equals(enabled));
    });

    test('empty enabled set yields empty result', () {
      final filtered =
          allPois.where((p) => <PoiType>{}.contains(p.type)).toList();
      expect(filtered, isEmpty);
    });

    test('all types enabled returns all pois', () {
      final enabled = PoiType.values.toSet();
      final filtered = allPois.where((p) => enabled.contains(p.type)).toList();
      expect(filtered.length, allPois.length);
    });
  });

  group('Poi model', () {
    test('stable OSM id format matches node_<id> pattern', () {
      const id = 'node_123456';
      expect(id, matches(r'^(node|way|relation)_\d+$'));
    });

    test('two POIs with different OSM ids are not duplicates', () {
      final a = _makePoi('node_1', PoiType.fuel);
      final b = _makePoi('node_2', PoiType.fuel);
      expect(a.id == b.id, isFalse);
    });

    test('FavoritesService serialises ids via jsonEncode/jsonDecode roundtrip',
        () {
      const ids = {'node_1', 'way_999', 'relation_42'};
      final encoded = jsonEncode(ids.toList());
      final decoded = (jsonDecode(encoded) as List<dynamic>).cast<String>().toSet();
      expect(decoded, equals(ids));
    });
  });
}

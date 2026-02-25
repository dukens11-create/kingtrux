import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/poi.dart';
import 'package:kingtrux/models/roadside_service_type.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Poi _makePoi(String id, Map<String, dynamic> tags) => Poi(
      id: id,
      type: PoiType.roadsideAssistance,
      name: 'Test $id',
      lat: 40.0,
      lng: -74.0,
      tags: tags,
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('RoadsideServiceType.displayName', () {
    test('towing label is Towing', () {
      expect(RoadsideServiceType.towing.displayName, 'Towing');
    });
    test('mechanic label is Mechanic', () {
      expect(RoadsideServiceType.mechanic.displayName, 'Mechanic');
    });
    test('tire label is Tire', () {
      expect(RoadsideServiceType.tire.displayName, 'Tire');
    });
    test('other label is Other', () {
      expect(RoadsideServiceType.other.displayName, 'Other');
    });
  });

  group('roadsideTypeFromTags', () {
    test('emergency=roadside_assistance maps to towing', () {
      final poi = _makePoi('a', {'emergency': 'roadside_assistance'});
      expect(roadsideTypeFromTags(poi.tags), RoadsideServiceType.towing);
    });

    test('service containing tow maps to towing', () {
      final poi = _makePoi('b', {'service': 'towing'});
      expect(roadsideTypeFromTags(poi.tags), RoadsideServiceType.towing);
    });

    test('shop=tyres maps to tire', () {
      final poi = _makePoi('c', {'shop': 'tyres'});
      expect(roadsideTypeFromTags(poi.tags), RoadsideServiceType.tire);
    });

    test('shop=tires maps to tire', () {
      final poi = _makePoi('d', {'shop': 'tires'});
      expect(roadsideTypeFromTags(poi.tags), RoadsideServiceType.tire);
    });

    test('shop=car_parts maps to tire', () {
      final poi = _makePoi('e', {'shop': 'car_parts'});
      expect(roadsideTypeFromTags(poi.tags), RoadsideServiceType.tire);
    });

    test('amenity=car_repair maps to mechanic', () {
      final poi = _makePoi('f', {'amenity': 'car_repair'});
      expect(roadsideTypeFromTags(poi.tags), RoadsideServiceType.mechanic);
    });

    test('shop=car_repair maps to mechanic', () {
      final poi = _makePoi('g', {'shop': 'car_repair'});
      expect(roadsideTypeFromTags(poi.tags), RoadsideServiceType.mechanic);
    });

    test('service containing repair maps to mechanic', () {
      final poi = _makePoi('h', {'service': 'vehicle_repair'});
      expect(roadsideTypeFromTags(poi.tags), RoadsideServiceType.mechanic);
    });

    test('empty tags maps to other', () {
      final poi = _makePoi('i', {});
      expect(roadsideTypeFromTags(poi.tags), RoadsideServiceType.other);
    });

    test('unrecognised tags maps to other', () {
      final poi = _makePoi('j', {'amenity': 'pharmacy'});
      expect(roadsideTypeFromTags(poi.tags), RoadsideServiceType.other);
    });
  });

  group('Poi with roadsideAssistance type', () {
    test('can be created with PoiType.roadsideAssistance', () {
      final poi = Poi(
        id: 'roadside_node_42',
        type: PoiType.roadsideAssistance,
        name: 'Quick Tow',
        lat: 41.0,
        lng: -80.0,
        tags: {'amenity': 'car_repair', 'phone': '+1-800-555-0199'},
      );
      expect(poi.type, PoiType.roadsideAssistance);
      expect(poi.tags['phone'], '+1-800-555-0199');
    });

    test('roadsideAssistance is a member of PoiType.values', () {
      expect(PoiType.values, contains(PoiType.roadsideAssistance));
    });
  });

  group('Roadside provider list filtering', () {
    final providers = [
      _makePoi('1', {'emergency': 'roadside_assistance'}), // towing
      _makePoi('2', {'shop': 'tyres'}),                    // tire
      _makePoi('3', {'amenity': 'car_repair'}),            // mechanic
      _makePoi('4', {'amenity': 'pharmacy'}),              // other
    ];

    test('filter by towing returns only towing providers', () {
      const filter = {RoadsideServiceType.towing};
      final result =
          providers.where((p) => filter.contains(roadsideTypeFromTags(p.tags))).toList();
      expect(result.length, 1);
      expect(result.first.id, '1');
    });

    test('filter by tire returns only tire providers', () {
      const filter = {RoadsideServiceType.tire};
      final result =
          providers.where((p) => filter.contains(roadsideTypeFromTags(p.tags))).toList();
      expect(result.length, 1);
      expect(result.first.id, '2');
    });

    test('filter by mechanic returns only mechanic providers', () {
      const filter = {RoadsideServiceType.mechanic};
      final result =
          providers.where((p) => filter.contains(roadsideTypeFromTags(p.tags))).toList();
      expect(result.length, 1);
      expect(result.first.id, '3');
    });

    test('filter by multiple types returns all matching providers', () {
      final filter = {RoadsideServiceType.towing, RoadsideServiceType.tire};
      final result =
          providers.where((p) => filter.contains(roadsideTypeFromTags(p.tags))).toList();
      expect(result.length, 2);
    });

    test('empty filter set means no providers shown', () {
      final filter = <RoadsideServiceType>{};
      final result =
          providers.where((p) => filter.contains(roadsideTypeFromTags(p.tags))).toList();
      expect(result, isEmpty);
    });
  });
}

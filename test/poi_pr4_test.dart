import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/poi.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

Poi _makePoi(
  String id,
  PoiType type, {
  Map<String, dynamic>? tags,
}) =>
    Poi(
      id: id,
      type: type,
      name: 'Test $id',
      lat: 0.0,
      lng: 0.0,
      tags: tags ?? {},
    );

// ---------------------------------------------------------------------------
// Mirrors the private _isOpenNow logic from PoiBrowserSheet so it can be unit
// tested without spinning up a widget tree.
// ---------------------------------------------------------------------------

bool _isOpenNow(Poi poi) {
  final hours = poi.tags['opening_hours'] as String?;
  if (hours == null || hours.isEmpty) return true;
  final normalized = hours.trim().toLowerCase();
  if (normalized == '24/7') return true;
  final now = DateTime.now();
  final match =
      RegExp(r'^(\d{2}):(\d{2})-(\d{2}):(\d{2})$').firstMatch(normalized);
  if (match == null) return true;
  final openH = int.parse(match.group(1)!);
  final openM = int.parse(match.group(2)!);
  final closeH = int.parse(match.group(3)!);
  final closeM = int.parse(match.group(4)!);
  final nowMins = now.hour * 60 + now.minute;
  final openMins = openH * 60 + openM;
  var closeMins = closeH * 60 + closeM;
  if (closeMins < openMins) closeMins += 24 * 60;
  return nowMins >= openMins && nowMins < closeMins;
}

bool _hasHoursData(List<Poi> pois) =>
    pois.any((p) => (p.tags['opening_hours'] as String?) != null);

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('POI favorites section logic', () {
    test('favPois is intersection of favoritePois IDs and visible pois', () {
      final pois = [
        _makePoi('a', PoiType.fuel),
        _makePoi('b', PoiType.truckStop),
        _makePoi('c', PoiType.parking),
      ];
      const favIds = {'a', 'c'};

      final favPois = pois.where((p) => favIds.contains(p.id)).toList();

      expect(favPois.length, 2);
      expect(favPois.map((p) => p.id).toSet(), equals({'a', 'c'}));
    });

    test('favPois is empty when no favorites are set', () {
      final pois = [
        _makePoi('a', PoiType.fuel),
        _makePoi('b', PoiType.truckStop),
      ];
      const favIds = <String>{};

      final favPois = pois.where((p) => favIds.contains(p.id)).toList();

      expect(favPois, isEmpty);
    });

    test('favPois excludes POIs not in the visible list', () {
      // 'z' is favorited but not in the current query results
      final pois = [_makePoi('a', PoiType.fuel)];
      const favIds = {'z'};

      final favPois = pois.where((p) => favIds.contains(p.id)).toList();

      expect(favPois, isEmpty);
    });

    test('list item count with favorites: favCount + header + allCount', () {
      final pois = [
        _makePoi('a', PoiType.fuel),
        _makePoi('b', PoiType.truckStop),
        _makePoi('c', PoiType.parking),
      ];
      final favPois = [pois[0], pois[2]]; // 2 favorites

      // header(1) + favCount(2) + all visible(3)
      final itemCount = favPois.length + 1 + pois.length;
      expect(itemCount, 6);
    });
  });

  group('Open Now filter logic', () {
    test('POI without opening_hours is treated as open', () {
      final poi = _makePoi('x', PoiType.fuel);
      expect(_isOpenNow(poi), isTrue);
    });

    test('24/7 POI is always open', () {
      final poi = _makePoi('x', PoiType.fuel, tags: {'opening_hours': '24/7'});
      expect(_isOpenNow(poi), isTrue);
    });

    test('complex hours string (not simple range) is treated as open', () {
      final poi = _makePoi('x', PoiType.fuel,
          tags: {'opening_hours': 'Mo-Fr 08:00-20:00; Sa 09:00-17:00'});
      expect(_isOpenNow(poi), isTrue);
    });

    test('_hasHoursData returns false when no POI has opening_hours', () {
      final pois = [
        _makePoi('a', PoiType.fuel),
        _makePoi('b', PoiType.truckStop),
      ];
      expect(_hasHoursData(pois), isFalse);
    });

    test('_hasHoursData returns true when at least one POI has opening_hours',
        () {
      final pois = [
        _makePoi('a', PoiType.fuel),
        _makePoi('b', PoiType.truckStop, tags: {'opening_hours': '24/7'}),
      ];
      expect(_hasHoursData(pois), isTrue);
    });
  });

  group('POI cache validity logic', () {
    // Mirror the private cache logic
    const ttl = Duration(minutes: 5);
    const threshold = 0.009;

    bool isCacheValid(
      DateTime? fetchedAt,
      double? cacheLat,
      double? cacheLng,
      double lat,
      double lng,
    ) {
      if (fetchedAt == null || cacheLat == null || cacheLng == null) {
        return false;
      }
      if (DateTime.now().difference(fetchedAt) > ttl) return false;
      return (lat - cacheLat).abs() < threshold &&
          (lng - cacheLng).abs() < threshold;
    }

    test('returns false when no previous fetch', () {
      expect(isCacheValid(null, null, null, 0, 0), isFalse);
    });

    test('returns true for same location within TTL', () {
      final now = DateTime.now();
      expect(isCacheValid(now, 45.0, -73.0, 45.0, -73.0), isTrue);
    });

    test('returns false when TTL has expired', () {
      final old = DateTime.now().subtract(const Duration(minutes: 6));
      expect(isCacheValid(old, 45.0, -73.0, 45.0, -73.0), isFalse);
    });

    test('returns false when location has changed beyond threshold', () {
      final now = DateTime.now();
      // ~1.1 km offset
      expect(isCacheValid(now, 45.0, -73.0, 45.01, -73.0), isFalse);
    });

    test('returns true when location is within threshold', () {
      final now = DateTime.now();
      // ~0.5 km offset (within 0.009 degrees)
      expect(isCacheValid(now, 45.0, -73.0, 45.005, -73.005), isTrue);
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/poi.dart';
import 'package:kingtrux/services/weigh_station_ahead_service.dart';

// ---------------------------------------------------------------------------
// Geometry helpers
// ---------------------------------------------------------------------------

void main() {
  group('weighStationHaversine', () {
    test('same point returns 0', () {
      expect(weighStationHaversine(40.0, -90.0, 40.0, -90.0), 0.0);
    });

    test('1 degree of latitude ≈ 111 km', () {
      final dist = weighStationHaversine(40.0, -90.0, 41.0, -90.0);
      expect(dist, closeTo(111195, 500)); // ±500 m tolerance
    });

    test('100 miles ≈ 160934 m', () {
      // ~1.449 degrees latitude at 40°N ≈ 100 miles.
      final dist = weighStationHaversine(40.0, -90.0, 41.449, -90.0);
      expect(dist, closeTo(160934, 2000));
    });
  });

  group('weighStationBearing', () {
    test('due north returns 0', () {
      expect(weighStationBearing(40.0, -90.0, 41.0, -90.0), closeTo(0, 0.1));
    });

    test('due east returns 90', () {
      expect(weighStationBearing(40.0, -90.0, 40.0, -89.0), closeTo(90, 1));
    });

    test('due south returns 180', () {
      expect(
        weighStationBearing(41.0, -90.0, 40.0, -90.0),
        closeTo(180, 0.1),
      );
    });

    test('due west returns 270', () {
      expect(
        weighStationBearing(40.0, -90.0, 40.0, -91.0),
        closeTo(270, 1),
      );
    });
  });

  group('weighStationAngularDiff', () {
    test('same bearing → 0', () {
      expect(weighStationAngularDiff(45, 45), 0);
    });

    test('90 apart → 90', () {
      expect(weighStationAngularDiff(0, 90), 90);
    });

    test('180 apart → 180', () {
      expect(weighStationAngularDiff(0, 180), 180);
    });

    test('wraps correctly across 0/360 boundary', () {
      // 350° and 10° are 20° apart.
      expect(weighStationAngularDiff(350, 10), closeTo(20, 0.001));
    });

    test('270 and 90 → 180', () {
      expect(weighStationAngularDiff(270, 90), 180);
    });
  });

  group('isAheadByHeading', () {
    test('scale due north, driver heading north (0°) → ahead', () {
      expect(
        isAheadByHeading(40.0, -90.0, 40.5, -90.0, 0.0),
        isTrue,
      );
    });

    test('scale due south, driver heading north → NOT ahead', () {
      expect(
        isAheadByHeading(40.0, -90.0, 39.5, -90.0, 0.0),
        isFalse,
      );
    });

    test('scale 59° off heading → ahead (within 60° cone)', () {
      // Bearing to scale is ≈0°, heading is 59°, diff = 59 < 60.
      expect(
        isAheadByHeading(40.0, -90.0, 40.5, -90.0, 59.0),
        isTrue,
      );
    });

    test('scale exactly 60° off heading → ahead (boundary)', () {
      expect(
        isAheadByHeading(40.0, -90.0, 40.5, -90.0, 60.0),
        isTrue,
      );
    });

    test('scale 61° off heading → NOT ahead', () {
      expect(
        isAheadByHeading(40.0, -90.0, 40.5, -90.0, 61.0),
        isFalse,
      );
    });

    test('custom maxDiffDeg overrides default 60°', () {
      // Bearing ≈ 0°, heading = 45° → diff = 45; within 50° cone.
      expect(
        isAheadByHeading(40.0, -90.0, 40.5, -90.0, 45.0,
            maxDiffDeg: 50.0),
        isTrue,
      );
      // NOT within 40° cone.
      expect(
        isAheadByHeading(40.0, -90.0, 40.5, -90.0, 45.0,
            maxDiffDeg: 40.0),
        isFalse,
      );
    });
  });

  group('closestPolylineIndex', () {
    final polyline = [
      [40.0, -90.0],
      [40.1, -90.0],
      [40.2, -90.0],
    ];

    test('point at start → index 0', () {
      expect(closestPolylineIndex(40.0, -90.0, polyline), 0);
    });

    test('point at end → index 2', () {
      expect(closestPolylineIndex(40.2, -90.0, polyline), 2);
    });

    test('point closest to middle → index 1', () {
      expect(closestPolylineIndex(40.1, -90.0, polyline), 1);
    });
  });

  group('isAheadOnRoute', () {
    // Simple north-going route: 40.0 → 40.1 → 40.2 → 40.3
    final polyline = [
      [40.0, -90.0],
      [40.1, -90.0],
      [40.2, -90.0],
      [40.3, -90.0],
    ];

    test('target at later polyline index is ahead', () {
      // Driver at 40.0 (idx 0), scale at 40.2 (idx 2) → ahead.
      expect(
        isAheadOnRoute(40.0, -90.0, 40.2, -90.0, polyline),
        isTrue,
      );
    });

    test('target at earlier polyline index is NOT ahead', () {
      // Driver at 40.2 (idx 2), scale at 40.0 (idx 0) → behind.
      expect(
        isAheadOnRoute(40.2, -90.0, 40.0, -90.0, polyline),
        isFalse,
      );
    });

    test('target far from route corridor is NOT ahead', () {
      // Scale 200 km east of route.
      expect(
        isAheadOnRoute(
          40.0, -90.0, 40.2, -88.0, // ≈180 km east
          polyline,
          corridorMeters: 5000,
        ),
        isFalse,
      );
    });

    test('empty polyline returns false', () {
      expect(isAheadOnRoute(40.0, -90.0, 40.2, -90.0, []), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // WeighStationAheadService – "passed" logic
  // ---------------------------------------------------------------------------

  group('WeighStationAheadService passed logic', () {
    late _FakePoiService poiService;
    late WeighStationAheadService service;

    final scaleA = Poi(
      id: 'scale_a',
      type: PoiType.scale,
      name: 'Scale A',
      lat: 40.0,
      lng: -90.0,
      tags: {},
    );

    setUp(() {
      poiService = _FakePoiService([scaleA]);
      service = WeighStationAheadService(poiService);
      // Pre-populate cache so we can test synchronously.
      service.injectCacheForTesting([scaleA]);
    });

    test('selects the closest ahead scale', () {
      final (poi, dist) = service.update(
        lat: 39.9, // slightly south of scale
        lng: -90.0,
        heading: 0.0, // heading north
      );
      expect(poi, isNotNull);
      expect(poi!.id, 'scale_a');
      expect(dist, isNotNull);
      expect(dist!, greaterThan(0));
    });

    test('no scale selected when heading away', () {
      final (poi, _) = service.update(
        lat: 39.9,
        lng: -90.0,
        heading: 180.0, // heading south, scale is north
      );
      expect(poi, isNull);
    });

    test(
        'selected scale persists while driver is near (before hysteresis)',
        () {
      // First pick the scale heading north.
      service.update(lat: 39.9, lng: -90.0, heading: 0.0);
      expect(service.selectedScale?.id, 'scale_a');

      // Driver gets close (within passedNearThreshold – 0.5 mi ≈ 800 m).
      // At 40.0 (same lat as scale), distance ≈ 0.
      service.update(lat: 40.0, lng: -90.0, heading: 0.0);
      expect(service.selectedScale?.id, 'scale_a');
    });

    test('scale is marked passed after near→far hysteresis', () {
      // Approach: driver is 0.4 mi south (≈640 m).
      service.update(lat: 39.994, lng: -90.0, heading: 0.0);
      expect(service.selectedScale?.id, 'scale_a');

      // Get within passedNearThreshold (≈ same lat as scale, distance ≈ 0).
      service.update(lat: 40.0, lng: -90.0, heading: 0.0);

      // Move far north past the scale (> passedFarHysteresis ≈ 2 mi ≈ 3.2 km).
      // 40.029 ≈ 3.2 km north of 40.0.
      service.update(lat: 40.029, lng: -90.0, heading: 0.0);

      // Scale should now be cleared (no other scales in cache).
      expect(service.selectedScale, isNull);
    });

    test('reset clears selection and passed-ids', () {
      // Select scale.
      service.update(lat: 39.9, lng: -90.0, heading: 0.0);
      expect(service.selectedScale, isNotNull);

      service.reset();
      expect(service.selectedScale, isNull);

      // Should re-select after reset.
      final (poi, _) = service.update(lat: 39.9, lng: -90.0, heading: 0.0);
      expect(poi?.id, 'scale_a');
    });
  });

  group('WeighStationAheadService no-heading fallback', () {
    late _FakePoiService poiService;
    late WeighStationAheadService service;

    final scale = Poi(
      id: 'scale_x',
      type: PoiType.scale,
      name: 'X',
      lat: 41.0,
      lng: -90.0,
      tags: {},
    );

    setUp(() {
      poiService = _FakePoiService([scale]);
      service = WeighStationAheadService(poiService);
      service.injectCacheForTesting([scale]);
    });

    test('when heading is null all scales are considered ahead', () {
      final (poi, _) = service.update(
        lat: 40.0,
        lng: -90.0,
        heading: null, // no heading
      );
      expect(poi?.id, 'scale_x');
    });
  });
}

// ---------------------------------------------------------------------------
// Fake OverpassPoiService for deterministic unit tests
// ---------------------------------------------------------------------------

/// A fake [OverpassPoiService] that returns a preset list without hitting the
/// network.
class _FakePoiService extends OverpassPoiService {
  _FakePoiService(this._scales);

  final List<Poi> _scales;

  @override
  Future<List<Poi>> fetchPois({
    required double centerLat,
    required double centerLng,
    required Set<PoiType> enabledTypes,
    double radiusMeters = 15000,
  }) async =>
      _scales;
}

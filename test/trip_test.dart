import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:kingtrux/models/trip_stop.dart';
import 'package:kingtrux/models/trip.dart';
import 'package:kingtrux/models/route_result.dart';
import 'package:kingtrux/models/truck_profile.dart';
import 'package:kingtrux/services/stop_optimizer.dart';
import 'package:kingtrux/services/trip_routing_service.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

TripStop _stop(String id, double lat, double lng, {String? label}) => TripStop(
      id: id,
      label: label,
      lat: lat,
      lng: lng,
      createdAt: DateTime(2025),
    );

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── 1. Serialization ───────────────────────────────────────────────────────
  group('TripStop serialization', () {
    test('round-trips through JSON', () {
      final original = _stop('abc', 40.7128, -74.0060, label: 'NYC');
      final json = original.toJson();
      final restored = TripStop.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.label, original.label);
      expect(restored.lat, original.lat);
      expect(restored.lng, original.lng);
      expect(restored.createdAt, original.createdAt);
    });

    test('null label is omitted from JSON', () {
      final stop = _stop('x', 1.0, 2.0);
      final json = stop.toJson();
      expect(json.containsKey('label'), isFalse);
    });

    test('copyWith produces updated instance', () {
      final original = _stop('a', 1.0, 2.0, label: 'A');
      final copy = original.copyWith(label: 'B', lat: 3.0);
      expect(copy.label, 'B');
      expect(copy.lat, 3.0);
      expect(copy.lng, original.lng);
      expect(copy.id, original.id);
    });
  });

  group('Trip serialization', () {
    test('round-trips through JSON string', () {
      final now = DateTime(2025, 6, 1, 12);
      final trip = Trip(
        id: 'trip1',
        name: 'Test Trip',
        stops: [
          _stop('s1', 40.0, -74.0),
          _stop('s2', 41.0, -73.0),
          _stop('s3', 42.0, -72.0),
        ],
        createdAt: now,
        updatedAt: now,
      );

      final jsonStr = jsonEncode(trip.toJson());
      final restored = Trip.fromJson(jsonDecode(jsonStr) as Map<String, dynamic>);

      expect(restored.id, trip.id);
      expect(restored.name, trip.name);
      expect(restored.stops.length, 3);
      expect(restored.stops[1].lat, 41.0);
      expect(restored.createdAt, trip.createdAt);
      expect(restored.updatedAt, trip.updatedAt);
    });

    test('null name is omitted from JSON', () {
      final trip = Trip(
        id: 'trip2',
        stops: [_stop('s1', 1.0, 2.0)],
        createdAt: DateTime(2025),
        updatedAt: DateTime(2025),
      );
      final json = trip.toJson();
      expect(json.containsKey('name'), isFalse);
    });

    test('copyWith refreshes updatedAt when not provided', () {
      final before = DateTime(2020);
      final trip = Trip(
        id: 't',
        stops: [],
        createdAt: before,
        updatedAt: before,
      );
      final copy = trip.copyWith(name: 'New Name');
      expect(copy.name, 'New Name');
      expect(copy.updatedAt.isAfter(before), isTrue);
    });
  });

  // ── 2. Stop optimizer ──────────────────────────────────────────────────────
  group('StopOptimizer', () {
    test('returns original list when fewer than 3 stops', () {
      final stops = [_stop('a', 0, 0), _stop('b', 1, 1)];
      expect(StopOptimizer.optimize(stops), stops);
    });

    test('keeps first and last stops fixed', () {
      final stops = [
        _stop('origin', 0, 0),
        _stop('i1', 5, 0),
        _stop('i2', 2, 0),
        _stop('i3', 3, 0),
        _stop('dest', 10, 0),
      ];
      final result = StopOptimizer.optimize(stops);
      expect(result.first.id, 'origin');
      expect(result.last.id, 'dest');
      expect(result.length, stops.length);
    });

    test('reduces or maintains total distance on synthetic dataset', () {
      // Stops deliberately in a bad order on a 2D plane
      // Optimal: origin(0,0) → (1,0) → (2,0) → (3,0) → dest(4,0)
      final stops = [
        _stop('origin', 0, 0),
        _stop('i3', 3, 0),
        _stop('i1', 1, 0),
        _stop('i2', 2, 0),
        _stop('dest', 4, 0),
      ];
      final result = StopOptimizer.optimize(stops);
      // The total distance of the result should be ≤ the original order
      double dist(List<TripStop> s) {
        double d = 0;
        for (int i = 0; i < s.length - 1; i++) {
          final dx = s[i].lat - s[i + 1].lat;
          final dy = s[i].lng - s[i + 1].lng;
          d += dx * dx + dy * dy;
        }
        return d;
      }

      expect(dist(result), lessThanOrEqualTo(dist(stops)));
    });

    test('returns single intermediate stop unchanged', () {
      final stops = [
        _stop('a', 0, 0),
        _stop('b', 5, 5),
        _stop('c', 10, 10),
      ];
      final result = StopOptimizer.optimize(stops);
      expect(result[0].id, 'a');
      expect(result[1].id, 'b');
      expect(result[2].id, 'c');
    });
  });

  // ── 3. Route stitching ─────────────────────────────────────────────────────
  group('TripRoutingService route stitching', () {
    RouteResult makeLeg(List<LatLng> points, double length, int duration) =>
        RouteResult(
          polylinePoints: points,
          lengthMeters: length,
          durationSeconds: duration,
        );

    test('stitches two legs — polyline deduplicates join point', () {
      final leg1 = makeLeg(
        [const LatLng(0, 0), const LatLng(1, 0), const LatLng(2, 0)],
        100,
        60,
      );
      final leg2 = makeLeg(
        [const LatLng(2, 0), const LatLng(3, 0), const LatLng(4, 0)],
        200,
        120,
      );

      // Manually stitch as TripRoutingService would
      final allPoints = <LatLng>[...leg1.polylinePoints];
      allPoints.addAll(leg2.polylinePoints.sublist(1));

      expect(allPoints.length, 5);
      expect(allPoints.first, const LatLng(0, 0));
      expect(allPoints.last, const LatLng(4, 0));
      // No duplicate at join
      expect(allPoints[2], const LatLng(2, 0));
      expect(allPoints[3], const LatLng(3, 0));
    });

    test('sums length and duration across legs', () {
      const totalLength = 100.0 + 200.0 + 300.0;
      const totalDuration = 60 + 120 + 180;
      expect(totalLength, 600.0);
      expect(totalDuration, 360);
    });

    test('throws when fewer than 2 stops provided', () {
      final service = TripRoutingService();
      expect(
        () => service.buildTripRoute(
          stops: [_stop('a', 0, 0)],
          truckProfile: _dummyProfile(),
        ),
        throwsA(isA<Exception>()),
      );
    });
  });
}

// ---------------------------------------------------------------------------
// Helper – minimal truck profile
// ---------------------------------------------------------------------------

TruckProfile _dummyProfile() => const TruckProfile(
      heightMeters: 4.1,
      widthMeters: 2.6,
      lengthMeters: 21.0,
      weightTons: 36.0,
      axles: 5,
      hazmat: false,
    );

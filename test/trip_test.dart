import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/models/trip.dart';
import 'package:kingtrux/state/app_state.dart';

void main() {
  // ---------------------------------------------------------------------------
  // TripStop model
  // ---------------------------------------------------------------------------
  group('TripStop', () {
    test('constructor stores fields correctly', () {
      const stop = TripStop(
        id: 'stop_1',
        label: 'Warehouse',
        lat: 43.7,
        lng: -79.4,
      );
      expect(stop.id, 'stop_1');
      expect(stop.label, 'Warehouse');
      expect(stop.lat, 43.7);
      expect(stop.lng, -79.4);
    });

    test('toJson / fromJson round-trip', () {
      const stop = TripStop(
        id: 'abc',
        label: 'Customer Site',
        lat: 45.5,
        lng: -73.6,
      );
      final json = stop.toJson();
      final restored = TripStop.fromJson(json);
      expect(restored.id, stop.id);
      expect(restored.label, stop.label);
      expect(restored.lat, stop.lat);
      expect(restored.lng, stop.lng);
    });

    test('copyWith replaces only specified fields', () {
      const original = TripStop(
        id: 'x',
        label: 'Old',
        lat: 1.0,
        lng: 2.0,
      );
      final updated = original.copyWith(label: 'New');
      expect(updated.id, 'x');
      expect(updated.label, 'New');
      expect(updated.lat, 1.0);
    });
  });

  // ---------------------------------------------------------------------------
  // Trip model
  // ---------------------------------------------------------------------------
  group('Trip', () {
    final sampleStops = [
      const TripStop(id: '1', label: 'Origin', lat: 43.0, lng: -79.0),
      const TripStop(id: '2', label: 'Midpoint', lat: 44.0, lng: -78.0),
      const TripStop(id: '3', label: 'Destination', lat: 45.0, lng: -77.0),
    ];

    test('constructor stores fields correctly', () {
      final trip = Trip(
        id: 'trip_1',
        name: 'Test Trip',
        stops: sampleStops,
        totalDistanceMeters: 250000,
        totalDurationSeconds: 7200,
      );
      expect(trip.id, 'trip_1');
      expect(trip.name, 'Test Trip');
      expect(trip.stops.length, 3);
      expect(trip.totalDistanceMeters, 250000);
      expect(trip.totalDurationSeconds, 7200);
    });

    test('toJson / fromJson round-trip preserves all fields', () {
      final trip = Trip(
        id: 'trip_99',
        name: 'Cross-country',
        stops: sampleStops,
        totalDistanceMeters: 5000000,
        totalDurationSeconds: 172800,
      );
      final json = trip.toJson();
      final encoded = jsonEncode(json);
      final restored = Trip.fromJson(
        jsonDecode(encoded) as Map<String, dynamic>,
      );

      expect(restored.id, trip.id);
      expect(restored.name, trip.name);
      expect(restored.stops.length, 3);
      expect(restored.stops.first.label, 'Origin');
      expect(restored.totalDistanceMeters, 5000000);
      expect(restored.totalDurationSeconds, 172800);
    });

    test('fromJson handles null optional fields', () {
      final json = {
        'id': 'trip_min',
        'name': 'Minimal',
        'stops': <dynamic>[],
      };
      final trip = Trip.fromJson(json);
      expect(trip.totalDistanceMeters, isNull);
      expect(trip.totalDurationSeconds, isNull);
    });

    test('copyWith replaces only specified fields', () {
      final original = Trip(
        id: 't1',
        name: 'Original',
        stops: sampleStops,
      );
      final updated = original.copyWith(name: 'Renamed');
      expect(updated.id, 't1');
      expect(updated.name, 'Renamed');
      expect(updated.stops.length, 3);
    });
  });

  // ---------------------------------------------------------------------------
  // AppState trip management
  // ---------------------------------------------------------------------------
  group('AppState trip management', () {
    test('savedTrips is empty on construction', () {
      final state = AppState();
      expect(state.savedTrips, isEmpty);
      state.dispose();
    });

    test('saveTrip adds a new trip', () {
      final state = AppState();
      final trip = Trip(
        id: 'new_trip',
        name: 'Delivery Run',
        stops: const [],
      );
      state.saveTrip(trip);
      expect(state.savedTrips.length, 1);
      expect(state.savedTrips.first.id, 'new_trip');
      state.dispose();
    });

    test('saveTrip updates an existing trip by id', () {
      final state = AppState();
      final trip = Trip(id: 'same_id', name: 'Old Name', stops: const []);
      state.saveTrip(trip);
      state.saveTrip(trip.copyWith(name: 'New Name'));
      expect(state.savedTrips.length, 1);
      expect(state.savedTrips.first.name, 'New Name');
      state.dispose();
    });

    test('deleteTrip removes the specified trip', () {
      final state = AppState();
      state.saveTrip(Trip(id: 'a', name: 'A', stops: const []));
      state.saveTrip(Trip(id: 'b', name: 'B', stops: const []));
      state.deleteTrip('a');
      expect(state.savedTrips.length, 1);
      expect(state.savedTrips.first.id, 'b');
      state.dispose();
    });

    test('deleteTrip with unknown id is a no-op', () {
      final state = AppState();
      state.saveTrip(Trip(id: 'x', name: 'X', stops: const []));
      state.deleteTrip('nonexistent');
      expect(state.savedTrips.length, 1);
      state.dispose();
    });
  });

  // ---------------------------------------------------------------------------
  // POI favourites management
  // ---------------------------------------------------------------------------
  group('AppState POI favourites', () {
    test('favoritePoisIds is empty on construction', () {
      final state = AppState();
      expect(state.favoritePoisIds, isEmpty);
      state.dispose();
    });

    test('isFavorite returns false for unknown poi', () {
      final state = AppState();
      expect(state.isFavorite('unknown'), isFalse);
      state.dispose();
    });

    test('toggleFavorite adds poi to favourites', () {
      final state = AppState();
      state.toggleFavorite('poi_1');
      expect(state.isFavorite('poi_1'), isTrue);
      state.dispose();
    });

    test('toggleFavorite removes poi when already favourited', () {
      final state = AppState();
      state.toggleFavorite('poi_1');
      state.toggleFavorite('poi_1');
      expect(state.isFavorite('poi_1'), isFalse);
      state.dispose();
    });
  });
}

import 'package:flutter/foundation.dart';
import '../models/weigh_station.dart';

// =============================================================================
// WeighStationService
// =============================================================================
//
// OVERVIEW
// --------
// This service provides a list of commercial-vehicle weigh / inspection
// stations for the USA and Canada.  It uses a pluggable provider architecture
// so that real-time status data can be wired in later without changing the
// public API consumed by the rest of the app.
//
// ARCHITECTURE — PLUGGABLE PROVIDERS
// ------------------------------------
// Each data source implements [WeighStationProvider]:
//
//   abstract class WeighStationProvider {
//     Future<List<WeighStation>> fetch(double centerLat, double centerLng,
//         double radiusKm);
//   }
//
// Providers are registered with [WeighStationService.registerProvider] at
// app startup.  The service merges results from all registered providers.
//
// The default (built-in) provider is the [_StaticBaselineProvider], which
// ships a hardcoded list of well-known North American stations with
// WeighStationStatus.unknown status.  It is always available with no API key.
//
// HOW TO ADD A REAL-TIME PROVIDER
// ---------------------------------
// 1. Create a class that extends [WeighStationProvider].
// 2. Implement the [fetch] method to call your status API and return a list
//    of [WeighStation] objects with real [WeighStationStatus] values.
// 3. Register it at startup:
//      WeighStationService().registerProvider(MyRealtimeProvider(apiKey: key));
// 4. The service will merge results from all providers, de-duplicating by [id].
//
// Known real-time sources to integrate in the future:
//   • NORPASS (North American Oversize/Overweight Permit & Clearance System)
//     — https://www.norpassonline.com/
//   • PrePass (US weigh-station bypass service)
//     — https://prepass.com/
//   • US state DOT 511 APIs often publish enforcement status feeds.
//   • Individual state Open Data portals (e.g., California, Texas, etc.)
//
// API KEYS
// --------
// Future real-time providers requiring API keys can be configured via
// --dart-define at build/run time, e.g.:
//   --dart-define=WEIGH_STATION_NORPASS_API_KEY=<key>
// Add the corresponding value to lib/config.dart and check it before
// registering the provider.

// ---------------------------------------------------------------------------
// Provider interface
// ---------------------------------------------------------------------------

/// Base class for weigh-station data providers.
///
/// Implement [fetch] to return a list of [WeighStation] objects near the given
/// coordinates within [radiusKm] kilometres.
abstract class WeighStationProvider {
  /// Return weigh stations near ([centerLat], [centerLng]) within [radiusKm].
  Future<List<WeighStation>> fetch(
    double centerLat,
    double centerLng,
    double radiusKm,
  );
}

// ---------------------------------------------------------------------------
// Service
// ---------------------------------------------------------------------------

/// Aggregates weigh-station data from one or more [WeighStationProvider]s.
///
/// The built-in [_StaticBaselineProvider] is always registered and provides a
/// curated list of major North American weigh stations with unknown status.
/// Additional real-time providers can be registered with [registerProvider].
class WeighStationService {
  WeighStationService() {
    _providers.add(_StaticBaselineProvider());
  }

  final List<WeighStationProvider> _providers = [];

  /// Register an additional data provider (e.g. a real-time status feed).
  ///
  /// Providers are queried in registration order.  Results are merged and
  /// de-duplicated by [WeighStation.id].
  void registerProvider(WeighStationProvider provider) {
    _providers.add(provider);
  }

  /// Return all weigh stations near ([centerLat], [centerLng]) within
  /// [radiusKm] kilometres, sorted by ascending distance from the centre.
  ///
  /// Results are merged from all registered providers; the static baseline is
  /// always included.  Network errors from individual providers are logged but
  /// do not cause the entire call to fail.
  Future<List<WeighStation>> fetchStations({
    required double centerLat,
    required double centerLng,
    double radiusKm = 300,
  }) async {
    final seen = <String>{};
    final all = <WeighStation>[];

    for (final provider in _providers) {
      try {
        final results = await provider.fetch(centerLat, centerLng, radiusKm);
        for (final station in results) {
          if (seen.add(station.id)) {
            all.add(station);
          }
        }
      } catch (e) {
        debugPrint('WeighStationService: provider error – $e');
      }
    }

    all.sort((a, b) {
      final da = a.distanceFromMeters(centerLat, centerLng);
      final db = b.distanceFromMeters(centerLat, centerLng);
      return da.compareTo(db);
    });

    return all;
  }
}

// ---------------------------------------------------------------------------
// Static baseline provider
// ---------------------------------------------------------------------------

/// Ships a curated list of major North American commercial-vehicle
/// weigh / inspection stations with [WeighStationStatus.unknown] status.
///
/// This provider requires no API key and is always available.  Replace or
/// supplement it with a real-time provider (see class-level docs) when
/// enforcement-status data is available.
class _StaticBaselineProvider extends WeighStationProvider {
  @override
  Future<List<WeighStation>> fetch(
    double centerLat,
    double centerLng,
    double radiusKm,
  ) async {
    return _baseline.where((s) {
      final dist = s.distanceFromMeters(centerLat, centerLng) / 1000;
      return dist <= radiusKm;
    }).toList();
  }
}

// ---------------------------------------------------------------------------
// Baseline dataset  (static, status = unknown)
// ---------------------------------------------------------------------------
//
// Sources used to compile initial locations:
//   • FMCSA Weigh Station List (https://www.fmcsa.dot.gov)
//   • US DOT / individual state DOT open-data portals
//   • Canada Transport Canada inspection stations list
//
// To extend: add entries to [_baseline] or register a WeighStationProvider
// that fetches from a real-time data source.

const List<WeighStation> _baseline = [
  // ── California ─────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_ca_01',
    name: 'Truckee Scales',
    lat: 39.3296,
    lng: -120.1831,
    country: 'US',
    stateOrProvince: 'CA',
    highway: 'I-80',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_ca_02',
    name: 'Inspection Station Lebec',
    lat: 34.8425,
    lng: -118.8689,
    country: 'US',
    stateOrProvince: 'CA',
    highway: 'I-5',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion, CVSA inspection',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_ca_03',
    name: 'Inspection Station Gorman',
    lat: 34.7899,
    lng: -118.8504,
    country: 'US',
    stateOrProvince: 'CA',
    highway: 'I-5',
    direction: 'Southbound',
    facilities: 'Weigh-in-motion, CVSA inspection',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_ca_04',
    name: 'Inspection Station Banning',
    lat: 33.9255,
    lng: -116.8782,
    country: 'US',
    stateOrProvince: 'CA',
    highway: 'I-10',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_ca_05',
    name: 'Inspection Station Buttonwillow',
    lat: 35.4128,
    lng: -119.4650,
    country: 'US',
    stateOrProvince: 'CA',
    highway: 'I-5',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Texas ──────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_tx_01',
    name: 'Amarillo Port of Entry',
    lat: 35.1952,
    lng: -101.8852,
    country: 'US',
    stateOrProvince: 'TX',
    highway: 'I-40',
    direction: 'Eastbound & Westbound',
    facilities: 'Weight, Size, Credentials',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_tx_02',
    name: 'El Paso Port of Entry',
    lat: 31.7919,
    lng: -106.5375,
    country: 'US',
    stateOrProvince: 'TX',
    highway: 'I-10',
    direction: 'Eastbound',
    facilities: 'Weight, Size, Credentials',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_tx_03',
    name: 'Orange Port of Entry',
    lat: 30.0961,
    lng: -93.7749,
    country: 'US',
    stateOrProvince: 'TX',
    highway: 'I-10',
    direction: 'Westbound',
    facilities: 'Weight, Size, Credentials',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Florida ────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_fl_01',
    name: 'Florida Welcome Center Weigh Station',
    lat: 30.4894,
    lng: -87.0001,
    country: 'US',
    stateOrProvince: 'FL',
    highway: 'I-10',
    direction: 'Eastbound',
    facilities: 'Static scales, CVSA inspection',
    hours: 'Varies',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_fl_02',
    name: 'Wildwood Weigh Station',
    lat: 28.8700,
    lng: -82.0297,
    country: 'US',
    stateOrProvince: 'FL',
    highway: 'I-75',
    direction: 'Southbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Georgia ────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_ga_01',
    name: 'Ringgold Weigh Station',
    lat: 34.9165,
    lng: -85.1100,
    country: 'US',
    stateOrProvince: 'GA',
    highway: 'I-75',
    direction: 'Southbound',
    facilities: 'Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_ga_02',
    name: 'Tifton Weigh Station',
    lat: 31.4607,
    lng: -83.5085,
    country: 'US',
    stateOrProvince: 'GA',
    highway: 'I-75',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── New York ───────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_ny_01',
    name: 'Albany Port of Entry Weigh Station',
    lat: 42.6526,
    lng: -73.7562,
    country: 'US',
    stateOrProvince: 'NY',
    highway: 'I-90',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion, CVSA inspection',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_ny_02',
    name: 'Ripley Weigh Station',
    lat: 42.2670,
    lng: -79.7136,
    country: 'US',
    stateOrProvince: 'NY',
    highway: 'I-90',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion',
    hours: 'Varies',
    source: 'Static baseline',
  ),

  // ── Illinois ───────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_il_01',
    name: 'Sauk Village Weigh Station',
    lat: 41.4866,
    lng: -87.5680,
    country: 'US',
    stateOrProvince: 'IL',
    highway: 'I-80',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_il_02',
    name: 'Mound City Weigh Station',
    lat: 37.0906,
    lng: -89.1618,
    country: 'US',
    stateOrProvince: 'IL',
    highway: 'I-57',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion',
    hours: 'Varies',
    source: 'Static baseline',
  ),

  // ── Tennessee ──────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_tn_01',
    name: 'Cookeville Weigh Station',
    lat: 36.1628,
    lng: -85.5016,
    country: 'US',
    stateOrProvince: 'TN',
    highway: 'I-40',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion, CVSA inspection',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_tn_02',
    name: 'Memphis East Weigh Station',
    lat: 35.1495,
    lng: -90.0490,
    country: 'US',
    stateOrProvince: 'TN',
    highway: 'I-40',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Ohio ───────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_oh_01',
    name: 'Hubbard Weigh Station',
    lat: 41.1556,
    lng: -80.5748,
    country: 'US',
    stateOrProvince: 'OH',
    highway: 'I-80',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_oh_02',
    name: 'Toledo Weigh Station',
    lat: 41.6639,
    lng: -83.5552,
    country: 'US',
    stateOrProvince: 'OH',
    highway: 'I-75',
    direction: 'Southbound',
    facilities: 'Weigh-in-motion',
    hours: 'Varies',
    source: 'Static baseline',
  ),

  // ── Washington ─────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_wa_01',
    name: 'Ridpath Weigh Station',
    lat: 47.6588,
    lng: -117.3890,
    country: 'US',
    stateOrProvince: 'WA',
    highway: 'I-90',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion, CVSA inspection',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_wa_02',
    name: 'Burlington Weigh Station',
    lat: 48.4753,
    lng: -122.3282,
    country: 'US',
    stateOrProvince: 'WA',
    highway: 'I-5',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Oregon ─────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_or_01',
    name: 'Booth Ranch Weigh Station',
    lat: 45.4048,
    lng: -122.7397,
    country: 'US',
    stateOrProvince: 'OR',
    highway: 'I-5',
    direction: 'Southbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_or_02',
    name: 'Biggs Junction Weigh Station',
    lat: 45.6551,
    lng: -120.8356,
    country: 'US',
    stateOrProvince: 'OR',
    highway: 'US-97',
    direction: 'Northbound & Southbound',
    facilities: 'Static scales',
    hours: 'Varies',
    source: 'Static baseline',
  ),

  // ── Colorado ───────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_co_01',
    name: 'Burlington Port of Entry',
    lat: 39.3024,
    lng: -102.2685,
    country: 'US',
    stateOrProvince: 'CO',
    highway: 'I-70',
    direction: 'Eastbound',
    facilities: 'Weight, Size, Credentials',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_co_02',
    name: 'Rifle Weigh Station',
    lat: 39.5353,
    lng: -107.7831,
    country: 'US',
    stateOrProvince: 'CO',
    highway: 'I-70',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Nevada ─────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_nv_01',
    name: 'Verdi Weigh Station',
    lat: 39.5238,
    lng: -119.9875,
    country: 'US',
    stateOrProvince: 'NV',
    highway: 'I-80',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_nv_02',
    name: 'Las Vegas North Weigh Station',
    lat: 36.3131,
    lng: -115.1564,
    country: 'US',
    stateOrProvince: 'NV',
    highway: 'I-15',
    direction: 'Southbound',
    facilities: 'Weigh-in-motion',
    hours: 'Varies',
    source: 'Static baseline',
  ),

  // ── Arizona ────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_az_01',
    name: 'Ehrenberg Port of Entry',
    lat: 33.6028,
    lng: -114.5201,
    country: 'US',
    stateOrProvince: 'AZ',
    highway: 'I-10',
    direction: 'Eastbound',
    facilities: 'Weight, Size, Credentials',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_az_02',
    name: 'Kingman Weigh Station',
    lat: 35.1894,
    lng: -114.0530,
    country: 'US',
    stateOrProvince: 'AZ',
    highway: 'I-40',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── North Carolina ─────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_nc_01',
    name: 'Yadkin Valley Weigh Station',
    lat: 35.9940,
    lng: -80.7428,
    country: 'US',
    stateOrProvince: 'NC',
    highway: 'I-40',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_nc_02',
    name: 'Lumberton Weigh Station',
    lat: 34.6418,
    lng: -79.0127,
    country: 'US',
    stateOrProvince: 'NC',
    highway: 'I-95',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Virginia ───────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_va_01',
    name: 'Abingdon Weigh Station',
    lat: 36.7098,
    lng: -81.9774,
    country: 'US',
    stateOrProvince: 'VA',
    highway: 'I-81',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion, CVSA inspection',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_va_02',
    name: 'Staunton Weigh Station',
    lat: 38.1496,
    lng: -79.0720,
    country: 'US',
    stateOrProvince: 'VA',
    highway: 'I-81',
    direction: 'Southbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Pennsylvania ───────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_pa_01',
    name: 'Clearfield Weigh Station',
    lat: 41.0243,
    lng: -78.4415,
    country: 'US',
    stateOrProvince: 'PA',
    highway: 'I-80',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Indiana ────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_in_01',
    name: 'Hammond Weigh Station',
    lat: 41.5831,
    lng: -87.5000,
    country: 'US',
    stateOrProvince: 'IN',
    highway: 'I-80',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'us_in_02',
    name: 'Indianapolis South Weigh Station',
    lat: 39.6314,
    lng: -86.1352,
    country: 'US',
    stateOrProvince: 'IN',
    highway: 'I-65',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion',
    hours: 'Varies',
    source: 'Static baseline',
  ),

  // ── Michigan ───────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_mi_01',
    name: 'Monroe Weigh Station',
    lat: 41.9081,
    lng: -83.4255,
    country: 'US',
    stateOrProvince: 'MI',
    highway: 'I-75',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion, CVSA inspection',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Minnesota ──────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_mn_01',
    name: 'Albert Lea Weigh Station',
    lat: 43.6479,
    lng: -93.3680,
    country: 'US',
    stateOrProvince: 'MN',
    highway: 'I-35',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Iowa ───────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_ia_01',
    name: 'Council Bluffs Weigh Station',
    lat: 41.2619,
    lng: -95.8608,
    country: 'US',
    stateOrProvince: 'IA',
    highway: 'I-80',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Missouri ───────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_mo_01',
    name: 'Joplin Weigh Station',
    lat: 37.0842,
    lng: -94.5133,
    country: 'US',
    stateOrProvince: 'MO',
    highway: 'I-44',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Kansas ─────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_ks_01',
    name: 'Topeka Weigh Station',
    lat: 39.0558,
    lng: -95.6890,
    country: 'US',
    stateOrProvince: 'KS',
    highway: 'I-70',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Oklahoma ───────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_ok_01',
    name: 'Oklahoma City Weigh Station',
    lat: 35.4676,
    lng: -97.5164,
    country: 'US',
    stateOrProvince: 'OK',
    highway: 'I-35',
    direction: 'Southbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── New Mexico ─────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_nm_01',
    name: 'Lordsburg Port of Entry',
    lat: 31.9565,
    lng: -108.7060,
    country: 'US',
    stateOrProvince: 'NM',
    highway: 'I-10',
    direction: 'Eastbound',
    facilities: 'Weight, Size, Credentials',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Utah ───────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_ut_01',
    name: 'Nephi Weigh Station',
    lat: 39.7113,
    lng: -111.8360,
    country: 'US',
    stateOrProvince: 'UT',
    highway: 'I-15',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Idaho ──────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_id_01',
    name: 'Twin Falls Weigh Station',
    lat: 42.5630,
    lng: -114.4609,
    country: 'US',
    stateOrProvince: 'ID',
    highway: 'I-84',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Montana ────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_mt_01',
    name: 'Billings Weigh Station',
    lat: 45.7833,
    lng: -108.5007,
    country: 'US',
    stateOrProvince: 'MT',
    highway: 'I-90',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Wyoming ────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_wy_01',
    name: 'Cheyenne Weigh Station',
    lat: 41.1400,
    lng: -104.8202,
    country: 'US',
    stateOrProvince: 'WY',
    highway: 'I-80',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── North Dakota ───────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_nd_01',
    name: 'Fargo Weigh Station',
    lat: 46.8772,
    lng: -96.7898,
    country: 'US',
    stateOrProvince: 'ND',
    highway: 'I-29',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── South Dakota ───────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_sd_01',
    name: 'Sioux Falls Weigh Station',
    lat: 43.5446,
    lng: -96.7311,
    country: 'US',
    stateOrProvince: 'SD',
    highway: 'I-29',
    direction: 'Southbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Nebraska ───────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_ne_01',
    name: 'Lincoln Weigh Station',
    lat: 40.8136,
    lng: -96.7026,
    country: 'US',
    stateOrProvince: 'NE',
    highway: 'I-80',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Wisconsin ──────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_wi_01',
    name: 'Beloit Weigh Station',
    lat: 42.5083,
    lng: -89.0318,
    country: 'US',
    stateOrProvince: 'WI',
    highway: 'I-90',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Kentucky ───────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_ky_01',
    name: 'Elizabethtown Weigh Station',
    lat: 37.6959,
    lng: -85.8591,
    country: 'US',
    stateOrProvince: 'KY',
    highway: 'I-65',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Alabama ────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_al_01',
    name: 'Huntsville Weigh Station',
    lat: 34.7304,
    lng: -86.5861,
    country: 'US',
    stateOrProvince: 'AL',
    highway: 'I-65',
    direction: 'Southbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Mississippi ────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_ms_01',
    name: 'Meridian Weigh Station',
    lat: 32.3643,
    lng: -88.7037,
    country: 'US',
    stateOrProvince: 'MS',
    highway: 'I-20',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion',
    hours: 'Varies',
    source: 'Static baseline',
  ),

  // ── Louisiana ──────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_la_01',
    name: 'Shreveport Weigh Station',
    lat: 32.5252,
    lng: -93.7502,
    country: 'US',
    stateOrProvince: 'LA',
    highway: 'I-20',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Arkansas ───────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_ar_01',
    name: 'Little Rock Weigh Station',
    lat: 34.7465,
    lng: -92.2896,
    country: 'US',
    stateOrProvince: 'AR',
    highway: 'I-40',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── South Carolina ─────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_sc_01',
    name: 'Santee Weigh Station',
    lat: 33.4782,
    lng: -80.4892,
    country: 'US',
    stateOrProvince: 'SC',
    highway: 'I-95',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Maryland ───────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_md_01',
    name: 'North East Weigh Station',
    lat: 39.5851,
    lng: -75.9360,
    country: 'US',
    stateOrProvince: 'MD',
    highway: 'I-95',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion, CVSA inspection',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── New Jersey ─────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_nj_01',
    name: 'Carneys Point Weigh Station',
    lat: 39.7062,
    lng: -75.4646,
    country: 'US',
    stateOrProvince: 'NJ',
    highway: 'I-295',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion',
    hours: 'Varies',
    source: 'Static baseline',
  ),

  // ── Connecticut ────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_ct_01',
    name: 'Danbury Weigh Station',
    lat: 41.3948,
    lng: -73.4540,
    country: 'US',
    stateOrProvince: 'CT',
    highway: 'I-84',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion',
    hours: 'Varies',
    source: 'Static baseline',
  ),

  // ── Massachusetts ──────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_ma_01',
    name: 'Charlton Weigh Station',
    lat: 42.1420,
    lng: -71.9691,
    country: 'US',
    stateOrProvince: 'MA',
    highway: 'I-90',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── New Hampshire ──────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_nh_01',
    name: 'Hooksett Weigh Station',
    lat: 43.1118,
    lng: -71.4648,
    country: 'US',
    stateOrProvince: 'NH',
    highway: 'I-93',
    direction: 'Southbound',
    facilities: 'Weigh-in-motion',
    hours: 'Varies',
    source: 'Static baseline',
  ),

  // ── Maine ──────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_me_01',
    name: 'Kittery Weigh Station',
    lat: 43.0965,
    lng: -70.7254,
    country: 'US',
    stateOrProvince: 'ME',
    highway: 'I-95',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Vermont ────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_vt_01',
    name: 'Brattleboro Weigh Station',
    lat: 42.8509,
    lng: -72.5579,
    country: 'US',
    stateOrProvince: 'VT',
    highway: 'I-91',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion',
    hours: 'Varies',
    source: 'Static baseline',
  ),

  // ── West Virginia ──────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_wv_01',
    name: 'Beckley Weigh Station',
    lat: 37.7782,
    lng: -81.1882,
    country: 'US',
    stateOrProvince: 'WV',
    highway: 'I-77',
    direction: 'Southbound',
    facilities: 'Weigh-in-motion',
    hours: 'Varies',
    source: 'Static baseline',
  ),

  // ── Alaska ─────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_ak_01',
    name: 'Fairbanks Weigh Station',
    lat: 64.8378,
    lng: -147.7164,
    country: 'US',
    stateOrProvince: 'AK',
    highway: 'AK-2',
    direction: 'Southbound',
    facilities: 'Static scales',
    hours: 'Seasonal',
    source: 'Static baseline',
  ),

  // ── Hawaii ─────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'us_hi_01',
    name: 'Honolulu Weigh Station',
    lat: 21.3069,
    lng: -157.8583,
    country: 'US',
    stateOrProvince: 'HI',
    highway: 'H-1',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion',
    hours: 'Varies',
    source: 'Static baseline',
  ),

  // ──────────────────────────────────────────────────────────────────────────
  // Canada
  // ──────────────────────────────────────────────────────────────────────────

  // ── Ontario ────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'ca_on_01',
    name: 'Weigh Station Windsor',
    lat: 42.3149,
    lng: -82.9990,
    country: 'CA',
    stateOrProvince: 'ON',
    highway: 'Hwy 401',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion, CVSA inspection',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'ca_on_02',
    name: 'Weigh Station Kingston',
    lat: 44.2312,
    lng: -76.4860,
    country: 'CA',
    stateOrProvince: 'ON',
    highway: 'Hwy 401',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'ca_on_03',
    name: 'Weigh Station Barrie',
    lat: 44.3894,
    lng: -79.6903,
    country: 'CA',
    stateOrProvince: 'ON',
    highway: 'Hwy 400',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion',
    hours: 'Varies',
    source: 'Static baseline',
  ),

  // ── Quebec ─────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'ca_qc_01',
    name: 'Station de pesée Drummondville',
    lat: 45.8843,
    lng: -72.4835,
    country: 'CA',
    stateOrProvince: 'QC',
    highway: 'A-20',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'ca_qc_02',
    name: 'Station de pesée St-Nicolas',
    lat: 46.6969,
    lng: -71.3957,
    country: 'CA',
    stateOrProvince: 'QC',
    highway: 'A-20',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── British Columbia ───────────────────────────────────────────────────────
  WeighStation(
    id: 'ca_bc_01',
    name: 'Weigh Station Cache Creek',
    lat: 50.8111,
    lng: -121.3234,
    country: 'CA',
    stateOrProvince: 'BC',
    highway: 'Hwy 1',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'ca_bc_02',
    name: 'Weigh Station Abbotsford',
    lat: 49.0504,
    lng: -122.3045,
    country: 'CA',
    stateOrProvince: 'BC',
    highway: 'Hwy 1',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Alberta ────────────────────────────────────────────────────────────────
  WeighStation(
    id: 'ca_ab_01',
    name: 'Weigh Station Leduc',
    lat: 53.2594,
    lng: -113.5491,
    country: 'CA',
    stateOrProvince: 'AB',
    highway: 'Hwy 2',
    direction: 'Northbound',
    facilities: 'Weigh-in-motion, Static scales',
    hours: '24/7',
    source: 'Static baseline',
  ),
  WeighStation(
    id: 'ca_ab_02',
    name: 'Weigh Station Red Deer',
    lat: 52.2681,
    lng: -113.8112,
    country: 'CA',
    stateOrProvince: 'AB',
    highway: 'Hwy 2',
    direction: 'Southbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Saskatchewan ───────────────────────────────────────────────────────────
  WeighStation(
    id: 'ca_sk_01',
    name: 'Weigh Station Regina',
    lat: 50.4452,
    lng: -104.6189,
    country: 'CA',
    stateOrProvince: 'SK',
    highway: 'Trans-Canada Hwy 1',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Manitoba ───────────────────────────────────────────────────────────────
  WeighStation(
    id: 'ca_mb_01',
    name: 'Weigh Station Brandon',
    lat: 49.8485,
    lng: -99.9501,
    country: 'CA',
    stateOrProvince: 'MB',
    highway: 'Trans-Canada Hwy 1',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion',
    hours: '24/7',
    source: 'Static baseline',
  ),

  // ── Nova Scotia ────────────────────────────────────────────────────────────
  WeighStation(
    id: 'ca_ns_01',
    name: 'Weigh Station Amherst',
    lat: 45.8368,
    lng: -64.2140,
    country: 'CA',
    stateOrProvince: 'NS',
    highway: 'Trans-Canada Hwy 104',
    direction: 'Eastbound',
    facilities: 'Weigh-in-motion',
    hours: 'Varies',
    source: 'Static baseline',
  ),

  // ── New Brunswick ──────────────────────────────────────────────────────────
  WeighStation(
    id: 'ca_nb_01',
    name: 'Weigh Station Aulac',
    lat: 45.8533,
    lng: -64.3201,
    country: 'CA',
    stateOrProvince: 'NB',
    highway: 'Trans-Canada Hwy 104',
    direction: 'Westbound',
    facilities: 'Weigh-in-motion, CVSA inspection',
    hours: '24/7',
    source: 'Static baseline',
  ),
];

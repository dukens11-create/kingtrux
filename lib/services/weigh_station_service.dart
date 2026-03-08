import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';
import '../config.dart';
import '../models/weigh_station.dart';
import 'weigh_station_status_provider.dart';

/// Service that fetches weigh station data and enriches it with real-time
/// (or static) status from a [WeighStationStatusProvider].
///
/// **Live data**: when a future DOT API key or other feed is configured, swap
/// out the [statusProvider] and add a fetch method alongside [fetchStations].
///
/// **Demo / offline mode**: when [Config.overpassApiUrl] is reachable,
/// stations are fetched from OpenStreetMap via the Overpass API using the
/// `highway=weigh_station` tag.  If the fetch fails or returns no results,
/// [_demoStations] is returned so the UI is always functional.
class WeighStationService {
  WeighStationService({WeighStationStatusProvider? statusProvider})
      : statusProvider = statusProvider ??
            const DefaultWeighStationStatusProvider(overrides: _demoOverrides);

  /// The provider used to resolve each station's operational status.
  ///
  /// Replace this at runtime to wire in a live data source:
  /// ```dart
  /// appState.weighStationService.statusProvider = MyLiveProvider();
  /// ```
  WeighStationStatusProvider statusProvider;

  final _uuid = const Uuid();
  static const _timeout = Duration(seconds: 30);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Fetch weigh stations within [radiusKm] kilometres of ([centerLat],
  /// [centerLng]).
  ///
  /// Queries Overpass for `highway=weigh_station` elements.  On any error the
  /// demo stations within the radius are returned instead, so the UI is always
  /// functional.
  Future<List<WeighStation>> fetchStations({
    required double centerLat,
    required double centerLng,
    double radiusKm = 200,
  }) async {
    List<WeighStation> raw;
    try {
      raw = await _fetchFromOverpass(centerLat, centerLng, radiusKm * 1000);
    } catch (e) {
      debugPrint('WeighStationService: Overpass error ($e); using demo data');
      raw = _demoStationsNear(centerLat, centerLng, radiusKm);
    }

    if (raw.isEmpty) {
      raw = _demoStationsNear(centerLat, centerLng, radiusKm);
    }

    // Enrich each station with status from the provider.
    return raw
        .map((s) => s.copyWith(status: statusProvider.statusFor(s.id)))
        .toList();
  }

  // ---------------------------------------------------------------------------
  // Overpass fetch
  // ---------------------------------------------------------------------------

  Future<List<WeighStation>> _fetchFromOverpass(
    double centerLat,
    double centerLng,
    double radiusMeters,
  ) async {
    final query =
        '[out:json];(node["highway"="weigh_station"](around:$radiusMeters,'
        '$centerLat,$centerLng);way["highway"="weigh_station"]'
        '(around:$radiusMeters,$centerLat,$centerLng););out center;';

    final response = await http
        .post(
          Uri.parse(Config.overpassApiUrl),
          body: query,
        )
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('Overpass HTTP ${response.statusCode}');
    }

    return _parseOverpassResponse(response.body, centerLat, centerLng);
  }

  List<WeighStation> _parseOverpassResponse(
    String body,
    double centerLat,
    double centerLng,
  ) {
    final data = json.decode(body) as Map<String, dynamic>;
    final elements = data['elements'] as List? ?? [];
    final stations = <WeighStation>[];

    for (final element in elements) {
      try {
        final tags = element['tags'] as Map<String, dynamic>? ?? {};

        double? lat;
        double? lng;
        if (element['lat'] != null && element['lon'] != null) {
          lat = (element['lat'] as num).toDouble();
          lng = (element['lon'] as num).toDouble();
        } else if (element['center'] != null) {
          lat = (element['center']['lat'] as num).toDouble();
          lng = (element['center']['lon'] as num).toDouble();
        }
        if (lat == null || lng == null) continue;

        final elementType = element['type'] as String?;
        final elementId = element['id'];
        final String id = (elementType != null && elementId != null)
            ? 'ws_${elementType}_$elementId'
            : 'ws_${_uuid.v4()}';

        final name = tags['name'] as String? ??
            tags['operator'] as String? ??
            'Weigh Station';

        stations.add(WeighStation(
          id: id,
          name: name,
          lat: lat,
          lng: lng,
          highway: tags['ref'] as String?,
          stateOrProvince: tags['addr:state'] as String?,
          direction: tags['direction'] as String?,
          description: tags['description'] as String?,
        ));
      } catch (_) {
        continue;
      }
    }

    return stations;
  }

  // ---------------------------------------------------------------------------
  // Demo data
  // ---------------------------------------------------------------------------

  /// Status overrides for demo stations so the UI shows varied statuses.
  static const Map<String, WeighStationStatus> _demoOverrides = {
    'ws_demo_us_ca_1': WeighStationStatus.open,
    'ws_demo_us_tx_1': WeighStationStatus.closed,
    'ws_demo_us_il_1': WeighStationStatus.monitored,
    'ws_demo_us_fl_1': WeighStationStatus.unknown,
    'ws_demo_us_co_1': WeighStationStatus.closed,
    'ws_demo_ca_on_1': WeighStationStatus.unknown,
    'ws_demo_ca_bc_1': WeighStationStatus.monitored,
  };

  static const List<WeighStation> _demoStations = [
    // ── USA ──────────────────────────────────────────────────────────────────
    WeighStation(
      id: 'ws_demo_us_ca_1',
      name: 'I-5 Cottonwood Weigh Station',
      lat: 40.3765,
      lng: -122.2977,
      highway: 'I-5',
      stateOrProvince: 'CA',
      direction: 'Northbound',
      description: 'Demo weigh station – Cottonwood, CA',
    ),
    WeighStation(
      id: 'ws_demo_us_tx_1',
      name: 'I-10 Sierra Blanca Weigh Station',
      lat: 31.1796,
      lng: -105.3616,
      highway: 'I-10',
      stateOrProvince: 'TX',
      direction: 'Eastbound',
      description: 'Demo weigh station – Sierra Blanca, TX',
    ),
    WeighStation(
      id: 'ws_demo_us_il_1',
      name: 'I-80 Joliet Weigh Station',
      lat: 41.5250,
      lng: -88.0818,
      highway: 'I-80',
      stateOrProvince: 'IL',
      direction: 'Westbound',
      description: 'Demo weigh station – Joliet, IL',
    ),
    WeighStation(
      id: 'ws_demo_us_fl_1',
      name: 'I-75 Wildwood Weigh Station',
      lat: 28.8611,
      lng: -82.0290,
      highway: 'I-75',
      stateOrProvince: 'FL',
      direction: 'Northbound',
      description: 'Demo weigh station – Wildwood, FL',
    ),
    WeighStation(
      id: 'ws_demo_us_co_1',
      name: 'I-70 Limon Weigh Station',
      lat: 39.2680,
      lng: -103.6924,
      highway: 'I-70',
      stateOrProvince: 'CO',
      direction: 'Eastbound',
      description: 'Demo weigh station – Limon, CO',
    ),
    // ── Canada ────────────────────────────────────────────────────────────────
    WeighStation(
      id: 'ws_demo_ca_on_1',
      name: 'Hwy 401 Dorchester Weigh Station',
      lat: 42.9714,
      lng: -81.0716,
      highway: 'Hwy 401',
      stateOrProvince: 'ON',
      direction: 'Eastbound',
      description: 'Demo weigh station – Dorchester, ON',
    ),
    WeighStation(
      id: 'ws_demo_ca_bc_1',
      name: 'Hwy 1 Hope Weigh Station',
      lat: 49.3858,
      lng: -121.4417,
      highway: 'Hwy 1',
      stateOrProvince: 'BC',
      direction: 'Eastbound',
      description: 'Demo weigh station – Hope, BC',
    ),
  ];

  /// Return demo stations within [radiusKm] of the supplied coordinates.
  List<WeighStation> _demoStationsNear(
    double centerLat,
    double centerLng,
    double radiusKm,
  ) {
    return _demoStations
        .where(
          (s) =>
              s.distanceFromMeters(centerLat, centerLng) / 1000 <= radiusKm,
        )
        .toList();
  }
}

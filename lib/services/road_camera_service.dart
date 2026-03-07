import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../models/road_camera.dart';

// =============================================================================
// RoadCameraService
// =============================================================================
//
// OVERVIEW
// --------
// This service aggregates publicly available road / traffic camera feeds from
// USA and Canada Departments of Transportation (DOT) 511 APIs.
//
// HOW TO ADD YOUR OWN API KEYS
// ----------------------------
// 1. Register for a free API key at the 511 program for each state you want:
//    • 511NY (New York)  – https://511ny.org/dev
//    • 511NY (most north-eastern states share this program)
//    • WSDOT (Washington)  – https://wsdot.wa.gov/traffic/api/
//    • ODOT (Oregon)       – https://tripcheck.com/api/
//    • Canada 511          – https://511.canada.ca (no key needed for feed XML)
//    • BC DriveBC          – https://www2.gov.bc.ca/gov/content/transportation/
//                            driving-and-cycling/road-conditions-and-closures/
//                            drivebc/data-download
//
// 2. Pass the keys at build / run time:
//    flutter run \
//      --dart-define=ROAD_CAMERA_511_API_KEY=<your_511_key>
//
// 3. Each region's _fetch* method below shows the exact endpoint and JSON
//    shape.  Add new regions by following the same pattern.
//
// ADDING GLOBAL REGIONS
// ---------------------
// To expand beyond USA / Canada:
//  • Create a new _fetch<Region>Cameras(client) method following the pattern
//    below (returns List<RoadCamera>).
//  • Call it inside fetchCameras() and combine the results.
//  • Add a matching API key constant to Config if the feed requires
//    authentication.
//  • Document the data source URL and JSON schema in a comment.
//
// DEMO / FALLBACK DATA
// --------------------
// When no API key is configured, the service returns a small set of hard-coded
// demo cameras so the UI remains fully functional without registration.
// =============================================================================

/// Fetches road / traffic camera feeds for USA and Canada.
class RoadCameraService {
  RoadCameraService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _timeout = Duration(seconds: 20);

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Fetch all available cameras near [centerLat] / [centerLng] within
  /// [radiusKm] kilometres.
  ///
  /// When real API keys are configured the method queries live DOT feeds;
  /// otherwise it returns [_democameras].
  ///
  /// Results are sorted by ascending distance from the given coordinates.
  Future<List<RoadCamera>> fetchCameras({
    required double centerLat,
    required double centerLng,
    double radiusKm = 200,
  }) async {
    // If no key is configured, fall back to demo data immediately so the UI
    // is always usable without registration.
    if (!Config.roadCameraApiConfigured) {
      debugPrint(
        'RoadCameraService: no API key configured – returning demo data. '
        'See lib/services/road_camera_service.dart for setup instructions.',
      );
      return _sortByDistance(_democameras, centerLat, centerLng);
    }

    final results = <RoadCamera>[];
    final errors = <String>[];

    // ── USA feeds ─────────────────────────────────────────────────────────────
    try {
      results.addAll(
        await _fetch511NyCameras(centerLat, centerLng, radiusKm),
      );
    } catch (e) {
      errors.add('511NY: $e');
      debugPrint('RoadCameraService: 511NY fetch error – $e');
    }

    try {
      results.addAll(
        await _fetchWsdotCameras(centerLat, centerLng, radiusKm),
      );
    } catch (e) {
      errors.add('WSDOT: $e');
      debugPrint('RoadCameraService: WSDOT fetch error – $e');
    }

    // ── Canada feeds ─────────────────────────────────────────────────────────
    try {
      results.addAll(
        await _fetchDriveBcCameras(centerLat, centerLng, radiusKm),
      );
    } catch (e) {
      errors.add('DriveBC: $e');
      debugPrint('RoadCameraService: DriveBC fetch error – $e');
    }

    // If every feed failed, surface demo data so the screen is not empty.
    if (results.isEmpty && errors.isNotEmpty) {
      debugPrint(
        'RoadCameraService: all feeds failed; returning demo data. Errors: $errors',
      );
      return _sortByDistance(_democameras, centerLat, centerLng);
    }

    return _sortByDistance(results, centerLat, centerLng);
  }

  // ---------------------------------------------------------------------------
  // USA – 511NY / 511 common feed
  // ---------------------------------------------------------------------------
  //
  // Endpoint: GET https://511ny.org/api/getCameras
  //   ?key=<API_KEY>&format=json
  //
  // Free registration: https://511ny.org/dev
  //
  // JSON shape (array of objects):
  //   {
  //     "ID": "CAM-1234",
  //     "Name": "I-90 @ Exit 5",
  //     "Latitude": 42.123,
  //     "Longitude": -73.456,
  //     "Url": "https://...jpg",
  //     "VideoUrl": "https://...m3u8",   // may be absent
  //     "DirectionOfTravel": "Eastbound",
  //     "County": "Albany",
  //     "Disabled": false
  //   }
  //
  // The same key / format works for several north-eastern 511 portals.
  // ---------------------------------------------------------------------------

  Future<List<RoadCamera>> _fetch511NyCameras(
    double centerLat,
    double centerLng,
    double radiusKm,
  ) async {
    final uri = Uri.https(
      '511ny.org',
      '/api/getCameras',
      {'key': Config.roadCamera511ApiKey, 'format': 'json'},
    );

    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('511NY HTTP ${response.statusCode}');
    }

    final List<dynamic> items = json.decode(response.body) as List<dynamic>;
    final cameras = <RoadCamera>[];

    for (final raw in items) {
      try {
        final map = raw as Map<String, dynamic>;
        if (map['Disabled'] == true) continue;

        final lat = (map['Latitude'] as num?)?.toDouble();
        final lng = (map['Longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final distKm =
            RoadCamera(id: '', name: '', lat: lat, lng: lng, country: 'US')
                    .distanceFromMeters(centerLat, centerLng) /
                1000;
        if (distKm > radiusKm) continue;

        cameras.add(RoadCamera(
          id: '511ny_${map["ID"]}',
          name: map['Name'] as String? ?? 'Camera',
          lat: lat,
          lng: lng,
          country: 'US',
          stateOrProvince: 'NY',
          direction: map['DirectionOfTravel'] as String?,
          imageUrl: map['Url'] as String?,
          streamUrl: map['VideoUrl'] as String?,
          description: map['County'] as String?,
        ));
      } catch (_) {
        continue;
      }
    }

    return cameras;
  }

  // ---------------------------------------------------------------------------
  // USA – WSDOT (Washington State DOT)
  // ---------------------------------------------------------------------------
  //
  // Endpoint: GET https://wsdot.wa.gov/Traffic/api/HighwayCameras/HighwayCamerasREST.svc/GetCamerasAsJson
  //   ?AccessCode=<API_KEY>
  //
  // Free registration: https://wsdot.wa.gov/traffic/api/
  //
  // JSON shape:
  //   {
  //     "CameraList": [
  //       {
  //         "CameraID": 1001,
  //         "Title": "I-5 at Northgate",
  //         "ImageURL": "https://...jpg",
  //         "DisplayLatitude": 47.7,
  //         "DisplayLongitude": -122.3,
  //         "CameraOwner": "WSDOT",
  //         "IsActive": true
  //       }
  //     ]
  //   }
  // ---------------------------------------------------------------------------

  Future<List<RoadCamera>> _fetchWsdotCameras(
    double centerLat,
    double centerLng,
    double radiusKm,
  ) async {
    final uri = Uri.https(
      'wsdot.wa.gov',
      '/Traffic/api/HighwayCameras/HighwayCamerasREST.svc/GetCamerasAsJson',
      {'AccessCode': Config.roadCamera511ApiKey},
    );

    final response = await _client
        .get(uri, headers: {'Accept': 'application/json'})
        .timeout(_timeout);

    if (response.statusCode != 200) {
      throw Exception('WSDOT HTTP ${response.statusCode}');
    }

    final body = json.decode(response.body) as Map<String, dynamic>;
    final List<dynamic> items = body['CameraList'] as List<dynamic>? ?? [];
    final cameras = <RoadCamera>[];

    for (final raw in items) {
      try {
        final map = raw as Map<String, dynamic>;
        if (map['IsActive'] == false) continue;

        final lat = (map['DisplayLatitude'] as num?)?.toDouble();
        final lng = (map['DisplayLongitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final distKm =
            RoadCamera(id: '', name: '', lat: lat, lng: lng, country: 'US')
                    .distanceFromMeters(centerLat, centerLng) /
                1000;
        if (distKm > radiusKm) continue;

        cameras.add(RoadCamera(
          id: 'wsdot_${map["CameraID"]}',
          name: map['Title'] as String? ?? 'Camera',
          lat: lat,
          lng: lng,
          country: 'US',
          stateOrProvince: 'WA',
          imageUrl: map['ImageURL'] as String?,
        ));
      } catch (_) {
        continue;
      }
    }

    return cameras;
  }

  // ---------------------------------------------------------------------------
  // Canada – DriveBC (British Columbia Ministry of Transportation)
  // ---------------------------------------------------------------------------
  //
  // Endpoint: GET https://api.open511.gov.bc.ca/cameras
  //   ?format=json&limit=100&offset=0
  //
  // No API key required – open data.
  // Docs: https://www2.gov.bc.ca/gov/content/transportation/
  //       driving-and-cycling/road-conditions-and-closures/drivebc/
  //       open511-api-documentation
  //
  // JSON shape:
  //   {
  //     "cameras": [
  //       {
  //         "id": "drivebc.ca/CAMERA/1",
  //         "name": "Hwy 1 at Cache Creek",
  //         "geography": { "type": "Point", "coordinates": [-121.3, 50.8] },
  //         "links": [
  //           { "rel": "imageURL", "href": "https://...jpg" }
  //         ]
  //       }
  //     ]
  //   }
  // ---------------------------------------------------------------------------

  Future<List<RoadCamera>> _fetchDriveBcCameras(
    double centerLat,
    double centerLng,
    double radiusKm,
  ) async {
    const pageSize = 100;
    final cameras = <RoadCamera>[];
    var offset = 0;

    while (true) {
      final uri = Uri.https(
        'api.open511.gov.bc.ca',
        '/cameras',
        {
          'format': 'json',
          'limit': '$pageSize',
          'offset': '$offset',
        },
      );

      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(_timeout);

      if (response.statusCode != 200) {
        throw Exception('DriveBC HTTP ${response.statusCode}');
      }

      final body = json.decode(response.body) as Map<String, dynamic>;
      final List<dynamic> items = body['cameras'] as List<dynamic>? ?? [];

      for (final raw in items) {
        try {
          final map = raw as Map<String, dynamic>;
          final geo = map['geography'] as Map<String, dynamic>?;
          final coords = geo?['coordinates'] as List<dynamic>?;
          if (coords == null || coords.length < 2) continue;

          final lat = (coords[1] as num).toDouble();
          final lng = (coords[0] as num).toDouble();

          final distKm =
              RoadCamera(id: '', name: '', lat: lat, lng: lng, country: 'CA')
                      .distanceFromMeters(centerLat, centerLng) /
                  1000;
          if (distKm > radiusKm) continue;

          // Extract snapshot URL from links array.
          String? imageUrl;
          final links = map['links'] as List<dynamic>?;
          if (links != null) {
            for (final link in links) {
              final l = link as Map<String, dynamic>;
              if (l['rel'] == 'imageURL') {
                imageUrl = l['href'] as String?;
                break;
              }
            }
          }

          final id = map['id'] as String? ?? 'bc_$offset';

          cameras.add(RoadCamera(
            id: 'drivebc_$id',
            name: map['name'] as String? ?? 'Camera',
            lat: lat,
            lng: lng,
            country: 'CA',
            stateOrProvince: 'BC',
            imageUrl: imageUrl,
          ));
        } catch (_) {
          continue;
        }
      }

      // DriveBC paginates; stop when fewer items than the page size are returned.
      if (items.length < pageSize) break;
      offset += pageSize;
    }

    return cameras;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  List<RoadCamera> _sortByDistance(
    List<RoadCamera> cameras,
    double lat,
    double lng,
  ) {
    final sorted = List<RoadCamera>.from(cameras);
    sorted.sort(
      (a, b) => a
          .distanceFromMeters(lat, lng)
          .compareTo(b.distanceFromMeters(lat, lng)),
    );
    return sorted;
  }

  // ---------------------------------------------------------------------------
  // Demo / fallback data
  // ---------------------------------------------------------------------------
  //
  // These cameras are fictional placeholders used when no API key is configured.
  // They cover a range of US states and Canadian provinces so the map markers
  // are spread across the continent.
  //
  // Replace or extend this list once you have real DOT API keys.
  // ---------------------------------------------------------------------------

  static final List<RoadCamera> _democameras = [
    // ── USA ───────────────────────────────────────────────────────────────────
    const RoadCamera(
      id: 'demo_us_ny_1',
      name: 'I-95 @ George Washington Bridge (Demo)',
      lat: 40.8508,
      lng: -73.9496,
      country: 'US',
      stateOrProvince: 'NY',
      direction: 'Southbound',
      description: 'Demo camera – configure ROAD_CAMERA_511_API_KEY for live data',
    ),
    const RoadCamera(
      id: 'demo_us_ca_1',
      name: 'US-101 @ Hollywood Bowl Interchange (Demo)',
      lat: 34.1016,
      lng: -118.3389,
      country: 'US',
      stateOrProvince: 'CA',
      direction: 'Northbound',
      description: 'Demo camera – configure ROAD_CAMERA_511_API_KEY for live data',
    ),
    const RoadCamera(
      id: 'demo_us_tx_1',
      name: 'I-35 @ Downtown Austin (Demo)',
      lat: 30.2672,
      lng: -97.7431,
      country: 'US',
      stateOrProvince: 'TX',
      direction: 'Northbound',
      description: 'Demo camera – configure ROAD_CAMERA_511_API_KEY for live data',
    ),
    const RoadCamera(
      id: 'demo_us_il_1',
      name: 'I-90/94 @ Chicago Express (Demo)',
      lat: 41.8827,
      lng: -87.6233,
      country: 'US',
      stateOrProvince: 'IL',
      description: 'Demo camera – configure ROAD_CAMERA_511_API_KEY for live data',
    ),
    const RoadCamera(
      id: 'demo_us_wa_1',
      name: 'I-5 @ Seattle Mercer Street (Demo)',
      lat: 47.6204,
      lng: -122.3320,
      country: 'US',
      stateOrProvince: 'WA',
      direction: 'Southbound',
      description: 'Demo camera – configure ROAD_CAMERA_511_API_KEY for live data',
    ),
    const RoadCamera(
      id: 'demo_us_fl_1',
      name: 'I-4 @ Orlando International (Demo)',
      lat: 28.4312,
      lng: -81.3081,
      country: 'US',
      stateOrProvince: 'FL',
      description: 'Demo camera – configure ROAD_CAMERA_511_API_KEY for live data',
    ),
    const RoadCamera(
      id: 'demo_us_co_1',
      name: 'I-70 @ Denver Mousetrap (Demo)',
      lat: 39.7392,
      lng: -104.9903,
      country: 'US',
      stateOrProvince: 'CO',
      description: 'Demo camera – configure ROAD_CAMERA_511_API_KEY for live data',
    ),
    const RoadCamera(
      id: 'demo_us_ga_1',
      name: 'I-285 @ Perimeter Center (Demo)',
      lat: 33.9304,
      lng: -84.3604,
      country: 'US',
      stateOrProvince: 'GA',
      description: 'Demo camera – configure ROAD_CAMERA_511_API_KEY for live data',
    ),

    // ── Canada ────────────────────────────────────────────────────────────────
    const RoadCamera(
      id: 'demo_ca_on_1',
      name: 'Hwy 401 @ Toronto (Demo)',
      lat: 43.7001,
      lng: -79.4163,
      country: 'CA',
      stateOrProvince: 'ON',
      description: 'Demo camera – no API key required for DriveBC open data',
    ),
    const RoadCamera(
      id: 'demo_ca_bc_1',
      name: 'Hwy 1 @ Vancouver Lions Gate (Demo)',
      lat: 49.3260,
      lng: -123.1391,
      country: 'CA',
      stateOrProvince: 'BC',
      description: 'Demo camera – no API key required for DriveBC open data',
    ),
    const RoadCamera(
      id: 'demo_ca_ab_1',
      name: 'Hwy 2 @ Calgary Deerfoot (Demo)',
      lat: 51.0447,
      lng: -114.0719,
      country: 'CA',
      stateOrProvince: 'AB',
      description: 'Demo camera – no API key required for DriveBC open data',
    ),
    const RoadCamera(
      id: 'demo_ca_qc_1',
      name: 'Autoroute 40 @ Montréal (Demo)',
      lat: 45.5017,
      lng: -73.5673,
      country: 'CA',
      stateOrProvince: 'QC',
      description: 'Demo camera – no API key required for DriveBC open data',
    ),
  ];
}

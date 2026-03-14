/// Maps US states and Canadian provinces/territories to their legal
/// commercial/truck speed limits in mph.
///
/// Speed limits are sourced from state/provincial DOT regulations (as of 2024).
/// For US states where limits vary by road type (divided vs. undivided highway,
/// interstate vs. arterial), the **conservative lower common limit** is used
/// rather than the highest-possible posted value.
///
/// Canadian province/territory limits are derived from the posted maximum
/// highway speed for commercial vehicles, converted from km/h to mph and
/// rounded to the nearest whole mile. Where provinces distinguish between
/// expressway and undivided-highway limits, the lower (undivided) limit is
/// used as the conservative default.
class TruckSpeedLimitService {
  // ---------------------------------------------------------------------------
  // US state → truck speed limit map (mph, conservative)
  // ---------------------------------------------------------------------------

  static const Map<String, double> _stateTruckLimits = {
    'AL': 70,
    'AK': 65,
    'AZ': 65, // conservative: 65 mph on most multi-lane; some interstates posted higher
    'AR': 70,
    'CA': 55, // California trucks always capped at 55 mph
    'CO': 65, // conservative: varies significantly by road type (55–75)
    'CT': 65,
    'DE': 65,
    'FL': 70,
    'GA': 70,
    'HI': 60,
    'ID': 70,
    'IL': 65,
    'IN': 65,
    'IA': 65,
    'KS': 70, // conservative: 70 mph on most interstates
    'KY': 65,
    'LA': 70,
    'ME': 65,
    'MD': 65,
    'MA': 65,
    'MI': 65,
    'MN': 70,
    'MS': 70,
    'MO': 70,
    'MT': 65, // Montana raised car limit to 80; trucks remain 65
    'NE': 65, // conservative: 65 on interstates; lower on 2-lane
    'NV': 70, // conservative: 70 mph (cars up to 80 on some roads)
    'NH': 65,
    'NJ': 65,
    'NM': 65, // conservative: 65 on 2-lane divided; some interstates higher
    'NY': 65,
    'NC': 70,
    'ND': 65, // conservative: 65 on rural 2-lane; some interstates 75
    'OH': 65,
    'OK': 70,
    'OR': 65,
    'PA': 65,
    'RI': 65,
    'SC': 70,
    'SD': 80, // South Dakota: interstates 80 for all vehicle classes
    'TN': 70,
    'TX': 70, // conservative: daytime truck max 70 on most interstates
    'UT': 70,
    'VT': 65,
    'VA': 70,
    'WA': 60,
    'WV': 65,
    'WI': 65,
    'WY': 65, // conservative: 65 on undivided highways; divided may be 75
    'DC': 55,
  };

  // ---------------------------------------------------------------------------
  // Canadian province/territory → truck speed limit map (mph equivalent)
  // ---------------------------------------------------------------------------
  //
  // Values are the conservative (lower common) commercial-vehicle highway
  // speed limit converted from km/h: 110 km/h ≈ 68 mph, 100 km/h ≈ 62 mph,
  // 90 km/h ≈ 56 mph, 80 km/h ≈ 50 mph.
  static const Map<String, double> _provinceTruckLimits = {
    'AB': 68, // Alberta: 110 km/h on divided highways
    'BC': 62, // British Columbia: 100 km/h commercial vehicle limit
    'MB': 62, // Manitoba: 100 km/h highway limit
    'NB': 62, // New Brunswick: 100 km/h highway limit
    'NL': 62, // Newfoundland & Labrador: 100 km/h Trans-Canada
    'NS': 62, // Nova Scotia: 100 km/h highway limit
    'NT': 56, // Northwest Territories: 90 km/h highway limit
    'NU': 50, // Nunavut: 80 km/h (limited paved road network)
    'ON': 62, // Ontario: 100 km/h commercial vehicle limit on expressways
    'PE': 56, // Prince Edward Island: 90 km/h highway limit
    'QC': 62, // Quebec: 100 km/h highway limit
    'SK': 62, // Saskatchewan: 100 km/h highway limit
    'YT': 56, // Yukon: 90 km/h on Alaska Highway and major routes
  };

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the commercial truck speed limit in mph for [regionCode].
  ///
  /// Accepts both US USPS 2-letter state codes (e.g., `'TX'`) and Canadian
  /// province/territory codes (e.g., `'ON'`, `'BC'`). Lookup is
  /// case-insensitive. Returns `null` for unrecognized codes.
  double? limitForState(String regionCode) {
    final code = regionCode.toUpperCase();
    return _stateTruckLimits[code] ?? _provinceTruckLimits[code];
  }

  /// Returns a read-only view of the combined US + Canadian speed-limit map.
  static Map<String, double> get allStateLimits => Map.unmodifiable({
        ..._stateTruckLimits,
        ..._provinceTruckLimits,
      });

  /// Returns a read-only view of the US-only speed-limit map.
  static Map<String, double> get usStateLimits =>
      Map.unmodifiable(_stateTruckLimits);

  /// Returns a read-only view of the Canadian province/territory speed-limit map.
  static Map<String, double> get canadaProvinceLimits =>
      Map.unmodifiable(_provinceTruckLimits);
}

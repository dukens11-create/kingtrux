/// Maps US states (USPS 2-letter codes) to their legal commercial/truck speed
/// limits in mph.
///
/// Speed limits are sourced from state DOT regulations (as of 2024).
/// Some states differentiate between divided/undivided highways; the highest
/// authorised interstate/freeway limit for commercial vehicles is used.
class TruckSpeedLimitService {
  // ---------------------------------------------------------------------------
  // State → truck speed limit map (mph)
  // ---------------------------------------------------------------------------

  static const Map<String, double> _stateTruckLimits = {
    'AL': 70,
    'AK': 65,
    'AZ': 75,
    'AR': 70,
    'CA': 55,
    'CO': 75,
    'CT': 65,
    'DE': 65,
    'FL': 70,
    'GA': 70,
    'HI': 60,
    'ID': 70,
    'IL': 65,
    'IN': 65,
    'IA': 65,
    'KS': 75,
    'KY': 65,
    'LA': 70,
    'ME': 65,
    'MD': 65,
    'MA': 65,
    'MI': 65,
    'MN': 70,
    'MS': 70,
    'MO': 70,
    'MT': 65,
    'NE': 75,
    'NV': 75,
    'NH': 65,
    'NJ': 65,
    'NM': 75,
    'NY': 65,
    'NC': 70,
    'ND': 75,
    'OH': 65,
    'OK': 70,
    'OR': 65,
    'PA': 65,
    'RI': 65,
    'SC': 70,
    'SD': 80,
    'TN': 70,
    'TX': 75,
    'UT': 70,
    'VT': 65,
    'VA': 70,
    'WA': 60,
    'WV': 65,
    'WI': 65,
    'WY': 75,
    'DC': 55,
  };

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the commercial truck speed limit in mph for [stateCode]
  /// (USPS 2-letter abbreviation, case-insensitive), or `null` when the state
  /// is not in the database (e.g., a Canadian province or unrecognised code).
  double? limitForState(String stateCode) =>
      _stateTruckLimits[stateCode.toUpperCase()];

  /// Returns a read-only view of the full state → speed-limit map.
  static Map<String, double> get allStateLimits =>
      Map.unmodifiable(_stateTruckLimits);
}

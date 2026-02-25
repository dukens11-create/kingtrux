/// US time zone regions used for truck navigation ETA display.
enum TzRegion {
  eastern,
  central,
  mountain,
  pacific,
  alaska,
  hawaii,
}

/// Provides US state → time zone mapping for automatic ETA and arrival-time
/// display in commercial truck navigation.
///
/// All calculations are DST-aware: the US Daylight Saving Time schedule
/// (second Sunday in March – first Sunday in November) is approximated
/// using a calendar algorithm, requiring no additional packages.
///
/// This is a pure-Dart, static-only utility class.
class TimeZoneService {
  const TimeZoneService._();

  // ---------------------------------------------------------------------------
  // State → region map
  // ---------------------------------------------------------------------------

  /// Maps USPS 2-letter state codes to their primary US time zone region.
  static const Map<String, TzRegion> stateRegions = {
    // Eastern Time
    'CT': TzRegion.eastern,
    'DC': TzRegion.eastern,
    'DE': TzRegion.eastern,
    'FL': TzRegion.eastern,
    'GA': TzRegion.eastern,
    'IN': TzRegion.eastern,
    'KY': TzRegion.eastern,
    'MA': TzRegion.eastern,
    'MD': TzRegion.eastern,
    'ME': TzRegion.eastern,
    'MI': TzRegion.eastern,
    'NC': TzRegion.eastern,
    'NH': TzRegion.eastern,
    'NJ': TzRegion.eastern,
    'NY': TzRegion.eastern,
    'OH': TzRegion.eastern,
    'PA': TzRegion.eastern,
    'RI': TzRegion.eastern,
    'SC': TzRegion.eastern,
    'TN': TzRegion.eastern,
    'VA': TzRegion.eastern,
    'VT': TzRegion.eastern,
    'WV': TzRegion.eastern,
    // Central Time
    'AL': TzRegion.central,
    'AR': TzRegion.central,
    'IA': TzRegion.central,
    'IL': TzRegion.central,
    'KS': TzRegion.central,
    'LA': TzRegion.central,
    'MN': TzRegion.central,
    'MO': TzRegion.central,
    'MS': TzRegion.central,
    'ND': TzRegion.central,
    'NE': TzRegion.central,
    'OK': TzRegion.central,
    'SD': TzRegion.central,
    'TX': TzRegion.central,
    'WI': TzRegion.central,
    // Mountain Time
    'AZ': TzRegion.mountain,
    'CO': TzRegion.mountain,
    'ID': TzRegion.mountain,
    'MT': TzRegion.mountain,
    'NM': TzRegion.mountain,
    'UT': TzRegion.mountain,
    'WY': TzRegion.mountain,
    // Pacific Time
    'CA': TzRegion.pacific,
    'NV': TzRegion.pacific,
    'OR': TzRegion.pacific,
    'WA': TzRegion.pacific,
    // Alaska Time
    'AK': TzRegion.alaska,
    // Hawaii–Aleutian Time (no DST)
    'HI': TzRegion.hawaii,
  };

  // ---------------------------------------------------------------------------
  // UTC offsets (hours) by region
  // ---------------------------------------------------------------------------

  static const Map<TzRegion, int> _dstOffsets = {
    TzRegion.eastern: -4,
    TzRegion.central: -5,
    TzRegion.mountain: -6,
    TzRegion.pacific: -7,
    TzRegion.alaska: -8,
    TzRegion.hawaii: -10, // no DST — constant year-round
  };

  static const Map<TzRegion, int> _stdOffsets = {
    TzRegion.eastern: -5,
    TzRegion.central: -6,
    TzRegion.mountain: -7,
    TzRegion.pacific: -8,
    TzRegion.alaska: -9,
    TzRegion.hawaii: -10,
  };

  // ---------------------------------------------------------------------------
  // Time zone abbreviations by region
  // ---------------------------------------------------------------------------

  static const Map<TzRegion, String> _dstAbbreviations = {
    TzRegion.eastern: 'EDT',
    TzRegion.central: 'CDT',
    TzRegion.mountain: 'MDT',
    TzRegion.pacific: 'PDT',
    TzRegion.alaska: 'AKDT',
    TzRegion.hawaii: 'HST',
  };

  static const Map<TzRegion, String> _stdAbbreviations = {
    TzRegion.eastern: 'EST',
    TzRegion.central: 'CST',
    TzRegion.mountain: 'MST',
    TzRegion.pacific: 'PST',
    TzRegion.alaska: 'AKST',
    TzRegion.hawaii: 'HST',
  };

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Returns the UTC offset [Duration] for [stateCode] at [when] (UTC),
  /// accounting for US Daylight Saving Time.
  ///
  /// Returns `null` for unrecognised state codes (e.g., Canadian provinces).
  static Duration? getUtcOffset(String stateCode, DateTime when) {
    final region = stateRegions[stateCode.toUpperCase()];
    if (region == null) return null;
    final hours = isDst(when) ? _dstOffsets[region]! : _stdOffsets[region]!;
    return Duration(hours: hours);
  }

  /// Returns the time zone abbreviation (e.g., `"CDT"`, `"PST"`) for
  /// [stateCode] at [when] (UTC), or `null` for unrecognised state codes.
  static String? getAbbreviation(String stateCode, DateTime when) {
    final region = stateRegions[stateCode.toUpperCase()];
    if (region == null) return null;
    return isDst(when) ? _dstAbbreviations[region] : _stdAbbreviations[region];
  }

  /// Returns `true` when US Daylight Saving Time is in effect for [when].
  ///
  /// US DST schedule: second Sunday in March at 02:00 local (approx 07:00 UTC)
  /// through the first Sunday in November at 02:00 local (approx 06:00 UTC).
  static bool isDst(DateTime when) {
    final utc = when.toUtc();
    final month = utc.month;
    // January, February, December are always standard time.
    if (month < 3 || month == 12) return false;
    // April through October are always DST.
    if (month > 3 && month < 11) return true;
    // March: DST starts on the second Sunday at 07:00 UTC.
    if (month == 3) {
      final start = _nthSundayOfMonth(utc.year, 3, 2);
      return utc.isAfter(start.add(const Duration(hours: 7)));
    }
    // November: DST ends on the first Sunday at 06:00 UTC.
    final end = _nthSundayOfMonth(utc.year, 11, 1);
    return utc.isBefore(end.add(const Duration(hours: 6)));
  }

  /// Converts a UTC [DateTime] to the local wall-clock time for [stateCode]
  /// at [when] (UTC). Returns `null` for unrecognised state codes.
  static DateTime? toStateLocalTime(
      String stateCode, DateTime utc, DateTime when) {
    final offset = getUtcOffset(stateCode, when);
    if (offset == null) return null;
    return utc.toUtc().add(offset);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  /// Returns the [n]-th Sunday (1-based) of the given [month] and [year] as
  /// a UTC midnight [DateTime].
  static DateTime _nthSundayOfMonth(int year, int month, int n) {
    final firstOfMonth = DateTime.utc(year, month, 1);
    // weekday: Monday=1 … Sunday=7
    final daysUntilSunday =
        (DateTime.sunday - firstOfMonth.weekday + 7) % 7;
    final firstSunday = firstOfMonth.add(Duration(days: daysUntilSunday));
    return firstSunday.add(Duration(days: 7 * (n - 1)));
  }
}

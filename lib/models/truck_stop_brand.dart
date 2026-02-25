/// Major truck stop brands supported by the brand-filter feature.
enum TruckStopBrand {
  ta,
  petro,
  loves,
  pilot,
  flyingJ,
}

/// Human-readable display name for each [TruckStopBrand].
extension TruckStopBrandLabel on TruckStopBrand {
  String get displayName {
    switch (this) {
      case TruckStopBrand.ta:
        return 'TA (TravelCenters of America)';
      case TruckStopBrand.petro:
        return 'Petro';
      case TruckStopBrand.loves:
        return "Love's";
      case TruckStopBrand.pilot:
        return 'Pilot';
      case TruckStopBrand.flyingJ:
        return 'Flying J';
    }
  }

  /// Normalized keyword fragments used to match OSM name/brand/operator tags.
  ///
  /// Each entry is already lowercased with punctuation and whitespace removed
  /// (i.e., pre-normalized via [TruckStopFilterService.normalize]).
  List<String> get matchTerms {
    switch (this) {
      case TruckStopBrand.ta:
        return [
          'ta',
          'travelcentersofamerica',
          'travelcenter',
          'travelcentre',
        ];
      case TruckStopBrand.petro:
        return [
          'petro',
          'petrostoppingcenter',
          'petroironskillet',
        ];
      case TruckStopBrand.loves:
        return [
          'loves',
          'lovestravelstop',
          'lovestravelstopsandcountrystores',
        ];
      case TruckStopBrand.pilot:
        return [
          'pilot',
          'pilottravelcenter',
          'pilotflyingj',
        ];
      case TruckStopBrand.flyingJ:
        return [
          'flyingj',
          'flyingjtravel',
          'pilotflyingj',
        ];
    }
  }
}

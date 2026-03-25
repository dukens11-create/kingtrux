/// Major truck stop brands supported by the brand-filter feature.
enum TruckStopBrand {
  ta,
  petro,
  loves,
  pilot,
  flyingJ,
  // Added in map-UI refactor
  kwikTrip,
  roadRanger,
  one9,
  amBest,
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
      case TruckStopBrand.kwikTrip:
        return 'KwikTrip / KwikStar';
      case TruckStopBrand.roadRanger:
        return 'Road Ranger';
      case TruckStopBrand.one9:
        return 'One9';
      case TruckStopBrand.amBest:
        return 'AM Best';
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
      case TruckStopBrand.kwikTrip:
        return [
          'kwiktrip',
          'kwikstar',
          'kwik trip',
          'kwik star',
        ];
      case TruckStopBrand.roadRanger:
        return [
          'roadranger',
          'road ranger',
        ];
      case TruckStopBrand.one9:
        return [
          'one9',
          'one 9',
        ];
      case TruckStopBrand.amBest:
        return [
          'ambest',
          'am best',
          'americanstop',
        ];
    }
  }
}

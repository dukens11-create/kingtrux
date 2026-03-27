/// Major truck stop brands supported by the brand-filter feature.
///
/// **Ordering matters**: more-specific brand names must appear before shorter
/// ones whose match-terms are substrings of the longer brands.  For example,
/// `petroCanada` before `petro` (otherwise "petrocanada" would be claimed by
/// the `'petro'` term), and `total` before `ta` (otherwise "total" / "totalenergies"
/// would be claimed by the two-letter `'ta'` term).
enum TruckStopBrand {
  // petroCanada before petro: 'petrocanada'.contains('petro') == true
  petroCanada,
  petro,
  // total before ta: 'total'.contains('ta') == true
  total,
  ta,
  loves,
  pilot,
  flyingJ,
  // Added in map-UI refactor
  kwikTrip,
  roadRanger,
  one9,
  amBest,
  // Added for brand-image feature
  roadys,
  sappBros,
  maverik,
  caseys,
  shell,
  bp,
  esso,
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
      case TruckStopBrand.roadys:
        return "Roady's";
      case TruckStopBrand.sappBros:
        return 'Sapp Bros';
      case TruckStopBrand.maverik:
        return 'Maverik';
      case TruckStopBrand.caseys:
        return "Casey's";
      case TruckStopBrand.shell:
        return 'Shell';
      case TruckStopBrand.bp:
        return 'BP';
      case TruckStopBrand.total:
        return 'Total';
      case TruckStopBrand.petroCanada:
        return 'Petro Canada';
      case TruckStopBrand.esso:
        return 'Esso';
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
        ];
      case TruckStopBrand.roadRanger:
        return [
          'roadranger',
        ];
      case TruckStopBrand.one9:
        return [
          'one9',
        ];
      case TruckStopBrand.amBest:
        return [
          'ambest',
          'americanstop',
        ];
      case TruckStopBrand.roadys:
        return [
          'roadys',
          'roadystruckstop',
        ];
      case TruckStopBrand.sappBros:
        return [
          'sappbros',
          'sappbrothers',
        ];
      case TruckStopBrand.maverik:
        return [
          'maverik',
          'maveriknc',
        ];
      case TruckStopBrand.caseys:
        return [
          'caseys',
          'casey',
          'caseysgeneral',
          'caseygeneralstores',
        ];
      case TruckStopBrand.shell:
        return [
          'shell',
        ];
      case TruckStopBrand.bp:
        return [
          'bp',
          'britishpetroleum',
        ];
      case TruckStopBrand.total:
        return [
          'total',
          'totalenergies',
          'totalaccess',
        ];
      case TruckStopBrand.petroCanada:
        return [
          'petrocanada',
        ];
      case TruckStopBrand.esso:
        return [
          'esso',
        ];
    }
  }
}

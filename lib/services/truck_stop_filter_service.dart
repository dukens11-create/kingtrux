import '../models/truck_stop_brand.dart';

/// Pure-Dart helper for matching OSM POI tags against [TruckStopBrand] values.
///
/// All matching is done on a normalized form of the string:
/// lowercase, with all non-alphanumeric characters stripped.
class TruckStopFilterService {
  const TruckStopFilterService._();

  /// Normalize [s]: lowercase and strip every character that is not a-z or 0-9.
  static String normalize(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  /// Return the [TruckStopBrand] that matches the given OSM [tags], or `null`
  /// if no known brand is detected.
  ///
  /// The fields checked, in priority order: `brand`, `operator`, `name`.
  static TruckStopBrand? detectBrand(Map<String, dynamic> tags) {
    final candidates = [
      tags['brand'] as String?,
      tags['operator'] as String?,
      tags['name'] as String?,
    ].whereType<String>().map(normalize).toList();

    for (final brand in TruckStopBrand.values) {
      for (final term in brand.matchTerms) {
        for (final candidate in candidates) {
          if (candidate.contains(term)) return brand;
        }
      }
    }
    return null;
  }

  /// Return `true` if any of the [brands] matches the given OSM [tags].
  static bool matchesAnyBrand(
    Set<TruckStopBrand> brands,
    Map<String, dynamic> tags,
  ) {
    final detected = detectBrand(tags);
    return detected != null && brands.contains(detected);
  }
}

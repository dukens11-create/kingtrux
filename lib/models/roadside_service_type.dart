import 'package:flutter/material.dart';

/// Subcategory of a roadside assistance service provider.
enum RoadsideServiceType {
  towing,
  mechanic,
  tire,
  other,
}

/// Human-readable label for each [RoadsideServiceType].
extension RoadsideServiceTypeLabel on RoadsideServiceType {
  String get displayName {
    switch (this) {
      case RoadsideServiceType.towing:
        return 'Towing';
      case RoadsideServiceType.mechanic:
        return 'Mechanic';
      case RoadsideServiceType.tire:
        return 'Tire';
      case RoadsideServiceType.other:
        return 'Other';
    }
  }

  IconData get icon {
    switch (this) {
      case RoadsideServiceType.towing:
        return Icons.car_repair;
      case RoadsideServiceType.mechanic:
        return Icons.build_rounded;
      case RoadsideServiceType.tire:
        return Icons.tire_repair_rounded;
      case RoadsideServiceType.other:
        return Icons.miscellaneous_services_rounded;
    }
  }
}

/// Derives the [RoadsideServiceType] from OSM tags stored in a [Poi].
RoadsideServiceType roadsideTypeFromTags(Map<String, dynamic> tags) {
  final amenity = (tags['amenity'] as String? ?? '').toLowerCase();
  final shop = (tags['shop'] as String? ?? '').toLowerCase();
  final emergency = (tags['emergency'] as String? ?? '').toLowerCase();
  final service = (tags['service'] as String? ?? '').toLowerCase();

  if (emergency == 'roadside_assistance' || service.contains('tow')) {
    return RoadsideServiceType.towing;
  }
  if (shop == 'tyres' || shop == 'tires' || shop == 'car_parts') {
    return RoadsideServiceType.tire;
  }
  if (amenity == 'car_repair' || shop == 'car_repair' ||
      service.contains('mechanic') || service.contains('repair')) {
    return RoadsideServiceType.mechanic;
  }
  return RoadsideServiceType.other;
}

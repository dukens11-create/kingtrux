// OverpassPoiService implementation

class OverpassPoiService {
  // Other existing methods and properties...

  String _defaultName(PoiType type) {
    switch (type) {
      case PoiType.fuel:
        return 'Fuel Station';
      case PoiType.restArea:
        return 'Rest Area';
      case PoiType.gym:
        return 'Gym';
      case PoiType.scale:
        return 'Scale';
      case PoiType.truckStop:
        return 'Truck Stop';
      case PoiType.parking:
        return 'Parking';
      case PoiType.roadsideAssistance:
        return 'Roadside Assistance';
      case PoiType.truckWash:
        return 'Truck Wash';
      case PoiType.hotel:
        return 'Hotel';
      case PoiType.repairShop:
        return 'Repair Shop';
      case PoiType.tires:
        return 'Tires';
      case PoiType.walmart:
        return 'Walmart';
      case PoiType.facility:
        return 'Facility';
      case PoiType.clearance:
        return 'Clearance';
      case PoiType.truckDealer:
        return 'Truck Dealer';
      default:
        return 'Unknown';
    }
  }

  // Other existing methods and properties...
}
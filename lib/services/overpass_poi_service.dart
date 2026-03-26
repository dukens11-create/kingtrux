String _defaultName(PoiType type) {
  switch (type) {
    case PoiType.truckWash:
      return 'Truck Wash';
    case PoiType.hotel:
      return 'Hotel';
    case PoiType.repairShop:
      return 'Repair Shop';
    case PoiType.tires:
      return 'Tire Shop';
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
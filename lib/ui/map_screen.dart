import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../models/poi.dart';
import 'widgets/truck_profile_sheet.dart';
import 'widgets/layer_sheet.dart';
import 'widgets/route_summary_card.dart';

/// Main map screen with Google Maps integration
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KINGTRUX'),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () => _onMyLocationPressed(context),
            tooltip: 'My Location',
          ),
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: () => _showTruckProfileSheet(context),
            tooltip: 'Truck Profile',
          ),
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: () => _showLayerSheet(context),
            tooltip: 'Layers',
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, child) {
          if (state.myLat == null || state.myLng == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Getting your location...'),
                ],
              ),
            );
          }

          return Stack(
            children: [
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(state.myLat!, state.myLng!),
                  zoom: 12,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                onLongPress: (latLng) => _onMapLongPress(context, latLng),
                markers: _buildMarkers(state),
                polylines: _buildPolylines(state),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
              ),
              // Weather pill at top
              if (state.weatherPoint != null)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wb_sunny, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${state.weatherPoint!.summary} • '
                              '${state.weatherPoint!.temperatureCelsius.toStringAsFixed(1)}°C • '
                              'Wind: ${state.weatherPoint!.windSpeedMs.toStringAsFixed(1)} m/s',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              // Route summary card at bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: const RouteSummaryCard(),
              ),
            ],
          );
        },
      ),
    );
  }

  Set<Marker> _buildMarkers(AppState state) {
    final markers = <Marker>{};

    // Current location marker
    if (state.myLat != null && state.myLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('my_location'),
          position: LatLng(state.myLat!, state.myLng!),
          infoWindow: const InfoWindow(title: 'You'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      );
    }

    // Destination marker
    if (state.destLat != null && state.destLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: LatLng(state.destLat!, state.destLng!),
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
    }

    // POI markers
    for (final poi in state.pois) {
      final color = _getPoiColor(poi.type);
      markers.add(
        Marker(
          markerId: MarkerId(poi.id),
          position: LatLng(poi.lat, poi.lng),
          infoWindow: InfoWindow(
            title: poi.name,
            snippet: _getPoiTypeName(poi.type),
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(color),
        ),
      );
    }

    return markers;
  }

  Set<Polyline> _buildPolylines(AppState state) {
    final polylines = <Polyline>{};

    if (state.routeResult != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('route'),
          points: state.routeResult!.polylinePoints,
          color: Colors.blue,
          width: 5,
        ),
      );
    }

    return polylines;
  }

  double _getPoiColor(PoiType type) {
    switch (type) {
      case PoiType.fuel:
        return BitmapDescriptor.hueOrange;
      case PoiType.restArea:
        return BitmapDescriptor.hueAzure;
      case PoiType.gym:
        return BitmapDescriptor.hueViolet;
      case PoiType.scale:
        return BitmapDescriptor.hueYellow;
      case PoiType.truckStop:
        return BitmapDescriptor.hueCyan;
      case PoiType.parking:
        return BitmapDescriptor.hueBlue;
    }
  }

  String _getPoiTypeName(PoiType type) {
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
    }
  }

  Future<void> _onMapLongPress(BuildContext context, LatLng latLng) async {
    final state = context.read<AppState>();
    state.setDestination(latLng.latitude, latLng.longitude);

    try {
      await state.buildTruckRoute();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error building route: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _onMyLocationPressed(BuildContext context) async {
    final state = context.read<AppState>();

    try {
      await state.refreshMyLocation();

      if (state.myLat != null && state.myLng != null && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(
            LatLng(state.myLat!, state.myLng!),
            14,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error refreshing location: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showTruckProfileSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const TruckProfileSheet(),
    );
  }

  void _showLayerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => const LayerSheet(),
    );
  }
}

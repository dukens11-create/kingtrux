import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../models/poi.dart';
import '../state/app_state.dart';
import 'widgets/truck_profile_sheet.dart';
import 'widgets/layer_sheet.dart';
import 'widgets/route_summary_card.dart';
import 'preview_gallery_page.dart';

/// Main map screen with Google Maps integration
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  GoogleMapController? _mapController;
  
  @override
  void initState() {
    super.initState();
    // Initialize app state
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().init();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: kDebugMode
            ? GestureDetector(
                onLongPress: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const PreviewGalleryPage(),
                  ),
                ),
                child: const Text('KINGTRUX'),
              )
            : const Text('KINGTRUX'),
        actions: [
          // My Location button
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: _onMyLocationPressed,
            tooltip: 'Refresh location',
          ),
          // Truck profile button
          IconButton(
            icon: const Icon(Icons.tune),
            onPressed: _onTruckProfilePressed,
            tooltip: 'Truck profile',
          ),
          // Layers button
          IconButton(
            icon: const Icon(Icons.layers),
            onPressed: _onLayersPressed,
            tooltip: 'POI layers',
          ),
        ],
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (state.myLat == null || state.myLng == null) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          return Stack(
            children: [
              // Google Map
              GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(state.myLat!, state.myLng!),
                  zoom: 12,
                ),
                onMapCreated: (controller) {
                  _mapController = controller;
                },
                onLongPress: _onMapLongPress,
                markers: _buildMarkers(state),
                polylines: _buildPolylines(state),
                myLocationEnabled: true,
                myLocationButtonEnabled: false,
              ),
              
              // Weather pill (top overlay)
              if (state.weatherAtCurrentLocation != null)
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _buildWeatherPill(state),
                ),
              
              // Route summary card (bottom overlay)
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

  /// Build markers for map
  Set<Marker> _buildMarkers(AppState state) {
    final markers = <Marker>{};

    // Current location marker
    if (state.myLat != null && state.myLng != null) {
      markers.add(
        Marker(
          markerId: const MarkerId('my_location'),
          position: LatLng(state.myLat!, state.myLng!),
          infoWindow: const InfoWindow(title: 'You'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
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
      markers.add(
        Marker(
          markerId: MarkerId('poi_${poi.id}'),
          position: LatLng(poi.lat, poi.lng),
          infoWindow: InfoWindow(
            title: poi.name,
            snippet: poi.type.name,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            _getPoiColor(poi.type),
          ),
        ),
      );
    }

    return markers;
  }

  /// Get marker color for POI type
  double _getPoiColor(PoiType type) {
    switch (type) {
      case PoiType.fuel:
        return BitmapDescriptor.hueOrange;
      case PoiType.restArea:
        return BitmapDescriptor.hueAzure;
      default:
        return BitmapDescriptor.hueGreen;
    }
  }

  /// Build polylines for route
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

  /// Build weather pill widget
  Widget _buildWeatherPill(AppState state) {
    final weather = state.weatherAtCurrentLocation!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud, size: 20),
            const SizedBox(width: 8),
            Text(
              '${weather.summary} • ${weather.temperatureCelsius.toStringAsFixed(1)}°C • ${weather.windSpeedMs.toStringAsFixed(1)} m/s',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  /// Handle my location button press
  Future<void> _onMyLocationPressed() async {
    try {
      final state = context.read<AppState>();
      await state.refreshMyLocation();
      
      if (state.myLat != null && state.myLng != null && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLng(LatLng(state.myLat!, state.myLng!)),
        );
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location updated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Handle truck profile button press
  void _onTruckProfilePressed() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => const TruckProfileSheet(),
    );
  }

  /// Handle layers button press
  void _onLayersPressed() {
    showModalBottomSheet(
      context: context,
      builder: (context) => const LayerSheet(),
    );
  }

  /// Handle long press on map to set destination
  Future<void> _onMapLongPress(LatLng position) async {
    final state = context.read<AppState>();
    state.setDestination(position.latitude, position.longitude);
    
    try {
      await state.buildTruckRoute();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Route calculated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Route error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}

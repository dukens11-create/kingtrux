import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/poi.dart';
import '../state/app_state.dart';
import 'widgets/layer_sheet.dart';
import 'widgets/route_summary_card.dart';
import 'widgets/truck_profile_sheet.dart';

/// In-app UI preview / gallery screen (debug/profile builds only).
///
/// Accessible via a long-press on the "KINGTRUX" app-bar title.
/// Shows key UI components rendered in both light and dark themes so
/// reviewers can inspect the look-and-feel without needing API keys or a
/// real device.
class PreviewGalleryPage extends StatefulWidget {
  const PreviewGalleryPage({super.key});

  @override
  State<PreviewGalleryPage> createState() => _PreviewGalleryPageState();
}

class _PreviewGalleryPageState extends State<PreviewGalleryPage> {
  bool _isDark = false;

  ThemeData get _theme => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: _isDark ? Brightness.dark : Brightness.light,
        ),
        useMaterial3: true,
      );

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _theme,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('UI Preview Gallery'),
          actions: [
            Tooltip(
              message: _isDark ? 'Switch to light theme' : 'Switch to dark theme',
              child: IconButton(
                icon: Icon(_isDark ? Icons.light_mode : Icons.dark_mode),
                onPressed: () => setState(() => _isDark = !_isDark),
              ),
            ),
          ],
        ),
        body: ChangeNotifierProvider(
          // Fresh AppState: no init() called so no network requests are made.
          create: (_) => AppState(),
          child: Builder(
            builder: (context) => ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Map screen shell ──────────────────────────────────────────
                const _SectionHeader(title: 'Map Screen Shell'),
                const _MapShellPreview(),
                const SizedBox(height: 24),

                // ── Route / bottom-sheet card ─────────────────────────────────
                const _SectionHeader(title: 'Route Card – Empty State'),
                const RouteSummaryCard(),
                const SizedBox(height: 16),

                const _SectionHeader(title: 'Route Card – With Route'),
                const _RouteCardWithRoute(),
                const SizedBox(height: 16),

                const _SectionHeader(title: 'Route Card – Loading State'),
                const _RouteCardLoading(),
                const SizedBox(height: 24),

                // ── Layer toggles ─────────────────────────────────────────────
                const _SectionHeader(title: 'Layer Sheet (POI Toggles)'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Consumer<AppState>(
                      builder: (ctx, state, _) => Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SwitchListTile(
                            title: const Text('Fuel / Truck Stops'),
                            subtitle: const Text('amenity=fuel'),
                            value: state.enabledPoiLayers.contains(PoiType.fuel),
                            onChanged: (v) => state.toggleLayer(PoiType.fuel, v),
                            contentPadding: EdgeInsets.zero,
                          ),
                          SwitchListTile(
                            title: const Text('Rest Areas'),
                            subtitle: const Text('highway=rest_area'),
                            value: state.enabledPoiLayers.contains(PoiType.restArea),
                            onChanged: (v) => state.toggleLayer(PoiType.restArea, v),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── FAB / Button cluster ──────────────────────────────────────
                const _SectionHeader(title: 'Buttons & FAB Cluster'),
                const _ButtonClusterPreview(),
                const SizedBox(height: 24),

                // ── Status states ─────────────────────────────────────────────
                const _SectionHeader(title: 'Loading State'),
                const _LoadingPreview(),
                const SizedBox(height: 16),

                const _SectionHeader(title: 'Empty State'),
                const _EmptyPreview(),
                const SizedBox(height: 16),

                const _SectionHeader(title: 'Error State'),
                const _ErrorPreview(),
                const SizedBox(height: 24),

                // ── Sheets (open in modal) ────────────────────────────────────
                const _SectionHeader(title: 'Open Sheets'),
                const _SheetButtons(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// Simulates the map-screen layout shell without requiring API keys.
class _MapShellPreview extends StatelessWidget {
  const _MapShellPreview();

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        height: 220,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Map placeholder
            Container(
              color: Colors.green.shade100,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.map, size: 48, color: Colors.green),
                    SizedBox(height: 8),
                    Text(
                      'Map Placeholder\n(Google Maps not shown in preview)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.green),
                    ),
                  ],
                ),
              ),
            ),
            // Weather pill overlay
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Partly Cloudy • 18.5°C • 3.2 m/s',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Route card with a pre-populated route for the "with route" preview.
class _RouteCardWithRoute extends StatelessWidget {
  const _RouteCardWithRoute();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Distance: 142.3 mi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text('Duration: 2h 18m', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: null,
                  tooltip: 'Clear route',
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.place),
                label: const Text('Load POIs Near Me (4)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Route card in loading state.
class _RouteCardLoading extends StatelessWidget {
  const _RouteCardLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

/// Buttons and FAB cluster preview.
class _ButtonClusterPreview extends StatelessWidget {
  const _ButtonClusterPreview();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.my_location),
              label: const Text('My Location'),
            ),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.layers),
              label: const Text('Layers'),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.tune),
              label: const Text('Truck Profile'),
            ),
            FilledButton(
              onPressed: () {},
              child: const Text('Calculate Route'),
            ),
            FloatingActionButton.small(
              onPressed: () {},
              heroTag: 'preview_fab_location',
              tooltip: 'My location',
              child: const Icon(Icons.my_location),
            ),
            FilterChip(
              label: const Text('Fuel'),
              selected: true,
              onSelected: (_) {},
            ),
            FilterChip(
              label: const Text('Rest Areas'),
              selected: false,
              onSelected: (_) {},
            ),
            FilterChip(
              label: const Text('Hazmat'),
              selected: false,
              onSelected: (_) {},
            ),
          ],
        ),
      ),
    );
  }
}

/// Loading state placeholder.
class _LoadingPreview extends StatelessWidget {
  const _LoadingPreview();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: const Padding(
        padding: EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Fetching route…'),
            ],
          ),
        ),
      ),
    );
  }
}

/// Empty state placeholder.
class _EmptyPreview extends StatelessWidget {
  const _EmptyPreview();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.map_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 12),
              const Text(
                'Long-press on map to set destination and calculate route',
                textAlign: TextAlign.center,
                style: TextStyle(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Error state placeholder.
class _ErrorPreview extends StatelessWidget {
  const _ErrorPreview();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Route error: Unable to reach HERE Routing API.'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Buttons that open the real modal bottom sheets.
class _SheetButtons extends StatelessWidget {
  const _SheetButtons();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        OutlinedButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            builder: (_) => ChangeNotifierProvider(
              create: (_) => AppState(),
              child: const LayerSheet(),
            ),
          ),
          child: const Text('Layer Sheet'),
        ),
        OutlinedButton(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            isScrollControlled: true,
            builder: (_) => ChangeNotifierProvider(
              create: (_) => AppState(),
              child: const TruckProfileSheet(),
            ),
          ),
          child: const Text('Truck Profile Sheet'),
        ),
      ],
    );
  }
}

/// Standalone helper used by tests to create a [PreviewGalleryPage]
/// wrapped in the minimal widget tree it needs.
Widget buildPreviewGalleryApp() {
  return const MaterialApp(home: PreviewGalleryPage());
}

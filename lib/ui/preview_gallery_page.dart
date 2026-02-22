import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/poi.dart';
import '../state/app_state.dart';
import 'theme/app_theme.dart';
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

  ThemeData get _theme => _isDark ? AppTheme.dark : AppTheme.light;

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
              padding: const EdgeInsets.all(AppTheme.spaceMD),
              children: [
                // ── Map screen shell ──────────────────────────────────────────
                const _SectionHeader(title: 'Map Screen Shell'),
                const _MapShellPreview(),
                const SizedBox(height: AppTheme.spaceLG),

                // ── Route / bottom-sheet card ─────────────────────────────────
                const _SectionHeader(title: 'Route Card – Empty State'),
                const RouteSummaryCard(),
                const SizedBox(height: AppTheme.spaceMD),

                const _SectionHeader(title: 'Route Card – With Route'),
                const _RouteCardWithRoute(),
                const SizedBox(height: AppTheme.spaceMD),

                const _SectionHeader(title: 'Route Card – Loading State'),
                const _RouteCardLoading(),
                const SizedBox(height: AppTheme.spaceLG),

                // ── Layer toggles ─────────────────────────────────────────────
                const _SectionHeader(title: 'Layer Sheet (POI Toggles)'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppTheme.spaceSM),
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
                const SizedBox(height: AppTheme.spaceLG),

                // ── FAB / Button cluster ──────────────────────────────────────
                const _SectionHeader(title: 'Buttons & FAB Cluster'),
                const _ButtonClusterPreview(),
                const SizedBox(height: AppTheme.spaceLG),

                // ── Status states ─────────────────────────────────────────────
                const _SectionHeader(title: 'Loading State'),
                const _LoadingPreview(),
                const SizedBox(height: AppTheme.spaceMD),

                const _SectionHeader(title: 'Empty State'),
                const _EmptyPreview(),
                const SizedBox(height: AppTheme.spaceMD),

                const _SectionHeader(title: 'Error State'),
                const _ErrorPreview(),
                const SizedBox(height: AppTheme.spaceLG),

                // ── Sheets (open in modal) ────────────────────────────────────
                const _SectionHeader(title: 'Open Sheets'),
                const _SheetButtons(),
                const SizedBox(height: AppTheme.spaceXL + AppTheme.spaceSM),
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
      padding: const EdgeInsets.only(bottom: AppTheme.spaceSM),
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
                    SizedBox(height: AppTheme.spaceSM),
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
              top: AppTheme.spaceMD,
              left: AppTheme.spaceMD,
              right: AppTheme.spaceMD,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                    vertical: AppTheme.spaceXS + 2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.cloud_outlined, size: 18),
                      const SizedBox(width: AppTheme.spaceSM),
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
      elevation: AppTheme.elevationSheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.route_rounded,
                    color: Theme.of(context).colorScheme.primary, size: 28),
                const SizedBox(width: AppTheme.spaceMD),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '142.3 mi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(height: AppTheme.spaceXS),
                      Text('2h 18m', style: TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: null,
                  tooltip: 'Clear route',
                ),
              ],
            ),
            const Divider(height: AppTheme.spaceLG),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.place_rounded),
                label: const Text('Nearby POIs (4)'),
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
      elevation: AppTheme.elevationSheet,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.radiusLG)),
      ),
      child: Padding(
        padding: EdgeInsets.all(AppTheme.spaceXL),
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
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Wrap(
          spacing: AppTheme.spaceMD,
          runSpacing: AppTheme.spaceMD,
          children: [
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.my_location_rounded),
              label: const Text('My Location'),
            ),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.layers_rounded),
              label: const Text('Layers'),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.local_shipping_rounded),
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
              child: const Icon(Icons.my_location_rounded),
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
        padding: EdgeInsets.all(AppTheme.spaceXL),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: AppTheme.spaceMD),
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
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app_rounded,
                size: 48,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: AppTheme.spaceMD),
              const Text(
                'Long-press anywhere on the map to set a destination',
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
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
            const SizedBox(width: AppTheme.spaceMD),
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
      spacing: AppTheme.spaceMD,
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

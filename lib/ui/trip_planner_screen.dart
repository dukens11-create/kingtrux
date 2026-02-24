import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/trip.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Trip planner screen — lists saved trips and allows creating / editing them.
class TripPlannerScreen extends StatelessWidget {
  const TripPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.map_rounded, size: 22),
            SizedBox(width: AppTheme.spaceSM),
            Text('Trip Planner'),
          ],
        ),
      ),
      body: Consumer<AppState>(
        builder: (context, state, _) {
          if (state.savedTrips.isEmpty) {
            return _buildEmptyState(context);
          }
          return _TripList(trips: state.savedTrips);
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _createTrip(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Trip'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 72, color: cs.outlineVariant),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              'No trips yet',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              'Tap + New Trip to plan your first multi-stop route.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _createTrip(BuildContext context) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<AppState>(),
          child: const _TripEditorScreen(trip: null),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Trip list
// ---------------------------------------------------------------------------

class _TripList extends StatelessWidget {
  const _TripList({required this.trips});
  final List<Trip> trips;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceSM),
      itemCount: trips.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final trip = trips[index];
        return _TripTile(trip: trip);
      },
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final state = context.read<AppState>();
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.primaryContainer,
        child: Icon(Icons.route_rounded,
            color: cs.onPrimaryContainer, size: 20),
      ),
      title: Text(trip.name),
      subtitle: Text('${trip.stops.length} stop${trip.stops.length == 1 ? '' : 's'}'
          '${_etaSummary(trip)}'),
      trailing: PopupMenuButton<_TripAction>(
        onSelected: (action) {
          HapticFeedback.selectionClick();
          if (action == _TripAction.edit) {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ChangeNotifierProvider.value(
                  value: state,
                  child: _TripEditorScreen(trip: trip),
                ),
              ),
            );
          } else {
            state.deleteTrip(trip.id);
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(
            value: _TripAction.edit,
            child: ListTile(
              leading: Icon(Icons.edit_rounded),
              title: Text('Edit'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
          PopupMenuItem(
            value: _TripAction.delete,
            child: ListTile(
              leading: Icon(Icons.delete_outline_rounded),
              title: Text('Delete'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder: (_) => ChangeNotifierProvider.value(
              value: state,
              child: _TripEditorScreen(trip: trip),
            ),
          ),
        );
      },
    );
  }

  String _etaSummary(Trip trip) {
    if (trip.totalDistanceMeters == null || trip.totalDurationSeconds == null) {
      return '';
    }
    final km = (trip.totalDistanceMeters! / 1000).toStringAsFixed(1);
    final h = trip.totalDurationSeconds! ~/ 3600;
    final m = (trip.totalDurationSeconds! % 3600) ~/ 60;
    final dur = h > 0 ? '${h}h ${m}m' : '${m}m';
    return ' · $km km · $dur';
  }
}

enum _TripAction { edit, delete }

// ---------------------------------------------------------------------------
// Trip editor
// ---------------------------------------------------------------------------

class _TripEditorScreen extends StatefulWidget {
  const _TripEditorScreen({required this.trip});

  /// Pass `null` to create a new trip.
  final Trip? trip;

  @override
  State<_TripEditorScreen> createState() => _TripEditorScreenState();
}

class _TripEditorScreenState extends State<_TripEditorScreen> {
  late final TextEditingController _nameController;
  late List<TripStop> _stops;

  @override
  void initState() {
    super.initState();
    _nameController =
        TextEditingController(text: widget.trip?.name ?? 'New Trip');
    _stops = List.of(widget.trip?.stops ?? []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _hasChanges {
    final orig = widget.trip;
    if (orig == null) return true;
    if (orig.name != _nameController.text) return true;
    if (orig.stops.length != _stops.length) return true;
    for (var i = 0; i < _stops.length; i++) {
      if (_stops[i].id != orig.stops[i].id) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.trip == null ? 'New Trip' : 'Edit Trip'),
        actions: [
          TextButton(
            onPressed: _saveTrip,
            child: const Text('Save'),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Trip name ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Trip name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.label_rounded),
              ),
              textInputAction: TextInputAction.done,
            ),
          ),

          // ── Stop list ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMD),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Stops', style: tt.titleSmall),
                TextButton.icon(
                  onPressed: _addStop,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add Stop'),
                ),
              ],
            ),
          ),

          Expanded(
            child: _stops.isEmpty
                ? Center(
                    child: Text(
                      'Add at least two stops to plan a route.',
                      style: tt.bodyMedium
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  )
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spaceSM),
                    itemCount: _stops.length,
                    onReorder: (oldIdx, newIdx) {
                      setState(() {
                        if (newIdx > oldIdx) newIdx--;
                        final s = _stops.removeAt(oldIdx);
                        _stops.insert(newIdx, s);
                      });
                    },
                    itemBuilder: (context, index) {
                      final stop = _stops[index];
                      return ListTile(
                        key: ValueKey(stop.id),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: cs.primaryContainer,
                          child: Text(
                            '${index + 1}',
                            style: tt.labelLarge?.copyWith(
                              color: cs.onPrimaryContainer,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(stop.label),
                        subtitle: Text(
                          '${stop.lat.toStringAsFixed(4)}, '
                          '${stop.lng.toStringAsFixed(4)}',
                          style: tt.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 20),
                              color: cs.error,
                              tooltip: 'Remove stop',
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                setState(() => _stops.removeAt(index));
                              },
                            ),
                            const Icon(Icons.drag_handle_rounded),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  void _addStop() {
    // Show a simple dialog to enter coordinates.
    // In a full implementation this would open a map picker.
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final latCtrl = TextEditingController();
        final lngCtrl = TextEditingController();
        final labelCtrl = TextEditingController();
        return AlertDialog(
          title: const Text('Add Stop'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: labelCtrl,
                decoration: const InputDecoration(labelText: 'Label / name'),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppTheme.spaceSM),
              TextField(
                controller: latCtrl,
                decoration: const InputDecoration(labelText: 'Latitude'),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: AppTheme.spaceSM),
              TextField(
                controller: lngCtrl,
                decoration: const InputDecoration(labelText: 'Longitude'),
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true, signed: true),
                textInputAction: TextInputAction.done,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final lat = double.tryParse(latCtrl.text);
                final lng = double.tryParse(lngCtrl.text);
                if (lat == null || lng == null) return;
                final label = labelCtrl.text.isEmpty
                    ? 'Stop ${_stops.length + 1}'
                    : labelCtrl.text;
                setState(() {
                  _stops.add(TripStop(
                    id: '${DateTime.now().millisecondsSinceEpoch}',
                    label: label,
                    lat: lat,
                    lng: lng,
                  ));
                });
                Navigator.pop(ctx);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _saveTrip() {
    final state = context.read<AppState>();
    final trip = Trip(
      id: widget.trip?.id ?? '${DateTime.now().millisecondsSinceEpoch}',
      name: _nameController.text.trim().isEmpty
          ? 'Trip'
          : _nameController.text.trim(),
      stops: _stops,
    );
    state.saveTrip(trip);
    if (context.mounted) Navigator.of(context).pop();
  }
}

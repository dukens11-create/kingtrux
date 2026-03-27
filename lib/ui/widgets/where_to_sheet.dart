import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/trip_stop.dart';
import '../../services/here_geocoding_service.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Bottom sheet that lets the driver pick one or more destinations by typing
/// an address or place name.
///
/// ## Multi-stop flow (A → B → C)
/// 1. Type an address and tap the search arrow.
/// 2. Tap **Add Stop** on the result card — the stop is appended to the list
///    and the search field clears so another can be entered.
/// 3. Repeat for every destination.
/// 4. Tap **Build Route** to call [AppState.buildTruckRoute] and close the
///    sheet.  The start point is always the current GPS location.
///
/// A single-stop route works exactly as before: add one stop, then tap
/// **Build Route**.
///
/// Long-pressing the map still sets a single destination (clears any stops and
/// uses [AppState.setDestination] directly) — that behavior is unchanged.
class WhereToSheet extends StatefulWidget {
  const WhereToSheet({super.key});

  @override
  State<WhereToSheet> createState() => _WhereToSheetState();
}

class _WhereToSheetState extends State<WhereToSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _geocodingService = HereGeocodingService();

  bool _isSearching = false;
  String? _errorMessage;
  GeocodedLocation? _result;

  @override
  void initState() {
    super.initState();
    // Auto-focus the text field when the sheet opens.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNode.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _onSearch() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _result = null;
    });
    final location = await _geocodingService.geocode(query);
    if (!mounted) return;
    if (location == null) {
      setState(() {
        _isSearching = false;
        _errorMessage = 'No results found. Try a more specific address.';
      });
    } else {
      setState(() {
        _isSearching = false;
        _result = location;
      });
    }
  }

  /// Add the geocoded [location] to the route-stop list and reset the search
  /// field so the driver can search for the next stop.
  void _onAddStop(GeocodedLocation location) {
    HapticFeedback.selectionClick();
    context.read<AppState>().addRouteStop(
          location.lat,
          location.lng,
          label: location.label,
        );
    setState(() {
      _result = null;
      _errorMessage = null;
    });
    _controller.clear();
    _focusNode.requestFocus();
  }

  /// Build the route through the current stop list and close the sheet.
  Future<void> _onBuildRoute() async {
    HapticFeedback.mediumImpact();
    final state = context.read<AppState>();
    // Pop before building route so the map is visible during calculation.
    if (mounted) Navigator.of(context).pop();
    try {
      await state.buildTruckRoute();
    } catch (_) {
      // Errors are handled inside buildTruckRoute / AppState.
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Consumer<AppState>(
          builder: (context, state, _) {
            final stops = state.routeStops;
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  AppTheme.spaceMD,
                  AppTheme.spaceSM,
                  AppTheme.spaceMD,
                  MediaQuery.of(context).viewInsets.bottom + AppTheme.spaceMD,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sheet handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppTheme.spaceMD),
                        decoration: BoxDecoration(
                          color: cs.outlineVariant,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),

                    Text('Where to?', style: tt.titleLarge),
                    const SizedBox(height: AppTheme.spaceMD),

                    // ── Search field ──────────────────────────────────────────
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const Key('where_to_field'),
                            controller: _controller,
                            focusNode: _focusNode,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _onSearch(),
                            decoration: InputDecoration(
                              hintText: 'Enter address or place name',
                              prefixIcon: const Icon(Icons.search_rounded),
                              border: OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(AppTheme.radiusLG),
                              ),
                              filled: true,
                              fillColor: cs.surfaceContainerHighest,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AppTheme.spaceMD,
                                vertical: AppTheme.spaceSM,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTheme.spaceSM),
                        FilledButton(
                          key: const Key('where_to_search_btn'),
                          onPressed: _isSearching ? null : _onSearch,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.all(AppTheme.spaceMD),
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppTheme.radiusLG),
                            ),
                          ),
                          child: _isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.arrow_forward_rounded),
                        ),
                      ],
                    ),

                    // ── Error message ─────────────────────────────────────────
                    if (_errorMessage != null) ...[
                      const SizedBox(height: AppTheme.spaceSM),
                      Row(
                        children: [
                          Icon(Icons.warning_rounded,
                              size: 16, color: cs.error),
                          const SizedBox(width: AppTheme.spaceXS),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: tt.bodySmall?.copyWith(color: cs.error),
                            ),
                          ),
                        ],
                      ),
                    ],

                    // ── Geocoded result ───────────────────────────────────────
                    if (_result != null) ...[
                      const SizedBox(height: AppTheme.spaceMD),
                      _ResultCard(
                        location: _result!,
                        onAddStop: () => _onAddStop(_result!),
                      ),
                    ],

                    // ── Added stops list ──────────────────────────────────────
                    if (stops.isNotEmpty) ...[
                      const SizedBox(height: AppTheme.spaceMD),
                      Text(
                        'Stops (${stops.length})',
                        style: tt.labelLarge,
                      ),
                      const SizedBox(height: AppTheme.spaceXS),
                      ...stops.asMap().entries.map(
                            (e) => _StopTile(
                              key: ValueKey(e.value.id),
                              index: e.key,
                              stop: e.value,
                              onRemove: () =>
                                  state.removeRouteStop(e.key),
                            ),
                          ),
                      const SizedBox(height: AppTheme.spaceMD),
                      // ── Build Route button ──────────────────────────────
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('where_to_build_route_btn'),
                          onPressed: state.isLoadingRoute ? null : _onBuildRoute,
                          icon: state.isLoadingRoute
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.directions_rounded),
                          label: Text(
                            stops.length == 1
                                ? 'Build Route'
                                : 'Build Route (${stops.length} stops)',
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: AppTheme.spaceMD),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Geocoded result card
// ---------------------------------------------------------------------------

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.location, required this.onAddStop});

  final GeocodedLocation location;
  final VoidCallback onAddStop;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      margin: EdgeInsets.zero,
      color: cs.primaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: ListTile(
        leading: Icon(Icons.place_rounded, color: cs.onPrimaryContainer),
        title: Text(
          location.label,
          style: tt.bodyMedium?.copyWith(color: cs.onPrimaryContainer),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${location.lat.toStringAsFixed(5)}, '
          '${location.lng.toStringAsFixed(5)}',
          style: tt.bodySmall
              ?.copyWith(color: cs.onPrimaryContainer.withValues(alpha: 0.7)),
        ),
        trailing: FilledButton.icon(
          key: const Key('where_to_add_stop_btn'),
          onPressed: onAddStop,
          icon: const Icon(Icons.add_location_alt_rounded, size: 18),
          label: const Text('Add Stop'),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Added stop tile (shows label + remove button)
// ---------------------------------------------------------------------------

class _StopTile extends StatelessWidget {
  const _StopTile({
    super.key,
    required this.index,
    required this.stop,
    required this.onRemove,
  });

  final int index;
  final TripStop stop;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceXS),
      child: Row(
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: cs.primary,
            child: Text(
              '${index + 1}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: cs.onPrimary,
              ),
            ),
          ),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: Text(
              stop.label ?? '${stop.lat.toStringAsFixed(4)}, '
                  '${stop.lng.toStringAsFixed(4)}',
              style: tt.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            key: Key('remove_stop_$index'),
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: onRemove,
            tooltip: 'Remove stop',
          ),
        ],
      ),
    );
  }
}

/// Shows the [WhereToSheet] as a modal bottom sheet.
Future<void> showWhereToSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const WhereToSheet(),
  );
}

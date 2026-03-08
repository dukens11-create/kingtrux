import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/weigh_station.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';

/// Bottom sheet listing nearby weigh / commercial-vehicle inspection stations
/// for the USA and Canada.
///
/// Features:
/// • Search bar filtering station names, highway, and state/province codes.
/// • Country filter chips (All / USA / Canada).
/// • Station list sorted by distance from the driver, with distance shown.
/// • Tap a row to open an inline detail card with status, highway, hours,
///   facilities, and a "Navigate" action.
/// • "Load Stations" button triggers [AppState.loadWeighStations].
///
/// ## Data providers
/// The default provider ships a curated static baseline with
/// [WeighStationStatus.unknown] status.  Register a real-time provider on
/// [WeighStationService] to display live enforcement status.
class WeighStationsSheet extends StatefulWidget {
  const WeighStationsSheet({super.key});

  @override
  State<WeighStationsSheet> createState() => _WeighStationsSheetState();
}

class _WeighStationsSheetState extends State<WeighStationsSheet> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  /// `null` = show all countries, `'US'` = US only, `'CA'` = Canada only.
  String? _countryFilter;

  /// Station currently shown in the detail panel; `null` = list mode.
  WeighStation? _selectedStation;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(
        () => _searchQuery = _searchController.text.trim().toLowerCase(),
      );
    });
    // Kick off the initial load if no stations are cached yet.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final state = context.read<AppState>();
      if (state.weighStations.isEmpty && !state.isLoadingWeighStations) {
        state.loadWeighStations();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Filtering
  // ---------------------------------------------------------------------------

  List<WeighStation> _filtered(AppState state) {
    var stations = state.weighStations;

    if (_countryFilter != null) {
      stations =
          stations.where((s) => s.country == _countryFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      stations = stations.where((s) {
        return s.name.toLowerCase().contains(_searchQuery) ||
            (s.stateOrProvince?.toLowerCase().contains(_searchQuery) ?? false) ||
            (s.highway?.toLowerCase().contains(_searchQuery) ?? false) ||
            (s.direction?.toLowerCase().contains(_searchQuery) ?? false);
      }).toList();
    }

    return stations;
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _formatDistance(double distMeters, bool metric) {
    if (metric) {
      if (distMeters < 1000) return '${distMeters.round()} m';
      return '${(distMeters / 1000).toStringAsFixed(1)} km';
    } else {
      final feet = distMeters * 3.28084;
      if (feet < 1000) return '${feet.round()} ft';
      final miles = feet / 5280;
      return '${miles.toStringAsFixed(1)} mi';
    }
  }

  Color _statusColor(WeighStationStatus status, ColorScheme cs) {
    return status.color;
  }

  IconData _statusIcon(WeighStationStatus status) {
    switch (status) {
      case WeighStationStatus.openBypass:
        return Icons.directions_car_rounded;
      case WeighStationStatus.openGoingThrough:
        return Icons.warning_amber_rounded;
      case WeighStationStatus.monitoring:
        return Icons.visibility_rounded;
      case WeighStationStatus.closed:
        return Icons.check_circle_rounded;
      case WeighStationStatus.unknown:
        return Icons.help_outline_rounded;
    }
  }

  /// Human-readable "updated X minutes ago" or "Last updated: …" label.
  String? _lastUpdatedLabel(WeighStation station) {
    final ts = station.statusUpdatedAt;
    if (ts == null) return null;
    final diff = DateTime.now().difference(ts);
    if (diff.inMinutes < 1) return 'Updated just now';
    if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} min ago';
    if (diff.inHours < 24) return 'Updated ${diff.inHours} h ago';
    return 'Updated ${diff.inDays} d ago';
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final stations = _filtered(state);
        final cs = Theme.of(context).colorScheme;

        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.35,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                // ── Drag handle ──────────────────────────────────────────────
                const SizedBox(height: AppTheme.spaceSM),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: AppTheme.spaceSM),

                // ── Title row ────────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spaceMD,
                  ),
                  child: Row(
                    children: [
                      if (_selectedStation != null)
                        IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          tooltip: 'Back to list',
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedStation = null);
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      if (_selectedStation != null)
                        const SizedBox(width: AppTheme.spaceXS),
                      Icon(Icons.scale_rounded, color: cs.primary),
                      const SizedBox(width: AppTheme.spaceXS),
                      Expanded(
                        child: Text(
                          _selectedStation != null
                              ? _selectedStation!.name
                              : 'Weigh Stations',
                          style:
                              Theme.of(context).textTheme.headlineSmall,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (state.isLoadingWeighStations &&
                          _selectedStation == null)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: AppTheme.spaceSM),

                if (_selectedStation != null) ...[
                  // ── Detail card ──────────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(
                        AppTheme.spaceMD,
                        0,
                        AppTheme.spaceMD,
                        AppTheme.spaceMD,
                      ),
                      child: _buildDetailCard(
                        context,
                        state,
                        cs,
                        _selectedStation!,
                      ),
                    ),
                  ),
                ] else ...[
                  // ── Search bar ─────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD,
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search stations, highway…',
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon:
                                    const Icon(Icons.clear_rounded, size: 18),
                                onPressed: _searchController.clear,
                              )
                            : null,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSM),

                  // ── Country filter chips ───────────────────────────────
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppTheme.spaceMD,
                      ),
                      children: [
                        _CountryChip(
                          label: 'All',
                          selected: _countryFilter == null,
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(() => _countryFilter = null);
                          },
                        ),
                        const SizedBox(width: AppTheme.spaceXS),
                        _CountryChip(
                          label: '🇺🇸 USA',
                          selected: _countryFilter == 'US',
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(
                              () => _countryFilter =
                                  _countryFilter == 'US' ? null : 'US',
                            );
                          },
                        ),
                        const SizedBox(width: AppTheme.spaceXS),
                        _CountryChip(
                          label: '🇨🇦 Canada',
                          selected: _countryFilter == 'CA',
                          onSelected: (_) {
                            HapticFeedback.selectionClick();
                            setState(
                              () => _countryFilter =
                                  _countryFilter == 'CA' ? null : 'CA',
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTheme.spaceSM),

                  // ── Reload button ──────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTheme.spaceMD,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        icon:
                            const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text('Load Stations Near Me'),
                        onPressed: state.isLoadingWeighStations
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                state.loadWeighStations();
                              },
                      ),
                    ),
                  ),

                  const Divider(height: AppTheme.spaceLG),

                  // ── Station list ───────────────────────────────────────
                  Expanded(
                    child: stations.isEmpty
                        ? _buildEmptyState(context, state, cs)
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: stations.length,
                            itemBuilder: (context, index) =>
                                _buildStationTile(
                              context,
                              state,
                              cs,
                              stations[index],
                            ),
                          ),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Station list tile
  // ---------------------------------------------------------------------------

  Widget _buildStationTile(
    BuildContext context,
    AppState state,
    ColorScheme cs,
    WeighStation station,
  ) {
    String? distanceLabel;
    if (state.myLat != null && state.myLng != null) {
      final dist =
          station.distanceFromMeters(state.myLat!, state.myLng!);
      distanceLabel = _formatDistance(dist, state.useMetricUnits);
    }

    final subtitle = [
      if (station.stateOrProvince != null)
        '${station.country} · ${station.stateOrProvince}',
      if (station.highway != null) station.highway!,
      if (station.direction != null) station.direction!,
      if (distanceLabel != null) distanceLabel,
    ].join('  •  ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.secondaryContainer,
        child: Icon(
          Icons.scale_rounded,
          color: cs.onSecondaryContainer,
          size: 18,
        ),
      ),
      title: Text(
        station.name,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: subtitle.isNotEmpty ? Text(subtitle) : null,
      trailing: Icon(
        _statusIcon(station.effectiveStatus),
        size: 18,
        color: _statusColor(station.effectiveStatus, cs),
      ),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedStation = station);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Detail card
  // ---------------------------------------------------------------------------

  Widget _buildDetailCard(
    BuildContext context,
    AppState state,
    ColorScheme cs,
    WeighStation station,
  ) {
    final tt = Theme.of(context).textTheme;

    String? distanceLabel;
    if (state.myLat != null && state.myLng != null) {
      final dist =
          station.distanceFromMeters(state.myLat!, state.myLng!);
      distanceLabel = _formatDistance(dist, state.useMetricUnits);
    }

    return Card(
      elevation: 0,
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status badge
            Row(
              children: [
                Icon(
                  _statusIcon(station.effectiveStatus),
                  size: 20,
                  color: _statusColor(station.effectiveStatus, cs),
                ),
                const SizedBox(width: AppTheme.spaceXS),
                Text(
                  station.statusLabel,
                  style: tt.titleMedium?.copyWith(
                    color: _statusColor(station.effectiveStatus, cs),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (station.effectiveStatus == WeighStationStatus.unknown) ...[
                  const SizedBox(width: AppTheme.spaceXS),
                  Tooltip(
                    message:
                        'No recent crowdsourced report. '
                        'Status is shown as Unknown when no report '
                        'within the last 60 minutes exists.',
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),

            // Last-updated label
            if (_lastUpdatedLabel(station) != null) ...[
              const SizedBox(height: 2),
              Text(
                _lastUpdatedLabel(station)!,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],

            // Stale warning
            if (station.isStale && station.statusUpdatedAt != null) ...[
              const SizedBox(height: AppTheme.spaceXS),
              Row(
                children: [
                  Icon(Icons.timer_off_outlined,
                      size: 13, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Report older than 60 min — displayed as Unknown.',
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: AppTheme.spaceMD),

            // Distance from driver
            if (distanceLabel != null)
              _DetailRow(
                icon: Icons.near_me_rounded,
                label: 'Distance',
                value: distanceLabel,
              ),

            // Highway / route
            if (station.highway != null)
              _DetailRow(
                icon: Icons.route_rounded,
                label: 'Highway',
                value: station.highway!,
              ),

            // Direction
            if (station.direction != null)
              _DetailRow(
                icon: Icons.navigation_rounded,
                label: 'Direction',
                value: station.direction!,
              ),

            // State / Province
            if (station.stateOrProvince != null)
              _DetailRow(
                icon: Icons.location_on_outlined,
                label: 'Jurisdiction',
                value:
                    '${station.country} · ${station.stateOrProvince}',
              ),

            // Facilities
            if (station.facilities != null)
              _DetailRow(
                icon: Icons.build_outlined,
                label: 'Facilities',
                value: station.facilities!,
              ),

            // Hours
            if (station.hours != null)
              _DetailRow(
                icon: Icons.schedule_rounded,
                label: 'Hours',
                value: station.hours!,
              ),

            // Data source
            if (station.source != null) ...[
              const SizedBox(height: AppTheme.spaceXS),
              Text(
                'Source: ${station.source}',
                style: tt.bodySmall
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],

            if (station.effectiveStatus == WeighStationStatus.unknown) ...[
              const SizedBox(height: AppTheme.spaceSM),
              Container(
                padding: const EdgeInsets.all(AppTheme.spaceXS),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerLow,
                  borderRadius:
                      BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppTheme.spaceXS),
                    Expanded(
                      child: Text(
                        'No fresh crowdsourced report. '
                        'Drive past the station to report its status '
                        'and help other drivers.',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Empty state
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState(
    BuildContext context,
    AppState state,
    ColorScheme cs,
  ) {
    final String msg;
    if (state.isLoadingWeighStations) {
      msg = 'Loading stations…';
    } else if (state.weighStationError != null) {
      msg = 'Error: ${state.weighStationError}\n\n'
          'Tap "Load Stations Near Me" to retry.';
    } else if (_searchQuery.isNotEmpty || _countryFilter != null) {
      msg = 'No stations match the current filter.\n'
          'Try clearing the search or filter.';
    } else {
      msg = 'No stations loaded yet.\n'
          'Tap "Load Stations Near Me" to search.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Private helper widgets
// ---------------------------------------------------------------------------

class _CountryChip extends StatelessWidget {
  const _CountryChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: onSelected,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spaceXS),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: cs.onSurfaceVariant),
          const SizedBox(width: AppTheme.spaceXS),
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Expanded(
            child: Text(value, style: tt.bodyMedium),
          ),
        ],
      ),
    );
  }
}

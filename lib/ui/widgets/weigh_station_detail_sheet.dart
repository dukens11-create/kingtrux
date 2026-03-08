import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import '../../models/weigh_station.dart';
import '../../state/app_state.dart';
import '../theme/app_theme.dart';
import 'navigation_utils.dart';

/// Bottom sheet that displays detail for a single [WeighStation].
///
/// Shows the station name, operational status badge, location info, and
/// a one-tap Navigate button.  The status chip uses traffic-light colours
/// so drivers can instantly gauge whether the station is open or closed.
class WeighStationDetailSheet extends StatelessWidget {
  const WeighStationDetailSheet({super.key, required this.station});

  final WeighStation station;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final state = context.read<AppState>();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppTheme.spaceMD,
          AppTheme.spaceSM,
          AppTheme.spaceMD,
          AppTheme.spaceMD,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: cs.primaryContainer,
                  child: Icon(
                    Icons.local_police_rounded,
                    color: cs.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: AppTheme.spaceMD),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        station.name,
                        style: tt.titleMedium,
                      ),
                      Text(
                        'Weigh Station',
                        style: tt.bodySmall?.copyWith(color: cs.primary),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: AppTheme.spaceLG),

            // ── Status badge ─────────────────────────────────────────────────
            _StatusBadge(status: station.status),

            const SizedBox(height: AppTheme.spaceMD),

            // ── Info rows ────────────────────────────────────────────────────
            ..._buildInfoRows(context, cs, state),

            const SizedBox(height: AppTheme.spaceMD),

            // ── Navigate button ──────────────────────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.navigation_rounded, size: 18),
                label: const Text('Navigate'),
                onPressed: () async {
                  HapticFeedback.mediumImpact();
                  Navigator.of(context).pop();
                  state.setDestination(station.lat, station.lng);
                  try {
                    await state.buildTruckRoute();
                  } catch (_) {
                    // Route errors are surfaced via state.routeError.
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildInfoRows(
    BuildContext context,
    ColorScheme cs,
    AppState state,
  ) {
    final tt = Theme.of(context).textTheme;
    final rows = <Widget>[];

    void addRow(IconData icon, String label, String? value) {
      if (value == null || value.isEmpty) return;
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXS),
          child: Row(
            children: [
              Icon(icon, size: 16, color: cs.onSurfaceVariant),
              const SizedBox(width: AppTheme.spaceSM),
              Text(
                label,
                style:
                    tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: AppTheme.spaceSM),
              Expanded(
                child: Text(
                  value,
                  style: tt.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );
    }

    addRow(Icons.signpost_rounded, 'Highway', station.highway);
    addRow(Icons.map_rounded, 'State / Province', station.stateOrProvince);
    addRow(Icons.navigation_rounded, 'Direction', station.direction);
    addRow(Icons.info_outline_rounded, 'Notes', station.description);

    // Distance from current location.
    if (state.myLat != null && state.myLng != null) {
      final distM = Geolocator.distanceBetween(
        state.myLat!,
        state.myLng!,
        station.lat,
        station.lng,
      );
      addRow(
        Icons.straighten_rounded,
        'Distance',
        formatPoiDistance(distM),
      );
    }

    return rows;
  }
}

/// Coloured status chip displayed in [WeighStationDetailSheet].
class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final WeighStationStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          _icon,
          size: 18,
          color: _color(cs),
        ),
        const SizedBox(width: AppTheme.spaceXS),
        Text(
          _label,
          style: tt.bodyMedium?.copyWith(
            color: _color(cs),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  String get _label {
    switch (status) {
      case WeighStationStatus.open:
        return 'OPEN — proceed for inspection';
      case WeighStationStatus.closed:
        return 'CLOSED — bypass permitted';
      case WeighStationStatus.monitored:
        return 'MONITORED — portable scales may be present';
      case WeighStationStatus.unknown:
        return 'Status unknown';
    }
  }

  IconData get _icon {
    switch (status) {
      case WeighStationStatus.open:
        return Icons.warning_amber_rounded;
      case WeighStationStatus.closed:
        return Icons.check_circle_outline_rounded;
      case WeighStationStatus.monitored:
        return Icons.visibility_rounded;
      case WeighStationStatus.unknown:
        return Icons.help_outline_rounded;
    }
  }

  Color _color(ColorScheme cs) {
    switch (status) {
      case WeighStationStatus.open:
        return cs.error;
      case WeighStationStatus.closed:
        return cs.primary;
      case WeighStationStatus.monitored:
        return cs.tertiary;
      case WeighStationStatus.unknown:
        return cs.onSurfaceVariant;
    }
  }
}

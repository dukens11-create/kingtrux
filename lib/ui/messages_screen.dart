import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/scale_report.dart';
import '../services/firestore_scale_report_service.dart';
import '../state/app_state.dart';
import 'account_screen.dart';
import 'settings_screen.dart';
import 'theme/app_theme.dart';
import 'weigh_station_status_screen.dart';

/// Full-screen Messages hub shown when the driver taps the Messages toolbar
/// button on the map.
///
/// Layout:
///   - AppBar: title "Messages" + profile + settings actions
///   - Quick-action strip: Announcement / Files / Static Link
///   - Scrollable category list (icons + title + subtitle + optional badge)
///   - "Weigh Station Status" row with live Firestore data
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle_outlined),
            tooltip: 'Profile',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const AccountScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Quick-action strip ─────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTheme.spaceMD,
              vertical: AppTheme.spaceMD,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _QuickActionButton(
                  icon: Icons.campaign_rounded,
                  label: 'Announcement',
                  color: cs.primaryContainer,
                  iconColor: cs.onPrimaryContainer,
                ),
                _QuickActionButton(
                  icon: Icons.folder_rounded,
                  label: 'Files',
                  color: cs.secondaryContainer,
                  iconColor: cs.onSecondaryContainer,
                ),
                _QuickActionButton(
                  icon: Icons.link_rounded,
                  label: 'Static Link',
                  color: cs.tertiaryContainer,
                  iconColor: cs.onTertiaryContainer,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // ── Category list ──────────────────────────────────────────────
          Expanded(
            child: ListView(
              children: [
                _MessageCategoryRow(
                  icon: Icons.notifications_rounded,
                  color: Colors.red.shade600,
                  title: 'Announcements',
                  subtitle: 'Company-wide updates & alerts',
                  badge: '5',
                  onTap: () {},
                ),
                _MessageCategoryRow(
                  icon: Icons.folder_rounded,
                  color: Colors.blue.shade600,
                  title: 'Files',
                  subtitle: 'Documents & attachments',
                  onTap: () {},
                ),
                _MessageCategoryRow(
                  icon: Icons.route_rounded,
                  color: Colors.green.shade700,
                  title: 'Trip Updates',
                  subtitle: 'Load & route notifications',
                  onTap: () {},
                ),
                // Weigh Station Status — live Firestore data
                const _WeighStationStatusRow(),
                _MessageCategoryRow(
                  icon: Icons.list_alt_rounded,
                  color: Colors.purple.shade600,
                  title: 'Load Board',
                  subtitle: 'Available loads near you',
                  badge: '99+',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick-action button
// ---------------------------------------------------------------------------

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(40),
          onTap: () => HapticFeedback.selectionClick(),
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: iconColor),
          ),
        ),
        const SizedBox(height: AppTheme.spaceXS),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Message category row
// ---------------------------------------------------------------------------

class _MessageCategoryRow extends StatelessWidget {
  const _MessageCategoryRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  /// Optional badge string (e.g. "5" or "99+").
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceMD,
        vertical: AppTheme.spaceXS,
      ),
      leading: _CircleIcon(icon: icon, color: color),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall,
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (badge != null) _Badge(label: badge!),
          if (badge != null) const SizedBox(width: AppTheme.spaceXS),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Weigh Station Status row (live Firestore)
// ---------------------------------------------------------------------------

/// A [_MessageCategoryRow]-style tile that shows the latest community-reported
/// status for the driver's nearest weigh station.
///
/// Data is sourced from:
///   - [AppState.closestScalePoi] — the nearest scale POI
///   - [FirestoreScaleReportService.watchLatest] — live Firestore stream
///
/// The service instance and stream are cached so they survive widget rebuilds
/// without opening duplicate Firestore listeners.
///
/// Tapping navigates to [WeighStationStatusScreen] for the full detail view.
class _WeighStationStatusRow extends StatefulWidget {
  const _WeighStationStatusRow();

  @override
  State<_WeighStationStatusRow> createState() => _WeighStationStatusRowState();
}

class _WeighStationStatusRowState extends State<_WeighStationStatusRow> {
  final _service = FirestoreScaleReportService();

  /// Cached stream keyed to the current [_scaleId].
  Stream<ScaleReport?>? _stream;
  String? _scaleId;

  /// Returns a cached stream for [scaleId], creating a new one only when the
  /// scale ID changes (e.g. the driver has moved to a different scale region).
  Stream<ScaleReport?> _streamFor(String scaleId) {
    if (_scaleId != scaleId) {
      _scaleId = scaleId;
      _stream = _service.watchLatest(scaleId);
    }
    return _stream!;
  }

  void _openStatusScreen(String? scaleId) {
    HapticFeedback.selectionClick();
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) => WeighStationStatusScreen(scaleId: scaleId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, _) {
        final scale = state.closestScalePoi;

        if (scale == null) {
          // No GPS fix or no nearby scale — show a graceful fallback.
          return _MessageCategoryRow(
            icon: Icons.scale_rounded,
            color: Colors.orange.shade700,
            title: 'Weigh Station Status',
            subtitle: 'No nearby scale',
            onTap: () => _openStatusScreen(null),
          );
        }

        return StreamBuilder<ScaleReport?>(
          stream: _streamFor(scale.id),
          builder: (context, snapshot) {
            final report = snapshot.data;
            final subtitle = report != null
                ? 'Latest status: ${_statusLabel(report.status)}'
                : 'No report yet';

            return _MessageCategoryRow(
              icon: Icons.scale_rounded,
              color: Colors.orange.shade700,
              title: 'Weigh Station Status',
              subtitle: subtitle,
              onTap: () => _openStatusScreen(scale.id),
            );
          },
        );
      },
    );
  }

  static String _statusLabel(ScaleStatus status) {
    switch (status) {
      case ScaleStatus.open:
        return 'OPEN';
      case ScaleStatus.monitoring:
        return 'MONITORING';
      case ScaleStatus.closed:
        return 'CLOSED';
    }
  }
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// A large (56 × 56) filled circle with a centred icon.
class _CircleIcon extends StatelessWidget {
  const _CircleIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 26, color: color),
    );
  }
}

/// Small pill badge (e.g. "5" or "99+").
class _Badge extends StatelessWidget {
  const _Badge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceXS + 2,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: cs.onError,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

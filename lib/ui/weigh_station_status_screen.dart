import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/scale_report.dart';
import '../services/firebase_auth_bootstrap.dart';
import '../services/firestore_scale_report_service.dart';
import 'theme/app_theme.dart';

/// Full-screen detail view for a specific weigh station, showing the live
/// status fetched from Firestore via [FirestoreScaleReportService.watchLatest].
///
/// When [scaleId] is `null` (no GPS fix or no nearby scale), a friendly
/// fallback message is displayed instead.
class WeighStationStatusScreen extends StatefulWidget {
  const WeighStationStatusScreen({super.key, required this.scaleId});

  /// Firestore document ID under the `scale_reports` collection.
  /// Pass `null` to show the "no scale available" placeholder.
  final String? scaleId;

  @override
  State<WeighStationStatusScreen> createState() =>
      _WeighStationStatusScreenState();
}

class _WeighStationStatusScreenState extends State<WeighStationStatusScreen> {
  late final FirestoreScaleReportService _service;

  /// Whether the auth bootstrap is still in progress.
  bool _authLoading = false;

  /// Active stream for the current [widget.scaleId].  Replaced on each retry.
  Stream<ScaleReport?>? _stream;

  @override
  void initState() {
    super.initState();
    _service = FirestoreScaleReportService();
    if (widget.scaleId != null) {
      _initStream(widget.scaleId!);
    }
  }

  /// Ensures auth then (re-)starts the Firestore stream for [scaleId].
  ///
  /// Called once on init and again whenever the user taps "Retry".
  Future<void> _initStream(String scaleId) async {
    if (!mounted) return;
    setState(() => _authLoading = true);
    try {
      await FirebaseAuthBootstrap.ensureSignedIn();
    } catch (e) {
      debugPrint('[WeighStationStatus] auth error: $e');
      // Auth failure is non-fatal: the finally block still initialises the
      // stream so we attempt the Firestore read; if it is rejected the
      // StreamBuilder error handler will surface the error to the user.
    } finally {
      if (mounted) {
        setState(() {
          _authLoading = false;
          _stream = _service.watchLatest(scaleId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Weigh Station Status')),
      body: widget.scaleId == null
          ? _buildNoScale(context)
          : _authLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildLiveStatus(context, widget.scaleId!),
    );
  }

  // ---------------------------------------------------------------------------
  // No-scale placeholder
  // ---------------------------------------------------------------------------

  Widget _buildNoScale(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.scale_rounded,
              size: 72,
              color: cs.outlineVariant,
            ),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              'No nearby weigh station',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              'GPS location or a nearby scale is required to display live status.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Live-status view
  // ---------------------------------------------------------------------------

  Widget _buildLiveStatus(BuildContext context, String scaleId) {
    final stream = _stream;
    if (stream == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return StreamBuilder<ScaleReport?>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final err = snapshot.error;
          debugPrint('[WeighStationStatus] Firestore error: $err');
          final isPermissionDenied = err is FirebaseException &&
              err.plugin == 'cloud_firestore' &&
              err.code == 'permission-denied';
          if (isPermissionDenied) {
            return _ErrorView(
              message: 'Status unavailable. Please sign in.',
              onRetry: () => _initStream(scaleId),
            );
          }
          return _ErrorView(
            message: 'Could not load status: $err',
            onRetry: () => _initStream(scaleId),
          );
        }

        final report = snapshot.data;

        if (report == null) {
          return _buildNoReport(context, scaleId);
        }

        return _buildReport(context, report);
      },
    );
  }

  Widget _buildNoReport(BuildContext context, String scaleId) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.scale_rounded, size: 64, color: cs.outlineVariant),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              'No reports yet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppTheme.spaceSM),
            Text(
              'Be the first to report the status for scale $scaleId.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReport(BuildContext context, ScaleReport report) {
    final cs = Theme.of(context).colorScheme;
    final statusColor = _statusColor(report.status);

    return ListView(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      children: [
        // ── Status hero card ─────────────────────────────────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceLG),
            child: Column(
              children: [
                Icon(
                  _statusIcon(report.status),
                  size: 56,
                  color: statusColor,
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Text(
                  _statusLabel(report.status),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppTheme.spaceXS),
                Text(
                  report.poiName,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AppTheme.spaceMD),
        // ── Details ──────────────────────────────────────────────────────
        _DetailRow(
          icon: Icons.access_time_rounded,
          label: 'Reported',
          value: _timeAgo(report.reportedAt),
        ),
        _DetailRow(
          icon: Icons.location_on_rounded,
          label: 'Location',
          value:
              '${report.lat.toStringAsFixed(4)}, ${report.lng.toStringAsFixed(4)}',
        ),
        const SizedBox(height: AppTheme.spaceMD),
        Text(
          'Status updates in real time as drivers report.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  static Color _statusColor(ScaleStatus status) {
    switch (status) {
      case ScaleStatus.open:
        return Colors.green.shade600;
      case ScaleStatus.monitoring:
        return Colors.orange.shade700;
      case ScaleStatus.closed:
        return Colors.red.shade600;
    }
  }

  static IconData _statusIcon(ScaleStatus status) {
    switch (status) {
      case ScaleStatus.open:
        return Icons.check_circle_rounded;
      case ScaleStatus.monitoring:
        return Icons.visibility_rounded;
      case ScaleStatus.closed:
        return Icons.cancel_rounded;
    }
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

  static String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ---------------------------------------------------------------------------
// Helper widgets
// ---------------------------------------------------------------------------

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
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spaceXS),
      child: Row(
        children: [
          Icon(icon, size: 18, color: cs.primary),
          const SizedBox(width: AppTheme.spaceSM),
          Text(
            '$label:',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(width: AppTheme.spaceXS),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceLG),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, size: 56, color: cs.error),
            const SizedBox(height: AppTheme.spaceMD),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: cs.error,
                  ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppTheme.spaceMD),
              FilledButton.tonal(
                onPressed: onRetry,
                child: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

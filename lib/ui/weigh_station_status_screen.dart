import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../config.dart';
import '../models/scale_report.dart';
import '../services/auth_service.dart';
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

  // Incremented to force the StreamBuilder to recreate the stream on retry.
  int _streamKey = 0;

  // Set to true while we are signing in anonymously for a retry.
  bool _signingIn = false;

  @override
  void initState() {
    super.initState();
    _service = FirestoreScaleReportService();
  }

  /// Returns `true` when [error] is a Firestore permission-denied exception.
  static bool _isPermissionDenied(Object error) {
    if (error is FirebaseException) {
      return error.code == 'permission-denied';
    }
    final msg = error.toString();
    return msg.contains('permission-denied') || msg.contains('PERMISSION_DENIED');
  }

  /// Attempts an anonymous sign-in and retries the Firestore stream.
  Future<void> _retryWithAnonymousAuth() async {
    setState(() => _signingIn = true);
    try {
      await AuthService().ensureSignedIn();
    } catch (e) {
      debugPrint('[WeighStationStatus] Anonymous sign-in failed on retry: $e');
    } finally {
      if (mounted) {
        setState(() {
          _signingIn = false;
          _streamKey++; // force a new stream subscription
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
    if (_signingIn) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<ScaleReport?>(
      key: ValueKey(_streamKey),
      stream: _service.watchLatest(scaleId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          final error = snapshot.error!;
          debugPrint('[WeighStationStatus] Firestore error: $error');

          if (_isPermissionDenied(error)) {
            return _ErrorView(
              message: 'Status unavailable. Please sign in to view live weigh station data.',
              isPermissionDenied: true,
              onRetry: Config.enableAnonymousAuthForStatus
                  ? _retryWithAnonymousAuth
                  : null,
            );
          }

          return _ErrorView(
            message: 'Could not load status: $error',
            onRetry: () => setState(() => _streamKey++),
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
  const _ErrorView({
    required this.message,
    this.isPermissionDenied = false,
    this.onRetry,
  });

  final String message;
  final bool isPermissionDenied;
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
              FilledButton.icon(
                onPressed: onRetry,
                icon: Icon(
                  isPermissionDenied
                      ? Icons.lock_open_rounded
                      : Icons.refresh_rounded,
                ),
                label: Text(isPermissionDenied ? 'Sign In & Retry' : 'Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

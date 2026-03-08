import 'package:flutter/material.dart';
import '../services/elevation_service.dart';

/// Admin area screen — accessible only to users whose email is in the
/// admin allowlist (see [AdminService] and [Config.adminEmails]).
///
/// Navigation to this screen is gated by [AccountScreen]: the "Admin Area"
/// tile is only rendered when the signed-in user is recognised as an admin.
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  bool _elevationLoading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Area'),
        leading: const BackButton(),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.admin_panel_settings_rounded, size: 64),
          ),
          const SizedBox(height: 16),
          Text(
            'Admin Area',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'You are signed in with an admin account.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 8),
          // Placeholder admin actions — extend this section as needed.
          ListTile(
            leading: const Icon(Icons.people_outline),
            title: const Text('Manage Users'),
            subtitle: const Text('View and manage registered users'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('User management coming soon.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.bar_chart_rounded),
            title: const Text('App Analytics'),
            subtitle: const Text('Usage statistics and metrics'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Analytics coming soon.')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('App Settings'),
            subtitle: const Text('Global configuration options'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Global settings coming soon.')),
              );
            },
          ),
          // Road Elevation demo — fetches elevation for a sample location.
          ListTile(
            leading: _elevationLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.terrain_rounded),
            title: const Text('Road Elevation'),
            subtitle: const Text('Fetch elevation for a sample coordinate'),
            trailing: const Icon(Icons.chevron_right),
            onTap: _elevationLoading ? null : _onElevationTapped,
          ),
        ],
      ),
    );
  }

  /// Fetches elevation for a demo coordinate (Denver, CO) and shows the
  /// result — or an error — in an [AlertDialog].
  Future<void> _onElevationTapped() async {
    // Demo coordinates: Denver, CO (~1609 m above sea level).
    const demoLat = 39.7392;
    const demoLng = -104.9903;

    setState(() => _elevationLoading = true);
    final service = ElevationService();
    try {
      final point = await service.fetchElevation(lat: demoLat, lng: demoLng);
      if (!mounted) return;
      _showElevationDialog(
        title: 'Road Elevation',
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ElevationRow(label: 'Latitude', value: point.lat.toStringAsFixed(4)),
            _ElevationRow(label: 'Longitude', value: point.lng.toStringAsFixed(4)),
            const SizedBox(height: 8),
            _ElevationRow(
              label: 'Elevation',
              value:
                  '${point.elevationMeters.toStringAsFixed(1)} m'
                  ' (${point.elevationFeet.toStringAsFixed(0)} ft)',
            ),
            if (point.resolution != null)
              _ElevationRow(
                label: 'Resolution',
                value: '${point.resolution!.toStringAsFixed(1)} m',
              ),
          ],
        ),
      );
    } on ElevationException catch (e) {
      if (!mounted) return;
      _showElevationDialog(
        title: 'Elevation Error',
        content: Text(e.message),
        isError: true,
      );
    } catch (e) {
      if (!mounted) return;
      _showElevationDialog(
        title: 'Elevation Error',
        content: Text('Unexpected error: $e'),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _elevationLoading = false);
    }
  }

  void _showElevationDialog({
    required String title,
    required Widget content,
    bool isError = false,
  }) {
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.terrain_rounded,
              color: isError
                  ? Theme.of(context).colorScheme.error
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: content,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// A simple label + value row used inside the elevation result dialog.
class _ElevationRow extends StatelessWidget {
  const _ElevationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 16),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

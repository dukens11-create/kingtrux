import 'package:flutter/material.dart';

/// Admin area screen — accessible only to users whose email is in the
/// admin allowlist (see [AdminService] and [Config.adminEmails]).
///
/// Navigation to this screen is gated by [AccountScreen]: the "Admin Area"
/// tile is only rendered when the signed-in user is recognised as an admin.
class AdminScreen extends StatelessWidget {
  const AdminScreen({super.key});

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
        ],
      ),
    );
  }
}

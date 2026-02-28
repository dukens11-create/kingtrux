import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/admin_service.dart';
import '../services/auth_service.dart';
import 'admin_screen.dart';

/// A simple account / profile screen.
///
/// Shows the currently signed-in user's display name / email and provides a
/// sign-out button that returns the user to [AuthScreen].
class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final cs = Theme.of(context).colorScheme;
    final adminService = context.read<AdminService>();
    final userIsAdmin = adminService.isAdmin(user?.email);

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Center(
            child: CircleAvatar(
              radius: 40,
              backgroundColor: cs.primaryContainer,
              backgroundImage: user?.photoURL != null
                  ? NetworkImage(user!.photoURL!)
                  : null,
              child: user?.photoURL == null
                  ? Icon(Icons.person, size: 40, color: cs.onPrimaryContainer)
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          if (user?.displayName != null && user!.displayName!.isNotEmpty)
            Center(
              child: Text(
                user.displayName!,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          if (user?.email != null && user!.email!.isNotEmpty)
            Center(
              child: Text(
                user.email!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          if (user?.phoneNumber != null && user!.phoneNumber!.isNotEmpty)
            Center(
              child: Text(
                user.phoneNumber!,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 8),
          if (userIsAdmin) ...[
            ListTile(
              leading: Icon(Icons.admin_panel_settings_rounded,
                  color: cs.primary),
              title: const Text('Admin Area'),
              subtitle: const Text('Access admin controls'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              ),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Sign Out'),
            onTap: () => _signOut(context),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will be returned to the login screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final auth = context.read<AuthService>();
    try {
      await auth.signOut();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign-out error: $e')),
        );
      }
    }
  }
}

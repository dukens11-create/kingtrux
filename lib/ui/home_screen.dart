import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

/// A placeholder home screen shown to authenticated users.
///
/// Displays the current user's email and UID, and provides a Sign Out button
/// that calls [AuthService.signOut], which causes [_AuthGate] in [app.dart]
/// to redirect back to [AuthScreen] via the [authStateChanges] stream.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('KINGTRUX'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () => _signOut(context),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.local_shipping_rounded, size: 72, color: cs.primary),
              const SizedBox(height: 24),
              Text(
                'Welcome!',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              if (user != null) ...[
                _InfoRow(label: 'Email', value: user.email ?? '—'),
                const SizedBox(height: 8),
                _InfoRow(label: 'UID', value: user.uid),
                const SizedBox(height: 32),
              ],
              FilledButton.icon(
                onPressed: () => _signOut(context),
                icon: const Icon(Icons.logout),
                label: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context) async {
    final authService = context.read<AuthService>();
    await authService.signOut();
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label: ',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        Flexible(child: Text(value, overflow: TextOverflow.ellipsis)),
      ],
    );
  }
}

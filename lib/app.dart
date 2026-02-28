import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/admin_service.dart';
import 'services/auth_service.dart';
import 'state/app_state.dart';
import 'ui/kingtrux_login_page.dart';
import 'ui/map_screen.dart';
import 'ui/theme/app_theme.dart';

class KingTruxApp extends StatelessWidget {
  final AuthService? authService;

  const KingTruxApp({super.key, this.authService});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(
          create: (_) => authService ?? AuthService(),
        ),
        Provider<AdminService>(
          create: (_) => AdminService(),
        ),
        ChangeNotifierProvider<AppState>(
          create: (_) => AppState(),
        ),
      ],
      child: Consumer<AppState>(
        builder: (context, appState, _) {
          final seedColor = appState.effectiveSeedColor;
          return MaterialApp(
            title: 'KINGTRUX',
            theme: AppTheme.lightFromSeed(seedColor),
            darkTheme: AppTheme.darkFromSeed(seedColor),
            themeMode:
                appState.isNightMode ? ThemeMode.dark : ThemeMode.light,
            home: const _AuthGate(),
          );
        },
      ),
    );
  }
}

class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const MapScreen();
        }
        return const KingtruxLoginPage();
      },
    );
  }
}
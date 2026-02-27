import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'state/app_state.dart';
import 'ui/auth_screen.dart';
import 'ui/map_screen.dart';
import 'ui/theme/app_theme.dart';

/// Main KINGTRUX application
class KingTruxApp extends StatelessWidget {
  const KingTruxApp({super.key, AuthService? authService})
      : _authService = authService;

  final AuthService? _authService;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()),
        Provider<AuthService>(create: (_) => _authService ?? AuthService()),
      ],
      child: Consumer<AppState>(
        builder: (context, state, _) => MaterialApp(
          title: 'KINGTRUX',
          theme: AppTheme.lightFromSeed(state.effectiveSeedColor),
          darkTheme: AppTheme.darkFromSeed(state.effectiveSeedColor),
          themeMode: state.isNightMode ? ThemeMode.dark : ThemeMode.light,
          home: const _AuthGate(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

/// Routes to [AuthScreen] or [MapScreen] based on Firebase auth state.
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
        if (snapshot.hasError) {
          debugPrint('[AuthGate] Auth state error: ${snapshot.error}');
          return const AuthScreen();
        }
        if (snapshot.hasData) {
          return const MapScreen();
        }
        return const AuthScreen();
      },
    );
  }
}

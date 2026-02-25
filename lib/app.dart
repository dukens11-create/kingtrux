import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'ui/map_screen.dart';
import 'ui/theme/app_theme.dart';

/// Main KINGTRUX application
class KingTruxApp extends StatelessWidget {
  const KingTruxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: Consumer<AppState>(
        builder: (context, state, _) => MaterialApp(
          title: 'KINGTRUX',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: state.isNightMode ? ThemeMode.dark : ThemeMode.light,
          home: const MapScreen(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

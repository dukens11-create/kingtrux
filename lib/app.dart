import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'state/app_state.dart';
import 'ui/map_screen.dart';

/// Main KINGTRUX application
class KingTruxApp extends StatelessWidget {
  const KingTruxApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState(),
      child: MaterialApp(
        title: 'KINGTRUX',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.amber,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.amber,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const MapScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}

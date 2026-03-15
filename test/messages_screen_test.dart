import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kingtrux/models/poi.dart';
import 'package:kingtrux/state/app_state.dart';
import 'package:kingtrux/ui/messages_screen.dart';
import 'package:kingtrux/ui/weigh_station_status_screen.dart';
import 'package:kingtrux/ui/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Minimal AppState stub
// ---------------------------------------------------------------------------

class _StubAppState extends AppState {
  _StubAppState({Poi? closestScale}) {
    closestScalePoi = closestScale;
  }

  @override
  Future<void> loadPois({double radiusMeters = 15000}) async {
    // No-op in tests — avoids network calls.
  }
}

// ---------------------------------------------------------------------------
// Build helper
// ---------------------------------------------------------------------------

Widget _buildScreen({_StubAppState? state}) {
  final appState = state ?? _StubAppState();
  return ChangeNotifierProvider<AppState>.value(
    value: appState,
    child: MaterialApp(
      theme: AppTheme.light,
      home: const MessagesScreen(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // ---------------------------------------------------------------------------
  // Rendering
  // ---------------------------------------------------------------------------
  group('MessagesScreen — layout', () {
    testWidgets('shows "Messages" in the AppBar title',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('Messages'), findsOneWidget);
    });

    testWidgets('shows profile and settings action icons',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.byIcon(Icons.account_circle_outlined), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('shows three quick-action buttons',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('Announcement'), findsOneWidget);
      expect(find.text('Files'), findsWidgets);
      expect(find.text('Static Link'), findsOneWidget);
    });

    testWidgets('shows Announcements and Load Board category rows',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('Announcements'), findsOneWidget);
      expect(find.text('Load Board'), findsOneWidget);
    });

    testWidgets('shows Weigh Station Status category row',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('Weigh Station Status'), findsOneWidget);
    });

    testWidgets('shows badge "5" on Announcements row',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('5'), findsOneWidget);
    });

    testWidgets('shows badge "99+" on Load Board row',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();

      expect(find.text('99+'), findsOneWidget);
    });
  });

  // ---------------------------------------------------------------------------
  // Weigh Station Status — fallback when no scale
  // ---------------------------------------------------------------------------
  group('MessagesScreen — Weigh Station Status fallback', () {
    testWidgets(
        'shows "No nearby scale" subtitle when closestScalePoi is null',
        (WidgetTester tester) async {
      // No closest scale — GPS missing or no nearby scale POI.
      final state = _StubAppState(closestScale: null);
      await tester.pumpWidget(_buildScreen(state: state));
      await tester.pump();

      expect(find.text('No nearby scale'), findsOneWidget);
    });

    testWidgets(
        'shows scale icon for Weigh Station Status row',
        (WidgetTester tester) async {
      final state = _StubAppState(closestScale: null);
      await tester.pumpWidget(_buildScreen(state: state));
      await tester.pump();

      expect(find.byIcon(Icons.scale_rounded), findsWidgets);
    });
  });

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------
  group('MessagesScreen — navigation', () {
    testWidgets(
        'tapping Weigh Station Status (no scale) navigates to WeighStationStatusScreen',
        (WidgetTester tester) async {
      final state = _StubAppState(closestScale: null);
      await tester.pumpWidget(_buildScreen(state: state));
      await tester.pump();

      // Tap the Weigh Station Status list tile.
      await tester.tap(find.text('Weigh Station Status'));
      await tester.pumpAndSettle();

      // WeighStationStatusScreen should be on the navigator stack.
      expect(find.byType(WeighStationStatusScreen), findsOneWidget);
    });

    testWidgets(
        'WeighStationStatusScreen shows "No nearby weigh station" when scaleId is null',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const WeighStationStatusScreen(scaleId: null),
        ),
      );
      await tester.pump();

      expect(find.text('No nearby weigh station'), findsOneWidget);
      expect(find.text('Weigh Station Status'), findsOneWidget);
    });
  });
}

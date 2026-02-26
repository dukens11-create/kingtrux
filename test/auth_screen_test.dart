import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kingtrux/services/auth_service.dart';
import 'package:kingtrux/ui/auth_screen.dart';

/// Wraps [AuthScreen] with the required Provider context.
Widget buildAuthApp() {
  return Provider<AuthService>(
    create: (_) => AuthService(),
    child: const MaterialApp(
      home: AuthScreen(),
    ),
  );
}

void main() {
  group('AuthScreen', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(buildAuthApp());
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('shows Email and Phone tabs', (WidgetTester tester) async {
      await tester.pumpWidget(buildAuthApp());
      await tester.pump();
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Phone'), findsOneWidget);
    });

    testWidgets('shows sign-in fields by default', (WidgetTester tester) async {
      await tester.pumpWidget(buildAuthApp());
      await tester.pump();
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('switches to create account mode', (WidgetTester tester) async {
      await tester.pumpWidget(buildAuthApp());
      await tester.pump();
      await tester.tap(find.text("Don't have an account? Create one"));
      await tester.pump();
      expect(find.text('Create Account'), findsOneWidget);
    });
  });
}

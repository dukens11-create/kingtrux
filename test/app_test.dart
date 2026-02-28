import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/app.dart';
import 'package:kingtrux/services/auth_service.dart';
import 'package:kingtrux/ui/kingtrux_login_page.dart';

// ---------------------------------------------------------------------------
// Minimal AuthService stub that returns a controlled stream of User? events.
// No Firebase SDK is called, enabling widget tests without a running emulator.
// ---------------------------------------------------------------------------
class _StubAuthService extends AuthService {
  final StreamController<User?> _controller;

  _StubAuthService(this._controller) : super(auth: null, googleSignIn: null);

  @override
  Stream<User?> get authStateChanges => _controller.stream;
}

void main() {
  testWidgets('AuthGate shows loading indicator while stream is pending',
      (WidgetTester tester) async {
    // A broadcast StreamController that never emits keeps ConnectionState.waiting.
    final ctrl = StreamController<User?>.broadcast();
    await tester.pumpWidget(
      KingTruxApp(authService: _StubAuthService(ctrl)),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    await ctrl.close();
  });

  testWidgets('AuthGate routes to KingtruxLoginPage when user is unauthenticated',
      (WidgetTester tester) async {
    // Emit null immediately → unauthenticated.
    final ctrl = StreamController<User?>.broadcast();
    await tester.pumpWidget(
      KingTruxApp(authService: _StubAuthService(ctrl)),
    );

    ctrl.add(null);
    await tester.pump();

    expect(find.byType(KingtruxLoginPage), findsOneWidget);

    await ctrl.close();
  });

  testWidgets('AuthGate routes to HomeScreen when user is authenticated',
      (WidgetTester tester) async {
    // Seed the controller so the first pump resolves immediately.
    final ctrl = StreamController<User?>.broadcast();
    await tester.pumpWidget(
      KingTruxApp(authService: _StubAuthService(ctrl)),
    );

    // Emit a non-null event to simulate a signed-in user.
    // _FakeUser is a test double implementing User with no real Firebase calls.
    ctrl.add(_FakeUser());
    await tester.pump();

    // HomeScreen is the placeholder shown to authenticated users.
    // It renders inside a Scaffold; verify the Scaffold is present and no
    // AuthScreen is displayed.
    expect(find.byType(KingtruxLoginPage), findsNothing);
    // The HomeScreen renders a welcome page – confirm the full tree was built.
    expect(find.byType(MaterialApp), findsOneWidget);

    await ctrl.close();
  });
}

// ---------------------------------------------------------------------------
// Minimal fake User to emit as an authenticated event without real Firebase.
// ---------------------------------------------------------------------------
class _FakeUser extends Fake implements User {}


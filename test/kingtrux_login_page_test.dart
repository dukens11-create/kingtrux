import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:kingtrux/services/auth_service.dart';
import 'package:kingtrux/ui/kingtrux_login_page.dart';

// ---------------------------------------------------------------------------
// Minimal AuthService stub – records calls without touching Firebase.
// ---------------------------------------------------------------------------

class _MockAuthService extends AuthService {
  _MockAuthService() : super(auth: null, googleSignIn: null);

  String? lastSignInEmail;
  String? lastSignInPassword;
  String? lastResetEmail;
  String? lastCreateEmail;

  /// Controls whether calls throw (simulate auth error).
  FirebaseAuthException? errorToThrow;

  @override
  Future<UserCredential> signInWithEmail(String email, String password) async {
    lastSignInEmail = email;
    lastSignInPassword = password;
    if (errorToThrow != null) throw errorToThrow!;
    return _FakeCredential();
  }

  @override
  Future<UserCredential> createAccountWithEmail(
      String email, String password) async {
    lastCreateEmail = email;
    if (errorToThrow != null) throw errorToThrow!;
    return _FakeCredential();
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    lastResetEmail = email;
    if (errorToThrow != null) throw errorToThrow!;
  }

  @override
  Stream<User?> get authStateChanges => const Stream.empty();
}

/// Wraps [KingtruxLoginPage] in the required Provider context.
Widget _buildPage(_MockAuthService auth) {
  return Provider<AuthService>.value(
    value: auth,
    child: const MaterialApp(home: KingtruxLoginPage()),
  );
}

void main() {
  group('KingtruxLoginPage', () {
    testWidgets('renders without crashing', (WidgetTester tester) async {
      await tester.pumpWidget(_buildPage(_MockAuthService()));
      expect(find.byType(KingtruxLoginPage), findsOneWidget);
    });

    testWidgets('shows KINGTRUX brand header', (WidgetTester tester) async {
      await tester.pumpWidget(_buildPage(_MockAuthService()));
      expect(find.text('KINGTRUX'), findsOneWidget);
      expect(find.text('Professional Truck GPS'), findsOneWidget);
    });

    testWidgets('shows email and password fields', (WidgetTester tester) async {
      await tester.pumpWidget(_buildPage(_MockAuthService()));
      expect(find.text('Email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('shows Sign in button and Create account button',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildPage(_MockAuthService()));
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Create account'), findsOneWidget);
    });

    testWidgets('shows Forgot password link in sign-in mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildPage(_MockAuthService()));
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('tapping Sign in with valid data calls signInWithEmail',
        (WidgetTester tester) async {
      final auth = _MockAuthService();
      await tester.pumpWidget(_buildPage(auth));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'user@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'secret123');

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();

      expect(auth.lastSignInEmail, 'user@example.com');
      expect(auth.lastSignInPassword, 'secret123');
    });

    testWidgets('tapping Sign in with empty email shows validation error',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildPage(_MockAuthService()));

      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();

      expect(find.text('Enter your email'), findsOneWidget);
    });

    testWidgets('tapping Sign in with empty password shows validation error',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildPage(_MockAuthService()));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'user@example.com');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pump();

      expect(find.text('Enter your password'), findsOneWidget);
    });

    testWidgets('Forgot password triggers sendPasswordReset',
        (WidgetTester tester) async {
      final auth = _MockAuthService();
      await tester.pumpWidget(_buildPage(auth));

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'reset@example.com');

      await tester.tap(find.text('Forgot password?'));
      await tester.pump();

      expect(auth.lastResetEmail, 'reset@example.com');
    });

    testWidgets('Forgot password without email shows error snackbar',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildPage(_MockAuthService()));

      await tester.tap(find.text('Forgot password?'));
      await tester.pump();

      expect(find.text('Enter your email address above first.'),
          findsOneWidget);
    });

    testWidgets('tapping Create account toggles to sign-up mode',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildPage(_MockAuthService()));

      await tester.tap(find.text('Create account'));
      await tester.pump();

      expect(find.text('Create Account'), findsOneWidget);
      expect(find.text('Confirm Password'), findsOneWidget);
      expect(find.text('Forgot password?'), findsNothing);
    });

    testWidgets(
        'sign-up validates password length and confirm password match',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildPage(_MockAuthService()));

      await tester.tap(find.text('Create account'));
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'new@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'abc');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm Password'), 'xyz');

      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Password must be at least 6 characters'), findsOneWidget);
    });

    testWidgets('sign-up with mismatched passwords shows error',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildPage(_MockAuthService()));

      await tester.tap(find.text('Create account'));
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'new@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm Password'), 'different');

      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pump();

      expect(find.text('Passwords do not match'), findsOneWidget);
    });

    testWidgets('successful sign-up calls createAccountWithEmail',
        (WidgetTester tester) async {
      final auth = _MockAuthService();
      await tester.pumpWidget(_buildPage(auth));

      await tester.tap(find.text('Create account'));
      await tester.pump();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Email'), 'new@example.com');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Password'), 'password123');
      await tester.enterText(
          find.widgetWithText(TextFormField, 'Confirm Password'),
          'password123');

      await tester.tap(find.widgetWithText(FilledButton, 'Create Account'));
      await tester.pump();

      expect(auth.lastCreateEmail, 'new@example.com');
    });

    testWidgets('password field is obscured by default',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildPage(_MockAuthService()));

      expect(_findPasswordField(tester).obscureText, isTrue);
    });

    testWidgets('tapping eye icon toggles password visibility',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildPage(_MockAuthService()));

      // Initially obscured – eye-off icon is shown.
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_outlined), findsNothing);

      // Tap the visibility toggle.
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      // Now the password is visible – eye icon is shown.
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      expect(find.byIcon(Icons.visibility_off_outlined), findsNothing);

      // The password field should no longer be obscured.
      expect(_findPasswordField(tester).obscureText, isFalse);
    });

    testWidgets('tapping eye icon again re-hides password',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildPage(_MockAuthService()));

      // Show the password.
      await tester.tap(find.byIcon(Icons.visibility_off_outlined));
      await tester.pump();

      // Hide it again.
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
      expect(_findPasswordField(tester).obscureText, isTrue);
    });
  });
}

// ---------------------------------------------------------------------------
// Minimal fake UserCredential
// ---------------------------------------------------------------------------

class _FakeCredential extends Fake implements UserCredential {}

// ---------------------------------------------------------------------------
// Helper: finds the EditableText inside the Password TextFormField.
// ---------------------------------------------------------------------------

EditableText _findPasswordField(WidgetTester tester) {
  return tester.widget<EditableText>(
    find
        .descendant(
          of: find.widgetWithText(TextFormField, 'Password'),
          matching: find.byType(EditableText),
        )
        .first,
  );
}

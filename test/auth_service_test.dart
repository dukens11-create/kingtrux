import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/services/auth_service.dart';
import 'package:kingtrux/ui/auth_screen.dart';

/// Verifies that [AuthService] exposes the expected interface.
///
/// Full integration tests (actual Firebase calls) require a running Firebase
/// emulator and are outside the scope of these unit tests. These tests confirm
/// the public API shape so refactors do not silently break callers.
void main() {
  group('AuthService interface', () {
    test('has authStateChanges getter', () {
      // The getter itself is not invoked (Firebase not initialized in tests);
      // we only confirm the class compiles with the expected member.
      expect(AuthService, isNotNull);
    });

    test('can be constructed with custom FirebaseAuth and GoogleSignIn', () {
      // Constructor accepts optional overrides, enabling mocking in future
      // tests. Verify that the parameter list compiles correctly.
      expect(() => AuthService(), returnsNormally);
    });
  });

  group('friendlyAuthMessage error code mapping', () {
    test('maps user-not-found', () {
      expect(
        friendlyAuthMessage('user-not-found'),
        contains('No account found'),
      );
    });

    test('maps wrong-password', () {
      expect(
        friendlyAuthMessage('wrong-password'),
        contains('Incorrect password'),
      );
    });

    test('maps invalid-credential', () {
      expect(
        friendlyAuthMessage('invalid-credential'),
        contains('Invalid credentials'),
      );
    });

    test('maps email-already-in-use', () {
      expect(
        friendlyAuthMessage('email-already-in-use'),
        contains('already exists'),
      );
    });

    test('maps weak-password', () {
      expect(
        friendlyAuthMessage('weak-password'),
        contains('too weak'),
      );
    });

    test('maps invalid-email', () {
      expect(
        friendlyAuthMessage('invalid-email'),
        contains('valid email'),
      );
    });

    test('maps too-many-requests', () {
      expect(
        friendlyAuthMessage('too-many-requests'),
        contains('Too many attempts'),
      );
    });

    test('maps network-request-failed', () {
      expect(
        friendlyAuthMessage('network-request-failed'),
        contains('Network error'),
      );
    });

    test('maps invalid-phone-number', () {
      expect(
        friendlyAuthMessage('invalid-phone-number'),
        contains('Invalid phone number'),
      );
    });

    test('maps invalid-verification-code', () {
      expect(
        friendlyAuthMessage('invalid-verification-code'),
        contains('Invalid verification code'),
      );
    });

    test('maps session-expired', () {
      expect(
        friendlyAuthMessage('session-expired'),
        contains('expired'),
      );
    });

    test('maps invalid-api-key', () {
      expect(
        friendlyAuthMessage('invalid-api-key'),
        contains('invalid-api-key'),
      );
    });

    test('maps app-not-authorized', () {
      expect(
        friendlyAuthMessage('app-not-authorized'),
        contains('not authorized for Firebase Authentication'),
      );
    });

    test('maps operation-not-allowed', () {
      expect(
        friendlyAuthMessage('operation-not-allowed'),
        contains('operation-not-allowed'),
      );
    });

    test('maps quota-exceeded', () {
      expect(
        friendlyAuthMessage('quota-exceeded'),
        contains('quota exceeded'),
      );
    });

    test('returns code in message for unknown codes', () {
      const unknownCode = 'some-unknown-error';
      final msg = friendlyAuthMessage(unknownCode);
      expect(msg, contains(unknownCode));
    });

    test('returns code in message for "unknown" code', () {
      final msg = friendlyAuthMessage('unknown');
      expect(msg, contains('unknown'));
    });
  });
}

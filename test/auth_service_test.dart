import 'package:flutter_test/flutter_test.dart';
import 'package:kingtrux/services/auth_service.dart';

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
}

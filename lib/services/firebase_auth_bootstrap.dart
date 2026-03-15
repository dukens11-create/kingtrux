import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Lightweight auth bootstrap that ensures the app always has a Firebase
/// identity before making authenticated Firestore reads.
///
/// If the user is already signed in (email, Google, Apple, or a previous
/// anonymous session) nothing happens.  Otherwise the app signs in
/// anonymously so that `request.auth != null` is satisfied in Firestore
/// security rules without presenting any login UI.
class FirebaseAuthBootstrap {
  const FirebaseAuthBootstrap._();

  /// Ensures a Firebase Auth user is present, signing in anonymously if
  /// needed.
  ///
  /// Safe to call multiple times — it is a no-op when a user is already
  /// signed in.  Errors are logged and re-thrown so callers can decide how
  /// to surface them.
  static Future<void> ensureSignedIn({FirebaseAuth? auth}) async {
    final firebaseAuth = auth ?? FirebaseAuth.instance;
    if (firebaseAuth.currentUser != null) return;
    try {
      await firebaseAuth.signInAnonymously();
    } catch (e) {
      debugPrint('[FirebaseAuthBootstrap] anonymous sign-in failed: $e');
      rethrow;
    }
  }
}

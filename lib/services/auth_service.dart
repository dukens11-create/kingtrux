import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

/// Encapsulates all Firebase Authentication provider flows.
///
/// Supports:
///   - Email/password (create account, sign in, password reset)
///   - Phone number (SMS OTP request + verification)
///   - Google sign-in
///   - Apple sign-in (iOS)
///
/// [FirebaseAuth] and [GoogleSignIn] are accessed lazily so this class can be
/// constructed in test environments where Firebase is not initialized, without
/// throwing. Pass explicit instances via the constructor to inject mocks.
class AuthService {
  FirebaseAuth? _authInstance;
  GoogleSignIn? _googleSignInInstance;

  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
      : _authInstance = auth,
        _googleSignInInstance = googleSignIn;

  FirebaseAuth get _auth => _authInstance ??= FirebaseAuth.instance;
  GoogleSignIn get _googleSignIn =>
      _googleSignInInstance ??= GoogleSignIn();

  // ---------------------------------------------------------------------------
  // Auth state
  // ---------------------------------------------------------------------------

  /// Stream of the currently signed-in [User], or `null` when signed out.
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// The currently signed-in [User], or `null`.
  User? get currentUser => _auth.currentUser;

  // ---------------------------------------------------------------------------
  // Email / password
  // ---------------------------------------------------------------------------

  /// Sign in with [email] and [password].
  ///
  /// Throws a [FirebaseAuthException] on failure; inspect [e.code] for the
  /// cause (e.g. `wrong-password`, `user-not-found`).
  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Create a new account with [email] and [password].
  ///
  /// Throws a [FirebaseAuthException] on failure (e.g. `email-already-in-use`).
  Future<UserCredential> createAccountWithEmail(
      String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Send a password-reset email to [email].
  Future<void> sendPasswordReset(String email) {
    return _auth.sendPasswordResetEmail(email: email);
  }

  // ---------------------------------------------------------------------------
  // Phone / SMS OTP
  // ---------------------------------------------------------------------------

  /// Request a verification SMS to [phoneNumber] (e.g. `+12025551234`).
  ///
  /// - [onCodeSent] is called once Firebase dispatches the SMS, with the
  ///   verification ID and an optional resend token.
  /// - [onVerificationCompleted] is called on Android when the code is
  ///   auto-retrieved (instant verification).
  /// - [onVerificationFailed] is called when the phone number is invalid or
  ///   quota exceeded.
  /// - [timeout] is the time before [onCodeAutoRetrievalTimeout] fires.
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) onCodeSent,
    required void Function(PhoneAuthCredential credential)
        onVerificationCompleted,
    required void Function(FirebaseAuthException e) onVerificationFailed,
    void Function(String verificationId)? onCodeAutoRetrievalTimeout,
    Duration timeout = const Duration(seconds: 60),
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: onCodeAutoRetrievalTimeout ?? (_) {},
      timeout: timeout,
    );
  }

  /// Sign in using [verificationId] (from [verifyPhoneNumber]) and the
  /// [smsCode] entered by the user.
  Future<UserCredential> signInWithPhoneOtp({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  // ---------------------------------------------------------------------------
  // Google
  // ---------------------------------------------------------------------------

  /// Sign in with a Google account.
  ///
  /// Returns `null` when the user cancels the sign-in flow.
  Future<UserCredential?> signInWithGoogle() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // user cancelled
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  // ---------------------------------------------------------------------------
  // Apple
  // ---------------------------------------------------------------------------

  /// Sign in with Apple (iOS / macOS).
  ///
  /// Throws [SignInWithAppleException] on failure.
  /// On unsupported platforms this throws [UnsupportedError].
  Future<UserCredential> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final oauthCredential = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );
    return _auth.signInWithCredential(oauthCredential);
  }

  // ---------------------------------------------------------------------------
  // Sign out
  // ---------------------------------------------------------------------------

  /// Sign out of Firebase and (if applicable) Google.
  Future<void> signOut() async {
    await _auth.signOut();
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('[Auth] Google sign-out error (ignored): $e');
    }
  }
}

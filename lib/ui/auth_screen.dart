import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../services/auth_service.dart';

/// Authentication screen offering Email/Password, Phone OTP, Google, and
/// Apple sign-in options.
///
/// On successful authentication the [AuthGate] in [app.dart] automatically
/// navigates the user to [HomeScreen] via the [authStateChanges] stream.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 16),
              // ── Logo / title ───────────────────────────────────────────────
              Icon(Icons.local_shipping_rounded,
                  size: 64, color: cs.primary),
              const SizedBox(height: 8),
              Text(
                'KINGTRUX',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Professional Truck GPS',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 32),

              // ── Email / Phone tabs ─────────────────────────────────────────
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'Email'),
                  Tab(text: 'Phone'),
                ],
              ),
              SizedBox(
                height: 400,
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    _EmailTab(),
                    _PhoneTab(),
                  ],
                ),
              ),

              const SizedBox(height: 16),
              const _Divider(label: 'or continue with'),
              const SizedBox(height: 16),

              // ── Social sign-in buttons ─────────────────────────────────────
              _SocialButton(
                icon: Image.asset(
                  'assets/google_logo.png',
                  height: 20,
                  width: 20,
                  errorBuilder: (_, __, ___) =>
                      const Icon(Icons.g_mobiledata, size: 24),
                ),
                label: 'Continue with Google',
                onPressed: () => _signInWithGoogle(context),
              ),
              const SizedBox(height: 12),
              if (defaultTargetPlatform == TargetPlatform.iOS)
                _SocialButton(
                  icon: const Icon(Icons.apple, size: 24),
                  label: 'Continue with Apple',
                  onPressed: () => _signInWithApple(context),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Social sign-in
  // ---------------------------------------------------------------------------

  Future<void> _signInWithGoogle(BuildContext context) async {
    final auth = context.read<AuthService>();
    try {
      final result = await auth.signInWithGoogle();
      if (result == null && context.mounted) {
        _showSnack(context, 'Google sign-in was cancelled.');
      }
    } on FirebaseAuthException catch (e, stack) {
      _logAuthError(e, stack);
      if (context.mounted) _showError(context, _authMessage(e));
    } catch (e, stack) {
      _logAuthError(e, stack);
      if (context.mounted) _showError(context, e.toString());
    }
  }

  Future<void> _signInWithApple(BuildContext context) async {
    final auth = context.read<AuthService>();
    try {
      await auth.signInWithApple();
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return;
      if (context.mounted) _showError(context, e.message);
    } on FirebaseAuthException catch (e, stack) {
      _logAuthError(e, stack);
      if (context.mounted) _showError(context, _authMessage(e));
    } catch (e, stack) {
      _logAuthError(e, stack);
      if (context.mounted) _showError(context, e.toString());
    }
  }
}

// ---------------------------------------------------------------------------
// Email tab
// ---------------------------------------------------------------------------

class _EmailTab extends StatefulWidget {
  const _EmailTab();

  @override
  State<_EmailTab> createState() => _EmailTabState();
}

class _EmailTabState extends State<_EmailTab> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _loading = false;
  bool _isSignUp = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Padding(
        padding: const EdgeInsets.only(top: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              textInputAction: TextInputAction.next,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your email';
                if (!v.contains('@')) return 'Enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _pwCtrl,
              decoration: const InputDecoration(
                labelText: 'Password',
                prefixIcon: Icon(Icons.lock_outline),
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              textInputAction:
                  _isSignUp ? TextInputAction.next : TextInputAction.done,
              onFieldSubmitted: _isSignUp ? null : (_) => _submit(),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter your password';
                if (_isSignUp && v.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            if (_isSignUp) ...[
              TextFormField(
                controller: _confirmPwCtrl,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Confirm your password';
                  if (v != _pwCtrl.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 8),
            ],
            if (!_isSignUp)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _resetPassword,
                  child: const Text('Forgot password?'),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isSignUp ? 'Create Account' : 'Sign In'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => setState(() {
                _isSignUp = !_isSignUp;
                _formKey.currentState?.reset();
              }),
              child: Text(_isSignUp
                  ? 'Already have an account? Sign In'
                  : "Don't have an account? Create one"),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthService>();
    setState(() => _loading = true);
    try {
      if (_isSignUp) {
        await auth.createAccountWithEmail(
            _emailCtrl.text.trim(), _pwCtrl.text);
      } else {
        await auth.signInWithEmail(_emailCtrl.text.trim(), _pwCtrl.text);
      }
    } on FirebaseAuthException catch (e, stack) {
      _logAuthError(e, stack);
      if (mounted) _showError(context, _authMessage(e));
    } catch (e, stack) {
      _logAuthError(e, stack);
      if (mounted) _showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError(context, 'Enter your email address above first.');
      return;
    }
    final auth = context.read<AuthService>();
    try {
      await auth.sendPasswordReset(email);
      if (mounted) {
        _showSnack(context, 'Password reset email sent to $email.');
      }
    } on FirebaseAuthException catch (e, stack) {
      _logAuthError(e, stack);
      if (mounted) _showError(context, _authMessage(e));
    } catch (e, stack) {
      _logAuthError(e, stack);
      if (mounted) _showError(context, e.toString());
    }
  }
}

// ---------------------------------------------------------------------------
// Phone tab
// ---------------------------------------------------------------------------

class _PhoneTab extends StatefulWidget {
  const _PhoneTab();

  @override
  State<_PhoneTab> createState() => _PhoneTabState();
}

class _PhoneTabState extends State<_PhoneTab> {
  final _phoneCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  bool _loading = false;
  String? _verificationId;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _phoneCtrl,
            decoration: const InputDecoration(
              labelText: 'Phone number (+12025551234)',
              prefixIcon: Icon(Icons.phone_outlined),
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
            enabled: _verificationId == null,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _requestCode(),
          ),
          const SizedBox(height: 12),
          if (_verificationId != null) ...[
            TextFormField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: '6-digit SMS code',
                prefixIcon: Icon(Icons.sms_outlined),
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _verifyCode(),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _loading ? null : _verifyCode,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Verify Code'),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => setState(() => _verificationId = null),
              child: const Text('Change phone number'),
            ),
          ] else ...[
            FilledButton(
              onPressed: _loading ? null : _requestCode,
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Send Verification Code'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _requestCode() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      _showError(context, 'Enter a phone number including country code.');
      return;
    }
    final auth = context.read<AuthService>();
    setState(() => _loading = true);
    try {
      await auth.verifyPhoneNumber(
        phoneNumber: phone,
        onCodeSent: (verificationId, _) {
          if (mounted) {
            setState(() {
              _verificationId = verificationId;
              _loading = false;
            });
            _showSnack(context, 'Verification code sent.');
          }
        },
        onVerificationCompleted: (credential) async {
          // Instant verification on Android — sign in automatically.
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
          } catch (e) {
            if (mounted) _showError(context, e.toString());
          }
        },
        onVerificationFailed: (e) {
          if (mounted) {
            _logAuthError(e);
            setState(() => _loading = false);
            _showError(context, _authMessage(e));
          }
        },
        onCodeAutoRetrievalTimeout: (_) {
          if (mounted) setState(() => _loading = false);
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        _showError(context, e.toString());
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      _showError(context, 'Enter the 6-digit code from the SMS.');
      return;
    }
    final auth = context.read<AuthService>();
    setState(() => _loading = true);
    try {
      await auth.signInWithPhoneOtp(
        verificationId: _verificationId!,
        smsCode: code,
      );
    } on FirebaseAuthException catch (e, stack) {
      _logAuthError(e, stack);
      if (mounted) {
        setState(() => _loading = false);
        _showError(context, _authMessage(e));
      }
    } catch (e, stack) {
      _logAuthError(e, stack);
      if (mounted) {
        setState(() => _loading = false);
        _showError(context, e.toString());
      }
    }
  }
}

// ---------------------------------------------------------------------------
// Shared helpers / widgets
// ---------------------------------------------------------------------------

class _Divider extends StatelessWidget {
  final String label;
  const _Divider({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ),
        const Expanded(child: Divider()),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final Widget icon;
  final String label;
  final VoidCallback onPressed;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: icon,
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        alignment: Alignment.center,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Auth error logging
// ---------------------------------------------------------------------------

/// Logs a Firebase authentication error to the console without including any
/// sensitive information (passwords, tokens, etc.).
///
/// In debug builds the full stack trace is also printed.
void _logAuthError(Object error, [StackTrace? stack]) {
  if (error is FirebaseAuthException) {
    debugPrint(
      '[Auth] FirebaseAuthException — code: ${error.code}, '
      'message: ${error.message}',
    );
  } else {
    debugPrint('[Auth] Auth error (${error.runtimeType}): $error');
  }
  if (kDebugMode && stack != null) {
    debugPrint('[Auth] Stack trace:\n$stack');
  }
}

// ---------------------------------------------------------------------------
// Error / snackbar helpers
// ---------------------------------------------------------------------------

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
    ),
  );
}

void _showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
}

/// Maps a [FirebaseAuthException] to a human-readable message.
///
/// In release builds a friendly message with the error code is returned.
/// In debug builds the raw Firebase error message is appended so that
/// misconfiguration issues (invalid API key, provider disabled, SHA mismatch,
/// etc.) are immediately visible.
String _authMessage(FirebaseAuthException e) {
  final friendlyMessage = _friendlyAuthMessage(e.code);
  if (kDebugMode && e.message != null && e.message!.isNotEmpty) {
    return '$friendlyMessage\n[Debug] ${e.code}: ${e.message}';
  }
  return friendlyMessage;
}

/// Returns a user-friendly string for a given [FirebaseAuthException] code.
@visibleForTesting
String friendlyAuthMessage(String code) => _friendlyAuthMessage(code);

String _friendlyAuthMessage(String code) {
  switch (code) {
    case 'user-not-found':
      return 'No account found for this email. Please create one.';
    case 'wrong-password':
      return 'Incorrect password. Please try again.';
    case 'invalid-credential':
      return 'Invalid credentials. Check your email and password.';
    case 'email-already-in-use':
      return 'An account with this email already exists. Please sign in.';
    case 'weak-password':
      return 'Password is too weak. Use at least 6 characters.';
    case 'invalid-email':
      return 'That does not look like a valid email address.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a moment and try again.';
    case 'network-request-failed':
      return 'Network error. Check your internet connection.';
    case 'invalid-phone-number':
      return 'Invalid phone number. Include the country code (e.g. +1).';
    case 'invalid-verification-code':
      return 'Invalid verification code. Check the SMS and try again.';
    case 'session-expired':
      return 'Verification session expired. Please request a new code.';
    case 'invalid-api-key':
      return 'Authentication configuration error (invalid-api-key). Contact support.';
    case 'app-not-authorized':
      return 'This app is not authorized for Firebase Authentication. Check your SHA certificate and Firebase project settings.';
    case 'operation-not-allowed':
      return 'This sign-in method is not enabled (operation-not-allowed). Enable it in the Firebase console.';
    case 'quota-exceeded':
      return 'Authentication quota exceeded. Please try again later.';
    default:
      return 'Authentication error ($code). Please try again.';
  }
}

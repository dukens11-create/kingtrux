import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

/// Full-screen login / sign-up page with a custom map-lines background,
/// vignette overlay, and a glassmorphism card containing the auth form.
///
/// Supports email/password sign-in, account creation, and password reset
/// using the app's [AuthService].
class KingtruxLoginPage extends StatefulWidget {
  const KingtruxLoginPage({super.key});

  @override
  State<KingtruxLoginPage> createState() => _KingtruxLoginPageState();
}

class _KingtruxLoginPageState extends State<KingtruxLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  bool _loading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _confirmPwCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen background image ───────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/logo_bg.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          // ── Scrollable content ─────────────────────────────────────────────
          SafeArea(
            child: SingleChildScrollView(
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 24),
                  const _BrandHeader(),
                  const SizedBox(height: 40),
                  _buildLoginCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Glassmorphism card
  // ---------------------------------------------------------------------------

  Widget _buildLoginCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Email
              _KtxField(
                controller: _emailCtrl,
                label: 'Email',
                hintText: 'Enter your email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your email';
                  if (!v.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Password
              _KtxField(
                controller: _pwCtrl,
                label: 'Password',
                hintText: 'Enter your password',
                prefixIcon: Icons.lock_outline,
                obscureText: _obscurePassword,
                suffixIcon: _VisibilityToggle(
                  obscure: _obscurePassword,
                  onToggle: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
                textInputAction: _isSignUp
                    ? TextInputAction.next
                    : TextInputAction.done,
                onFieldSubmitted: _isSignUp ? null : (_) => _submit(),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter your password';
                  if (_isSignUp && v.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
              ),
              // Confirm password (sign-up only)
              if (_isSignUp) ...[
                const SizedBox(height: 16),
                _KtxField(
                  controller: _confirmPwCtrl,
                  label: 'Confirm Password',
                  hintText: 'Re-enter your password',
                  prefixIcon: Icons.lock_outline,
                  obscureText: _obscureConfirmPassword,
                  suffixIcon: _VisibilityToggle(
                    obscure: _obscureConfirmPassword,
                    onToggle: () => setState(() =>
                        _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return 'Confirm your password';
                    }
                    if (v != _pwCtrl.text) return 'Passwords do not match';
                    return null;
                  },
                ),
              ],
              // Forgot password (sign-in only)
              if (!_isSignUp) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Semantics(
                    label: 'Forgot password',
                    child: TextButton(
                      onPressed: _loading ? null : _resetPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Primary action button – filled blue
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Semantics(
                        button: true,
                        label: _isSignUp ? 'Create Account' : 'Sign in',
                        child: Text(
                          _isSignUp ? 'Create Account' : 'Sign in',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              // Toggle sign-in / create-account – outlined blue
              OutlinedButton(
                onPressed: _loading
                    ? null
                    : () => setState(() {
                          _isSignUp = !_isSignUp;
                          _formKey.currentState?.reset();
                        }),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: Color(0xFF1565C0), width: 1.5),
                  foregroundColor: const Color(0xFF1565C0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Semantics(
                  button: true,
                  label: _isSignUp
                      ? 'Sign in to existing account'
                      : 'Create account',
                  child: Text(
                    _isSignUp ? 'Sign in' : 'Create account',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Auth actions
  // ---------------------------------------------------------------------------

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
// Brand header
// ---------------------------------------------------------------------------

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          label: 'KINGTRUX logo',
          child: Image.asset(
            'assets/logo_bg.png',
            height: 180,
            fit: BoxFit.contain,
            semanticLabel: 'KINGTRUX logo',
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'KINGTRUX',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            letterSpacing: 4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Smart Truck Navigation',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white70,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable styled text field
// ---------------------------------------------------------------------------

class _KtxField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hintText;
  final IconData prefixIcon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputAction? textInputAction;
  final void Function(String)? onFieldSubmitted;
  final String? Function(String?)? validator;

  const _KtxField({
    required this.controller,
    required this.label,
    this.hintText,
    required this.prefixIcon,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.textInputAction,
    this.onFieldSubmitted,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      child: TextFormField(
        controller: controller,
        obscureText: obscureText,
        keyboardType: keyboardType,
        autocorrect: false,
        textInputAction: textInputAction,
        onFieldSubmitted: onFieldSubmitted,
        validator: validator,
        style: const TextStyle(color: Color(0xFF1A237E)),
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: const TextStyle(color: Colors.black54),
          hintStyle: const TextStyle(color: Colors.black38),
          prefixIcon: Icon(prefixIcon, color: Colors.blueGrey),
          suffixIcon: suffixIcon,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Colors.black26),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Color(0xFF1565C0), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
          ),
          errorStyle: TextStyle(color: Colors.red.shade600),
          filled: true,
          fillColor: const Color(0xFFF5F7FF),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Password visibility toggle icon button
// ---------------------------------------------------------------------------

class _VisibilityToggle extends StatelessWidget {
  final bool obscure;
  final VoidCallback onToggle;

  const _VisibilityToggle({required this.obscure, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: Colors.blueGrey,
      ),
      tooltip: obscure ? 'Show password' : 'Hide password',
      onPressed: onToggle,
    );
  }
}

// ---------------------------------------------------------------------------
// Auth error helpers (private to this file)
// ---------------------------------------------------------------------------

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

String _authMessage(FirebaseAuthException e) {
  final msg = _friendlyAuthMessage(e.code);
  if (kDebugMode && e.message != null && e.message!.isNotEmpty) {
    return '$msg\n[Debug] ${e.code}: ${e.message}';
  }
  return msg;
}

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
    default:
      return 'Authentication error ($code). Please try again.';
  }
}

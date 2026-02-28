import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const _kPrimaryBlue = Color(0xFF1565C0);
const _kDarkNavy = Color(0xFF0D1B3E);
const _kMidNavy = Color(0xFF1A237E);
const _kFallbackEmail = 'kingtrux00@gmail.com';

/// Full-screen login / account page for KINGTRUX.
///
/// **Signed-out state**: email/password login form with brand header.
/// **Signed-in state**: profile card with K avatar, "Signed in" status, email,
/// "Driver account" and "GPS Ready" badges, a large Sign-out button, and a
/// branded footer. Background uses a custom stylised map painter.
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
    final authService = context.read<AuthService>();
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Stylised map background ────────────────────────────────────────
          CustomPaint(painter: _MapBackgroundPainter()),
          // ── Semi-transparent overlay for card readability ──────────────────
          Container(color: _kDarkNavy.withAlpha(160)),
          // ── Scrollable content ─────────────────────────────────────────────
          SafeArea(
            child: StreamBuilder<User?>(
              stream: authService.authStateChanges,
              builder: (context, snapshot) {
                final user = snapshot.data;
                return SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (user != null) ...[
                        _SignedInView(
                            user: user, authService: authService),
                      ] else ...[
                        const _BrandHeader(),
                        const SizedBox(height: 24),
                        _buildLoginCard(),
                        const SizedBox(height: 32),
                        const _Footer(),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Login card (signed-out state)
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
                  backgroundColor: _kPrimaryBlue,
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
                  side: const BorderSide(color: _kPrimaryBlue, width: 1.5),
                  foregroundColor: _kPrimaryBlue,
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
// Signed-in full view (avatar card + badges + sign-out button + footer)
// ---------------------------------------------------------------------------

class _SignedInView extends StatelessWidget {
  final User user;
  final AuthService authService;

  const _SignedInView({required this.user, required this.authService});

  @override
  Widget build(BuildContext context) {
    final email =
        (user.email?.isNotEmpty == true) ? user.email! : _kFallbackEmail;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        // ── Profile card ─────────────────────────────────────────────────────
        _ProfileCard(email: email),
        const SizedBox(height: 20),
        // ── Large Sign out button ─────────────────────────────────────────────
        _SignOutButton(authService: authService),
        const SizedBox(height: 40),
        // ── Footer ───────────────────────────────────────────────────────────
        const _Footer(),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Profile card – avatar, "Signed in" status, email, badges
// ---------------------------------------------------------------------------

class _ProfileCard extends StatelessWidget {
  final String email;

  const _ProfileCard({required this.email});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        // ── White card body ─────────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.only(top: 44),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(60),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // "Signed in ✓"
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Signed in',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: _kMidNavy,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.verified_rounded,
                      color: Colors.green, size: 22),
                ],
              ),
              const SizedBox(height: 10),
              // Email row with envelope icon
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.email_outlined,
                      color: Colors.blueGrey, size: 15),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      email,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black54,
                      ),
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // ── Badges row ─────────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const _Badge(
                    icon: Icons.local_shipping_rounded,
                    label: 'Driver account',
                    foreground: Colors.white,
                    background: _kPrimaryBlue,
                  ),
                  const SizedBox(width: 12),
                  const _Badge(
                    icon: Icons.gps_fixed,
                    label: 'GPS Ready',
                    foreground: Colors.white,
                    background: Color(0xFF2E7D32),
                    trailingIcon: Icons.check_circle_rounded,
                  ),
                ],
              ),
            ],
          ),
        ),
        // ── Circular K avatar (overlaps card top) ───────────────────────────
        const Positioned(
          top: 0,
          child: _KAvatar(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Circular K avatar
// ---------------------------------------------------------------------------

class _KAvatar extends StatelessWidget {
  const _KAvatar();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'KINGTRUX logo',
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF1E88E5), Color(0xFF0D47A1)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: _kPrimaryBlue.withAlpha(120),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(color: Colors.white, width: 3),
        ),
        alignment: Alignment.center,
        child: const Text(
          'K',
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Badge pill widget
// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color foreground;
  final Color background;
  final IconData? trailingIcon;

  const _Badge({
    required this.icon,
    required this.label,
    required this.foreground,
    required this.background,
    this.trailingIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(50),
        boxShadow: [
          BoxShadow(
            color: background.withAlpha(90),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: foreground, size: 15),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 5),
            Icon(trailingIcon, color: foreground, size: 14),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brand header (shown in signed-out state)
// ---------------------------------------------------------------------------

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Logo avatar (reuse _KAvatar)
        const Center(child: _KAvatar()),
        const SizedBox(height: 16),
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
          'Professional Truck GPS',
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
// Sign-out button (shown in signed-in state)
// ---------------------------------------------------------------------------

class _SignOutButton extends StatefulWidget {
  final AuthService authService;
  const _SignOutButton({required this.authService});

  @override
  State<_SignOutButton> createState() => _SignOutButtonState();
}

class _SignOutButtonState extends State<_SignOutButton> {
  bool _loading = false;

  Future<void> _signOut() async {
    setState(() => _loading = true);
    try {
      await widget.authService.signOut();
    } catch (e, stack) {
      _logAuthError(e, stack);
      if (mounted) _showError(context, e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: FilledButton.icon(
        onPressed: _loading ? null : _signOut,
        icon: _loading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.logout_rounded, size: 22),
        label: const Text(
          'Sign out',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        style: FilledButton.styleFrom(
          backgroundColor: _kPrimaryBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Footer
// ---------------------------------------------------------------------------

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'KINGTRUX • Built for truckers',
        style: TextStyle(
          color: Colors.white60,
          fontSize: 12,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Stylised map background painter
// ---------------------------------------------------------------------------

class _MapBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Deep navy base
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF0A1628),
    );

    final roadPaint = Paint()
      ..color = const Color(0xFF1C2E52)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final majorRoadPaint = Paint()
      ..color = const Color(0xFF1E3A66)
      ..strokeWidth = 5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // Horizontal roads
    for (var i = 0; i < 6; i++) {
      final y = h * (0.1 + i * 0.15);
      final path = Path()
        ..moveTo(0, y)
        ..cubicTo(w * 0.25, y - 20, w * 0.5, y + 15, w, y + 5);
      canvas.drawPath(path, i.isEven ? majorRoadPaint : roadPaint);
    }

    // Vertical roads
    for (var i = 0; i < 5; i++) {
      final x = w * (0.15 + i * 0.18);
      final path = Path()
        ..moveTo(x, 0)
        ..cubicTo(x + 10, h * 0.3, x - 15, h * 0.6, x + 5, h);
      canvas.drawPath(path, i.isEven ? majorRoadPaint : roadPaint);
    }

    // Diagonal connector roads
    final diagPaint = Paint()
      ..color = const Color(0xFF162340)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(Offset(0, h * 0.2), Offset(w * 0.6, h * 0.8), diagPaint);
    canvas.drawLine(Offset(w * 0.3, 0), Offset(w, h * 0.7), diagPaint);
    canvas.drawLine(Offset(0, h * 0.6), Offset(w * 0.4, h), diagPaint);

    // Subtle intersection dots
    final dotPaint = Paint()
      ..color = const Color(0xFF243B6E)
      ..style = PaintingStyle.fill;

    final rng = math.Random(42);
    for (var i = 0; i < 12; i++) {
      canvas.drawCircle(
        Offset(rng.nextDouble() * w, rng.nextDouble() * h),
        3,
        dotPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
        style: const TextStyle(color: _kMidNavy),
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
            borderSide: const BorderSide(color: _kPrimaryBlue, width: 1.5),
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

import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'widgets/kingtrux_logo.dart';

class KingtruxLoginPage extends StatefulWidget {
  const KingtruxLoginPage({super.key});

  @override
  State<KingtruxLoginPage> createState() => _KingtruxLoginPageState();
}

class _KingtruxLoginPageState extends State<KingtruxLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;
  bool _isSignUp = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final auth = context.read<AuthService>();
      await auth.signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthMessage(e.code));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _createAccount() async {
    if (_isSignUp) {
      if (!(_formKey.currentState?.validate() ?? false)) return;
      FocusScope.of(context).unfocus();
      setState(() {
        _loading = true;
        _error = null;
      });
      try {
        final auth = context.read<AuthService>();
        await auth.createAccountWithEmail(
            _emailCtrl.text.trim(), _passCtrl.text);
      } on FirebaseAuthException catch (e) {
        if (mounted) setState(() => _error = _friendlyAuthMessage(e.code));
      } catch (e) {
        if (mounted) setState(() => _error = e.toString());
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    } else {
      setState(() {
        _isSignUp = true;
        _error = null;
        _formKey.currentState?.reset();
      });
    }
  }

  Future<void> _forgotPassword() async {
    FocusScope.of(context).unfocus();
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Enter your email address above first.')),
      );
      return;
    }
    try {
      final auth = context.read<AuthService>();
      await auth.sendPasswordReset(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() => _error = _friendlyAuthMessage(e.code));
    }
  }

  void _switchToSignIn() {
    setState(() {
      _isSignUp = false;
      _error = null;
      _formKey.currentState?.reset();
    });
  }

  static String _friendlyAuthMessage(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Authentication error ($code). Please try again.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 740;

    // Force a light theme for the login page regardless of the app's
    // night-mode setting so the page is always bright and readable.
    final lightTheme = Theme.of(context).copyWith(
      brightness: Brightness.light,
      scaffoldBackgroundColor: Colors.white,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF214EA8),
        brightness: Brightness.light,
      ),
    );

    return Theme(
      data: lightTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarBrightness: Brightness.light,
          statusBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          body: Stack(
        children: [
          // BACKGROUND (map image if available, otherwise gradient)
          Positioned.fill(
            child: Image.asset(
              'assets/images/map_bg.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xFFE8EEF9),
                        Color(0xFFCBD7F2),
                        Color(0xFFE8EEF9),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Soft overlay to make text readable
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.15),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        const SizedBox(height: 8),

                        // TOP CHIPS
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: const [
                            _TopChip(
                              icon: Icons.directions_bus_filled,
                              label: 'Driver account',
                              bg: Colors.white,
                              fg: Color(0xFF243B6B),
                            ),
                            _TopChip(
                              icon: Icons.gps_fixed,
                              label: 'GPS Ready',
                              bg: Color(0xFF203B7A),
                              fg: Colors.white,
                              trailingCheck: true,
                            ),
                          ],
                        ),

                        SizedBox(height: isSmall ? 36 : 62),

                        // BRAND HEADER
                        const _BrandHeader(),

                        SizedBox(height: isSmall ? 26 : 38),

                        // LOGIN GLASS CARD
                        _GlassCard(
                          child: Padding(
                            padding:
                                const EdgeInsets.fromLTRB(18, 18, 18, 18),
                            child: Column(
                              children: [
                                if (_error != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color:
                                          Colors.red.shade50.withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                ],

                                // Email field
                                _InputFormField(
                                  controller: _emailCtrl,
                                  hint: 'Email',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Enter your email';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 14),

                                // Password field
                                _InputFormField(
                                  controller: _passCtrl,
                                  hint: 'Password',
                                  icon: Icons.lock_outline,
                                  obscureText: _obscure,
                                  validator: (v) {
                                    if (v == null || v.isEmpty) {
                                      return 'Enter your password';
                                    }
                                    if (_isSignUp && v.length < 6) {
                                      return 'Password must be at least 6 characters';
                                    }
                                    return null;
                                  },
                                  suffix: IconButton(
                                    onPressed: () =>
                                        setState(() => _obscure = !_obscure),
                                    icon: Icon(
                                      _obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined,
                                      color: const Color(0xFF6D7A96),
                                    ),
                                  ),
                                ),

                                // Confirm password (sign-up only)
                                if (_isSignUp) ...[
                                  const SizedBox(height: 14),
                                  _InputFormField(
                                    controller: _confirmPassCtrl,
                                    hint: 'Confirm Password',
                                    icon: Icons.lock_outline,
                                    obscureText: true,
                                    validator: (v) {
                                      if (v == null || v.isEmpty) {
                                        return 'Confirm your password';
                                      }
                                      if (v != _passCtrl.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                ],

                                // Forgot password (sign-in only)
                                if (!_isSignUp) ...[
                                  const SizedBox(height: 12),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                      onPressed: _forgotPassword,
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF7B3A2E),
                                        textStyle: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      child: const Text('Forgot password?'),
                                    ),
                                  ),
                                ] else
                                  const SizedBox(height: 12),

                                const SizedBox(height: 4),

                                // PRIMARY BUTTON (Sign in / Create Account)
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: FilledButton(
                                    onPressed:
                                        _loading ? null : (_isSignUp ? _createAccount : _signIn),
                                    style: FilledButton.styleFrom(
                                      backgroundColor:
                                          const Color(0xFF214EA8),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                      ),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white),
                                          )
                                        : Text(
                                            _isSignUp
                                                ? 'Create Account'
                                                : 'Sign in',
                                            style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700),
                                          ),
                                  ),
                                ),

                                const SizedBox(height: 12),

                                // SECONDARY BUTTON
                                SizedBox(
                                  width: double.infinity,
                                  height: 56,
                                  child: OutlinedButton(
                                    onPressed: _loading
                                        ? null
                                        : (_isSignUp
                                            ? _switchToSignIn
                                            : _createAccount),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor:
                                          const Color(0xFF214EA8),
                                      side: const BorderSide(
                                          color: Color(0xFF214EA8),
                                          width: 1.6),
                                      shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(18),
                                      ),
                                      backgroundColor:
                                          Colors.white.withOpacity(0.15),
                                    ),
                                    child: Text(
                                      _isSignUp
                                          ? 'Back to Sign in'
                                          : 'Create account',
                                      style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const Spacer(),

                        // FOOTER
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            'KINGTRUX • Built for truckers',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
        ),
      ),
    );
  }
}

/// ====== BRAND HEADER ======
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const KingtruxLogo(size: 64),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'KINGTRUX',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: Color(0xFF214EA8),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Professional Truck GPS',
              style: TextStyle(
                fontSize: 15,
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ====== TOP CHIP ======
class _TopChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final bool trailingCheck;

  const _TopChip({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    this.trailingCheck = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.92),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: fg),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
          if (trailingCheck) ...[
            const SizedBox(width: 10),
            Container(
              height: 18,
              width: 18,
              decoration: BoxDecoration(
                color: const Color(0xFF22C1A1),
                borderRadius: BorderRadius.circular(30),
              ),
              child: const Icon(Icons.check, size: 14, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }
}

/// ====== GLASS CARD ======
class _GlassCard extends StatelessWidget {
  final Widget child;

  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.22),
            borderRadius: BorderRadius.circular(26),
            border:
                Border.all(color: Colors.white.withOpacity(0.35), width: 1.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.22),
                blurRadius: 26,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

/// ====== INPUT FORM FIELD ======
class _InputFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const _InputFormField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.70),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        validator: validator,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF22314F),
        ),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: const Color(0xFF6D7A96)),
          suffixIcon: suffix,
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF6D7A96),
            fontWeight: FontWeight.w600,
          ),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          errorStyle: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}



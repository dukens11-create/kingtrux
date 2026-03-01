import 'dart:ui';
import 'package:flutter/material.dart';

class KingtruxLoginPage extends StatefulWidget {
  const KingtruxLoginPage({super.key});

  @override
  State<KingtruxLoginPage> createState() => _KingtruxLoginPageState();
}

class _KingtruxLoginPageState extends State<KingtruxLoginPage> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);

    // TODO: Replace with your real auth (Firebase / API).
    await Future.delayed(const Duration(milliseconds: 900));

    setState(() => _loading = false);

    // Example:
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Signed in (demo). Hook up real auth now.")),
    );
  }

  void _createAccount() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Create account (demo). Navigate to signup.")),
    );
  }

  void _forgotPassword() {
    FocusScope.of(context).unfocus();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Forgot password (demo). Add reset flow.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 740;

    return Scaffold(
      body: Stack(
        children: [
          // BACKGROUND (map image if available, otherwise gradient)
          Positioned.fill(
            child: Image.asset(
              "assets/images/map_bg.png",
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
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.15),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  child: Column(
                    children: [
                      const SizedBox(height: 8),

                      // TOP CHIPS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          _TopChip(
                            icon: Icons.directions_bus_filled,
                            label: "Driver account",
                            bg: Colors.white,
                            fg: Color(0xFF243B6B),
                          ),
                          _TopChip(
                            icon: Icons.gps_fixed,
                            label: "GPS Ready",
                            bg: Color(0xFF203B7A),
                            fg: Colors.white,
                            trailingCheck: true,
                          ),
                        ],
                      ),

                      // push brand higher
                      SizedBox(height: isSmall ? 36 : 62),

                      // BRAND HEADER (LOGO LEFT + TEXT RIGHT)
                      const _BrandHeader(),

                      SizedBox(height: isSmall ? 26 : 38),

                      // LOGIN GLASS CARD
                      _GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                          child: Column(
                            children: [
                              _InputField(
                                controller: _emailCtrl,
                                hint: "Email",
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 14),
                              _InputField(
                                controller: _passCtrl,
                                hint: "Password",
                                icon: Icons.lock_outline,
                                obscureText: _obscure,
                                suffix: IconButton(
                                  onPressed: () => setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure ? Icons.visibility_off : Icons.visibility,
                                    color: const Color(0xFF6D7A96),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _forgotPassword,
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFF7B3A2E),
                                    textStyle: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  child: const Text("Forgot password?"),
                                ),
                              ),

                              const SizedBox(height: 4),

                              // SIGN IN BUTTON
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _loading ? null : _signIn,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF214EA8),
                                    foregroundColor: Colors.white,
                                    elevation: 8,
                                    shadowColor: Colors.black.withOpacity(0.25),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Text(
                                          "Sign in",
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // CREATE ACCOUNT BUTTON (OUTLINE)
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: OutlinedButton(
                                  onPressed: _createAccount,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: const Color(0xFF214EA8),
                                    side: const BorderSide(color: Color(0xFF214EA8), width: 1.6),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18),
                                    ),
                                    backgroundColor: Colors.white.withOpacity(0.15),
                                  ),
                                  child: const Text(
                                    "Create account",
                                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
                          "KINGTRUX • Built for truckers",
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
        ],
      ),
    );
  }
}

/// ====== BRAND HEADER (LOGO LEFT + TEXT RIGHT) ======
class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Image.asset(
          "assets/logo/kingtrux_shield.png",
          height: 64,
          errorBuilder: (_, __, ___) {
            // fallback if logo missing
            return Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: const Color(0xFF214EA8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Center(
                child: Text("K", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 26)),
              ),
            );
          },
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "KINGTRUX",
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: 2.0,
                color: Color(0xFF214EA8),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              "Smart Truck Navigation",
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
            border: Border.all(color: Colors.white.withOpacity(0.35), width: 1.0),
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

/// ====== INPUT FIELD ======
class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffix;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.obscureText = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.70),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.8)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
        ),
      ),
    );
  }
}

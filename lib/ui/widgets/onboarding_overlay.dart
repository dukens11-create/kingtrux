import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';

/// Callout descriptor used by [OnboardingOverlay].
class _Callout {
  const _Callout({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

const _callouts = [
  _Callout(
    icon: Icons.search_rounded,
    title: '"Where to?"',
    body: 'Tap the "Where to?" bar at the top to search for a destination by address, or long-press anywhere on the map to drop a pin.',
  ),
  _Callout(
    icon: Icons.layers_rounded,
    title: 'POI Layers',
    body: 'Tap "Layers" in the bottom toolbar to filter Points of Interest — fuel stops, rest areas, scales, parking, and more.',
  ),
  _Callout(
    icon: Icons.flag_rounded,
    title: 'Set Destination',
    body: 'Use the "Destination" toolbar button to activate tap-to-pin mode, or tap "Truck" to set your vehicle profile for accurate routing.',
  ),
];

/// A semi-transparent full-screen overlay shown once on the first map launch.
///
/// Displays 2–3 feature callout cards and a "Got it" dismiss button.
/// The caller is responsible for persisting dismissal (via [OnboardingOverlay.onDismiss])
/// so the overlay is not shown again on subsequent launches.
class OnboardingOverlay extends StatefulWidget {
  const OnboardingOverlay({super.key, required this.onDismiss});

  /// Called when the user dismisses the overlay. The caller should persist
  /// the dismissal to avoid showing the overlay again.
  final VoidCallback onDismiss;

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    )..forward();
    _fade = CurvedAnimation(parent: _anim, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    HapticFeedback.lightImpact();
    await _anim.reverse();
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final mq = MediaQuery.of(context);

    return FadeTransition(
      opacity: _fade,
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.spaceMD),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ── Header ────────────────────────────────────────────────
                Row(
                  children: [
                    Icon(Icons.local_shipping_rounded, color: cs.primary, size: 32),
                    const SizedBox(width: AppTheme.spaceSM),
                    Expanded(
                      child: Text(
                        'Welcome to KINGTRUX',
                        style: tt.titleLarge?.copyWith(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTheme.spaceSM),
                Text(
                  'Here\'s a quick tour of the key features:',
                  style: tt.bodyMedium?.copyWith(color: Colors.white70),
                ),
                const SizedBox(height: AppTheme.spaceLG),

                // ── Callout cards ─────────────────────────────────────────
                // Constrain height on small screens.
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: mq.size.height * 0.5,
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _callouts.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppTheme.spaceSM),
                    itemBuilder: (context, index) {
                      final c = _callouts[index];
                      return _CalloutCard(
                        icon: c.icon,
                        title: c.title,
                        body: c.body,
                        cs: cs,
                        tt: tt,
                      );
                    },
                  ),
                ),
                const SizedBox(height: AppTheme.spaceLG),

                // ── Dismiss button ────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    key: const Key('onboarding_got_it'),
                    onPressed: _dismiss,
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Got it'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppTheme.spaceSM + AppTheme.spaceXS,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Callout card
// ---------------------------------------------------------------------------

class _CalloutCard extends StatelessWidget {
  const _CalloutCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.cs,
    required this.tt,
  });

  final IconData icon;
  final String title;
  final String body;
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      color: cs.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cs.primary, size: 28),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: tt.titleSmall?.copyWith(color: cs.onSurface),
                  ),
                  const SizedBox(height: AppTheme.spaceXS),
                  Text(
                    body,
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

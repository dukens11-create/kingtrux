import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config.dart';
import '../state/app_state.dart';
import 'theme/app_theme.dart';

/// Full-screen paywall for KINGTRUX Pro subscription.
///
/// Displays available packages fetched from RevenueCat, handles purchase /
/// restore, and reflects entitlement state back into [AppState].
class PaywallScreen extends StatefulWidget {
  const PaywallScreen({super.key});

  @override
  State<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends State<PaywallScreen> {
  Offerings? _offerings;
  Package? _selectedPackage;
  bool _isLoading = true;
  bool _isPurchasing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadOfferings();
  }

  Future<void> _loadOfferings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final service = context.read<AppState>().revenueCatService;

    if (!service.hasKeys) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'In-app purchases are not configured yet.\n'
            'Set REVENUECAT_IOS_API_KEY / REVENUECAT_ANDROID_API_KEY via '
            '--dart-define. See README for instructions.';
      });
      return;
    }

    final offerings = await service.fetchOfferings();
    if (!mounted) return;

    if (offerings == null) {
      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not load subscription options.\n'
            'Check your internet connection and try again.';
      });
      return;
    }

    final current = offerings.getOffering(Config.offeringId) ?? offerings.current;

    setState(() {
      _isLoading = false;
      _offerings = offerings;
      // Default to yearly ("Best Value") when available.
      if (current != null) {
        _selectedPackage = current.annual ?? current.monthly ?? current.availablePackages.firstOrNull;
      }
    });
  }

  Future<void> _purchase() async {
    if (_selectedPackage == null) return;

    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<AppState>().revenueCatService;
      final info = await service.purchase(_selectedPackage!);
      if (!mounted) return;
      final isPro = service.isProActive(info);
      context.read<AppState>().setProStatus(active: isPro);
      if (isPro && mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome to KINGTRUX Pro! 🚛')),
        );
      }
    } on PlatformException catch (e) {
      if (!mounted) return;
      final code = PurchasesErrorHelper.getErrorCode(e);
      if (code != PurchasesErrorCode.purchaseCancelledError) {
        setState(() => _errorMessage = _friendlyError(code));
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  Future<void> _restore() async {
    setState(() {
      _isPurchasing = true;
      _errorMessage = null;
    });

    try {
      final service = context.read<AppState>().revenueCatService;
      final info = await service.restorePurchases();
      if (!mounted) return;
      final isPro = service.isProActive(info);
      context.read<AppState>().setProStatus(active: isPro);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isPro
                ? 'Pro subscription restored!'
                : 'No active subscription found.',
          ),
        ),
      );
      if (isPro) Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  String _friendlyError(PurchasesErrorCode code) {
    switch (code) {
      case PurchasesErrorCode.networkError:
        return 'Network error. Check your internet connection and try again.';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Purchases are not allowed on this device.';
      case PurchasesErrorCode.receiptAlreadyInUseError:
        return 'This receipt is already in use. Try restoring purchases.';
      default:
        return 'Purchase failed (${code.name}). Please try again.';
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('KINGTRUX Pro'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: 'Close',
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppTheme.spaceMD,
                  vertical: AppTheme.spaceMD,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // ── Hero section ──────────────────────────────────────
                    _HeroSection(cs: cs, tt: tt),
                    const SizedBox(height: AppTheme.spaceLG),

                    // ── Feature bullets ───────────────────────────────────
                    const _BulletList(),
                    const SizedBox(height: AppTheme.spaceLG),

                    // ── Error banner ──────────────────────────────────────
                    if (_errorMessage != null) ...[
                      _ErrorBanner(message: _errorMessage!, cs: cs),
                      const SizedBox(height: AppTheme.spaceMD),
                    ],

                    // ── Package selector ──────────────────────────────────
                    if (_offerings != null) ...[
                      _PackageSelector(
                        offerings: _offerings!,
                        selectedPackage: _selectedPackage,
                        onSelected: (pkg) =>
                            setState(() => _selectedPackage = pkg),
                      ),
                      const SizedBox(height: AppTheme.spaceLG),
                    ],

                    // ── CTA button ────────────────────────────────────────
                    _CtaButton(
                      isPurchasing: _isPurchasing,
                      enabled: _selectedPackage != null && !_isPurchasing,
                      onTap: _purchase,
                      cs: cs,
                    ),
                    const SizedBox(height: AppTheme.spaceSM),

                    // ── Pricing line ──────────────────────────────────────
                    Text(
                      'Then \$9.99/month or \$99.99/year (Best Value). Cancel anytime.',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppTheme.spaceMD),

                    // ── Restore purchases ─────────────────────────────────
                    Center(
                      child: TextButton(
                        onPressed: _isPurchasing ? null : _restore,
                        child: const Text('Restore purchases'),
                      ),
                    ),
                    const SizedBox(height: AppTheme.spaceMD),

                    // ── Fine print ────────────────────────────────────────
                    const _FinePrint(),
                    const SizedBox(height: AppTheme.spaceMD),

                    // ── Terms & Privacy links ─────────────────────────────
                    const _LegalLinks(),
                    const SizedBox(height: AppTheme.spaceMD),
                  ],
                ),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hero section
// ---------------------------------------------------------------------------

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.cs, required this.tt});
  final ColorScheme cs;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(Icons.local_shipping_rounded, size: 64, color: cs.primary),
        const SizedBox(height: AppTheme.spaceSM),
        Text(
          'KINGTRUX Pro',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurface,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppTheme.spaceXS),
        Text(
          'Truck GPS built for OTR in USA + Canada.',
          style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Feature bullet list
// ---------------------------------------------------------------------------

const List<String> _bullets = [
  'Truck routing with restrictions (height/weight/length/axles/hazmat)',
  'Driver POIs: truck stops, parking, scales, rest areas, fuel (near-me + along-route)',
  'Trip planning: multi-stop routes, reorder stops, save trips',
  'Turn-by-turn navigation + voice (EN/FR/ES) + alerts',
];

class _BulletList extends StatelessWidget {
  const _BulletList();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spaceMD),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _bullets
              .map(
                (b) => Padding(
                  padding: const EdgeInsets.only(bottom: AppTheme.spaceSM),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle_rounded,
                          size: 18, color: cs.primary),
                      const SizedBox(width: AppTheme.spaceSM),
                      Expanded(
                        child: Text(b, style: tt.bodyMedium),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Package selector
// ---------------------------------------------------------------------------

class _PackageSelector extends StatelessWidget {
  const _PackageSelector({
    required this.offerings,
    required this.selectedPackage,
    required this.onSelected,
  });

  final Offerings offerings;
  final Package? selectedPackage;
  final ValueChanged<Package> onSelected;

  @override
  Widget build(BuildContext context) {
    final current = offerings.getOffering(Config.offeringId) ?? offerings.current;
    if (current == null) return const SizedBox.shrink();

    // Build ordered list: yearly first (Best Value), then monthly.
    final packages = <Package>[];
    if (current.annual != null) packages.add(current.annual!);
    if (current.monthly != null) packages.add(current.monthly!);
    for (final pkg in current.availablePackages) {
      if (!packages.contains(pkg)) packages.add(pkg);
    }

    return Column(
      children: packages.map((pkg) {
        final isYearly = pkg.packageType == PackageType.annual;
        final isSelected = pkg == selectedPackage;
        return _PackageTile(
          pkg: pkg,
          isYearly: isYearly,
          isSelected: isSelected,
          onTap: () => onSelected(pkg),
        );
      }).toList(),
    );
  }
}

class _PackageTile extends StatelessWidget {
  const _PackageTile({
    required this.pkg,
    required this.isYearly,
    required this.isSelected,
    required this.onTap,
  });

  final Package pkg;
  final bool isYearly;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final price = pkg.storeProduct.priceString;
    final label = isYearly ? 'Yearly (Best Value)' : 'Monthly';

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: AppTheme.spaceSM),
        padding: const EdgeInsets.symmetric(
          horizontal: AppTheme.spaceMD,
          vertical: AppTheme.spaceMD,
        ),
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer : cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          border: Border.all(
            color: isSelected ? cs.primary : cs.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? cs.primary : cs.outline,
            ),
            const SizedBox(width: AppTheme.spaceMD),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        label,
                        style: tt.titleSmall?.copyWith(
                          color: isSelected
                              ? cs.onPrimaryContainer
                              : cs.onSurface,
                        ),
                      ),
                      if (isYearly) ...[
                        const SizedBox(width: AppTheme.spaceSM),
                        _Badge(
                          label: 'Best Value',
                          color: cs.primary,
                          onColor: cs.onPrimary,
                        ),
                      ],
                    ],
                  ),
                  Text(
                    price,
                    style: tt.bodySmall?.copyWith(
                      color: isSelected
                          ? cs.onPrimaryContainer
                          : cs.onSurfaceVariant,
                    ),
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

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.color,
    required this.onColor,
  });

  final String label;
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spaceSM,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: onColor,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// CTA button
// ---------------------------------------------------------------------------

class _CtaButton extends StatelessWidget {
  const _CtaButton({
    required this.isPurchasing,
    required this.enabled,
    required this.onTap,
    required this.cs,
  });

  final bool isPurchasing;
  final bool enabled;
  final VoidCallback onTap;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        child: isPurchasing
            ? SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: cs.onPrimary,
                ),
              )
            : const Text(
                'Start 7-day free trial',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Error banner
// ---------------------------------------------------------------------------

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.cs});
  final String message;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spaceMD),
      decoration: BoxDecoration(
        color: cs.errorContainer,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: cs.onErrorContainer, size: 20),
          const SizedBox(width: AppTheme.spaceSM),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: cs.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Fine print
// ---------------------------------------------------------------------------

class _FinePrint extends StatelessWidget {
  const _FinePrint();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text(
      'Payment will be charged to your Apple ID / Google Play account at '
      'confirmation of purchase. Subscription auto-renews unless canceled at '
      'least 24 hours before the end of the current period. Cancel at least '
      '24 hours before renewal to avoid charges. Manage or cancel in Account '
      'Settings.',
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: cs.onSurfaceVariant, fontSize: 11),
      textAlign: TextAlign.center,
    );
  }
}

// ---------------------------------------------------------------------------
// Legal links (Terms & Privacy)
// ---------------------------------------------------------------------------

class _LegalLinks extends StatelessWidget {
  const _LegalLinks();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Text.rich(
      TextSpan(
        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
        children: [
          TextSpan(
            text: 'Terms of Service',
            style: TextStyle(
              color: cs.primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openUrl(context, Config.termsUrl),
          ),
          const TextSpan(text: '  ·  '),
          TextSpan(
            text: 'Privacy Policy',
            style: TextStyle(
              color: cs.primary,
              decoration: TextDecoration.underline,
            ),
            recognizer: TapGestureRecognizer()
              ..onTap = () => _openUrl(context, Config.privacyUrl),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }

  /// Opens [url] via SnackBar feedback (url_launcher not included to minimise
  /// dependencies; integrate url_launcher to actually launch the browser).
  void _openUrl(BuildContext context, String url) {
    // TODO: Replace with url_launcher when added as a dependency.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Open: $url')),
    );
  }
}

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../config.dart';

/// Entitlement identifier that gates KINGTRUX Pro features.
const String _entitlementId = 'pro';

/// Service wrapping the RevenueCat Purchases SDK.
///
/// Responsibilities:
/// - Configure the SDK at app startup (no-op when keys are absent).
/// - Expose [fetchOfferings] so the paywall can display packages.
/// - Expose [purchase] and [restorePurchases] for the purchase flow.
/// - Provide [isProActive] to gate features on entitlement state.
class RevenueCatService {
  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Returns `true` when RevenueCat keys are available for the current platform.
  bool get hasKeys {
    if (Platform.isIOS || Platform.isMacOS) {
      return Config.revenueCatIosApiKey.isNotEmpty;
    }
    if (Platform.isAndroid) {
      return Config.revenueCatAndroidApiKey.isNotEmpty;
    }
    return false;
  }

  /// Configure the RevenueCat SDK.
  ///
  /// Safe to call multiple times; subsequent calls are no-ops.
  /// When no SDK key is set for the current platform the method returns
  /// without initialising so the app does not crash during development.
  Future<void> init() async {
    if (_initialized) return;

    if (!hasKeys) {
      debugPrint(
        '[RevenueCat] SDK key not configured for ${Platform.operatingSystem}. '
        'Pass REVENUECAT_IOS_API_KEY or REVENUECAT_ANDROID_API_KEY via '
        '--dart-define to enable in-app purchases.',
      );
      return;
    }

    try {
      await Purchases.setLogLevel(LogLevel.info);

      final String apiKey;
      if (Platform.isAndroid) {
        apiKey = Config.revenueCatAndroidApiKey;
      } else {
        apiKey = Config.revenueCatIosApiKey;
      }

      final configuration = PurchasesConfiguration(apiKey);
      await Purchases.configure(configuration);
      _initialized = true;
      debugPrint('[RevenueCat] SDK configured successfully.');
    } catch (e) {
      debugPrint('[RevenueCat] Failed to configure SDK: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Offerings
  // ---------------------------------------------------------------------------

  /// Fetch the current RevenueCat offerings.
  ///
  /// Returns `null` when the SDK is not initialised or a network/config error
  /// occurs — callers should show an actionable message instead of crashing.
  Future<Offerings?> fetchOfferings() async {
    if (!_initialized) {
      debugPrint('[RevenueCat] Cannot fetch offerings – SDK not initialised.');
      return null;
    }
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint('[RevenueCat] Error fetching offerings: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Purchase
  // ---------------------------------------------------------------------------

  /// Purchase the given [package].
  ///
  /// Returns the updated [CustomerInfo] on success.
  /// Throws a [PlatformException] on failure; use
  /// [PurchasesErrorHelper.getErrorCode] to classify the error.
  Future<CustomerInfo> purchase(Package package) async {
    return Purchases.purchasePackage(package);
  }

  // ---------------------------------------------------------------------------
  // Restore
  // ---------------------------------------------------------------------------

  /// Restore previous purchases and return refreshed [CustomerInfo].
  Future<CustomerInfo> restorePurchases() async {
    return Purchases.restorePurchases();
  }

  // ---------------------------------------------------------------------------
  // Entitlement helper
  // ---------------------------------------------------------------------------

  /// Returns `true` when the active [CustomerInfo] contains the Pro entitlement.
  bool isProActive(CustomerInfo info) {
    return info.entitlements.active.containsKey(_entitlementId);
  }

  /// Fetch the latest [CustomerInfo] directly from RevenueCat.
  ///
  /// Returns `null` when the SDK is not initialised.
  Future<CustomerInfo?> getCustomerInfo() async {
    if (!_initialized) return null;
    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint('[RevenueCat] Error fetching customer info: $e');
      return null;
    }
  }
}

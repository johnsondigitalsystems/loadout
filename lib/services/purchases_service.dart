import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:purchases_flutter/purchases_flutter.dart';

import 'revenue_cat_config.dart';

/// Wraps the RevenueCat `purchases_flutter` SDK so the rest of the app talks
/// to a single, mockable surface — same pattern as [AuthService] for
/// Firebase Auth.
///
/// The entitlement key checked everywhere is [RevenueCatConfig.proEntitlement]
/// (the lowercase string `'pro'`). It MUST match the entitlement defined in
/// the RevenueCat dashboard, otherwise [isProEntitled] will always return
/// false and nobody will ever unlock Pro.
class PurchasesService {
  PurchasesService();

  bool _initialized = false;
  StreamController<CustomerInfo>? _customerInfoController;

  /// True once [initialize] has finished and the SDK is configured. False if
  /// initialization was skipped because the API keys are placeholders.
  bool get isConfigured => _initialized;

  /// Initialize the RevenueCat SDK. Call once after Firebase is ready and
  /// before [runApp]. Safe to call when API keys are still placeholders —
  /// in that case it logs and returns without configuring the SDK so the
  /// app can launch and the paywall can show its placeholder state.
  ///
  /// Purposely does NOT set the user ID here — that happens later in
  /// [setAppUserId] once Firebase Auth has resolved the current user.
  Future<void> initialize() async {
    if (_initialized) return;
    if (RevenueCatConfig.isPlaceholder) {
      debugPrint(
        'PurchasesService: RevenueCat API keys are placeholders; '
        'skipping SDK configuration.',
      );
      return;
    }

    await Purchases.setLogLevel(
      kReleaseMode ? LogLevel.error : LogLevel.warn,
    );

    final apiKey = Platform.isIOS
        ? RevenueCatConfig.iosApiKey
        : RevenueCatConfig.androidApiKey;
    await Purchases.configure(PurchasesConfiguration(apiKey));

    _initialized = true;
  }

  /// Sync the active app user ID with Firebase Auth. Call whenever the
  /// auth user changes:
  ///   - non-null `firebaseUid` → [Purchases.logIn]
  ///   - null (signed out)      → [Purchases.logOut]
  ///
  /// No-op when the SDK was never configured (placeholder keys path).
  Future<void> setAppUserId(String? firebaseUid) async {
    if (!_initialized) return;
    try {
      if (firebaseUid != null) {
        await Purchases.logIn(firebaseUid);
      } else {
        await Purchases.logOut();
      }
    } on PlatformException catch (e) {
      // Already-logged-out, "anonymous user can't log out" etc. are routine
      // edge cases when auth state churns. Log and continue.
      debugPrint('PurchasesService.setAppUserId: ${e.message}');
    }
  }

  /// Broadcast stream of [CustomerInfo] updates fired by the SDK whenever
  /// entitlement state changes (purchase, restore, expiry, etc.).
  ///
  /// Lazily wires the underlying RevenueCat listener on first listen and
  /// keeps a single subscription alive for the lifetime of this service.
  Stream<CustomerInfo> get customerInfoStream {
    if (_customerInfoController != null) {
      return _customerInfoController!.stream;
    }
    final controller = StreamController<CustomerInfo>.broadcast(
      onCancel: () {
        // Keep the controller alive — the SDK's listener can only be added
        // once per process and there may be other subscribers later.
      },
    );
    _customerInfoController = controller;
    if (_initialized) {
      Purchases.addCustomerInfoUpdateListener(controller.add);
    }
    return controller.stream;
  }

  /// Direct fetch of the current [CustomerInfo]. Useful for one-shot reads
  /// at startup or before showing the paywall.
  Future<CustomerInfo> getCustomerInfo() => Purchases.getCustomerInfo();

  /// Fetch the configured offerings from RevenueCat. Returns null on failure
  /// (errors are logged) so paywall UI can render an error state instead of
  /// crashing.
  Future<Offerings?> getOfferings() async {
    if (!_initialized) return null;
    try {
      return await Purchases.getOfferings();
    } on PlatformException catch (e) {
      debugPrint('PurchasesService.getOfferings: ${e.message}');
      return null;
    }
  }

  /// Purchase [package]. Throws on cancel/error so the caller (paywall) can
  /// distinguish user-cancel from real failures via the platform error code.
  Future<CustomerInfo> purchase(Package package) async {
    final result = await Purchases.purchase(PurchaseParams.package(package));
    return result.customerInfo;
  }

  /// Restore prior purchases tied to the current store account. Throws on
  /// failure; callers show a snackbar with the result either way.
  Future<CustomerInfo> restorePurchases() => Purchases.restorePurchases();

  /// Returns whether [info] has the Pro entitlement currently active.
  /// Static so widgets can call it on a [CustomerInfo] from any source
  /// (stream snapshot, one-shot fetch, mocked test fixture).
  static bool isProEntitled(CustomerInfo info) {
    final entitlement =
        info.entitlements.active[RevenueCatConfig.proEntitlement];
    return entitlement != null && entitlement.isActive;
  }

  /// Tear down the broadcast controller. Currently no callers — the service
  /// lives for the lifetime of the app — but defined for completeness so
  /// tests can drop the listener cleanly.
  Future<void> dispose() async {
    await _customerInfoController?.close();
    _customerInfoController = null;
  }
}

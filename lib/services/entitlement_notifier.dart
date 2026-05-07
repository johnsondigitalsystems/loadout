import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'purchases_service.dart';
import 'revenue_cat_config.dart';

/// Lightweight [ChangeNotifier] over [PurchasesService.customerInfoStream] so
/// widgets can `context.watch<EntitlementNotifier>().isPro` without each
/// reading [CustomerInfo] themselves.
///
/// We picked ChangeNotifier (rather than `StreamProvider<bool>`) so consumers
/// can also call helpers like [refresh] imperatively without rewiring the
/// provider tree.
class EntitlementNotifier extends ChangeNotifier {
  EntitlementNotifier(this._purchases) {
    if (_purchases.isConfigured) {
      _sub = _purchases.customerInfoStream.listen(
        _handleCustomerInfo,
        onError: (Object e) =>
            debugPrint('EntitlementNotifier: stream error: $e'),
      );
      // Prime with the current state so widgets don't render "not pro" for
      // the first frame after a restart while waiting for the first event.
      // ignore: discarded_futures
      refresh();
    }
  }

  /// **DEV ONLY:** when true (and running in debug mode), [isPro] always
  /// returns `true` so Pro-gated UI is reachable without going through a
  /// real sandbox purchase. Has no effect in release builds (kDebugMode is
  /// const-false there, so the dead branch gets stripped).
  ///
  /// Flip back to `false` before cutting any TestFlight / App Store build.
  static const bool debugForceProActive = true;

  final PurchasesService _purchases;
  StreamSubscription<CustomerInfo>? _sub;

  bool _isPro = false;

  /// Whether the current user has the Pro entitlement active.
  bool get isPro {
    if (debugForceProActive && kDebugMode) return true;
    return _isPro;
  }

  /// Force a re-fetch of [CustomerInfo] and update [isPro] accordingly.
  /// Useful right after a successful purchase to ensure the UI flips
  /// before the listener event lands.
  Future<void> refresh() async {
    if (!_purchases.isConfigured) return;
    try {
      final info = await _purchases.getCustomerInfo();
      _handleCustomerInfo(info);
    } catch (e) {
      debugPrint('EntitlementNotifier.refresh: $e');
    }
  }

  void _handleCustomerInfo(CustomerInfo info) {
    final next = PurchasesService.isProEntitled(info);
    if (next != _isPro) {
      _isPro = next;
      notifyListeners();
    }
  }

  /// Returns the active entitlement key for diagnostics. Null when the user
  /// has no active Pro entitlement.
  static String get entitlementKey => RevenueCatConfig.proEntitlement;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}

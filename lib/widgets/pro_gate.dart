import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../screens/paywall/paywall_screen.dart';
import '../services/entitlement_notifier.dart';

/// Inline Pro feature gate. Renders [child] when the user has Pro,
/// otherwise renders a lock tile that opens the [PaywallScreen] on tap.
///
/// ```dart
/// ProGate(
///   feature: 'Smart import',
///   child: ImportButton(...),
/// )
/// ```
class ProGate extends StatelessWidget {
  const ProGate({
    super.key,
    required this.feature,
    required this.child,
    this.dense = false,
  });

  /// Human-readable feature name shown on the lock tile (e.g. "Smart import").
  final String feature;

  /// Widget rendered when the user has Pro.
  final Widget child;

  /// When true, render a more compact tile suitable for inline placement
  /// inside list rows. Defaults to a roomier card layout.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final isPro = context.watch<EntitlementNotifier>().isPro;
    if (isPro) return child;
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        dense: dense,
        leading: Icon(Icons.lock_outline, color: theme.colorScheme.primary),
        title: Text(feature),
        subtitle: const Text('Pro Feature'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => ensurePro(context),
      ),
    );
  }
}

/// Action gate. Resolves to true if the user is already Pro, otherwise
/// shows the [PaywallScreen] and resolves to true only if the user
/// upgraded during the visit.
///
/// ```dart
/// onTap: () async {
///   if (!await ensurePro(context)) return;
///   await runImport();
/// }
/// ```
Future<bool> ensurePro(BuildContext context) async {
  final entitlements = context.read<EntitlementNotifier>();
  if (entitlements.isPro) return true;
  final upgraded = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => const PaywallScreen(),
      fullscreenDialog: true,
    ),
  );
  // Re-check the notifier in case the paywall popped without an explicit
  // result (e.g. via system back gesture) but a purchase still completed.
  return entitlements.isPro || upgraded == true;
}

// FILE: lib/widgets/ble_android_legacy_explainer.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// One-time explainer dialog that fires before the OS prompts the user
// for `ACCESS_FINE_LOCATION` on Android 10 / Android 11 devices. Lives
// here as a top-level helper so every screen that calls
// `BleService.startScan` can wire it up without re-implementing the
// copy or re-coordinating the SharedPreferences "seen" flag.
//
// Public surface:
//
//   * `showBleAndroidLegacyExplainer(BuildContext)` — async function
//     that pushes the dialog and resolves to `true` if the user tapped
//     "Continue", `false` if they cancelled or dismissed the dialog
//     via the system back gesture / barrier tap.
//
// Pass this function as the `androidLegacyLocationExplainer` parameter
// to `BleService.startScan(...)`. The service handles the
// "have we shown this before?" gate; the widget is purely the UI.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Android 10/11 require `ACCESS_FINE_LOCATION` for BLE scanning. The
// OS prompt fires with the bare-bones "Allow LoadOut to access this
// device's location?" text, which alarms the precision-shooter
// audience the app is built for ("why does my reloading app want
// location?"). We surface our own dialog beforehand to explain that
// the location permission is exclusively a side-effect of the
// pre-Android-12 BLE stack and that we don't read or transmit
// location.
//
// Centralising the dialog here means every BLE entry point (devices
// screen, range-day rangefinder picker, recipe-form Garmin Xero
// lookup, firearm-form Kestrel lookup) gets the same explainer with
// the same copy.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * `showDialog<bool>` returns `null` if the user dismisses with the
//     system back gesture or by tapping outside the modal barrier.
//     We coerce that to `false` so the BleService's
//     `androidLegacyLocationExplainer` callback contract is strict:
//     "true means continue, anything else means abort."
//   * The dialog is `barrierDismissible: false` so users can't
//     accidentally tap-out and skip the explainer — they must
//     deliberately choose Cancel or Continue.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/devices/device_scan_screen.dart — wires this into
//   `_startScan` so the dialog fires before the runtime permission.
// - Any future screen that calls `BleService.startScan` directly.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Pushes a Material modal dialog. No persistence, no network.
//   The "seen" flag is owned by `BleService.markAndroidLegacyExplainerSeen()`,
//   not by this widget.

import 'package:flutter/material.dart';

/// Pushes the Android 10/11 BLE-needs-location explainer dialog.
///
/// Resolves to `true` if the user tapped "Continue", `false`
/// otherwise (dismissed via back gesture, barrier tap, or Cancel
/// button). The caller is responsible for short-circuiting their
/// scan when the result is `false`.
Future<bool> showBleAndroidLegacyExplainer(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Bluetooth Needs Location Permission'),
      content: const SingleChildScrollView(
        child: Text(
          'Android 10 requires location permission to discover '
          "Bluetooth peripherals. We don't actually use your location, "
          "and your location is never sent off your device — it's a "
          'system requirement of the older Bluetooth stack.\n\n'
          'On Android 12 or newer this requirement goes away entirely; '
          'the system splits Bluetooth and location into separate '
          "permissions and we don't ask for location at all.",
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Continue'),
        ),
      ],
    ),
  );
  return result == true;
}

// FILE: lib/services/watch_settings_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Phone-side preferences for the Apple Watch / Wear OS companion apps.
// Today the only persisted preference is the **shot-capture sensitivity**
// — a four-way enum that maps to the watch's accelerometer threshold +
// sustained-peak window. Other watch preferences (stage timer defaults,
// glanceable DOPE preferences, …) will land here as the surface grows.
//
// Public surface:
//   * `ShotCaptureSensitivity` — `off | low | medium | high`. Default
//     `medium`.
//   * `WatchSettingsService` — `ChangeNotifier` exposing the current
//     sensitivity, a setter that persists + pushes to the watch over
//     [WatchBridgeService], and helpers that translate the enum into
//     the watch-side threshold (g) + sustained-peak duration (ms).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The Wear OS / watchOS Stage Log composables already persist the
// motion-detect threshold on the watch. But the user lives mostly on
// the phone, and the new Settings → Watch & Wear submenu is the only
// place we want them to think about it. A phone-side preferences
// service (a) gives the Settings tile a `ChangeNotifier` to bind to,
// (b) survives an iOS / Android reinstall of the watch app (the phone
// keeps the user's choice), and (c) lets the bridge push the value
// down to a freshly-installed watch on first connection.
//
// Privacy: this service writes only to the on-device
// `SharedPreferences` store and to the encrypted peer-to-peer
// WatchConnectivity / Wearable Data Layer transport. No network — same
// posture as everything else under [WatchBridgeService].
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **`ShotCaptureSensitivity.off` means more than "low threshold".**
//    The watch must DISABLE the accelerometer entirely (battery + UX:
//    "Off" ought to mean off). The Stage Log composables both already
//    obey a `motionEnabled` toggle; the watch-side handler for the
//    `shot_capture_sensitivity` payload flips that toggle in addition
//    to (or instead of) updating the threshold. Don't model `off` as
//    "threshold = 99 g" — that still wakes the sensor.
//
// 2. **Threshold table mirrors the spec in CLAUDE.md §15 / `ShotCaptureSensitivity.thresholdG`.**
//    If you tune these numbers, also update the spec table in CLAUDE.md
//    so the documentation doesn't drift away from the code. The native
//    sides have the same table built in (default sensitivity is
//    `medium`) so the watch is usable even before the first phone push
//    arrives.
//
// 3. **`pushToWatch()` is fire-and-forget.** Watch may be unreachable
//    or the app may not be installed; either way the value lives in
//    `SharedPreferences` and gets re-pushed the next time the user
//    visits the Watch & Wear screen or changes the sensitivity again.
//    Don't await it from the setter or a passing watch glitch will
//    block the UI.

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/watch_payloads.dart';
import 'watch_bridge_service.dart';

/// Pref key for the sensitivity choice. Stored as the lowercased enum
/// `name` so the watch and phone agree on the wire string verbatim.
const String kShotCaptureSensitivityPrefKey = 'watch_shot_capture_sensitivity';

/// Four-way preference describing how aggressively the watch listens
/// for shot impulses. Maps to a threshold (g) + sustained-peak window
/// (ms) on the watch's [MotionDetector].
enum ShotCaptureSensitivity {
  /// Motion detect disabled entirely. Swipe-to-log still works.
  off,

  /// Quietest band — fewer false positives, may miss shots in soft
  /// recoil (.22 LR, suppressed pistols).
  low,

  /// Default. Tuned for typical centerfire rifles.
  medium,

  /// Most sensitive — useful for low-recoil rifles. May trigger on
  /// heavy walking.
  high;

  /// Wire-format string. Keep in lockstep with the iOS / Wear OS
  /// handlers that consume the `shot_capture_sensitivity` path.
  String get wireValue {
    switch (this) {
      case ShotCaptureSensitivity.off:
        return 'off';
      case ShotCaptureSensitivity.low:
        return 'low';
      case ShotCaptureSensitivity.medium:
        return 'medium';
      case ShotCaptureSensitivity.high:
        return 'high';
    }
  }

  /// Threshold (g) the watch's [MotionDetector] should compare each
  /// sample magnitude against. Returns `null` for [off] — the caller
  /// is expected to disable the detector entirely in that case.
  double? get thresholdG {
    switch (this) {
      case ShotCaptureSensitivity.off:
        return null;
      case ShotCaptureSensitivity.low:
        return 8.0;
      case ShotCaptureSensitivity.medium:
        return 5.0;
      case ShotCaptureSensitivity.high:
        return 3.0;
    }
  }

  /// Sustained-peak duration (ms). The detector requires the magnitude
  /// to STAY above the threshold for at least this many ms before
  /// firing a candidate, which rejects single-sample spikes (clapping
  /// the wrist on a bench). Returns `null` for [off].
  int? get sustainedPeakMs {
    switch (this) {
      case ShotCaptureSensitivity.off:
        return null;
      case ShotCaptureSensitivity.low:
        return 80;
      case ShotCaptureSensitivity.medium:
        return 50;
      case ShotCaptureSensitivity.high:
        return 30;
    }
  }

  /// Decode the wire-format string into an enum. Returns null if the
  /// input is unknown so callers can fall back to the default.
  static ShotCaptureSensitivity? fromWire(String? raw) {
    if (raw == null) return null;
    for (final v in ShotCaptureSensitivity.values) {
      if (v.wireValue == raw) return v;
    }
    return null;
  }
}

/// `ChangeNotifier` for watch-companion preferences. Provided once at
/// the root via `Provider<WatchSettingsService>` and shared across the
/// app.
class WatchSettingsService extends ChangeNotifier {
  WatchSettingsService({WatchBridgeService? bridge}) : _bridge = bridge {
    // ignore: discarded_futures
    _load();
  }

  final WatchBridgeService? _bridge;

  ShotCaptureSensitivity _sensitivity = ShotCaptureSensitivity.medium;

  /// Currently-selected sensitivity. Defaults to [medium] until the
  /// SharedPreferences read returns; the disk default also matches.
  ShotCaptureSensitivity get sensitivity => _sensitivity;

  /// Persist the new value, notify listeners, and best-effort push it
  /// to the watch. Watch-push failures are silent — the watch will
  /// pick up the value the next time the bridge reconnects.
  Future<void> setSensitivity(ShotCaptureSensitivity value) async {
    if (_sensitivity == value) return;
    _sensitivity = value;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(kShotCaptureSensitivityPrefKey, value.wireValue);
    } catch (_) {
      // Persistence failure is non-fatal; the in-memory value stays
      // until the user changes it again.
    }
    // ignore: discarded_futures
    pushToWatch();
  }

  /// Re-send the current preference to the watch. Called automatically
  /// after `setSensitivity` and exposed publicly so the Watch & Wear
  /// settings screen can offer a "Sync to watch" button if the user
  /// reconnects after a watch reinstall.
  Future<void> pushToWatch() async {
    final bridge = _bridge;
    if (bridge == null || !bridge.isSupported) return;
    await bridge.sendShotCaptureSensitivity(_sensitivity.wireValue);
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(kShotCaptureSensitivityPrefKey);
      final parsed = ShotCaptureSensitivity.fromWire(raw);
      if (parsed != null && parsed != _sensitivity) {
        _sensitivity = parsed;
        notifyListeners();
      }
    } catch (_) {
      // Disk read failure — keep the in-memory default.
    }
  }
}

/// Convenience for callers that already hold a [WatchBridgeService]
/// but want to invoke the new bridge path without a service instance.
extension WatchBridgeShotCaptureSensitivity on WatchBridgeService {
  /// Push the sensitivity value to the watch via the
  /// [WatchPaths.shotCaptureSensitivity] reserved path. Returns
  /// silently on unsupported platforms.
  Future<void> sendShotCaptureSensitivity(String value) async {
    if (!isSupported) return;
    await sendRawForWatchSettings(
      WatchPaths.shotCaptureSensitivity,
      <String, Object?>{'value': value},
    );
  }
}

// FILE: lib/services/device_compatibility_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Detects the current device's OS version and exposes a typed list of
// "feature is gated by the OS version on this device" rows that the
// Settings → Device Compatibility screen, the paywall footer link, and
// the home drawer all read from.
//
// Public surface:
//
//   * `DeviceCompatibilityService.detect()` — async one-shot factory
//     that calls into `device_info_plus`, builds a `DeviceProfile`, and
//     returns a fully-resolved service instance. The resolved profile
//     is cached on the instance so subsequent calls to `gatedFeatures`
//     / `hasAnyGates` are synchronous.
//   * `gatedFeatures` — list of `GatedFeature` rows describing each
//     hardware-linked feature in LoadOut, the OS minimum that unlocks
//     it, and whether THIS device meets that bar. Sorted "blocked
//     first," then alphabetic, so the Device Compatibility screen
//     leads with the rows that matter to the user.
//   * `hasAnyGates` — convenience boolean. True iff at least one
//     feature is gated on this device. Used by the home drawer and
//     Settings to hide the entry entirely on modern devices that have
//     no gates active.
//   * `DeviceCompatibilityService.fromProfile(...)` — synchronous
//     constructor that takes an explicit `DeviceProfile`. Used by tests
//     to drive every code path without mocking platform channels.
//
// `DeviceProfile` carries the platform name, the API level (Android
// only — null on iOS / macOS / web), and the user-facing OS version
// string ("Android 10", "iOS 16.4", "macOS 14.2"). All three feed
// into the gated-features list.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// LoadOut deliberately keeps its Android floor at API 29 (Android 10) so
// the install base stays wide. That floor is too low for several
// hardware-linked Pro features:
//
//   * Bluetooth devices (Kestrel, rangefinders) need
//     `BLUETOOTH_SCAN` / `BLUETOOTH_CONNECT` runtime permissions which
//     only exist on API 31+. On API 29 / 30 the legacy
//     `ACCESS_FINE_LOCATION` permission still works (we ask for it),
//     but plenty of OEM Android-10 firmware ships an unstable BLE
//     stack — so we hide the affordance and let the user know via this
//     service rather than letting them discover it the hard way.
//
//   * The Wear OS companion app requires Wear OS 3 (Android 11 / API
//     30+) on the host — Compose for Wear OS will not load on older
//     hosts.
//
//   * The watch-shot motion-detection sensor pipeline depends on
//     sensor-event APIs that are unreliable on Android 10 OEM
//     firmware. We surface the gate even though the underlying
//     sensors may technically respond.
//
// Centralising the rule set here lets Settings, Onboarding, and the
// paywall all read the same list — a single source of truth for what
// "supported on this device" means.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * **`device_info_plus` is plugin-mediated and async.** It has to
//     cross the platform channel to read the SDK level on Android, the
//     `systemVersion` on iOS, etc. The factory is `Future<...>` for
//     that reason. We build the profile once at app start and provide
//     the resolved service via `Provider` so widgets don't await on
//     every rebuild.
//
//   * **Web returns null sdk + a fake "Web" platform name.** The web
//     build has no concept of "OS version too old"; on web we report
//     `hasAnyGates == false` and the Settings entry hides itself. The
//     same is true for desktop platforms (macOS / Windows / Linux) —
//     LoadOut on desktop doesn't claim any of these features, so
//     there's nothing to gate.
//
//   * **iOS deliberately exposes no gated features today.** Per
//     the user decision, iOS stays at 15.0 and every Pro feature is
//     reachable from iOS 15+. If we ever introduce an iOS-version-
//     gated feature, add a row that returns `Platform.isIOS && parsed
//     iOS major < N`.
//
//   * **The `iosInfo.systemVersion` parse is loose.** Apple's value
//     can be `"17.4"` or `"17.4.1"` — we split on '.' and take the
//     leading int. Tests cover the malformed-string paths.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/settings/device_compatibility_screen.dart — renders
//   each `GatedFeature` as a calm "feature → requirement → currently
//   on" row.
// - lib/screens/settings/settings_screen.dart — hides the
//   "Device Compatibility" tile when `hasAnyGates == false`.
// - lib/screens/paywall/paywall_screen.dart — footer "What does my
//   device support?" link reads `hasAnyGates` to decide whether to
//   show the link AT ALL or whether to show it in the calm modern-
//   user variant. (The link is non-alarming; modern users see "All
//   features supported on this device" if they tap through.)
// - lib/app.dart — provides the resolved instance to the widget tree.
// - test/device_compatibility_service_test.dart — drives every
//   code path through `fromProfile(...)`.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - `detect()` calls into `device_info_plus`, which crosses the
//   platform channel to read `Build.VERSION.SDK_INT` (Android),
//   `[UIDevice currentDevice].systemVersion` (iOS), `osRelease`
//   (macOS). No network, no disk, no permission prompts.

import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Snapshot of the platform + OS version the app is currently running
/// on. Carrier struct — no behaviour.
@immutable
class DeviceProfile {
  const DeviceProfile({
    required this.platform,
    required this.osDisplay,
    this.androidSdkInt,
    this.iosMajorVersion,
  });

  /// Platform name for diagnostic / log purposes.
  /// Examples: "Android", "iOS", "macOS", "Web", "Linux", "Windows", "Other".
  final String platform;

  /// User-facing OS version string (e.g. "Android 10", "iOS 16.4",
  /// "macOS 14.2", "Web"). Shown verbatim in the "you're on …" copy on
  /// the Device Compatibility screen.
  final String osDisplay;

  /// Android SDK level (e.g. 29 for Android 10). Null on every other
  /// platform.
  final int? androidSdkInt;

  /// iOS major version (e.g. 17 for iOS 17.4.1). Null on every other
  /// platform.
  final int? iosMajorVersion;

  /// Synthetic profile for unit tests / web builds where reading the
  /// platform info isn't possible or meaningful.
  static const unknown = DeviceProfile(
    platform: 'Unknown',
    osDisplay: 'Unknown',
  );
}

/// One feature that may or may not be available on the current device,
/// depending on the OS version. Pure data — `DeviceCompatibilityService`
/// builds these from its `DeviceProfile`.
@immutable
class GatedFeature {
  const GatedFeature({
    required this.name,
    required this.requirement,
    required this.isAvailable,
    required this.shortDescription,
  });

  /// Human-readable feature name. Title Case (per CLAUDE.md § 0a).
  /// Examples: "Bluetooth Devices", "Wear OS Watch Pairing".
  final String name;

  /// User-facing OS-version requirement, e.g. "Requires Android 11+".
  /// Sentence-case prose, no terminal period (the screen adds the
  /// "you're on Android 10" suffix).
  final String requirement;

  /// True iff the current device meets the requirement. The Device
  /// Compatibility screen lists `false` rows first so the user sees
  /// what's missing without scrolling.
  final bool isAvailable;

  /// One-sentence prose description of what the feature does — shown
  /// as the row's secondary line. Sentence case.
  final String shortDescription;
}

/// Single source of truth for "is this feature available on this
/// device's OS version?" Provided once at app root via `Provider`.
///
/// Use the async factory `DeviceCompatibilityService.detect()` at app
/// startup, or `DeviceCompatibilityService.fromProfile(...)` in tests.
class DeviceCompatibilityService {
  DeviceCompatibilityService.fromProfile(this.profile);

  /// Snapshot of the current device. Cached; safe to read multiple
  /// times.
  final DeviceProfile profile;

  /// Async one-shot factory. Reads the platform info via
  /// `device_info_plus`, builds a `DeviceProfile`, and returns a
  /// resolved service instance.
  ///
  /// Never throws — on any failure the profile falls back to
  /// `DeviceProfile.unknown` so the calling code can still ask
  /// "is anything gated?" without try/catch.
  static Future<DeviceCompatibilityService> detect() async {
    try {
      if (kIsWeb) {
        // Web has no concept of "OS too old" for our gates. Report a
        // distinct platform so the diagnostic line on the Device
        // Compatibility screen reads sensibly if we ever expose the
        // service on web (today the entry hides itself).
        return DeviceCompatibilityService.fromProfile(
          const DeviceProfile(platform: 'Web', osDisplay: 'Web'),
        );
      }
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final android = await info.androidInfo;
        return DeviceCompatibilityService.fromProfile(
          DeviceProfile(
            platform: 'Android',
            osDisplay: 'Android ${android.version.release}',
            androidSdkInt: android.version.sdkInt,
          ),
        );
      }
      if (Platform.isIOS) {
        final ios = await info.iosInfo;
        final major = _parseLeadingInt(ios.systemVersion);
        return DeviceCompatibilityService.fromProfile(
          DeviceProfile(
            platform: 'iOS',
            osDisplay: 'iOS ${ios.systemVersion}',
            iosMajorVersion: major,
          ),
        );
      }
      if (Platform.isMacOS) {
        final mac = await info.macOsInfo;
        return DeviceCompatibilityService.fromProfile(
          DeviceProfile(
            platform: 'macOS',
            osDisplay: 'macOS ${mac.osRelease}',
          ),
        );
      }
      if (Platform.isWindows) {
        return DeviceCompatibilityService.fromProfile(
          const DeviceProfile(platform: 'Windows', osDisplay: 'Windows'),
        );
      }
      if (Platform.isLinux) {
        return DeviceCompatibilityService.fromProfile(
          const DeviceProfile(platform: 'Linux', osDisplay: 'Linux'),
        );
      }
    } catch (_) {
      // Fall through to unknown.
    }
    return DeviceCompatibilityService.fromProfile(DeviceProfile.unknown);
  }

  /// Convenience boolean — true iff at least one row in
  /// [gatedFeatures] reports `isAvailable == false`.
  bool get hasAnyGates => gatedFeatures.any((f) => !f.isAvailable);

  /// True iff this device is Android with an SDK level strictly less
  /// than [target]. Returns false on every other platform. Used by
  /// `BleService` to decide whether to surface the Android 10
  /// "location permission for BLE" explainer dialog.
  bool isAndroidBelow(int target) {
    final sdk = profile.androidSdkInt;
    return sdk != null && sdk < target;
  }

  /// Live list of gated features for THIS device. Re-evaluated on
  /// every getter call (cheap; the rule set is small) so the list
  /// reflects any future hot-swappable profile.
  ///
  /// Order: blocked rows first, then available rows, alphabetic
  /// within each group. The Device Compatibility screen relies on
  /// this ordering so the user sees what's missing without
  /// scrolling.
  List<GatedFeature> get gatedFeatures {
    final all = <GatedFeature>[];

    // BLE devices — pairing with Kestrel / Garmin / rangefinders.
    // Floor is API 31 (Android 12). The phone-app minSdk = 29
    // (Android 10), so devices on API 29 / 30 fall into the gate.
    // On Android 12+ the modern BLUETOOTH_SCAN / BLUETOOTH_CONNECT
    // permissions exist; on API ≤ 30 the legacy fallback works in
    // theory, but OEM stack quality varies enough that we
    // conservatively hide the affordance.
    if (profile.platform == 'Android') {
      final sdk = profile.androidSdkInt ?? 0;
      all.add(GatedFeature(
        name: 'Bluetooth Devices',
        requirement: 'Requires Android 12 or newer',
        isAvailable: sdk >= 31,
        shortDescription:
            'Pair a Kestrel weather meter, Garmin Xero chronograph, '
            'or supported rangefinder for live data.',
      ));

      // Wear OS pairing — Compose for Wear OS host requires API 30+.
      all.add(GatedFeature(
        name: 'Wear OS Watch Pairing',
        requirement: 'Requires Android 11 or newer',
        isAvailable: sdk >= 30,
        shortDescription:
            'Use the LoadOut companion app on a Wear OS 3 watch '
            "(stage timer, glanceable DOPE, on-wrist shot capture).",
      ));

      // Watch-shot motion-capture pipeline. Same SDK bar as Wear OS
      // pairing — without the host the watch service can't start.
      all.add(GatedFeature(
        name: 'Watch Motion Sensors',
        requirement: 'Requires Android 11 or newer',
        isAvailable: sdk >= 30,
        shortDescription:
            'Auto-log shots from your wrist using the watch '
            "accelerometer's recoil-spike detector.",
      ));
    }

    // Sort: blocked first, then alphabetic within each bucket.
    all.sort((a, b) {
      if (a.isAvailable != b.isAvailable) {
        return a.isAvailable ? 1 : -1;
      }
      return a.name.compareTo(b.name);
    });
    return all;
  }

  /// Splits a version string like "17.4.1" into its leading integer
  /// (17 in this example). Returns null if the string can't be
  /// parsed. Used by the iOS branch of [detect] which cares only
  /// about the major version.
  static int? _parseLeadingInt(String s) {
    if (s.isEmpty) return null;
    final firstDot = s.indexOf('.');
    final head = firstDot < 0 ? s : s.substring(0, firstDot);
    return int.tryParse(head);
  }
}

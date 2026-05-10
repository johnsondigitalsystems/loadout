// FILE: lib/services/ble/ble_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Thin platform-abstraction layer over `flutter_blue_plus`. Wraps the
// global `FlutterBluePlus` singleton in a small instance API the rest of
// the app actually wants to talk to:
//
//   - `ensurePermissions()` — request the runtime permissions BLE needs
//     (Android 12+ split BLUETOOTH_SCAN / BLUETOOTH_CONNECT, iOS handled
//     automatically by Info.plist usage strings; macOS needs the
//     `com.apple.security.device.bluetooth` entitlement to be present).
//   - `isAvailable()` — reports whether Bluetooth is supported at all on
//     the current device + platform combination. Surfaces a friendly
//     "Bluetooth not available on this device" copy upstream when this
//     returns false.
//   - `adapterState` / `currentAdapterState` — observed Bluetooth radio
//     state. Lets the UI gate on "is the radio on?" without falling
//     through to a confusing scan-with-no-results.
//   - `startScan()` / `stopScan()` — wraps the scanning APIs with sane
//     defaults (12 second timeout, optional service-UUID filter so
//     discovery is fast on devices that broadcast known UUIDs like the
//     Kestrel weather meter).
//   - `connect()` / `disconnect()` — wraps the connect calls and surfaces
//     errors as `BleException`s the UI can display verbatim.
//   - `connectionStream()` — re-exposes a device's connection state stream
//     so the UI can stop / start subscriptions in lock-step with
//     reconnects.
//
// All async methods either succeed or throw `BleException` with a
// user-friendly `userMessage`. The UI never has to peer at platform
// channel exceptions.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Two device adapters depend on this:
//
//   - `lib/services/ble/kestrel_service.dart` — Kestrel 5xxx Link weather
//     meter, drives the live atmospheric data stream into the ballistics
//     calculator and range-day Environment sections.
//   - `lib/services/ble/garmin_xero_service.dart` — placeholder for the
//     Garmin Xero C1 Pro chronograph; the v1 path is .fit file import,
//     but a future direct-BLE pull will live alongside this service.
//
// Centralizing permission + scan + connect in one place means each
// device adapter focuses solely on the GATT-specific side of its job
// (which characteristic to subscribe to, how to parse the bytes).
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/services/ble/kestrel_service.dart
// - lib/services/ble/garmin_xero_service.dart (future direct-BLE path)
// - lib/screens/devices/devices_screen.dart
// - lib/screens/devices/device_scan_screen.dart
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - `ensurePermissions()` may pop OS permission dialogs.
// - `startScan()` activates the Bluetooth radio; the scan auto-stops at
//   the timeout you pass.
// - `connect()` keeps a live connection open until you call
//   `disconnect()`. The OS may clean up if the device disappears.

import 'dart:async';
import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// User-facing BLE failure. Thrown by [BleService] methods so the UI
/// can present a friendly snackbar verbatim from [userMessage].
class BleException implements Exception {
  const BleException(this.userMessage, {this.cause});

  /// Friendly, short, end-user-readable failure text.
  final String userMessage;

  /// Underlying error (if any). Diagnostic only — never shown to user.
  final Object? cause;

  @override
  String toString() =>
      'BleException($userMessage)${cause == null ? '' : ' caused by $cause'}';
}

/// Outcome of an [BleService.ensurePermissions] call. Carries enough
/// information for the UI to either proceed, show a soft "we still
/// need…" hint, or deep-link the user to system settings when a
/// permission was denied permanently.
class BlePermissionResult {
  const BlePermissionResult({
    required this.granted,
    required this.permanentlyDenied,
  });

  /// Convenience constant for the all-good path.
  static const ok = BlePermissionResult(
    granted: true,
    permanentlyDenied: false,
  );

  /// True iff every required permission resolved to granted.
  final bool granted;

  /// True iff at least one required permission was denied with the
  /// "don't ask again" / iOS Settings-only flag set. The UI should
  /// surface an "Open Settings" button instead of retrying.
  final bool permanentlyDenied;
}

/// SharedPreferences key for the "user has acknowledged the Android 10
/// location-permission-for-BLE explainer" flag. The dialog only fires
/// the first time the user starts a scan on Android 10/11; subsequent
/// scans skip straight to the runtime permission request.
const String kBleAndroidLegacyExplainerSeenPref =
    'ble.android_legacy_location_explainer_seen';

/// Callback signature the UI can pass to [BleService.startScan] so the
/// service can show the one-time Android 10/11 location-permission
/// explainer before the OS permission prompt fires. Returns true if the
/// user acknowledged ("Continue"), false if they dismissed ("Cancel").
typedef BleExplainerCallback = Future<bool> Function();

/// Cross-platform BLE service. Single instance, provided once via
/// `Provider<BleService>` at the app root. Stateless beyond what
/// `flutter_blue_plus` already keeps internally, so creating two
/// instances is harmless but pointless.
class BleService extends ChangeNotifier {
  BleService()
      : _androidSdkIntReaderForTest = null,
        _explainerSeenReaderForTest = null,
        _explainerSeenWriterForTest = null;

  /// Test-only constructor. Lets unit tests inject a fake SDK-level
  /// reader and explainer-seen reader/writer without crossing the
  /// platform channel.
  @visibleForTesting
  BleService.forTesting({
    required Future<int?> Function() androidSdkIntReader,
    required Future<bool> Function() explainerSeenReader,
    required Future<void> Function() explainerSeenWriter,
  })  : _androidSdkIntReaderForTest = androidSdkIntReader,
        _explainerSeenReaderForTest = explainerSeenReader,
        _explainerSeenWriterForTest = explainerSeenWriter;

  /// Test-only override for the platform-channel SDK-level read.
  /// Production builds always go through [_readAndroidSdkInt].
  final Future<int?> Function()? _androidSdkIntReaderForTest;

  /// Test-only override for "has the user already seen the Android 10
  /// explainer?" Production builds read SharedPreferences.
  final Future<bool> Function()? _explainerSeenReaderForTest;

  /// Test-only override for the explainer-seen write. Production
  /// builds write SharedPreferences.
  final Future<void> Function()? _explainerSeenWriterForTest;

  /// Cached Android SDK level. Read once on first access; null on
  /// non-Android platforms. Cached because the device-info plugin
  /// crosses the platform channel and the value never changes for
  /// the life of the process.
  int? _cachedAndroidSdkInt;
  bool _sdkIntFetched = false;

  /// Expose the package's adapter-state stream so the devices screen
  /// can listen and live-update its "Bluetooth is off" banner.
  Stream<BluetoothAdapterState> get adapterState =>
      FlutterBluePlus.adapterState;

  /// Last-known adapter state. Updated lazily as
  /// [FlutterBluePlus.adapterState] emits.
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  BluetoothAdapterState get currentAdapterState => _adapterState;

  /// Stream of in-flight scan results. Re-emits [ScanResult] lists each
  /// time a new device is discovered (or an existing device's RSSI
  /// updates). Consumers should `take(...)` or close the subscription
  /// when their UI tears down.
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  /// Whether a scan is currently active. Mirrors the package's flag.
  bool get isScanning => FlutterBluePlus.isScanningNow;

  StreamSubscription<BluetoothAdapterState>? _adapterStateSub;
  bool _initialized = false;

  /// Wires up the adapter-state subscription and grabs whatever the OS
  /// last reported. Call this once during provider construction. Safe
  /// to invoke more than once — it is a no-op after the first call.
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    if (!await isAvailable()) return;
    try {
      _adapterState = await FlutterBluePlus.adapterState.first
          .timeout(const Duration(seconds: 2));
    } catch (_) {
      // Some platforms / permission states never emit synchronously;
      // fall back to the default `unknown` and trust the stream
      // listener below to backfill.
    }
    _adapterStateSub = FlutterBluePlus.adapterState.listen((s) {
      _adapterState = s;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    // ignore: discarded_futures
    _adapterStateSub?.cancel();
    super.dispose();
  }

  /// Whether the platform supports Bluetooth Low Energy at all. Returns
  /// false on:
  ///   - desktop Linux (we don't ship a Linux build today),
  ///   - Web (no flutter_blue_plus_web yet at the version we depend on),
  ///   - any platform that throws when the package's `isSupported`
  ///     getter is invoked.
  Future<bool> isAvailable() async {
    if (kIsWeb) return false;
    if (!(Platform.isIOS ||
        Platform.isAndroid ||
        Platform.isMacOS)) {
      return false;
    }
    try {
      return await FlutterBluePlus.isSupported;
    } catch (_) {
      return false;
    }
  }

  /// Convenience boolean: Bluetooth radio currently powered on.
  bool get isAdapterOn => _adapterState == BluetoothAdapterState.on;

  /// Returns the cached Android SDK level, fetching it from
  /// `device_info_plus` on first call. Null on non-Android platforms.
  ///
  /// Cached because the lookup crosses the platform channel; the value
  /// is immutable for the lifetime of the process.
  Future<int?> readAndroidSdkInt() async {
    if (!Platform.isAndroid && _androidSdkIntReaderForTest == null) {
      return null;
    }
    if (_sdkIntFetched) return _cachedAndroidSdkInt;
    _sdkIntFetched = true;
    if (_androidSdkIntReaderForTest != null) {
      _cachedAndroidSdkInt = await _androidSdkIntReaderForTest();
      return _cachedAndroidSdkInt;
    }
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      _cachedAndroidSdkInt = info.version.sdkInt;
    } catch (_) {
      _cachedAndroidSdkInt = null;
    }
    return _cachedAndroidSdkInt;
  }

  /// True iff this platform is Android AND the SDK level is below 31
  /// (i.e. Android 10 or Android 11). On those API levels the BLE
  /// scanner needs `ACCESS_FINE_LOCATION` rather than the modern
  /// `BLUETOOTH_SCAN` permission, and we surface a one-time explainer
  /// dialog before requesting it.
  Future<bool> isAndroidLegacyBleStack() async {
    if (!Platform.isAndroid && _androidSdkIntReaderForTest == null) {
      return false;
    }
    final sdk = await readAndroidSdkInt();
    return sdk != null && sdk < 31;
  }

  /// True iff the user has already acknowledged the Android 10/11
  /// "we need location permission for BLE" explainer dialog. Reads
  /// `SharedPreferences[kBleAndroidLegacyExplainerSeenPref]`.
  Future<bool> hasSeenAndroidLegacyExplainer() async {
    if (_explainerSeenReaderForTest != null) {
      return _explainerSeenReaderForTest();
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(kBleAndroidLegacyExplainerSeenPref) ?? false;
  }

  /// Persist the "user has acknowledged the explainer" flag. Called
  /// from [startScan] after the user taps "Continue" on the dialog.
  Future<void> markAndroidLegacyExplainerSeen() async {
    if (_explainerSeenWriterForTest != null) {
      await _explainerSeenWriterForTest();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kBleAndroidLegacyExplainerSeenPref, true);
  }

  /// Request the runtime permissions BLE scanning + connecting needs.
  ///
  /// Platform behaviour:
  ///
  ///   * **iOS / macOS** — the OS prompts via
  ///     `NSBluetoothAlwaysUsageDescription` automatically the first
  ///     time we call into the platform channel; we return `ok`
  ///     unconditionally so callers don't gate on a redundant check.
  ///   * **Android 12+ (API 31+)** — we request
  ///     `Permission.bluetoothScan` and `Permission.bluetoothConnect`
  ///     separately. The manifest declares `neverForLocation` on
  ///     `BLUETOOTH_SCAN` so the OS knows we are NOT trying to derive
  ///     the user's location from BLE beacons.
  ///   * **Android 10/11 (API 29-30)** — modern split permissions
  ///     don't exist yet. The OS instead requires
  ///     `ACCESS_FINE_LOCATION` to scan for BLE peripherals at all.
  ///     We request that on this branch. The `BLUETOOTH` /
  ///     `BLUETOOTH_ADMIN` install-time permissions are already in
  ///     the manifest with `maxSdkVersion="30"`.
  ///
  /// CALLERS that want to show the one-time Android 10/11 explainer
  /// dialog ("Android 10 needs location permission to discover BLE
  /// peripherals — we don't actually use your location") should call
  /// [startScan] with the `androidLegacyLocationExplainer` callback.
  /// This method itself never shows UI.
  Future<BlePermissionResult> ensurePermissions() async {
    if (kIsWeb) {
      return const BlePermissionResult(
        granted: false,
        permanentlyDenied: false,
      );
    }
    if (Platform.isIOS || Platform.isMacOS) {
      // iOS / macOS surface their own prompt via NSBluetooth*UsageDescription;
      // permission_handler returns granted once the user has answered.
      // On macOS the entitlement gate happens at app-launch.
      return BlePermissionResult.ok;
    }
    if (Platform.isAndroid) {
      // On Android 10/11 the modern split permissions DON'T exist
      // (they're API 31+). Requesting them on the legacy branch is a
      // no-op that returns `granted` immediately, but the OS would
      // still refuse to scan without ACCESS_FINE_LOCATION. So on
      // legacy we ask for fine location instead.
      final isLegacy = await isAndroidLegacyBleStack();
      if (isLegacy) {
        final loc = await Permission.locationWhenInUse.request();
        return BlePermissionResult(
          granted: loc.isGranted,
          permanentlyDenied: loc.isPermanentlyDenied,
        );
      }
      final scan = await Permission.bluetoothScan.request();
      final connect = await Permission.bluetoothConnect.request();
      final granted = scan.isGranted && connect.isGranted;
      final permanentlyDenied =
          scan.isPermanentlyDenied || connect.isPermanentlyDenied;
      return BlePermissionResult(
        granted: granted,
        permanentlyDenied: permanentlyDenied,
      );
    }
    return const BlePermissionResult(
      granted: false,
      permanentlyDenied: false,
    );
  }

  /// Open the OS's app-settings screen so the user can grant a
  /// permanently-denied permission. Returns true on success, false if
  /// the platform refused.
  Future<bool> openAppSettingsPage() => openAppSettings();

  /// Start a scan. Returns the package's [scanResults] stream for
  /// convenience. Auto-stops after [timeout]. Pass a list of GATT
  /// service UUIDs in [withServices] to filter at the OS level — much
  /// faster on devices like Kestrel that advertise a known service.
  ///
  /// On Android 10/11 (API 29-30) the platform requires
  /// `ACCESS_FINE_LOCATION` to scan for BLE peripherals — modern
  /// `BLUETOOTH_SCAN` doesn't exist on those API levels. To explain
  /// that to the user before the OS prompt fires, the caller can pass
  /// [androidLegacyLocationExplainer]: an async callback the service
  /// will invoke ONCE per device-lifetime (the "seen" flag is stashed
  /// in `SharedPreferences[kBleAndroidLegacyExplainerSeenPref]`)
  /// before the runtime permission request. The callback should
  /// resolve to `true` if the user tapped "Continue" and `false` if
  /// they cancelled — on `false` we throw a `BleException` and abort
  /// the scan.
  ///
  /// Throws [BleException] if the radio is off, permissions are
  /// denied, or the user cancelled the Android 10/11 explainer.
  Future<Stream<List<ScanResult>>> startScan({
    Duration timeout = const Duration(seconds: 12),
    List<Guid>? withServices,
    BleExplainerCallback? androidLegacyLocationExplainer,
  }) async {
    if (!await isAvailable()) {
      throw const BleException(
        'Bluetooth is not available on this device.',
      );
    }

    // Android 10/11 explainer dialog. Surface BEFORE the OS permission
    // prompt — the system prompt says "Allow LoadOut to access this
    // device's location" with no context, which scares reloaders.
    final isLegacy = await isAndroidLegacyBleStack();
    if (isLegacy && androidLegacyLocationExplainer != null) {
      final seen = await hasSeenAndroidLegacyExplainer();
      if (!seen) {
        final acknowledged = await androidLegacyLocationExplainer();
        if (!acknowledged) {
          throw const BleException(
            'Bluetooth scanning needs location permission on Android 10. '
            'You can try again any time.',
          );
        }
        await markAndroidLegacyExplainerSeen();
      }
    }

    final perm = await ensurePermissions();
    if (!perm.granted) {
      throw BleException(
        perm.permanentlyDenied
            ? (isLegacy
                ? 'Location permission is denied. Open Settings to enable '
                    'Bluetooth scanning on Android 10.'
                : 'Bluetooth permission is denied. Open Settings to enable.')
            : (isLegacy
                ? 'Location permission is required to scan for Bluetooth '
                    'devices on Android 10.'
                : 'Bluetooth permission is required to scan for devices.'),
      );
    }
    if (!isAdapterOn) {
      throw const BleException(
        'Bluetooth is turned off. Turn it on to scan for devices.',
      );
    }
    try {
      await FlutterBluePlus.startScan(
        timeout: timeout,
        withServices: withServices ?? const [],
        // On the legacy branch the platform requires fine location to
        // scan — flutter_blue_plus's option must agree with the
        // permission we just asked for. On API 31+ we keep this off
        // because the manifest declares `neverForLocation` on
        // BLUETOOTH_SCAN.
        androidUsesFineLocation: isLegacy,
      );
    } catch (e) {
      throw BleException(
        'Couldn\'t start a Bluetooth scan. Try again.',
        cause: e,
      );
    }
    return FlutterBluePlus.scanResults;
  }

  /// Stop any in-flight scan. Idempotent: safe to call when no scan is
  /// running.
  Future<void> stopScan() async {
    try {
      await FlutterBluePlus.stopScan();
    } catch (_) {
      // Stopping a not-running scan is fine — silently ignore.
    }
  }

  /// Connect to [device]. Throws [BleException] on failure.
  Future<void> connect(BluetoothDevice device) async {
    try {
      await device.connect(
        timeout: const Duration(seconds: 15),
        autoConnect: false,
      );
    } catch (e) {
      throw BleException(
        'Couldn\'t connect to ${_friendlyName(device)}.',
        cause: e,
      );
    }
  }

  /// Drop a connection. Idempotent: silently ignores "already
  /// disconnected" errors.
  Future<void> disconnect(BluetoothDevice device) async {
    try {
      await device.disconnect();
    } catch (_) {
      // Already disconnected — fine.
    }
  }

  /// Per-device connection-state stream. Useful for UIs that want to
  /// flip a status indicator between "connecting / connected /
  /// disconnected" without polling.
  Stream<BluetoothConnectionState> connectionStream(BluetoothDevice d) =>
      d.connectionState;

  /// Best-effort friendly name. Some devices broadcast an empty name
  /// (only the MAC / UUID is exposed); fall through to a short prefix
  /// of the remote-id so the user has something to read.
  String _friendlyName(BluetoothDevice d) {
    final n = d.platformName.trim();
    if (n.isNotEmpty) return n;
    final id = d.remoteId.str;
    return id.length > 8 ? '${id.substring(0, 8)}…' : id;
  }
}

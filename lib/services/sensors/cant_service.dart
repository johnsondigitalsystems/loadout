// FILE: lib/services/sensors/cant_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Wraps the OS accelerometer stream behind a `ChangeNotifier` that the rest
// of the app can `context.watch<CantService>()` on. Computes the phone's
// roll angle ("cant" — rotation around its long axis) in degrees and
// exposes it as a single signed scalar:
//
//   * positive  = phone canted to the right
//   * negative  = phone canted to the left
//   * zero      = phone perfectly level OR pinned to the active calibration
//
// The accelerometer reports a 3-axis acceleration vector in m/s² that
// includes gravity. When the device is stationary the magnitude of that
// vector is the local gravity (~9.81 m/s²) and its DIRECTION points away
// from the centre of the Earth in the device's coordinate frame. Roll
// around the long axis of the phone (cant) is therefore:
//
//     roll_rad = atan2(x, y)
//
// Sign convention follows the Flutter / iOS / Android coordinate system:
// when the phone is held upright facing the user, positive `x` points
// right and positive `y` points up. atan2(x, y) returns 0 when the phone
// is upright, ~+90° when canted full right (phone in landscape with home
// button right on iOS) and ~-90° when canted full left.
//
// We low-pass filter the raw stream because accelerometer samples are
// noisy at rest. A simple exponential smoother (alpha = 0.15) gives a
// readout that's stable to ~0.1° on a phone resting on a table without
// adding visible lag.
//
// CALIBRATION. Phones are rarely mounted dead-square on a rifle. The
// shooter taps "Use phone level" when the rifle is established level
// (bubble level on a scope rail, etc.), and we record the current
// smoothed roll as the zero offset. Subsequent readings are reported
// minus that offset, so the displayed cant is the rifle cant rather than
// the absolute phone cant.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Cant is one of the bigger silent error sources in long-range shooting.
// A 1° muzzle cant translates an elevation correction at 1000 yards into
// roughly 1.7" of windage at the target — easy to mistake for wind
// readout error. Surfacing live cant in the Range Day Setup section lets
// the shooter notice and zero it before pressing the trigger, and the
// Pro "Apply cant correction" toggle injects a deterministic correction
// term into the firing solution so the displayed drop / wind is what
// the shooter will actually see at the target.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. PLATFORM SUPPORT. `sensors_plus` ships native code for iOS and
//    Android only. macOS / Linux / Windows have no accelerometer (and
//    macOS laptops that DO have one don't expose it through the package
//    we use). On those targets the platform method throws
//    `MissingPluginException`. We catch that during `start()` and
//    surface an `available` flag so the UI can hide the level / cant
//    affordance on desktop instead of crashing.
//
// 2. atan2 BRANCH WHEN THE PHONE IS UPSIDE DOWN. atan2 wraps from +π to
//    -π near the discontinuity. For our use (rifle held roughly upright)
//    that branch is irrelevant — we never want to report cant > ±90°
//    because the phone would have to be lying on its back. We clamp
//    just to be defensive.
//
// 3. CALIBRATION DRIFT. A single-shot calibration captures the current
//    rifle pose. If the rifle moves between calibration and shooting,
//    the calibration is stale. The UI exposes "Use phone level" as a
//    one-tap re-zero, and `clearCalibration()` resets to the absolute
//    phone roll for users who haven't established a known-level pose.
//
// 4. EXPONENTIAL SMOOTHER WARM-UP. The first sample after start() is
//    NOT smoothed — we seed the EMA with that raw value so the first
//    reading isn't visibly "wrong" while the filter spins up.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show MissingPluginException;
import 'package:sensors_plus/sensors_plus.dart';

/// `ChangeNotifier` that subscribes to the device accelerometer and
/// computes a signed cant angle (degrees) around the phone's long axis.
///
/// Provided once via `Provider` in `lib/app.dart` and consumed by the
/// Range Day Setup card. Notifies on every smoothed sample (~5–10 Hz at
/// the default sampling period), and ALSO whenever the calibration
/// offset is updated.
///
/// Use [start] to begin sampling and [stop] to release the OS sensor.
/// The provider keeps a single instance alive for the app's lifetime;
/// individual screens [start] on enter and [stop] on dispose so the
/// sensor isn't running when nobody is looking at it.
class CantService extends ChangeNotifier {
  /// Smoothing coefficient for the EMA filter on the roll angle.
  /// 0.15 gives a stable, jitter-free readout at the default 5 Hz
  /// sampling period without visible lag. Tune carefully — values
  /// above 0.4 reintroduce visible jitter; values below 0.05 introduce
  /// half-second lag the shooter will notice.
  static const double _emaAlpha = 0.15;

  /// Sampling period for the accelerometer stream. UI interval (~15 Hz)
  /// is plenty for a level readout — the human eye cannot resolve more
  /// than that on a 1° dial.
  static const Duration _samplingPeriod = SensorInterval.uiInterval;

  StreamSubscription<AccelerometerEvent>? _sub;

  /// Smoothed absolute roll angle of the phone (degrees). Null until
  /// the first sample has arrived.
  double? _smoothedDeg;

  /// Calibration offset (degrees) — the absolute roll recorded at the
  /// last "Use phone level" tap. Subtracted from the smoothed reading
  /// to produce [cantDegrees].
  double _calibrationOffsetDeg = 0.0;

  /// True after [start] has successfully subscribed to the OS stream.
  bool _running = false;

  /// True if the platform exposes an accelerometer through `sensors_plus`.
  /// Set to `false` if [start] catches `MissingPluginException` (desktop
  /// targets) or any other error on subscribe.
  bool _available = true;

  /// Latest signed cant in degrees relative to the active calibration.
  /// Returns `null` until the first sensor sample arrives. Sign:
  /// positive = phone canted right, negative = canted left.
  double? get cantDegrees {
    final s = _smoothedDeg;
    if (s == null) return null;
    return s - _calibrationOffsetDeg;
  }

  /// Whether the platform supports the accelerometer. False on desktop
  /// targets where `sensors_plus` has no implementation.
  bool get isAvailable => _available;

  /// Whether the service is currently subscribed to the OS stream.
  bool get isRunning => _running;

  /// The current calibration offset in degrees. Useful for diagnostics
  /// and to render a "calibrated" badge in the UI.
  double get calibrationOffsetDeg => _calibrationOffsetDeg;

  /// Begin sampling. Idempotent — calling twice does not double-subscribe.
  /// Returns false if the platform has no accelerometer (desktop), in
  /// which case the UI should hide the cant affordance.
  Future<bool> start() async {
    if (_running) return _available;
    // sensors_plus has no macOS/Linux/Windows implementation. Bail out
    // before the platform channel call so we don't leak a thrown
    // MissingPluginException into the logs on desktop.
    if (kIsWeb) {
      _markUnavailable();
      return false;
    }
    if (!(Platform.isIOS || Platform.isAndroid)) {
      _markUnavailable();
      return false;
    }
    try {
      _sub = accelerometerEventStream(samplingPeriod: _samplingPeriod)
          .listen(_handleAccelerometer, onError: (Object e, StackTrace _) {
        // Treat stream errors the same as no-such-sensor — gate the UI.
        debugPrint('CantService stream error: $e');
        _markUnavailable();
      });
      _running = true;
      _available = true;
      return true;
    } on MissingPluginException {
      _markUnavailable();
      return false;
    } catch (e) {
      debugPrint('CantService start failed: $e');
      _markUnavailable();
      return false;
    }
  }

  /// Set `_available = false` and emit a notification so any listening
  /// widget can hide the affordance on this frame. No-op if already
  /// flagged unavailable so we don't burn rebuilds in tight loops.
  void _markUnavailable() {
    if (!_available) return;
    _available = false;
    notifyListeners();
  }

  /// Stop sampling and release the OS sensor. Safe to call when not
  /// running.
  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _running = false;
  }

  /// Record the current smoothed roll as the new zero. UX entry point
  /// for the "Use phone level" button.
  ///
  /// Returns false (no-op) when no sample has arrived yet — the UI
  /// should disable the button until [cantDegrees] returns non-null.
  bool calibrateLevel() {
    final s = _smoothedDeg;
    if (s == null) return false;
    _calibrationOffsetDeg = s;
    notifyListeners();
    return true;
  }

  /// Reset calibration to absolute phone roll (no offset). Useful when
  /// the user wants to re-confirm whether the rifle is square to the
  /// world or for diagnostic UI.
  void clearCalibration() {
    if (_calibrationOffsetDeg == 0.0) return;
    _calibrationOffsetDeg = 0.0;
    notifyListeners();
  }

  void _handleAccelerometer(AccelerometerEvent e) {
    // atan2(x, y) returns 0 when the phone is upright with positive y
    // pointing up. Right-cant produces positive x, left-cant produces
    // negative x.
    final rollRad = math.atan2(e.x, e.y);
    var rollDeg = rollRad * 180.0 / math.pi;
    // Clamp to ±90° because the upside-down branch is meaningless for
    // a rifle-mounted phone.
    if (rollDeg > 90.0) rollDeg = 90.0;
    if (rollDeg < -90.0) rollDeg = -90.0;

    final prev = _smoothedDeg;
    if (prev == null) {
      // Seed the EMA with the first sample so we don't render a stale
      // zero for the first ~1 second after start().
      _smoothedDeg = rollDeg;
    } else {
      _smoothedDeg = prev + _emaAlpha * (rollDeg - prev);
    }
    notifyListeners();
  }

  @override
  void dispose() {
    // ignore: discarded_futures
    _sub?.cancel();
    super.dispose();
  }
}

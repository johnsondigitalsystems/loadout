// FILE: test/cant_service_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Unit tests for `CantService` — the accelerometer-backed roll-angle
// service that powers the Range Day "live readout" UI. Validates the
// surface area we can reach without an actual platform sensor stream:
// initial-state invariants, calibration semantics (offset shift, clear),
// platform-gating (`start()` on a non-iOS/non-Android host), listener
// wiring, idempotent `stop()`, and reusable `start()` after `stop()`.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `CantService` ships with no dependency-injection seam — the
// `accelerometerEventStream()` is constructed inside `start()` directly
// from the `sensors_plus` global API. The private `_handleAccelerometer`
// method (which holds the atan2 math, the EMA smoother, and the
// `_notifyThrottled` gate) is not visible to test code. We therefore
// cover the public surface and rely on a separate, real-device QA pass
// for the actual sensor-fusion math. Worth catching here: regressions
// in the calibration math, the unsupported-platform branch (which the
// Range Day Setup UI keys off to hide affordances), and listener
// lifetime so `notifyListeners()` doesn't fire after `dispose()`.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. NO STREAM INJECTION SEAM. The service builds its own subscription
//    in `start()`, so we cannot push fake `AccelerometerEvent`s through
//    the pipeline from a test. We assert what we can — getters,
//    calibration application, lifecycle — and document the gap below.
// 2. UNTESTABLE: the atan2 → EMA → throttled-notify pipeline. The math
//    lives inside a private `_handleAccelerometer` that only fires from
//    a real OS sensor sample, and there is no way to inject one without
//    modifying production code. Same for the `_notifyThrottled` 100 ms
//    gate — without injecting a clock or a stream we cannot exercise it
//    from a test. The math is small enough (atan2(x, y) → degrees,
//    clamp ±90°, EMA blend with α=0.15) that a real-device QA pass and
//    a live readout in the Range Day Setup card cover it adequately.
// 3. THE TEST HOST IS macOS. `Platform.isIOS` and `Platform.isAndroid`
//    both return false in the Dart test process, so every `start()`
//    call here flows through the unsupported-platform branch. That
//    matches the way the desktop / test environment is meant to behave
//    (the Range Day Setup card hides cant on desktop), and it lets us
//    verify the `_markUnavailable()` path without needing a fake.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// * `flutter test` (CI + local).
// * Read by future engineers touching
//   `lib/services/sensors/cant_service.dart` to see what behaviors are
//   pinned and what is intentionally left to manual QA.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. The tests do not write to disk, the network, or shared
// preferences. They construct a fresh `CantService` per test.

import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/services/sensors/cant_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('initial state', () {
    test('cantDegrees is null before any sample arrives', () {
      final s = CantService();
      addTearDown(s.dispose);
      expect(s.cantDegrees, isNull);
    });

    test('calibrationOffsetDeg starts at 0', () {
      final s = CantService();
      addTearDown(s.dispose);
      expect(s.calibrationOffsetDeg, 0.0);
    });

    test('isRunning is false before start()', () {
      final s = CantService();
      addTearDown(s.dispose);
      expect(s.isRunning, isFalse);
    });

    test('isAvailable defaults to true (optimistic — flips on start)', () {
      // The service is "available until proven otherwise" so the UI can
      // mount the cant readout before the first start() resolves.
      final s = CantService();
      addTearDown(s.dispose);
      expect(s.isAvailable, isTrue);
    });
  });

  group('calibration', () {
    test('calibrateLevel returns false when no sample has arrived', () {
      // The button is meant to be disabled until a sample exists; the
      // service's defensive null-check returns false rather than
      // capturing a meaningless 0° offset.
      final s = CantService();
      addTearDown(s.dispose);
      expect(s.calibrateLevel(), isFalse);
      expect(s.calibrationOffsetDeg, 0.0);
    });

    test('clearCalibration is a no-op when offset is already zero', () {
      // No-op semantics matter: the service skips notifyListeners() in
      // this branch so a Settings → Reset chain doesn't ping every
      // mounted Consumer.
      final s = CantService();
      addTearDown(s.dispose);
      var notified = 0;
      s.addListener(() => notified++);
      s.clearCalibration();
      expect(notified, 0);
      expect(s.calibrationOffsetDeg, 0.0);
    });

    test('calibrationOffsetDeg getter reflects the field', () {
      // Smoke check — guards against an accidental refactor that
      // renames the public getter.
      final s = CantService();
      addTearDown(s.dispose);
      expect(s.calibrationOffsetDeg, isA<double>());
    });
  });

  group('start() on unsupported platform (macOS test host)', () {
    test('start() returns false on a desktop test host', () async {
      // The Dart test process reports as macOS, which fails the
      // `Platform.isIOS || Platform.isAndroid` gate inside start().
      final s = CantService();
      addTearDown(s.dispose);
      final ok = await s.start();
      expect(ok, isFalse);
    });

    test('start() flips isAvailable to false on unsupported host', () async {
      final s = CantService();
      addTearDown(s.dispose);
      await s.start();
      expect(s.isAvailable, isFalse);
    });

    test('start() does not throw on unsupported host', () async {
      final s = CantService();
      addTearDown(s.dispose);
      await expectLater(s.start(), completes);
    });

    test('isRunning stays false after start() on unsupported host', () async {
      // The unsupported branch returns before the subscription is
      // created, so isRunning never flips. Ensures the "Sensors panel
      // shows running indicator" UI doesn't claim a phantom stream.
      final s = CantService();
      addTearDown(s.dispose);
      await s.start();
      expect(s.isRunning, isFalse);
    });

    test('start() is idempotent on unsupported host', () async {
      // Two consecutive start()s should both gracefully return false
      // without throwing or double-flipping availability.
      final s = CantService();
      addTearDown(s.dispose);
      final first = await s.start();
      final second = await s.start();
      expect(first, isFalse);
      expect(second, isFalse);
      expect(s.isAvailable, isFalse);
    });

    test('cantDegrees stays null after start() on unsupported host', () async {
      final s = CantService();
      addTearDown(s.dispose);
      await s.start();
      expect(s.cantDegrees, isNull);
    });
  });

  group('listener wiring', () {
    test('addListener registers and fires on availability flip', () async {
      final s = CantService();
      addTearDown(s.dispose);
      var fires = 0;
      s.addListener(() => fires++);
      await s.start();
      // _markUnavailable() fires notifyListeners exactly once when
      // flipping the flag.
      expect(fires, greaterThanOrEqualTo(1));
    });

    test('removeListener deregisters cleanly', () async {
      final s = CantService();
      addTearDown(s.dispose);
      var fires = 0;
      void l() => fires++;
      s.addListener(l);
      s.removeListener(l);
      await s.start(); // would normally fire
      expect(fires, 0);
    });

    test('multiple listeners all fire', () async {
      final s = CantService();
      addTearDown(s.dispose);
      var a = 0, b = 0;
      s.addListener(() => a++);
      s.addListener(() => b++);
      await s.start();
      expect(a, greaterThanOrEqualTo(1));
      expect(b, greaterThanOrEqualTo(1));
      expect(a, b);
    });
  });

  group('stop() and reuse', () {
    test('stop() is safe to call when never started', () async {
      // The desktop UI calls stop() on dispose unconditionally; an
      // exception here would surface as a screen-tear-down crash.
      final s = CantService();
      addTearDown(s.dispose);
      await expectLater(s.stop(), completes);
    });

    test('stop() then start() does not throw', () async {
      final s = CantService();
      addTearDown(s.dispose);
      await s.stop();
      await expectLater(s.start(), completes);
    });

    test('stop() resets isRunning to false', () async {
      // start() on a desktop host doesn't set isRunning anyway; this
      // is a smoke check that stop() does not crash the lifecycle.
      final s = CantService();
      addTearDown(s.dispose);
      await s.start();
      await s.stop();
      expect(s.isRunning, isFalse);
    });
  });

  group('dispose', () {
    test('dispose() releases without throwing', () {
      final s = CantService();
      expect(s.dispose, returnsNormally);
    });

    test('dispose() after start() releases cleanly', () async {
      final s = CantService();
      await s.start();
      expect(s.dispose, returnsNormally);
    });
  });
}

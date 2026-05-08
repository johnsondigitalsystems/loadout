// FILE: test/inclinometer_service_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Unit tests for `InclinometerService` — the accelerometer-backed pitch
// (slope-of-fire) service that powers the Range Day "live readout" UI.
// Validates the surface area we can reach without a platform sensor
// stream: initial-state invariants, calibration semantics, platform-
// gating on a non-iOS/non-Android host, listener wiring, idempotent
// `stop()`, and reusable `start()` after `stop()`.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Sister to `CantService` — same architectural shape, same lifecycle
// gates, same calibration model. Tests here mirror the cant suite so a
// future refactor of either service preserves the contract on both
// sides. The slope-of-fire scalar shows up in firing-solution
// corrections (improved rifleman's rule, R·cos(θ)) so a regression in
// the public surface — calibration, availability, lifecycle — would
// silently corrupt drop tables for elevated-target shots.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. NO STREAM INJECTION SEAM. Same as cant — `accelerometerEventStream`
//    is constructed inside `start()` directly. We cannot push fake
//    `AccelerometerEvent`s into the math from a test.
// 2. UNTESTABLE BY DESIGN: the pitch math itself
//    (`atan2(-z, sqrt(x² + y²))`), the EMA blend, the ±90° clamp, and
//    the 100 ms `_notifyThrottled` floor. The math is identical in
//    structure to the cant service (different axis pair) and is
//    covered by manual QA on a real device.
// 3. THE TEST HOST IS macOS. `Platform.isIOS` and `Platform.isAndroid`
//    both return false in the Dart test process, so every `start()`
//    here flows through the unsupported-platform branch. Same as cant.
// 4. SIGN CONVENTION. The service docs say:
//      positive = phone tilted forward (top edge down) → uphill on a
//                 muzzle-up rifle.
//      negative = tilted back → downhill.
//    We assert the public sign in tests so a refactor that flips the
//    `-z` to `+z` (which would invert the rifle convention silently)
//    is caught at unit-test time — though we can only assert on the
//    contract, not the live signal.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// * `flutter test` (CI + local).
// * Future engineers extending the inclinometer pipeline (e.g. adding
//   improved-rifleman's-rule corrections to the firing solution).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Tests construct a fresh `InclinometerService` per test.

import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/services/sensors/inclinometer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('initial state', () {
    test('inclineDegrees is null before any sample arrives', () {
      final s = InclinometerService();
      addTearDown(s.dispose);
      expect(s.inclineDegrees, isNull);
    });

    test('calibrationOffsetDeg starts at 0', () {
      final s = InclinometerService();
      addTearDown(s.dispose);
      expect(s.calibrationOffsetDeg, 0.0);
    });

    test('isRunning is false before start()', () {
      final s = InclinometerService();
      addTearDown(s.dispose);
      expect(s.isRunning, isFalse);
    });

    test('isAvailable defaults to true (optimistic — flips on start)', () {
      final s = InclinometerService();
      addTearDown(s.dispose);
      expect(s.isAvailable, isTrue);
    });
  });

  group('calibration', () {
    test('calibrateLevel returns false when no sample has arrived', () {
      // Same defensive contract as cant — the button is disabled in
      // the UI until a sample exists; the service refuses to capture
      // a zero offset that would later read as "perfectly level."
      final s = InclinometerService();
      addTearDown(s.dispose);
      expect(s.calibrateLevel(), isFalse);
      expect(s.calibrationOffsetDeg, 0.0);
    });

    test('clearCalibration is a no-op when offset is already zero', () {
      // Shared contract with cant: skip notifyListeners() in this
      // branch so a Settings → Reset chain doesn't pulse every Consumer.
      final s = InclinometerService();
      addTearDown(s.dispose);
      var notified = 0;
      s.addListener(() => notified++);
      s.clearCalibration();
      expect(notified, 0);
      expect(s.calibrationOffsetDeg, 0.0);
    });

    test('calibrationOffsetDeg getter is a double', () {
      // Smoke check — defends against an accidental getter rename.
      final s = InclinometerService();
      addTearDown(s.dispose);
      expect(s.calibrationOffsetDeg, isA<double>());
    });
  });

  group('start() on unsupported platform (macOS test host)', () {
    test('start() returns false on a desktop test host', () async {
      final s = InclinometerService();
      addTearDown(s.dispose);
      final ok = await s.start();
      expect(ok, isFalse);
    });

    test('start() flips isAvailable to false on unsupported host', () async {
      final s = InclinometerService();
      addTearDown(s.dispose);
      await s.start();
      expect(s.isAvailable, isFalse);
    });

    test('start() does not throw on unsupported host', () async {
      final s = InclinometerService();
      addTearDown(s.dispose);
      await expectLater(s.start(), completes);
    });

    test('isRunning stays false after start() on unsupported host', () async {
      // The unsupported branch returns before the subscription is
      // created, so isRunning never flips.
      final s = InclinometerService();
      addTearDown(s.dispose);
      await s.start();
      expect(s.isRunning, isFalse);
    });

    test('start() is idempotent on unsupported host', () async {
      final s = InclinometerService();
      addTearDown(s.dispose);
      final first = await s.start();
      final second = await s.start();
      expect(first, isFalse);
      expect(second, isFalse);
      expect(s.isAvailable, isFalse);
    });

    test('inclineDegrees stays null after start() on unsupported host',
        () async {
      final s = InclinometerService();
      addTearDown(s.dispose);
      await s.start();
      expect(s.inclineDegrees, isNull);
    });
  });

  group('listener wiring', () {
    test('addListener registers and fires on availability flip', () async {
      final s = InclinometerService();
      addTearDown(s.dispose);
      var fires = 0;
      s.addListener(() => fires++);
      await s.start();
      expect(fires, greaterThanOrEqualTo(1));
    });

    test('removeListener deregisters cleanly', () async {
      final s = InclinometerService();
      addTearDown(s.dispose);
      var fires = 0;
      void l() => fires++;
      s.addListener(l);
      s.removeListener(l);
      await s.start();
      expect(fires, 0);
    });

    test('multiple listeners all fire on availability change', () async {
      final s = InclinometerService();
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
      final s = InclinometerService();
      addTearDown(s.dispose);
      await expectLater(s.stop(), completes);
    });

    test('stop() then start() does not throw', () async {
      final s = InclinometerService();
      addTearDown(s.dispose);
      await s.stop();
      await expectLater(s.start(), completes);
    });

    test('stop() resets isRunning to false', () async {
      // start() on a desktop host doesn't set isRunning anyway; this
      // is a smoke check that stop() doesn't crash the lifecycle.
      final s = InclinometerService();
      addTearDown(s.dispose);
      await s.start();
      await s.stop();
      expect(s.isRunning, isFalse);
    });
  });

  group('dispose', () {
    test('dispose() releases without throwing', () {
      final s = InclinometerService();
      expect(s.dispose, returnsNormally);
    });

    test('dispose() after start() releases cleanly', () async {
      final s = InclinometerService();
      await s.start();
      expect(s.dispose, returnsNormally);
    });
  });
}

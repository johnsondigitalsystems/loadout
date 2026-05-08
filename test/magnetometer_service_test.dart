// FILE: test/magnetometer_service_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Unit tests for `MagnetometerService` — the tilt-compensated compass
// service that powers the Range Day "live readout" UI. Validates the
// surface area we can reach without a platform sensor stream:
// initial-state invariants, declination set / clear semantics, the
// `lookupDeclinationDeg` const region table, the
// `setDeclinationFromLocation` shortcut, platform-gating on a
// non-iOS/non-Android host, listener wiring, idempotent `stop()`, and
// reusable `start()` after `stop()`.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `MagnetometerService` is the only sensor service that exposes a
// non-trivial public surface beyond `start`/`stop`/`calibrate*`: it
// also handles the magnetic-to-true conversion via `setDeclinationDegrees`
// and looks up coarse declinations from a const region table. Those
// pieces ARE testable without a platform stream, so we cover them in
// detail here. The platform-stream-gated math (atan2 fusion, EMA on the
// unit circle, throttling) is left to manual QA on a real device.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. NO STREAM INJECTION SEAM. The accelerometer and magnetometer
//    streams are constructed inside `start()` from the global
//    `sensors_plus` API. Without a test seam we cannot drive samples
//    through the fusion math from a unit test. We assert what we can
//    and document the gap.
// 2. UNTESTABLE BY DESIGN: the tilt-compensation fusion (atan2 over
//    the gravity vector + magnetometer projection), the unit-circle
//    EMA (which avoids the naive 359°→1° wrap bug), the conversion to
//    cardinal labels (the service exposes `headingDegrees` only — the
//    N/NE/E/... label mapping lives in the consuming widget, NOT in
//    the service), and the 100 ms `_notifyThrottled` floor.
// 3. THE TEST HOST IS macOS. `start()` flows through the unsupported-
//    platform branch and never subscribes — same situation as
//    `CantService`. We use that branch to verify availability flips
//    correctly.
// 4. DECLINATION SIGN CONVENTION. NOAA reports declination as
//    "positive east of true north." The service's table follows that
//    convention: California is positive (~12°E), New England is
//    negative (~-14°W). Tests below pin both signs so a refactor
//    that flips the convention is caught immediately.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// * `flutter test` (CI + local).
// * Future engineers extending the declination region table or the
//   tilt-compensation math; tests below pin the externally-visible
//   contract so the math can change underneath without breaking
//   callers.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Tests construct a fresh `MagnetometerService` per test.

import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/services/sensors/magnetometer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('initial state', () {
    test('headingDegrees is null before any sample arrives', () {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      expect(s.headingDegrees, isNull);
    });

    test('isTrueNorth defaults to false (no declination known)', () {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      expect(s.isTrueNorth, isFalse);
    });

    test('declinationDeg starts at 0', () {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      expect(s.declinationDeg, 0.0);
    });

    test('isAvailable defaults to true (optimistic)', () {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      expect(s.isAvailable, isTrue);
    });

    test('isRunning is false before start()', () {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      expect(s.isRunning, isFalse);
    });
  });

  group('setDeclinationDegrees', () {
    test('setting a declination flips isTrueNorth to true', () {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      s.setDeclinationDegrees(-5.3);
      expect(s.isTrueNorth, isTrue);
      expect(s.declinationDeg, -5.3);
    });

    test('setting fires notifyListeners', () {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      var fires = 0;
      s.addListener(() => fires++);
      s.setDeclinationDegrees(7.5);
      expect(fires, 1);
    });

    test('setting the same value while already-known is a no-op', () {
      // The 0.01° threshold prevents notifying for floating-point
      // jitter when the same value is re-applied (e.g. after a
      // re-locate that snapped back to the same grid bin).
      final s = MagnetometerService();
      addTearDown(s.dispose);
      s.setDeclinationDegrees(5.0);
      var fires = 0;
      s.addListener(() => fires++);
      s.setDeclinationDegrees(5.0); // identical
      s.setDeclinationDegrees(5.005); // within threshold
      expect(fires, 0);
    });

    test('positive declination (east of agonic line) preserves sign', () {
      // California is east-of-agonic — declination ~+12°E.
      final s = MagnetometerService();
      addTearDown(s.dispose);
      s.setDeclinationDegrees(12.5);
      expect(s.declinationDeg, 12.5);
    });

    test('negative declination (west of agonic line) preserves sign', () {
      // New England is west-of-agonic — declination ~-14°W.
      final s = MagnetometerService();
      addTearDown(s.dispose);
      s.setDeclinationDegrees(-14.5);
      expect(s.declinationDeg, -14.5);
    });
  });

  group('clearDeclination', () {
    test('reverts isTrueNorth to false', () {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      s.setDeclinationDegrees(8.0);
      s.clearDeclination();
      expect(s.isTrueNorth, isFalse);
      expect(s.declinationDeg, 0.0);
    });

    test('is a no-op when no declination was ever set', () {
      // Same notify-throttle pattern as cant.clearCalibration — the
      // service skips notifyListeners() so a Settings → Reset chain
      // doesn't ping every Consumer.
      final s = MagnetometerService();
      addTearDown(s.dispose);
      var fires = 0;
      s.addListener(() => fires++);
      s.clearDeclination();
      expect(fires, 0);
    });

    test('fires notifyListeners when actually clearing', () {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      s.setDeclinationDegrees(3.0);
      var fires = 0;
      s.addListener(() => fires++);
      s.clearDeclination();
      expect(fires, 1);
    });
  });

  group('setDeclinationFromLocation (region-table lookup)', () {
    test('returns true and applies a value for a known bin (Pacific NW)', () {
      // Lat 47, lon -122 falls into the (45, -125, 50, -115) bin which
      // maps to 14.5° (Pacific Northwest entry in the const table).
      final s = MagnetometerService();
      addTearDown(s.dispose);
      final ok = s.setDeclinationFromLocation(47.0, -122.0);
      expect(ok, isTrue);
      expect(s.isTrueNorth, isTrue);
      expect(s.declinationDeg, closeTo(14.5, 0.01));
    });

    test('returns true and applies negative value for east-coast bin', () {
      // Lat 40, lon -74 (NYC area) → (35, -75, 50, -65) Northeast bin → -14.5°.
      final s = MagnetometerService();
      addTearDown(s.dispose);
      final ok = s.setDeclinationFromLocation(40.0, -74.0);
      expect(ok, isTrue);
      expect(s.declinationDeg, closeTo(-14.5, 0.01));
    });

    test('returns false for a location with no bin (mid-Pacific)', () {
      // Lat 0, lon -150 falls in no bin in the coarse region table.
      final s = MagnetometerService();
      addTearDown(s.dispose);
      final ok = s.setDeclinationFromLocation(0.0, -150.0);
      expect(ok, isFalse);
      expect(s.isTrueNorth, isFalse);
    });
  });

  group('lookupDeclinationDeg helper', () {
    test('returns null for out-of-table locations', () {
      // Mid-Atlantic ocean (lat 20, lon -40) is not in the table.
      expect(lookupDeclinationDeg(20.0, -40.0), isNull);
    });

    test('matches Camp Atterbury, IN region bin', () {
      // Camp Atterbury is Indianapolis-ish, lat 39.34 lon -86.04 → in
      // the Midwest bin (35, -95, 45, -85) → -2.5°.
      final v = lookupDeclinationDeg(39.34, -86.04);
      expect(v, isNotNull);
      expect(v!, closeTo(-2.5, 0.01));
    });

    test('matches Sydney, AU region bin', () {
      // Sydney lat -33.87 lon 151.21 → Australia East/SE bin
      // (-45, 130, -25, 155) → 11.5°.
      final v = lookupDeclinationDeg(-33.87, 151.21);
      expect(v, isNotNull);
      expect(v!, closeTo(11.5, 0.01));
    });

    test('lat/lon edges respect the contains() left-closed/right-open rule',
        () {
      // The bin uses [start, end) on both axes so adjacent bins don't
      // overlap. (35, -85, 45, -75) ends at lat=45; lat=45.0 should NOT
      // match this bin. Use lat=44.99 to confirm we land inside.
      final inside = lookupDeclinationDeg(44.99, -80.0);
      expect(inside, isNotNull);
      // The "Mid-Atlantic" bin lookup is -8.5°.
      expect(inside!, closeTo(-8.5, 0.01));
    });
  });

  group('start() on unsupported platform (macOS test host)', () {
    test('start() returns false on a desktop test host', () async {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      final ok = await s.start();
      expect(ok, isFalse);
    });

    test('start() flips isAvailable to false on unsupported host', () async {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      await s.start();
      expect(s.isAvailable, isFalse);
    });

    test('start() does not throw on unsupported host', () async {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      await expectLater(s.start(), completes);
    });

    test('start() is idempotent on unsupported host', () async {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      final first = await s.start();
      final second = await s.start();
      expect(first, isFalse);
      expect(second, isFalse);
    });

    test('headingDegrees stays null after start() on unsupported host',
        () async {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      await s.start();
      expect(s.headingDegrees, isNull);
    });
  });

  group('listener wiring', () {
    test('addListener registers and fires on availability flip', () async {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      var fires = 0;
      s.addListener(() => fires++);
      await s.start();
      expect(fires, greaterThanOrEqualTo(1));
    });

    test('removeListener deregisters cleanly', () async {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      var fires = 0;
      void l() => fires++;
      s.addListener(l);
      s.removeListener(l);
      await s.start();
      expect(fires, 0);
    });

    test('setDeclinationDegrees fires the listener', () {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      var fires = 0;
      s.addListener(() => fires++);
      s.setDeclinationDegrees(2.5);
      expect(fires, 1);
    });
  });

  group('stop() and reuse', () {
    test('stop() is safe to call when never started', () async {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      await expectLater(s.stop(), completes);
    });

    test('stop() then start() does not throw', () async {
      final s = MagnetometerService();
      addTearDown(s.dispose);
      await s.stop();
      await expectLater(s.start(), completes);
    });
  });

  group('dispose', () {
    test('dispose() releases without throwing', () {
      final s = MagnetometerService();
      expect(s.dispose, returnsNormally);
    });

    test('dispose() after start() releases cleanly', () async {
      final s = MagnetometerService();
      await s.start();
      expect(s.dispose, returnsNormally);
    });
  });
}

// FILE: test/units_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Coverage tests for `lib/services/ballistics/units.dart`. The existing
// `ballistics_test.dart` has a single round-trip smoke test for unit
// conversions; this file pins down the angular and BC-family helpers
// that drive the UI-facing trajectory holds, plus a handful of
// edge-case guards (zero / very small distances).
//
// Coverage:
//
//   * inchesToMoaAtYards / inchesToMilAtYards: 1 MOA ≈ 1.047 in / 100 yd,
//     1 mil = 3.6 in / 100 yd, plus the textbook 1 mil = 3.4377 MOA
//     conversion.
//   * Length round-trips: yards ↔ meters, inches ↔ meters, feet ↔ meters.
//   * Speed round-trips: fps ↔ m/s, mph ↔ m/s, knots ↔ m/s, mph ↔ knots.
//   * Mass: grains ↔ kg.
//   * Energy: J ↔ ft-lb.
//   * Edge cases: zero distance returns 0 (no divide-by-zero), negative
//     distance returns 0, very small distances stay sane.
//   * BC family conversion: G1 ↔ G7 ratio matches the published 0.512
//     constant; round-trip is exact.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `units.dart` is the lowest layer of the ballistics package — every
// other file depends on it. A regression in any conversion factor
// silently shifts every output number in the app. Pinning the
// individual conversions to NIST values means a future "reorganize
// the constants" PR cannot change a result by 1% without breaking
// here.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The 1 MOA = 1.047 in / 100 yd value comes from `tan(1/60°) × 36 in
//     × 100`. Computing it by hand vs the helper introduces a few
//     ulps of difference, so the tolerance is set at the 0.5%
//     small-angle-approximation accuracy bound documented in the file
//     header.
//
//   * `inchesToMoaAtYards(0, 100)` should return 0 (no offset → no
//     correction); `inchesToMoaAtYards(N, 0)` should return 0 (the
//     helper guards the divide-by-zero) — neither case should produce
//     NaN.
//
//   * BC family conversion is not algebraically exact (see the long
//     note in units.dart). Tests pin only the published-rule-of-thumb
//     factor, not a physically meaningful invariant.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   - `flutter test` suite.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure unit tests.
// ============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/ballistics/units.dart';

void main() {
  group('Length conversions', () {
    test('inches ↔ meters round-trip exact to ulp', () {
      // 1 inch = 0.0254 m exactly.
      expect(inchesToMeters(1.0), closeTo(0.0254, 1e-12));
      expect(metersToInches(0.0254), closeTo(1.0, 1e-9));
      expect(metersToInches(inchesToMeters(123.456)), closeTo(123.456, 1e-9));
    });

    test('yards ↔ meters round-trip exact to ulp', () {
      // 1 yard = 0.9144 m exactly.
      expect(yardsToMeters(100.0), closeTo(91.44, 1e-9));
      expect(metersToYards(91.44), closeTo(100.0, 1e-9));
      expect(metersToYards(yardsToMeters(750.0)), closeTo(750.0, 1e-9));
    });

    test('feet ↔ meters round-trip', () {
      // 1 foot = 0.3048 m exactly.
      expect(feetToMeters(3.0), closeTo(0.9144, 1e-9));
      expect(metersToFeet(0.3048), closeTo(1.0, 1e-9));
    });
  });

  group('Speed conversions', () {
    test('fps → m/s matches NIST factor 0.3048', () {
      // Mach 1 ICAO = 1116.45 fps = 340.294 m/s.
      expect(fpsToMps(1116.45), closeTo(340.294, 0.01));
      expect(mpsToFps(340.294), closeTo(1116.45, 0.05));
    });

    test('mph → m/s matches NIST factor 0.44704', () {
      expect(mphToMps(60.0), closeTo(26.8224, 1e-6));
      expect(mpsToMph(mphToMps(60.0)), closeTo(60.0, 1e-9));
    });

    test('knots → m/s matches 0.514444', () {
      // 1 knot = 0.514444 m/s exactly per international convention.
      expect(knotsToMps(10.0), closeTo(5.14444, 1e-6));
      expect(mpsToKnots(5.14444), closeTo(10.0, 1e-5));
    });

    test('knots ↔ mph: 1 knot ≈ 1.150779 mph', () {
      expect(knotsToMph(10.0), closeTo(11.50779, 1e-3));
      expect(mphToKnots(11.50779), closeTo(10.0, 1e-3));
    });
  });

  group('Mass conversions', () {
    test('grains ↔ kg via 1/7000 lb factor', () {
      // 7000 grains = 1 lb = 0.45359237 kg
      expect(grainsToKg(7000.0), closeTo(0.45359237, 1e-6));
      expect(kgToGrains(0.45359237), closeTo(7000.0, 0.5));
      expect(grainsToKg(140.0), closeTo(140.0 * 6.479891e-5, 1e-12));
    });
  });

  group('Energy conversions', () {
    test('joules ↔ foot-pounds round-trip exact', () {
      // 1 J = 0.7375621493 ft-lb (NIST).
      expect(joulesToFootPounds(1.0), closeTo(0.7375621493, 1e-9));
      expect(footPoundsToJoules(0.7375621493), closeTo(1.0, 1e-9));
      expect(
        footPoundsToJoules(joulesToFootPounds(1234.5)),
        closeTo(1234.5, 1e-6),
      );
    });
  });

  group('Angles — MOA, mil, radians', () {
    test('1 mil = 3.4377 MOA (small-angle textbook conversion)', () {
      // 1 mil = 1/1000 rad. 1 MOA = 1/60 deg = pi/(180*60) rad.
      // Ratio: 1 mil / 1 MOA = (1/1000) / (pi/10800) = 10800/(1000·pi)
      // ≈ 3.4377.
      final moaForOneMil = radiansToMoa(milToRadians(1.0));
      expect(moaForOneMil, closeTo(3.4377, 5e-4));
    });

    test('1 mil = 3.6 inches at 100 yd', () {
      // 1 mil at 100 yd = 0.001 rad × (100 × 36) in = 3.6 in.
      // We confirm the inverse: an offset of 3.6 in at 100 yd reads
      // back as ~1 mil.
      final mil = inchesToMilAtYards(3.6, 100.0);
      expect(mil, closeTo(1.0, 1e-3));
    });

    test('1 MOA ≈ 1.047 inches at 100 yd', () {
      // 1 MOA at 100 yd = (1/60)° × tan() × 100 yd × 36 in/yd ≈ 1.047 in.
      // We assert the inverse: 1.047 in at 100 yd should read back
      // close to 1 MOA. Tolerance accounts for the small-angle
      // approximation documented in the file header (<0.5% out to
      // 1500 yards).
      final moa = inchesToMoaAtYards(1.047, 100.0);
      expect(moa, closeTo(1.0, 5e-3));
    });

    test('linear scaling — 10 in at 100 yd ≈ 10× the per-inch correction',
        () {
      // Angles scale linearly with offset at small angles; the
      // 10-inch case should be 10× the 1-inch case to high precision.
      final per1 = inchesToMoaAtYards(1.0, 100.0);
      final per10 = inchesToMoaAtYards(10.0, 100.0);
      // Within 0.1% — small-angle approximation holds.
      expect(per10 / per1, closeTo(10.0, 0.001));
    });
  });

  group('Angles — degenerate inputs', () {
    test('zero range returns 0 MOA / 0 mil (no divide-by-zero)', () {
      expect(inchesToMoaAtYards(10.0, 0.0), 0.0);
      expect(inchesToMilAtYards(10.0, 0.0), 0.0);
    });

    test('negative range returns 0 (guard prevents NaN/garbage)', () {
      expect(inchesToMoaAtYards(10.0, -100.0), 0.0);
      expect(inchesToMilAtYards(10.0, -100.0), 0.0);
    });

    test('1-yard range stays mathematically sane (very large angle)', () {
      // 36 inches drop at 1 yard = 45° angle → 2700 MOA.
      // The helper uses atan(opposite/adjacent), so for a 36 in
      // offset at 1 yd (= 36 in) the angle is exactly 45° = 2700 MOA.
      final moa = inchesToMoaAtYards(36.0, 1.0);
      expect(moa.isFinite, isTrue);
      expect(moa, closeTo(2700.0, 1.0));
    });
  });

  group('Temperature conversions', () {
    test('°F ↔ °C round-trip', () {
      expect(fToC(32.0), closeTo(0.0, 1e-12));
      expect(fToC(212.0), closeTo(100.0, 1e-12));
      expect(cToF(0.0), 32.0);
      expect(cToF(100.0), 212.0);
      expect(fToC(cToF(25.0)), closeTo(25.0, 1e-9));
    });

    test('°F → K and °C → K reach 273.15 at the freezing point', () {
      expect(fToK(32.0), closeTo(273.15, 1e-12));
      expect(cToK(0.0), closeTo(273.15, 1e-12));
    });
  });

  group('Pressure conversions', () {
    test('inHg ↔ Pa via NIST factor 3386.389', () {
      expect(inHgToPa(1.0), closeTo(3386.389, 1e-3));
      expect(paToInHg(3386.389), closeTo(1.0, 1e-9));
      // 29.92 × 3386.389 = 101320.7589 Pa (the standard sea-level
      // pressure rounds to 29.9213 inHg, not 29.92).
      expect(inHgToPa(29.92), closeTo(101320.759, 0.5));
    });
  });

  group('BC family conversion (rule of thumb)', () {
    test('industry standard published BC_G7 ≈ BC_G1 × 0.512', () {
      // The conversion constant is the only number in the file with
      // a published source — pin it.
      expect(bcG1ToG7(1.0), closeTo(0.512, 1e-9));
      expect(bcG7ToG1(0.512), closeTo(1.0, 1e-9));
    });

    test('round-trip is mathematically exact (multiply / divide by 0.512)',
        () {
      // The round-trip is exact only because we multiply and then
      // divide by the same constant. The underlying physics is NOT
      // exact, as the file header notes — but a regression that
      // breaks the symmetric numeric round-trip is a code change,
      // not a physics one.
      expect(bcG7ToG1(bcG1ToG7(0.55)), closeTo(0.55, 1e-9));
      expect(bcG1ToG7(bcG7ToG1(0.30)), closeTo(0.30, 1e-9));
    });
  });
}

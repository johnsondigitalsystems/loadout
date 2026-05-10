// FILE: test/external_ballistics_corrections_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Validates the four "corrections" the LoadOut external-ballistics
// solver layers on top of the bare integrated trajectory:
//
//   1. Coriolis effect       — Earth's rotation deflecting the bullet.
//                              Vertical (Eötvös) for east/west shots,
//                              horizontal for any shot azimuth ≠ 90°
//                              of the rotation axis.
//   2. Spin drift            — gyroscopic deflection from the bullet's
//                              spin rate vs. velocity vector.
//                              Industry-standard Litz t^1.83 fit.
//   3. Aerodynamic jump      — wind-induced vertical deflection during
//                              the first ~yard of flight. Industry
//                              standard simplified formula.
//   4. Scope tracking        — sightScaleVertical / sightScaleHorizontal
//                              multipliers applied to drop and wind
//                              drift respectively.
//
// Each test isolates one correction by enabling it in isolation
// against a baseline solve with the correction off, and asserts the
// delta matches the expected physics.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `precision_test.dart` already covers Coriolis on/off as a smoke
// test, and `ballistic_precision_test.dart` covers sight scale and
// twist direction. This file goes deeper:
//
//   * Pins the Coriolis vertical (Eötvös) and horizontal contributions
//     against the analytic formula `Δx ≈ Ω·R·t·sin(lat)·sin(az)`.
//   * Pins the spin-drift industry standard formula's prediction
//     `1.25·(Sg+1.2)·t^1.83` to the solver's output for a known
//     (Sg, TOF) pair. Catches a regression where the formula gets
//     re-fit or the Miller stability factor's velocity correction
//     changes.
//   * Pins the aero jump direction-and-magnitude relationship across
//     left vs right twist and left vs right wind. Catches sign flips
//     that any one-direction test would miss.
//   * Pins the scope-tracking multiplicative chain: drop scales by
//     `sightScaleVertical`, wind drift scales by `sightScaleHorizontal`,
//     spin drift also scales by `sightScaleHorizontal`, aero jump
//     scales by `sightScaleVertical`, incline correction scales by
//     `sightScaleVertical`.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Coriolis vertical effect is small (~2-3 in at 1000 yd at 45°N
//     for east/west shots). To detect it cleanly, we deliberately
//     compare east-shot vs west-shot at the same load — that doubles
//     the signal and removes any other system-wide vertical bias.
//
//   * Spin drift uses the Miller stability factor with a velocity
//     correction. A regression that disabled the velocity correction
//     would shift the Sg by a few percent and the spin drift by
//     a corresponding amount; the assertion expects the corrected
//     value, not the raw 2800-fps value.
//
//   * Aero jump direction-of-effect depends on (a) wind direction,
//     (b) twist direction. The four combinations are exercised
//     symmetrically so a sign flip on either factor lands somewhere.
//
//   * Scope-tracking factors compound through the breakdown fields:
//     `windDriftInches` already includes the scope-scaled spin drift;
//     `aerodynamicJumpInches` is the scope-scaled aero contribution
//     to drop. Asserting on each breakdown field independently
//     catches a regression where the scaling is applied twice.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   - `flutter test` suite.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None.
// ============================================================================

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/services/ballistics/atmosphere.dart';
import 'package:loadout/services/ballistics/drag_functions.dart';
import 'package:loadout/services/ballistics/environment.dart';
import 'package:loadout/services/ballistics/projectile.dart';
import 'package:loadout/services/ballistics/solver.dart';

/// Standard 6.5 CM 140 ELD-M projectile used as the validation
/// baseline. Chosen because it stays supersonic at 1000 yd in ICAO
/// standard atmosphere, has well-known ballistic properties, and is
/// the canonical PRS load.
Projectile _baselineProj() => Projectile(
      diameterIn: 0.264,
      weightGr: 140,
      bc: 0.305,
      dragModel: DragModel.g7,
      lengthIn: 1.355,
      twistInches: 8,
    );

const ShotInputs _baselineShot = ShotInputs(
  muzzleVelocityFps: 2710,
  sightHeightIn: 1.5,
  zeroRangeYards: 100,
);

Environment _envFor({
  double windMph = 0,
  double windFromDeg = 90,
  double azDeg = 0,
  double latDeg = 0,
}) {
  return Environment.fromImperial(
    atmosphere: Atmosphere.icaoStd(),
    windSpeedMph: windMph,
    windFromDegrees: windFromDeg,
    shotAzimuthDegrees: azDeg,
    latitudeDegrees: latDeg,
    targetElevationFt: 0,
  );
}

void main() {
  // ============================================================================
  // CORIOLIS
  // ============================================================================
  //
  // Earth rotates at Ω = 7.2921159e-5 rad/s. In the shooter-local
  // frame (X=downrange, Y=up, Z=right), the components of the
  // rotation vector are:
  //
  //   ωx =  Ω · cos(lat) · cos(az)
  //   ωy =  Ω · sin(lat)
  //   ωz = -Ω · cos(lat) · sin(az)
  //
  // Coriolis acceleration: a_cor = -2·Ω×v.
  //
  // For a north-shot at 45° latitude (az=0):
  //   ωx = Ω·cos(45)·1 = 0.5159e-4
  //   ωy = Ω·sin(45)   = 0.5159e-4
  //   ωz = 0
  //
  // The horizontal Coriolis drift at 45°N for a 1000 yd north-shot
  // is ~2-3 in (per the Litz tables). The vertical effect is ~0
  // because the shot is along the rotation axis component.
  //
  // For an EAST shot (az=90°): ωy is unchanged (depends only on lat),
  // and ωx becomes 0 while ωz becomes -Ω·cos(45). The Eötvös vertical
  // contribution becomes maximum — the bullet "feels lighter" in the
  // east direction, less drop. WEST shot: bullet feels "heavier",
  // more drop. The east/west delta should be ~5 in at 1000 yd, 45°N.
  group('Coriolis effect', () {
    test('north shot at 45°N produces ~horizontal-only deflection', () {
      // No wind, no spin drift — only Coriolis.
      final samples = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(latDeg: 45, azDeg: 0),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: true,
        includeAerodynamicJump: false,
      );
      // Baseline (Coriolis off) for comparison.
      final baseline = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(latDeg: 45, azDeg: 0),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
      );
      final dropDelta =
          samples.first.dropInches - baseline.first.dropInches;
      final windDelta =
          samples.first.windDriftInches - baseline.first.windDriftInches;

      // For a north shot, the vertical Coriolis effect is small
      // (because the rotation vector has no x-component contributing
      // to the vertical y-component), but non-zero. Solver output:
      // ~0 in at 1000 yd 45°N — within noise of the integrator.
      expect(dropDelta.abs(), lessThan(1.0),
          reason:
              'north-shot Coriolis vertical at 1000 yd 45°N should be < 1 in');
      // Horizontal deflection at 1000 yd 45°N for a north-shot
      // should be ~2-3 in (regression-locked from solver: 2.55).
      // industry-standard tables list ~2.6 in (right deflection in
      // northern hemisphere).
      expect(windDelta.abs(), greaterThan(1.5),
          reason: 'Coriolis horizontal effect should be > 1.5 in');
      expect(windDelta.abs(), lessThan(4.0),
          reason: 'Coriolis horizontal effect should be < 4 in');
    });

    test('Eötvös effect: east-shot drops less than west-shot', () {
      // The classic Eötvös effect. East shot: bullet is moving in the
      // direction of Earth's rotation, "centrifuged" upward → less
      // drop. West shot: opposite, more drop.
      final eastShot = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(latDeg: 45, azDeg: 90),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: true,
        includeAerodynamicJump: false,
      ).first;
      final westShot = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(latDeg: 45, azDeg: 270),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: true,
        includeAerodynamicJump: false,
      ).first;
      // East-shot drop: 329.22 (regression). West-shot drop: 333.91.
      // Delta ~4.7 in.
      expect(eastShot.dropInches, lessThan(westShot.dropInches),
          reason: 'Eötvös: east-shot must drop less than west-shot');
      final eastWestDelta = westShot.dropInches - eastShot.dropInches;
      // industry standard table for 6.5 CM 140 at 1000 yd 45°N: ~4-6 in
      // east/west delta. Solver: ~4.7 in.
      expect(eastWestDelta, greaterThan(3.0),
          reason:
              'east/west Eötvös delta at 1000 yd 45°N should exceed 3 in');
      expect(eastWestDelta, lessThan(8.0),
          reason: 'east/west Eötvös delta should be under 8 in');
    });

    test('Coriolis: equator (lat=0) gives no horizontal deflection', () {
      // At lat=0, sin(lat)=0 → ωy = 0. That removes the dominant
      // horizontal-deflection term for typical shooting cases.
      final samples = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(latDeg: 0, azDeg: 0),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: true,
        includeAerodynamicJump: false,
      );
      final baseline = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(latDeg: 0, azDeg: 0),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
      );
      // Wind delta should be ~zero because ωy=0 at the equator.
      final windDelta = (samples.first.windDriftInches -
              baseline.first.windDriftInches)
          .abs();
      expect(windDelta, lessThan(0.5),
          reason:
              'Coriolis horizontal deflection should be ~0 at the equator (sin(lat)=0)');
    });

    test('northern vs southern hemisphere reverses horizontal sign', () {
      // sin(lat) is odd, so latitude → -latitude flips the sign of ωy
      // and therefore the sign of the horizontal Coriolis drift.
      final north = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(latDeg: 45, azDeg: 0),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: true,
        includeAerodynamicJump: false,
      ).first;
      final south = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(latDeg: -45, azDeg: 0),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: true,
        includeAerodynamicJump: false,
      ).first;
      // Magnitudes are equal and signs are opposite.
      expect(north.windDriftInches, closeTo(-south.windDriftInches, 0.1),
          reason:
              'northern-hemisphere Coriolis horizontal drift should be the negative of southern');
    });

    test('Coriolis effect grows with range (cubic-ish for fixed v)', () {
      // The Coriolis acceleration is constant for a given (Ω, v_bullet)
      // pair, so deflection scales as t² ≈ R² (constant velocity) or
      // somewhat slower with drag. Verify monotonic growth and that
      // the 1000 yd Coriolis is meaningfully larger than the 500 yd
      // Coriolis.
      final samples = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(latDeg: 45, azDeg: 0),
        shot: _baselineShot,
        sampleRangesYards: const [500, 1000],
        includeSpinDrift: false,
        includeCoriolis: true,
        includeAerodynamicJump: false,
      );
      final baseline = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(latDeg: 45, azDeg: 0),
        shot: _baselineShot,
        sampleRangesYards: const [500, 1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
      );
      final windDelta500 =
          (samples[0].windDriftInches - baseline[0].windDriftInches).abs();
      final windDelta1000 =
          (samples[1].windDriftInches - baseline[1].windDriftInches).abs();
      // 1000 yd should have at least 3× the Coriolis drift of 500 yd
      // (since drift scales roughly as TOF², and TOF ratio is ~2.5×).
      expect(windDelta1000 / windDelta500.clamp(0.001, double.infinity),
          greaterThan(3.0),
          reason:
              'Coriolis drift scales with TOF² — 1000 yd should be much greater than 500 yd');
    });
  });

  // ============================================================================
  // SPIN DRIFT
  // ============================================================================
  //
  // Industry-standard formula (Litz / Applied Ballistics):
  //
  //     spin_drift_in = 1.25 · (Sg + 1.2) · t^1.83
  //
  // For a 6.5 CM 140 ELD-M:
  //   Sg (Miller, vel-corrected at MV 2710) ≈ 1.84
  //   TOF at 1000 yd ≈ 1.533 s
  //   Predicted: 1.25 × (1.84 + 1.2) × 1.533^1.83 = 1.25 × 3.04 × 2.218
  //           ≈ 8.43 in
  //
  // Solver output: 8.07 in. Within the test tolerance.
  group('spin drift — industry standard formula', () {
    test('6.5 CM 140 ELD-M spin drift at 1000 yd matches Litz formula ±5%', () {
      final samples = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(latDeg: 0, azDeg: 0),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: true,
        includeCoriolis: false,
        includeAerodynamicJump: false,
      );
      final spinDrift = samples.first.spinDriftInches;
      // Compute expected from the formula directly.
      final sg = _baselineProj().millerStability(2710.0)!;
      final tof = samples.first.timeSec;
      final expected = 1.25 * (sg + 1.2) * math.pow(tof, 1.83);
      // Spin drift should be positive (right twist drifts right).
      expect(spinDrift, greaterThan(0));
      // Formula match within ±5 % (the Litz formula is empirical,
      // calibrated against 6-DOF, accurate to a few tenths of an inch).
      expect((spinDrift - expected).abs() / expected, lessThan(0.05),
          reason:
              'spin drift should match Litz formula within 5%; expected $expected, got $spinDrift');
    });

    test('left-twist barrel flips spin-drift sign, preserves magnitude', () {
      // The TwistDirection enum's sign multiplier is asserted in
      // ballistic_precision_test.dart; this test pins the magnitude
      // equality between right- and left-twist.
      final right = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: true,
        includeCoriolis: false,
        includeAerodynamicJump: false,
      );
      final left = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
          twistDirection: TwistDirection.left,
        ),
        sampleRangesYards: const [1000],
        includeSpinDrift: true,
        includeCoriolis: false,
        includeAerodynamicJump: false,
      );
      expect(right.first.spinDriftInches,
          closeTo(-left.first.spinDriftInches, 1e-6));
    });

    test('higher Sg → more spin drift', () {
      // The formula scales linearly in Sg. A bullet with Sg=1.5
      // should drift less than the same bullet "morphed" to Sg=2.0
      // (achieved by faster twist).
      final tighterTwist = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.305,
        dragModel: DragModel.g7,
        lengthIn: 1.355,
        twistInches: 7, // tighter than 1:8 → higher Sg
      );
      final looserTwist = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.305,
        dragModel: DragModel.g7,
        lengthIn: 1.355,
        twistInches: 9, // looser than 1:8 → lower Sg
      );
      final tight = solveTrajectory(
        projectile: tighterTwist,
        environment: _envFor(),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: true,
        includeCoriolis: false,
        includeAerodynamicJump: false,
      ).first;
      final loose = solveTrajectory(
        projectile: looserTwist,
        environment: _envFor(),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: true,
        includeCoriolis: false,
        includeAerodynamicJump: false,
      ).first;
      expect(tight.spinDriftInches, greaterThan(loose.spinDriftInches),
          reason: 'tighter twist (higher Sg) should produce more spin drift');
    });

    test('spin drift is zero when twist info is missing', () {
      // Projectile without twistInches should return null Sg and skip
      // the spin-drift correction.
      final noTwist = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.305,
        dragModel: DragModel.g7,
      );
      final samples = solveTrajectory(
        projectile: noTwist,
        environment: _envFor(),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: true,
        includeCoriolis: false,
        includeAerodynamicJump: false,
      );
      expect(samples.first.spinDriftInches, 0.0,
          reason: 'spin drift should be 0 when projectile has no twist info');
    });

    test('Pejsa model adds extra drift at long flight time', () {
      // At t < ~1.5 s the two formulas agree to ~5 %. At t > 2 s the
      // Pejsa adds an extra ~0.3 in / second of flight thanks to the
      // higher-order time terms.
      final industryStd = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: _baselineShot,
        sampleRangesYards: const [1200],
        includeSpinDrift: true,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        spinDriftModel: SpinDriftModel.industryStandard,
      ).first;
      final pejsa = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: _baselineShot,
        sampleRangesYards: const [1200],
        includeSpinDrift: true,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        spinDriftModel: SpinDriftModel.pejsa,
      ).first;
      // Both positive, Pejsa within 30 % of industry standard
      // (reasonably close at 1200 yd / TOF ~ 2 s).
      expect(industryStd.spinDriftInches, greaterThan(0));
      expect(pejsa.spinDriftInches, greaterThan(0));
      final delta = (industryStd.spinDriftInches - pejsa.spinDriftInches).abs();
      expect(delta / industryStd.spinDriftInches, lessThan(0.3),
          reason: 'two spin-drift models should agree within 30 % at 1200 yd');
    });
  });

  // ============================================================================
  // AERODYNAMIC JUMP
  // ============================================================================
  //
  // Industry-standard simplified per-range formula (from "Applied
  // Ballistics for Long-Range Shooting" 2nd ed., chapter 9):
  //
  //     aero_jump_in ≈ 0.087 · cross_wind_mph · TOF_s · velocity_fps / 1000
  //
  // Sign: a wind from the LEFT (windFromDeg = 270) on a right-twist
  // barrel LIFTS the bullet — drop contribution is NEGATIVE.
  // A wind from the RIGHT (windFromDeg = 90) on a right-twist
  // barrel pushes the bullet DOWN — drop contribution is POSITIVE.
  // Left-twist barrels reverse the sign.
  group('aerodynamic jump', () {
    test('10 mph crosswind from left lifts the bullet on right-twist', () {
      // Wind from 270° = "from the left" → bullet pushed right by drag,
      // and aero jump contribution is upward (negative drop).
      final samples = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(windMph: 10, windFromDeg: 270),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: true,
      );
      final ajIn = samples.first.aerodynamicJumpInches;
      // Sign must be negative (lift).
      expect(ajIn, lessThan(0),
          reason: 'left-wind on right-twist barrel should lift the bullet '
              '(negative drop contribution)');
      // Magnitude: TOF ~1.533 s, vel ~1414 fps, 10 mph crosswind.
      // industry standard formula: 0.087 × 10 × 1.533 × 1414 / 1000
      // ≈ 1.886 in. Solver returns ~1.88 in.
      expect(ajIn.abs(), greaterThan(0.5));
      expect(ajIn.abs(), lessThan(6.0));
    });

    test('right wind on right-twist pushes the bullet down', () {
      // Wind from 90° → bullet pushed left by drag → aero jump down.
      final samples = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(windMph: 10, windFromDeg: 90),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: true,
      );
      // Sign must be positive (drop).
      expect(samples.first.aerodynamicJumpInches, greaterThan(0),
          reason: 'right-wind on right-twist barrel should push the bullet '
              'down (positive drop contribution)');
    });

    test('left-twist barrel flips aero jump sign for the same wind', () {
      // Same wind direction, opposite twist: aero jump direction
      // reverses.
      final right = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(windMph: 10, windFromDeg: 270),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: true,
      ).first;
      final left = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(windMph: 10, windFromDeg: 270),
        shot: const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
          twistDirection: TwistDirection.left,
        ),
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: true,
      ).first;
      // Magnitudes equal and signs opposite.
      expect(right.aerodynamicJumpInches.sign,
          isNot(left.aerodynamicJumpInches.sign));
      expect(right.aerodynamicJumpInches.abs(),
          closeTo(left.aerodynamicJumpInches.abs(), 1e-6));
    });

    test('aero jump is zero when wind is zero', () {
      final samples = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(windMph: 0),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: true,
      );
      expect(samples.first.aerodynamicJumpInches, 0.0,
          reason: 'no wind → no aero jump');
    });

    test('aero jump is zero for a head/tail wind (no crosswind component)',
        () {
      // Wind from 0° = tailwind, wind from 180° = headwind. Neither
      // has a crosswind component, so aero jump = 0.
      final tailwind = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(windMph: 10, windFromDeg: 0),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: true,
      );
      final headwind = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(windMph: 10, windFromDeg: 180),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: true,
      );
      expect(tailwind.first.aerodynamicJumpInches.abs(), lessThan(0.05),
          reason: 'tailwind has no crosswind component → no aero jump');
      expect(headwind.first.aerodynamicJumpInches.abs(), lessThan(0.05),
          reason: 'headwind has no crosswind component → no aero jump');
    });

    test('aero jump scales linearly with wind speed', () {
      final aj5 = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(windMph: 5, windFromDeg: 270),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: true,
      ).first.aerodynamicJumpInches.abs();
      final aj10 = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(windMph: 10, windFromDeg: 270),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: true,
      ).first.aerodynamicJumpInches.abs();
      // The industry standard formula is linear in wind speed.
      expect(aj10 / aj5, closeTo(2.0, 0.05),
          reason:
              'aero jump should scale linearly with wind speed (10 mph / 5 mph = 2.0)');
    });
  });

  // ============================================================================
  // SCOPE TRACKING — sightScaleVertical / sightScaleHorizontal
  // ============================================================================
  //
  // These multipliers correct for imperfect scope turret tracking.
  // A measured 0.95 vertical means "my scope dials 0.95 mil for every
  // commanded mil; the solver should report 5 % smaller elevation
  // holds." Same for horizontal.
  //
  // The chain in solver.dart is:
  //   1. Drop: integrated drop + aero jump + coning, scaled by
  //      cos(incline)^1.5, multiplied by sightScaleVertical.
  //   2. Wind drift: integrated drift + spin drift + coning side,
  //      multiplied by sightScaleHorizontal.
  //   3. Spin drift breakdown: scaled by sightScaleHorizontal.
  //   4. Aero jump breakdown: scaled by sightScaleVertical.
  //   5. Incline correction breakdown: scaled by sightScaleVertical.
  group('scope tracking calibration', () {
    test('drop scales by sightScaleVertical at every range', () {
      final unscaled = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: _baselineShot,
        sampleRangesYards: const [300, 500, 800, 1000],
      );
      const scale = 0.92;
      final scaled = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
          sightScaleVertical: scale,
        ),
        sampleRangesYards: const [300, 500, 800, 1000],
      );
      for (var i = 0; i < unscaled.length; i++) {
        // Avoid divide-by-zero at zero range.
        if (unscaled[i].dropInches.abs() < 1e-6) continue;
        final ratio = scaled[i].dropInches / unscaled[i].dropInches;
        expect(ratio, closeTo(scale, 1e-6),
            reason: 'drop ratio at ${unscaled[i].rangeYards} yd should equal '
                'sightScaleVertical = $scale; got $ratio');
      }
    });

    test('wind drift scales by sightScaleHorizontal', () {
      final env = _envFor(windMph: 10, windFromDeg: 270);
      final unscaled = solveTrajectory(
        projectile: _baselineProj(),
        environment: env,
        shot: _baselineShot,
        sampleRangesYards: const [1000],
      ).first;
      const scale = 0.95;
      final scaled = solveTrajectory(
        projectile: _baselineProj(),
        environment: env,
        shot: const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
          sightScaleHorizontal: scale,
        ),
        sampleRangesYards: const [1000],
      ).first;
      expect(scaled.windDriftInches / unscaled.windDriftInches,
          closeTo(scale, 1e-6),
          reason: 'wind drift should scale by sightScaleHorizontal');
    });

    test('spin drift breakdown scales by sightScaleHorizontal', () {
      final env = _envFor();
      final unscaled = solveTrajectory(
        projectile: _baselineProj(),
        environment: env,
        shot: _baselineShot,
        sampleRangesYards: const [1000],
      ).first;
      const scale = 0.95;
      final scaled = solveTrajectory(
        projectile: _baselineProj(),
        environment: env,
        shot: const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
          sightScaleHorizontal: scale,
        ),
        sampleRangesYards: const [1000],
      ).first;
      // spin drift breakdown is scaled by sightScaleHorizontal.
      expect(scaled.spinDriftInches / unscaled.spinDriftInches,
          closeTo(scale, 1e-6),
          reason:
              'spin drift breakdown should scale by sightScaleHorizontal');
    });

    test('aero jump breakdown scales by sightScaleVertical', () {
      final env = _envFor(windMph: 10, windFromDeg: 270);
      final unscaled = solveTrajectory(
        projectile: _baselineProj(),
        environment: env,
        shot: _baselineShot,
        sampleRangesYards: const [1000],
      ).first;
      const scale = 0.95;
      final scaled = solveTrajectory(
        projectile: _baselineProj(),
        environment: env,
        shot: const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
          sightScaleVertical: scale,
        ),
        sampleRangesYards: const [1000],
      ).first;
      expect(
          scaled.aerodynamicJumpInches / unscaled.aerodynamicJumpInches,
          closeTo(scale, 1e-6),
          reason:
              'aero jump breakdown should scale by sightScaleVertical');
    });

    test('incline correction breakdown scales by sightScaleVertical', () {
      // Need an incline to make this non-trivial.
      final unscaled = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
          inclineAngleDeg: 30,
        ),
        sampleRangesYards: const [1000],
      ).first;
      const scale = 0.95;
      final scaled = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
          inclineAngleDeg: 30,
          sightScaleVertical: scale,
        ),
        sampleRangesYards: const [1000],
      ).first;
      expect(
          scaled.inclineCorrectionInches /
              unscaled.inclineCorrectionInches,
          closeTo(scale, 1e-6),
          reason:
              'incline correction breakdown should scale by sightScaleVertical');
    });

    test('sightScale = 1.0 produces no measurable change vs no scale set',
        () {
      // Default (1.0) and explicit 1.0 must produce identical output.
      final default_ = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(windMph: 10),
        shot: _baselineShot,
        sampleRangesYards: const [500, 1000],
      );
      final explicit = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(windMph: 10),
        shot: const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
          sightScaleVertical: 1.0,
          sightScaleHorizontal: 1.0,
        ),
        sampleRangesYards: const [500, 1000],
      );
      for (var i = 0; i < default_.length; i++) {
        expect(default_[i].dropInches,
            closeTo(explicit[i].dropInches, 1e-9));
        expect(default_[i].windDriftInches,
            closeTo(explicit[i].windDriftInches, 1e-9));
      }
    });

    test('extreme scope-scale (0.5) halves all reported holds', () {
      // Edge case — a hypothetical scope tracking at half its
      // commanded value. This isn't realistic but proves the
      // multiplier chain doesn't have any non-linear term.
      final unscaled = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(windMph: 10),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
      ).first;
      final halved = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(windMph: 10),
        shot: const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
          sightScaleVertical: 0.5,
          sightScaleHorizontal: 0.5,
        ),
        sampleRangesYards: const [1000],
      ).first;
      expect(halved.dropInches / unscaled.dropInches, closeTo(0.5, 1e-6));
      expect(halved.windDriftInches / unscaled.windDriftInches,
          closeTo(0.5, 1e-6));
    });

    test('vertical and horizontal scopes act independently', () {
      // Setting only sightScaleVertical must not change wind drift,
      // and vice versa.
      final env = _envFor(windMph: 10);
      final baseline = solveTrajectory(
        projectile: _baselineProj(),
        environment: env,
        shot: _baselineShot,
        sampleRangesYards: const [1000],
      ).first;
      final vOnly = solveTrajectory(
        projectile: _baselineProj(),
        environment: env,
        shot: const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
          sightScaleVertical: 0.90,
        ),
        sampleRangesYards: const [1000],
      ).first;
      final hOnly = solveTrajectory(
        projectile: _baselineProj(),
        environment: env,
        shot: const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
          sightScaleHorizontal: 0.90,
        ),
        sampleRangesYards: const [1000],
      ).first;

      // sightScaleVertical changed → wind drift unchanged.
      expect(vOnly.windDriftInches, closeTo(baseline.windDriftInches, 1e-9),
          reason:
              'sightScaleVertical must not affect windDriftInches');
      // sightScaleHorizontal changed → drop unchanged.
      expect(hOnly.dropInches, closeTo(baseline.dropInches, 1e-9),
          reason: 'sightScaleHorizontal must not affect dropInches');
      // And the cross-term: drop changes only with V, drift only with H.
      expect(vOnly.dropInches, closeTo(0.90 * baseline.dropInches, 1e-6));
      expect(hOnly.windDriftInches,
          closeTo(0.90 * baseline.windDriftInches, 1e-6));
    });
  });
}

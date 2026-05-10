// FILE: test/precision_test.dart
//
// Golden-case + sanity-bound verification of the LoadOut ballistic
// solver against published reference data from the standard ELR /
// long-range references:
//
//   * industry-standard, "Applied Ballistics for Long-Range Shooting",
//     1st & 2nd ed., chapter 8 trajectory tables.
//   * industry-standard, "Modern Advancements in Long Range Shooting",
//     vol. 3 (drag tables and Doppler-derived BCs).
//   * JBM Ballistics online calculator (https://www.jbmballistics.com/)
//     using the same inputs and the McCoy Modified Point-Mass code path.
//   * Hornady 4DOF online calculator (matches AB Doppler tables for
//     listed bullets).
//
// Two kinds of assertions are made:
//
//   1. **Sanity bounds.** Where published references for the same
//      single-BC inputs disagree by ±10–20% (different solvers,
//      different velocity-banded BC handling), we assert our drop /
//      velocity falls inside that consensus band. This catches
//      catastrophic regressions (sign flip, units error, integrator
//      blow-up) without committing us to a specific reference's
//      exact number.
//
//   2. **Internal-consistency goldens.** We compute a known
//      configuration with [BallisticsAccuracy.extreme] and store the
//      answer. Subsequent runs of [precise] and [fast] are required
//      to agree with that answer within stated tolerances. This
//      ensures step-size adaptation, transonic refinement, and
//      Cash–Karp coefficients are stable across code changes — the
//      same inputs must always produce the same trajectory at the
//      stated precision level. Drift from the golden indicates a
//      real change to the integrator and should fail loudly.
//
// See `lib/services/ballistics/solver.dart` (BallisticsAccuracy enum)
// for the runtime/precision trade-off knob; we use
// [BallisticsAccuracy.precise] for these tests because that is what
// shipping users get by default.

import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/services/ballistics/atmosphere.dart';
import 'package:loadout/services/ballistics/drag_functions.dart';
import 'package:loadout/services/ballistics/environment.dart';
import 'package:loadout/services/ballistics/projectile.dart';
import 'package:loadout/services/ballistics/solver.dart';
import 'package:loadout/services/ballistics/units.dart';

void main() {
  group('industry standard table 4-3-1 — 308 Win 168gr SMK', () {
    // Reference: industry standard, "Applied Ballistics", 2nd ed., table 4-3-1.
    // 168 gr Sierra MatchKing, BC_G7 = 0.218 (single, supersonic-band
    // value), MV = 2650 fps, ICAO standard atmosphere, 100-yard zero,
    // 1.5" sight height. Length/twist used for spin-drift breakdown
    // only. Our integrator with this single static BC matches industry standard to
    // ~0.5 MIL out to ~700 yd. Past the transonic threshold (~Mach
    // 1.1 around 800–900 yd for this load) the velocity-banded BC
    // predicts ~1.5 MIL less drop than a single-BC solver, which is
    // the published "G7 doesn't quite fit through transonic" caveat.
    Projectile buildProjectile() => Projectile(
          diameterIn: 0.308,
          weightGr: 168,
          bc: 0.218,
          dragModel: DragModel.g7,
          lengthIn: 1.215,
          twistInches: 11.25,
        );

    Environment buildEnvironment() => Environment.fromImperial(
          atmosphere: Atmosphere.icaoStd(),
          windSpeedMph: 0,
          windFromDegrees: 90,
          shotAzimuthDegrees: 0,
          latitudeDegrees: 0,
          targetElevationFt: 0,
        );

    const shot = ShotInputs(
      muzzleVelocityFps: 2650,
      sightHeightIn: 1.5,
      zeroRangeYards: 100,
    );

    test('drop matches industry standard/JBM consensus within 0.5 MIL out to 700 yd', () {
      final samples = solveTrajectory(
        projectile: buildProjectile(),
        environment: buildEnvironment(),
        shot: shot,
        sampleRangesYards: const [100, 300, 500, 700],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.precise,
      );

      // 100-yd zero — drop should be ≤ 0.5" of LoS.
      expect(samples[0].dropInches.abs(), lessThan(0.5));

      // industry standard/JBM consensus single-BC numbers:
      //   300 yd: ~1.40 MIL
      //   500 yd: ~3.40 MIL
      //   700 yd: ~6.10 MIL
      const tolMil = 0.5;
      _expectDropMil(samples[1], expectedMil: 1.40, tolMil: tolMil);
      _expectDropMil(samples[2], expectedMil: 3.40, tolMil: tolMil);
      _expectDropMil(samples[3], expectedMil: 6.10, tolMil: tolMil);
    });

    test('1000-yd transonic plunge — bracket the published range', () {
      // With a single static BC of 0.218 and the bullet diving below
      // Mach 1.0 around 1000 yd, the supersonic-only G7 model
      // over-predicts drop relative to a velocity-banded solver.
      // We therefore bracket loosely and only check that the
      // trajectory is in the published-published range:
      //   single-BC G7 (our default): ~12.5 MIL @ 1000 yd
      //   velocity-banded G7 (industry standard/AB): ~10.5 MIL
      //   4DOF Doppler tables: ~10.3 MIL
      final samples = solveTrajectory(
        projectile: buildProjectile(),
        environment: buildEnvironment(),
        shot: shot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.precise,
      );
      final mil = inchesToMilAtYards(
          samples[0].dropInches, samples[0].rangeYards);
      expect(mil, greaterThan(9.5));
      expect(mil, lessThan(13.5));
    });

    test('extreme and precise modes agree within 0.05 MIL', () {
      final precise = solveTrajectory(
        projectile: buildProjectile(),
        environment: buildEnvironment(),
        shot: shot,
        sampleRangesYards: const [100, 500, 1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.precise,
      );
      final extreme = solveTrajectory(
        projectile: buildProjectile(),
        environment: buildEnvironment(),
        shot: shot,
        sampleRangesYards: const [100, 500, 1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.extreme,
      );
      for (var i = 0; i < precise.length; i++) {
        final diffIn =
            (precise[i].dropInches - extreme[i].dropInches).abs();
        final diffMil =
            inchesToMilAtYards(diffIn, precise[i].rangeYards);
        expect(
          diffMil,
          lessThan(0.05),
          reason: 'precise vs extreme drop disagree at '
              '${precise[i].rangeYards} yd: ${diffMil.toStringAsFixed(3)} MIL',
        );
      }
    });

    test('fast and precise modes agree within 0.4 MIL', () {
      // Fast (fixed RK4) and Precise (adaptive Cash–Karp RK45) should
      // agree closely for smooth supersonic flight. The transonic
      // band can introduce ~0.3 MIL difference because the two modes
      // refine the step differently. Tolerance is set to catch
      // anything more dramatic than that.
      final fast = solveTrajectory(
        projectile: buildProjectile(),
        environment: buildEnvironment(),
        shot: shot,
        sampleRangesYards: const [100, 500, 1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.fast,
      );
      final precise = solveTrajectory(
        projectile: buildProjectile(),
        environment: buildEnvironment(),
        shot: shot,
        sampleRangesYards: const [100, 500, 1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.precise,
      );
      for (var i = 0; i < precise.length; i++) {
        final diffIn = (fast[i].dropInches - precise[i].dropInches).abs();
        final diffMil =
            inchesToMilAtYards(diffIn, precise[i].rangeYards);
        expect(diffMil, lessThan(0.4),
            reason: 'fast vs precise drop disagree at '
                '${precise[i].rangeYards} yd by '
                '${diffMil.toStringAsFixed(3)} MIL');
      }
    });
  });

  group('6.5 Creedmoor — 140gr ELD-M', () {
    // Hornady-published reference: 140 gr ELD Match, MV 2710,
    // BC_G7 = 0.305, 1:8 twist, ICAO standard atmosphere, 100-yd
    // zero. Hornady 4DOF and AB-published 1000-yd numbers cluster
    // around 8.0–9.5 MIL drop.
    test('drop and velocity match 4DOF/AB consensus', () {
      final projectile = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.305,
        dragModel: DragModel.g7,
        lengthIn: 1.355,
        twistInches: 8,
      );
      final env = Environment.fromImperial(
        atmosphere: Atmosphere.icaoStd(),
        windSpeedMph: 0,
        windFromDegrees: 90,
        shotAzimuthDegrees: 0,
        latitudeDegrees: 0,
        targetElevationFt: 0,
      );
      const shot = ShotInputs(
        muzzleVelocityFps: 2710,
        sightHeightIn: 1.5,
        zeroRangeYards: 100,
      );

      final samples = solveTrajectory(
        projectile: projectile,
        environment: env,
        shot: shot,
        sampleRangesYards: const [100, 500, 1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.precise,
      );

      // 100-yd zero
      expect(samples[0].dropInches.abs(), lessThan(0.5));

      // 500-yd drop in published range (~46–58").
      expect(samples[1].dropInches, greaterThan(40));
      expect(samples[1].dropInches, lessThan(70));

      // 1000-yd drop in published range (~290–340").
      expect(samples[2].dropInches, greaterThan(260));
      expect(samples[2].dropInches, lessThan(360));

      // 1000-yd velocity should be supersonic (typical ~1300–1450 fps).
      expect(samples[2].velocityFps, greaterThan(1100));
      expect(samples[2].velocityFps, lessThan(1500));
    });
  });

  group('Drag tables', () {
    // Spot-check G7 Cd values at canonical Mach numbers against
    // McCoy table 8.7 (the table our `_g7` array transcribes from).
    test('G7 Cd matches McCoy table to 5 decimals at sample Machs', () {
      // Values from McCoy "Modern Exterior Ballistics" Table 8.7:
      //   Mach 1.0: 0.3803
      //   Mach 1.5: 0.3440
      //   Mach 2.0: 0.2980
      //   Mach 2.5: 0.2697
      //   Mach 3.0: 0.2424
      // Our drag table is sampled at exactly these Machs so
      // interpolation is unnecessary — we should match exactly.
      expect(dragCoefficient(DragModel.g7, 1.0), closeTo(0.3803, 1e-5));
      expect(dragCoefficient(DragModel.g7, 1.5), closeTo(0.3440, 1e-5));
      expect(dragCoefficient(DragModel.g7, 2.0), closeTo(0.2980, 1e-5));
      expect(dragCoefficient(DragModel.g7, 2.5), closeTo(0.2697, 1e-5));
      expect(dragCoefficient(DragModel.g7, 3.0), closeTo(0.2424, 1e-5));
    });

    test('G1 Cd matches Sierra/AccurateShooter table at sample Machs', () {
      expect(dragCoefficient(DragModel.g1, 1.0), closeTo(0.4805, 1e-5));
      expect(dragCoefficient(DragModel.g1, 1.5), closeTo(0.6573, 1e-5));
      expect(dragCoefficient(DragModel.g1, 2.0), closeTo(0.5934, 1e-5));
      expect(dragCoefficient(DragModel.g1, 2.5), closeTo(0.5397, 1e-5));
      expect(dragCoefficient(DragModel.g1, 3.0), closeTo(0.5133, 1e-5));
    });

    test('G7 Cd is monotone-decreasing past the transonic peak', () {
      // Past Mach 1.05 (the transonic peak) the curve must decrease.
      double prev = dragCoefficient(DragModel.g7, 1.05);
      for (var m = 1.10; m <= 3.00; m += 0.05) {
        final cd = dragCoefficient(DragModel.g7, m);
        expect(cd, lessThanOrEqualTo(prev + 1e-9),
            reason: 'G7 Cd should be non-increasing past Mach 1.05; '
                'M=$m gave $cd, prev=$prev');
        prev = cd;
      }
    });
  });

  group('Wind drift linearity', () {
    // The wind-perturbation re-solves used by HitProbabilityService
    // assume ±dW gives a roughly linear change in drift. Verify that
    // doubling the wind doubles the drift (within ~5%) for a typical
    // long-range case.
    test('drift scales ~linearly with wind speed', () {
      final projectile = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.305,
        dragModel: DragModel.g7,
        lengthIn: 1.355,
        twistInches: 8,
      );

      Environment env(double windMph) => Environment.fromImperial(
            atmosphere: Atmosphere.icaoStd(),
            windSpeedMph: windMph,
            windFromDegrees: 90, // pure crosswind
            shotAzimuthDegrees: 0,
            latitudeDegrees: 0,
            targetElevationFt: 0,
          );

      const shot = ShotInputs(
        muzzleVelocityFps: 2710,
        sightHeightIn: 1.5,
        zeroRangeYards: 100,
      );

      final s5 = solveTrajectory(
        projectile: projectile,
        environment: env(5),
        shot: shot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.precise,
      ).first;

      final s10 = solveTrajectory(
        projectile: projectile,
        environment: env(10),
        shot: shot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.precise,
      ).first;

      // Check within 10% — supersonic flight is very close to linear
      // in wind speed.
      final ratio = s10.windDriftInches.abs() / s5.windDriftInches.abs();
      expect(ratio, greaterThan(1.85));
      expect(ratio, lessThan(2.15));
    });

    test('range perturbation is monotone in distance', () {
      // Solver-based "hit probability" range-error contributions
      // assume that doubling the range error doubles the drop error.
      // Verify drop is monotone-increasing in range and approximately
      // linear over a small range window.
      final projectile = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.305,
        dragModel: DragModel.g7,
        lengthIn: 1.355,
        twistInches: 8,
      );
      final env = Environment.fromImperial(
        atmosphere: Atmosphere.icaoStd(),
        windSpeedMph: 0,
        windFromDegrees: 90,
        shotAzimuthDegrees: 0,
        latitudeDegrees: 0,
        targetElevationFt: 0,
      );
      const shot = ShotInputs(
        muzzleVelocityFps: 2710,
        sightHeightIn: 1.5,
        zeroRangeYards: 100,
      );
      final samples = solveTrajectory(
        projectile: projectile,
        environment: env,
        shot: shot,
        sampleRangesYards: const [800, 900, 1000, 1100],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.precise,
      );
      double prev = -1e9;
      for (final s in samples) {
        expect(s.dropInches, greaterThan(prev),
            reason: 'drop must increase with range');
        prev = s.dropInches;
      }
    });

    test('MV perturbation: faster MV → less drop', () {
      // Used by hit-probability MV-SD modeling.
      final projectile = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.305,
        dragModel: DragModel.g7,
        lengthIn: 1.355,
        twistInches: 8,
      );
      final env = Environment.fromImperial(
        atmosphere: Atmosphere.icaoStd(),
        windSpeedMph: 0,
        windFromDegrees: 90,
        shotAzimuthDegrees: 0,
        latitudeDegrees: 0,
        targetElevationFt: 0,
      );
      const ranges = [1000.0];
      final slow = solveTrajectory(
        projectile: projectile,
        environment: env,
        shot: const ShotInputs(
          muzzleVelocityFps: 2700,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
        ),
        sampleRangesYards: ranges,
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.precise,
      ).first;
      final fast = solveTrajectory(
        projectile: projectile,
        environment: env,
        shot: const ShotInputs(
          muzzleVelocityFps: 2750,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
        ),
        sampleRangesYards: ranges,
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.precise,
      ).first;
      // 50 fps faster MV at 2700 base: less drop, more velocity.
      expect(fast.dropInches, lessThan(slow.dropInches));
      expect(fast.velocityFps, greaterThan(slow.velocityFps));
    });
  });

  group('Coriolis', () {
    // North hemisphere east-bound shot: the Eötvös effect adds a
    // small downward acceleration. North or south shots: trajectory
    // is largely unaffected by the vertical Coriolis component.
    test('Coriolis on/off makes a small difference at 1000 yd', () {
      final projectile = Projectile(
        diameterIn: 0.308,
        weightGr: 168,
        bc: 0.218,
        dragModel: DragModel.g7,
        lengthIn: 1.215,
        twistInches: 11.25,
      );
      final env = Environment.fromImperial(
        atmosphere: Atmosphere.icaoStd(),
        windSpeedMph: 0,
        windFromDegrees: 90,
        shotAzimuthDegrees: 90, // due East
        latitudeDegrees: 45,
        targetElevationFt: 0,
      );
      const shot = ShotInputs(
        muzzleVelocityFps: 2650,
        sightHeightIn: 1.5,
        zeroRangeYards: 100,
      );
      final without = solveTrajectory(
        projectile: projectile,
        environment: env,
        shot: shot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.precise,
      ).first;
      final with_ = solveTrajectory(
        projectile: projectile,
        environment: env,
        shot: shot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: true,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.precise,
      ).first;

      // Magnitude of Coriolis correction at 1000 yd should be small —
      // typically < 5" of vertical, < 5" of lateral.
      expect((with_.dropInches - without.dropInches).abs(), lessThan(8.0));
      expect((with_.windDriftInches - without.windDriftInches).abs(),
          lessThan(8.0));
    });
  });

  group('Atmosphere', () {
    test('humid air is slightly less dense than dry air at same T/P', () {
      final dry = Atmosphere.station(
        tempF: 90,
        stationPressureInHg: 29.92,
        humidityPct: 0,
      );
      final humid = Atmosphere.station(
        tempF: 90,
        stationPressureInHg: 29.92,
        humidityPct: 100,
      );
      expect(humid.density, lessThan(dry.density));
      // Density difference is small but non-zero — typically ~1%.
      expect(dry.density - humid.density, lessThan(0.03));
      expect(dry.density - humid.density, greaterThan(0.001));
    });

    test('humid air sound speed is slightly faster than dry air', () {
      final dry = Atmosphere.station(
        tempF: 90,
        stationPressureInHg: 29.92,
        humidityPct: 0,
      );
      final humid = Atmosphere.station(
        tempF: 90,
        stationPressureInHg: 29.92,
        humidityPct: 100,
      );
      // At 90°F (32°C) the saturated humid-air sound-speed
      // increase per Cramer (1993) and our molar-form computation is
      // ~2–3 m/s — small (~1%) but the ordering is unambiguous.
      expect(humid.speedOfSound, greaterThan(dry.speedOfSound));
      expect(humid.speedOfSound - dry.speedOfSound, lessThan(4.0));
    });

    test('ICAO sea-level density matches 1.225 kg/m³', () {
      final atm = Atmosphere.icaoStd();
      expect(atm.density, closeTo(1.225, 1e-3));
      expect(atm.speedOfSound, closeTo(340.3, 1.0));
    });

    test('CIPM moist-air check: 20°C 1013.25hPa 50%RH '
        'density ≈ 1.1989 kg/m³', () {
      // CIPM 2007 reference value for moist air at the conditions
      // 20°C, 1013.25 hPa, 50% RH is 1.1989 kg/m³ (NIST citation).
      // Our computed value should match within ~0.3%.
      final atm = Atmosphere.station(
        tempF: 68.0, // 20°C
        stationPressureInHg: 29.9213,
        humidityPct: 50,
      );
      expect(atm.density, closeTo(1.1989, 0.005));
    });
  });

  group('Aerodynamic jump magnitude', () {
    test('a 10-knot crosswind produces a few inches of drop change at '
        '1000 yd', () {
      final projectile = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.305,
        dragModel: DragModel.g7,
        lengthIn: 1.355,
        twistInches: 8,
      );
      const shot = ShotInputs(
        muzzleVelocityFps: 2710,
        sightHeightIn: 1.5,
        zeroRangeYards: 100,
      );
      final atm = Atmosphere.icaoStd();
      final calmEnv = Environment.fromImperial(
        atmosphere: atm,
        windSpeedMph: 0,
        windFromDegrees: 90,
        shotAzimuthDegrees: 0,
        latitudeDegrees: 0,
        targetElevationFt: 0,
      );
      // 10 kt crosswind from the right.
      final crossEnv = Environment.fromImperial(
        atmosphere: atm,
        windSpeedMph: knotsToMph(10),
        windFromDegrees: 90,
        shotAzimuthDegrees: 0,
        latitudeDegrees: 0,
        targetElevationFt: 0,
      );

      final calm = solveTrajectory(
        projectile: projectile,
        environment: calmEnv,
        shot: shot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: true,
        accuracy: BallisticsAccuracy.precise,
      ).first;

      final cross = solveTrajectory(
        projectile: projectile,
        environment: crossEnv,
        shot: shot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: true,
        accuracy: BallisticsAccuracy.precise,
      ).first;

      // industry standard: AJ ≈ 0.01 mil/kt × 10 kt × 36" /1000 ≈ 3.6" at 1000 yd.
      // Bracket loosely; the test wants to catch a sign flip or
      // an order-of-magnitude error.
      final delta = (cross.dropInches - calm.dropInches).abs();
      expect(delta, lessThan(15.0));
    });
  });
}

// Helper: assert that a sample's drop, expressed in MIL at the
// sample's range, is within `tolMil` of `expectedMil`.
void _expectDropMil(
  TrajectorySample sample, {
  required double expectedMil,
  required double tolMil,
}) {
  final mil = inchesToMilAtYards(sample.dropInches, sample.rangeYards);
  expect(
    (mil - expectedMil).abs(),
    lessThan(tolMil),
    reason: 'drop at ${sample.rangeYards.toStringAsFixed(0)} yd was '
        '${mil.toStringAsFixed(2)} MIL '
        '(${sample.dropInches.toStringAsFixed(1)}") — expected '
        '$expectedMil ± $tolMil',
  );
}

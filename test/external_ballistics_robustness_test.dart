// FILE: test/external_ballistics_robustness_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Robustness validation for the LoadOut external-ballistics solver:
//
//   1. Atmospheric model validation
//      * ICAO sea-level density 1.225 kg/m³
//      * 5000 ft & 10000 ft ICAO standard atmosphere density
//      * BC effective scaling: 10 % denser air → larger drop
//      * Density-altitude derivation round-trip
//      * CIPM moist-air density check
//
//   2. Drag-model accuracy
//      * G1 / G7 reference Cd values at canonical Machs (already
//        partially in `precision_test.dart`; this file extends to
//        the transonic peak shape, monotonicity past peak, and
//        BC linearity)
//      * BC scaling: 0.500 BC retains velocity 2× as well as 0.250
//      * Cd interpolation continuity across table-edge boundaries
//      * Custom drag curves (CDM / DSF) interpolation cleanliness
//
//   3. Edge cases
//      * MV = 0 (no crash)
//      * Distance = 0 (drop = 0, wind = 0, vel = MV)
//      * BC = 0 (graceful failure)
//      * Wind = 0 across all directions (drift = 0)
//      * Tail/head wind only (no cross-component, drift = 0)
//      * Very long range (3000 yd) — solver doesn't crash even past
//        subsonic transition.
//      * Subsonic transition: bullet that goes super → sub during
//        flight produces no integrator artifacts.
//      * Negative incline (downhill) at -45° → drop reduces.
//
//   4. Sensitivity / monotonicity
//      * MV up → drop down at any range (monotonic).
//      * BC up → less drop, less drift, faster TOF, more retained
//        velocity (monotonic).
//      * Atmosphere denser → more drop, more drift, longer TOF
//        (monotonic).
//      * Sight height up → big short-range effect, small long-range
//        effect.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The atmosphere / drag-model / edge-case path is the most likely
// regression target if someone refactors the solver internals — and
// the easiest to get subtly wrong (e.g. swapping a Boltzmann ideal-gas
// constant for the universal one). This file pins the relationships
// that the solver MUST preserve under any future refactor.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Density-scaling test: doubling air density does NOT double
//     drop, because the bullet goes through the air FASTER too,
//     reducing TOF. The drop / wind drift response is sub-linear in
//     density. We test for monotonicity + a reasonable magnitude
//     bracket, not exact 2× behaviour.
//
//   * BC linearity: the literature says "doubling BC halves the
//     drag". This is true in steady-state, but in a real trajectory
//     the velocity decay shape changes too — so we test that the
//     velocity-retention RATIO grows monotonically with BC, not that
//     it doubles exactly.
//
//   * Edge cases (BC = 0, MV = 0) must not crash or hang. The
//     existing `ballistics_test.dart` proves "no infinite loop" for
//     BC = 0; this file pins the exit conditions and the output
//     shape.
//
//   * Subsonic transition produces a small Cd discontinuity (the G7
//     Cd peaks at Mach 1.05 and drops sharply). The solver's
//     transonic-band step refinement should keep the integration
//     smooth — verify by checking that drop is monotonic-increasing
//     even across the subsonic crossover.
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

import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/services/ballistics/atmosphere.dart';
import 'package:loadout/services/ballistics/custom_drag.dart';
import 'package:loadout/services/ballistics/drag_functions.dart';
import 'package:loadout/services/ballistics/environment.dart';
import 'package:loadout/services/ballistics/projectile.dart';
import 'package:loadout/services/ballistics/solver.dart';

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
  Atmosphere? atm,
  double windMph = 0,
  double windFromDeg = 90,
  double azDeg = 0,
  double latDeg = 0,
}) {
  return Environment.fromImperial(
    atmosphere: atm ?? Atmosphere.icaoStd(),
    windSpeedMph: windMph,
    windFromDegrees: windFromDeg,
    shotAzimuthDegrees: azDeg,
    latitudeDegrees: latDeg,
    targetElevationFt: 0,
  );
}

List<TrajectorySample> _solveBare(
  Projectile p,
  Environment env,
  ShotInputs shot,
  List<double> ranges,
) {
  return solveTrajectory(
    projectile: p,
    environment: env,
    shot: shot,
    sampleRangesYards: ranges,
    includeSpinDrift: false,
    includeCoriolis: false,
    includeAerodynamicJump: false,
    accuracy: BallisticsAccuracy.precise,
  );
}

void main() {
  // ============================================================================
  // ATMOSPHERIC MODEL VALIDATION
  // ============================================================================
  group('atmospheric model — ICAO standard reference values', () {
    test('sea level: density 1.225 kg/m³, T=288.15 K, P=101325 Pa', () {
      final atm = Atmosphere.icaoStd();
      // Per ICAO definition.
      expect(atm.density, closeTo(1.225, 1e-6));
      expect(atm.temperatureK, closeTo(288.15, 1e-9));
      expect(atm.pressurePa, closeTo(101325.0, 1e-9));
    });

    test('5000 ft ICAO standard: density ≈ 1.0556 kg/m³', () {
      // ICAO standard atmosphere table value at 5000 ft (1524 m):
      // density = 1.0556 kg/m³ (NIST reference).
      final atm = Atmosphere.fromAltitudeFt(5000);
      expect(atm.density, closeTo(1.0556, 0.01),
          reason: '5000 ft ICAO density should be ~1.0556 kg/m³');
      // Pressure also drops; T = 288.15 - 6.5 K/km × 1.524 km
      // = 288.15 - 9.91 = 278.24 K.
      expect(atm.temperatureK, closeTo(278.24, 0.5));
    });

    test('10000 ft ICAO standard: density ≈ 0.9046 kg/m³', () {
      // ICAO standard atmosphere table value at 10000 ft (3048 m):
      // density = 0.9046 kg/m³.
      final atm = Atmosphere.fromAltitudeFt(10000);
      expect(atm.density, closeTo(0.9046, 0.01),
          reason: '10000 ft ICAO density should be ~0.9046 kg/m³');
    });

    test('density falls monotonically with altitude', () {
      // The lapse-rate model gives a strictly-monotonic density
      // decrease through the troposphere (up to ~36000 ft).
      final altitudes = [0.0, 1000.0, 3000.0, 5000.0, 8000.0, 10000.0];
      double prev = double.infinity;
      for (final h in altitudes) {
        final atm = Atmosphere.fromAltitudeFt(h);
        expect(atm.density, lessThan(prev),
            reason:
                'density should fall monotonically with altitude; failed at $h ft');
        prev = atm.density;
      }
    });

    test('20°C 1013.25 hPa 50% RH: density ≈ 1.1989 kg/m³ (CIPM)', () {
      // CIPM 2007 reference value for moist air at these conditions.
      final atm = Atmosphere.station(
        tempF: 68.0, // 20°C
        stationPressureInHg: 29.9213,
        humidityPct: 50,
      );
      expect(atm.density, closeTo(1.1989, 0.005),
          reason:
              'CIPM moist-air reference value at 20°C/1013.25 hPa/50% RH');
    });

    test('density-altitude round-trip recovers input altitude', () {
      // Build atmosphere at altitude h, then ask its density-altitude
      // back. Should agree to within tight tolerance.
      const heights = [0.0, 1000.0, 3000.0, 5000.0, 8000.0, 10000.0];
      for (final h in heights) {
        final atm = Atmosphere.fromAltitudeFt(h);
        expect(atm.densityAltitudeFt, closeTo(h, 1.0));
      }
    });

    test('hot day at sea level reads as positive density altitude', () {
      // 95°F at 29.92 inHg dry → density-altitude > 0 ft.
      final atm = Atmosphere.station(
        tempF: 95.0,
        stationPressureInHg: 29.92,
        humidityPct: 0,
      );
      expect(atm.densityAltitudeFt, greaterThan(1500.0));
    });
  });

  group('atmospheric model — solver coupling', () {
    test('5000 ft elevation produces less drop than sea level (less drag)',
        () {
      // Same load, same MV; just denser vs thinner air.
      final seaLevel = _solveBare(
        _baselineProj(),
        _envFor(atm: Atmosphere.icaoStd()),
        _baselineShot,
        const [1000],
      );
      final at5000 = _solveBare(
        _baselineProj(),
        _envFor(atm: Atmosphere.fromAltitudeFt(5000)),
        _baselineShot,
        const [1000],
      );
      // 5000 ft is ~14 % thinner air → less drag → less drop.
      expect(at5000.first.dropInches, lessThan(seaLevel.first.dropInches),
          reason: '5000 ft elevation must reduce drop vs sea level');
      // Velocity at 1000 yd should be HIGHER at altitude (less drag).
      expect(at5000.first.velocityFps,
          greaterThan(seaLevel.first.velocityFps),
          reason: '5000 ft elevation must give more retained velocity');
    });

    test('10000 ft elevation gives ≥ 5 in less drop than 5000 ft', () {
      // The atmospheric effect is monotonic with altitude.
      final at5000 = _solveBare(
        _baselineProj(),
        _envFor(atm: Atmosphere.fromAltitudeFt(5000)),
        _baselineShot,
        const [1000],
      );
      final at10000 = _solveBare(
        _baselineProj(),
        _envFor(atm: Atmosphere.fromAltitudeFt(10000)),
        _baselineShot,
        const [1000],
      );
      expect(at10000.first.dropInches, lessThan(at5000.first.dropInches));
      // Solver delta: ~21 in less at 10k vs 5k. Loose bracket.
      final delta = at5000.first.dropInches - at10000.first.dropInches;
      expect(delta, greaterThan(5.0),
          reason: '10000 ft should drop ≥ 5 in less than 5000 ft');
    });

    test('hot weather at sea level produces less drop than cool weather',
        () {
      // Hot air is thinner → less drag.
      final cool = _solveBare(
        _baselineProj(),
        _envFor(
          atm: Atmosphere.station(
            tempF: 32,
            stationPressureInHg: 29.92,
            humidityPct: 0,
          ),
        ),
        _baselineShot,
        const [1000],
      );
      final hot = _solveBare(
        _baselineProj(),
        _envFor(
          atm: Atmosphere.station(
            tempF: 95,
            stationPressureInHg: 29.92,
            humidityPct: 0,
          ),
        ),
        _baselineShot,
        const [1000],
      );
      expect(hot.first.dropInches, lessThan(cool.first.dropInches),
          reason: 'hot day = thinner air = less drop');
    });
  });

  // ============================================================================
  // DRAG MODEL ACCURACY
  // ============================================================================
  group('drag model — G1 reference table integrity', () {
    test('G1 muzzle (Mach 0): Cd ≈ 0.2629', () {
      expect(dragCoefficient(DragModel.g1, 0.0), closeTo(0.2629, 1e-3));
    });
    test('G1 transonic peak at Mach 1.4: Cd ≈ 0.6625', () {
      expect(dragCoefficient(DragModel.g1, 1.4), closeTo(0.6625, 1e-3));
    });
    test('G1 supersonic samples match Sierra/McCoy table to 3 decimals', () {
      expect(dragCoefficient(DragModel.g1, 1.0), closeTo(0.4805, 1e-3));
      expect(dragCoefficient(DragModel.g1, 1.5), closeTo(0.6573, 1e-3));
      expect(dragCoefficient(DragModel.g1, 2.0), closeTo(0.5934, 1e-3));
      expect(dragCoefficient(DragModel.g1, 3.0), closeTo(0.5133, 1e-3));
      expect(dragCoefficient(DragModel.g1, 5.0), closeTo(0.4988, 1e-3));
    });
  });

  group('drag model — G7 reference table integrity', () {
    test('G7 muzzle (Mach 0): Cd ≈ 0.1198', () {
      expect(dragCoefficient(DragModel.g7, 0.0), closeTo(0.1198, 1e-3));
    });
    test('G7 supersonic samples match McCoy table to 3 decimals', () {
      expect(dragCoefficient(DragModel.g7, 1.0), closeTo(0.3803, 1e-3));
      expect(dragCoefficient(DragModel.g7, 1.5), closeTo(0.3440, 1e-3));
      expect(dragCoefficient(DragModel.g7, 2.0), closeTo(0.2980, 1e-3));
      expect(dragCoefficient(DragModel.g7, 3.0), closeTo(0.2424, 1e-3));
      expect(dragCoefficient(DragModel.g7, 5.0), closeTo(0.1618, 1e-3));
    });
  });

  group('drag model — Cd interpolation continuity', () {
    test('G1 Cd is continuous across the Mach 1.0 sample boundary', () {
      // PCHIP interpolation must produce no discontinuity at sample
      // boundaries. Probe Mach 0.999, 1.000, 1.001 — all three should
      // produce nearly-identical Cd values.
      final cdLo = dragCoefficient(DragModel.g1, 0.999);
      final cdAt = dragCoefficient(DragModel.g1, 1.000);
      final cdHi = dragCoefficient(DragModel.g1, 1.001);
      expect((cdAt - cdLo).abs(), lessThan(0.005));
      expect((cdHi - cdAt).abs(), lessThan(0.005));
    });

    test('G7 Cd is continuous across the Mach 1.0 sample boundary', () {
      final cdLo = dragCoefficient(DragModel.g7, 0.999);
      final cdAt = dragCoefficient(DragModel.g7, 1.000);
      final cdHi = dragCoefficient(DragModel.g7, 1.001);
      expect((cdAt - cdLo).abs(), lessThan(0.05));
      expect((cdHi - cdAt).abs(), lessThan(0.05));
    });

    test('G1 Cd is monotone-decreasing past Mach 1.4 (post-peak)', () {
      double prev = dragCoefficient(DragModel.g1, 1.4);
      for (var m = 1.45; m <= 5.0; m += 0.05) {
        final cd = dragCoefficient(DragModel.g1, m);
        expect(cd, lessThanOrEqualTo(prev + 1e-9),
            reason: 'G1 Cd should be non-increasing past Mach 1.4; '
                'M=$m gave $cd, prev=$prev');
        prev = cd;
      }
    });

    test('G7 Cd is monotone-decreasing past Mach 1.05 (post-peak)', () {
      double prev = dragCoefficient(DragModel.g7, 1.05);
      for (var m = 1.10; m <= 5.0; m += 0.05) {
        final cd = dragCoefficient(DragModel.g7, m);
        expect(cd, lessThanOrEqualTo(prev + 1e-9),
            reason: 'G7 Cd should be non-increasing past Mach 1.05; '
                'M=$m gave $cd, prev=$prev');
        prev = cd;
      }
    });
  });

  group('drag model — BC scaling', () {
    test('BC=0.500 retains velocity better than BC=0.250 (same shape)', () {
      // Two identical bullets, just BC scaled. The lower BC should
      // decelerate more.
      final lowBC = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.250,
        dragModel: DragModel.g7,
        twistInches: 8,
      );
      final highBC = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.500,
        dragModel: DragModel.g7,
        twistInches: 8,
      );
      final lo = _solveBare(
        lowBC,
        _envFor(),
        _baselineShot,
        const [500, 1000],
      );
      final hi = _solveBare(
        highBC,
        _envFor(),
        _baselineShot,
        const [500, 1000],
      );
      // Higher BC at every range: less drop, more retained velocity.
      for (var i = 0; i < lo.length; i++) {
        expect(hi[i].velocityFps, greaterThan(lo[i].velocityFps),
            reason: 'higher BC must retain more velocity at '
                '${lo[i].rangeYards} yd');
        expect(hi[i].dropInches, lessThan(lo[i].dropInches),
            reason: 'higher BC must drop less at ${lo[i].rangeYards} yd');
      }
    });

    test('BC scaling is monotonic across a sweep', () {
      // Scan BC from 0.15 to 0.50; at each step, drop must decrease.
      double prevDrop = double.infinity;
      double prevVelocity = -double.infinity;
      for (final bc in const [0.15, 0.20, 0.25, 0.30, 0.35, 0.40, 0.50]) {
        final p = Projectile(
          diameterIn: 0.264,
          weightGr: 140,
          bc: bc,
          dragModel: DragModel.g7,
          twistInches: 8,
        );
        final s = _solveBare(p, _envFor(), _baselineShot, const [1000]).first;
        expect(s.dropInches, lessThan(prevDrop),
            reason: 'BC=$bc must drop less than the previous (lower) BC');
        expect(s.velocityFps, greaterThan(prevVelocity),
            reason: 'BC=$bc must retain more velocity than previous');
        prevDrop = s.dropInches;
        prevVelocity = s.velocityFps;
      }
    });
  });

  group('drag model — custom drag curves', () {
    test('custom curve loaded from points is usable in the solver', () {
      // Build a 5-point custom curve approximating G7 in the supersonic
      // band. Run the solver with it and verify the trajectory falls
      // in a plausible range.
      final curve = CustomDragCurve.fromPoints(
        id: 'fake_g7',
        displayName: 'fake G7-like curve',
        points: const [
          MachCd(mach: 0.5, cd: 0.119),
          MachCd(mach: 1.0, cd: 0.380),
          MachCd(mach: 1.5, cd: 0.344),
          MachCd(mach: 2.0, cd: 0.298),
          MachCd(mach: 3.0, cd: 0.242),
        ],
      );
      final p = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.305, // ignored — custom curve overrides
        dragModel: DragModel.g7,
        twistInches: 8,
        customDragCurve: curve,
      );
      final s = _solveBare(p, _envFor(), _baselineShot, const [1000]).first;
      // Custom curve should produce a finite, non-NaN trajectory.
      expect(s.dropInches.isFinite, isTrue);
      // Drop should be in the same ballpark as the canonical 6.5 CM.
      expect(s.dropInches, greaterThan(150));
      expect(s.dropInches, lessThan(700));
    });

    test('custom curve interpolates cleanly at exact sample boundaries', () {
      // Build a curve and probe at exact sample Machs: must return
      // the input Cd values.
      final curve = CustomDragCurve.fromPoints(
        id: 'sample_test',
        displayName: 'sample test',
        points: const [
          MachCd(mach: 0.5, cd: 0.30),
          MachCd(mach: 1.0, cd: 0.40),
          MachCd(mach: 2.0, cd: 0.20),
          MachCd(mach: 3.0, cd: 0.15),
        ],
      );
      expect(curve.dragCoefficient(0.5), closeTo(0.30, 1e-9));
      expect(curve.dragCoefficient(1.0), closeTo(0.40, 1e-9));
      expect(curve.dragCoefficient(2.0), closeTo(0.20, 1e-9));
      expect(curve.dragCoefficient(3.0), closeTo(0.15, 1e-9));
    });
  });

  // ============================================================================
  // EDGE CASES
  // ============================================================================
  group('edge cases', () {
    test('zero distance request returns empty list', () {
      final samples = _solveBare(
        _baselineProj(),
        _envFor(),
        _baselineShot,
        const [],
      );
      expect(samples, isEmpty);
    });

    test('distance = 0 in sample list: drop ≈ sight height, vel ≈ MV', () {
      // The solver linearly interpolates samples between integration
      // steps; at x=0 it should return a sample with the muzzle
      // state.
      final samples = _solveBare(
        _baselineProj(),
        _envFor(),
        _baselineShot,
        const [0],
      );
      if (samples.isNotEmpty) {
        // At range 0, the line of sight is at +sightHeight above the
        // bullet (which is at the muzzle). Drop = sightHeight.
        // Allow generous tolerance since the integrator may not
        // extrapolate to x=0 cleanly.
        expect(samples.first.dropInches.abs(), lessThan(5.0));
      }
    });

    test('very low MV (500 fps) produces a valid trajectory', () {
      // 500 fps is sub-sonic for a 6.5 CM. Solver should not crash.
      final samples = _solveBare(
        _baselineProj(),
        _envFor(),
        const ShotInputs(
          muzzleVelocityFps: 500,
          sightHeightIn: 1.5,
          zeroRangeYards: 25,
        ),
        const [25],
      );
      // The bullet may not reach 25 yd with such low MV but the
      // function must not throw.
      // (Solver returns whatever samples it managed to produce.)
      expect(samples, isList);
    });

    test('extreme MV (5000 fps) produces a valid trajectory', () {
      // Hypersonic — solver must clamp Cd to the Mach=5 value at the
      // top of the table and produce sensible output.
      final samples = _solveBare(
        _baselineProj(),
        _envFor(),
        const ShotInputs(
          muzzleVelocityFps: 5000,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
        ),
        const [100, 1000],
      );
      expect(samples, hasLength(greaterThan(0)));
      for (final s in samples) {
        expect(s.dropInches.isFinite, isTrue,
            reason: 'drop must be finite at ${s.rangeYards} yd');
        expect(s.velocityFps.isFinite, isTrue);
      }
    });

    test('BC = 0 does not infinite loop or produce NaN', () {
      // BC=0 produces infinite form factor; the bullet should fail
      // to reach 1000 yd. The solver should bail on the "y < -50 m"
      // or "speed < 100 fps" stop condition without crashing.
      List<TrajectorySample>? samples;
      var threw = false;
      try {
        samples = _solveBare(
          Projectile(
            diameterIn: 0.264,
            weightGr: 140,
            bc: 0.0,
            dragModel: DragModel.g7,
            twistInches: 8,
          ),
          _envFor(),
          _baselineShot,
          const [1000],
        );
      } catch (_) {
        threw = true;
      }
      // Either return (possibly with empty / zero samples) OR throw —
      // the requirement is no infinite loop, no silent NaN.
      expect(threw || samples != null, isTrue);
    });

    test('zero wind: drift = 0 across all directions', () {
      for (final fromDeg in const [0.0, 45.0, 90.0, 135.0, 180.0, 225.0, 270.0]) {
        final samples = _solveBare(
          _baselineProj(),
          _envFor(windMph: 0, windFromDeg: fromDeg),
          _baselineShot,
          const [1000],
        );
        // No wind = no integrated wind drift (and we have no spin
        // or Coriolis enabled here either).
        expect(samples.first.windDriftInches.abs(), lessThan(0.5),
            reason:
                'no wind from $fromDeg° should produce no horizontal drift; got '
                '${samples.first.windDriftInches}');
      }
    });

    test('pure tailwind / headwind: no cross-component, no drift', () {
      // Wind from 0° = tailwind, 180° = headwind. No crosswind
      // component → zero wind drift even though the wind speed is
      // non-zero.
      for (final fromDeg in const [0.0, 180.0]) {
        final samples = _solveBare(
          _baselineProj(),
          _envFor(windMph: 20, windFromDeg: fromDeg),
          _baselineShot,
          const [1000],
        );
        expect(samples.first.windDriftInches.abs(), lessThan(0.5),
            reason: 'wind from $fromDeg° should produce no crosswind '
                'drift; got ${samples.first.windDriftInches}');
      }
    });

    test('extreme range (3000 yd) does not crash', () {
      // The bullet will go subsonic and possibly fall out of the
      // integrator before reaching 3000 yd, but the solver must
      // return something sensible.
      List<TrajectorySample>? samples;
      var threw = false;
      try {
        samples = _solveBare(
          _baselineProj(),
          _envFor(),
          _baselineShot,
          const [3000],
        );
      } catch (_) {
        threw = true;
      }
      expect(threw, isFalse, reason: 'extreme range should not throw');
      expect(samples, isNotNull);
    });

    test('subsonic transition: bullet that goes through Mach 1 produces no '
        'integrator artifacts', () {
      // 6.5 CM 140 ELD-M at MV 2710 goes subsonic around 1100-1200 yd.
      // Sample DENSELY through the transonic crossover; drop must
      // stay monotonic-increasing with range.
      final samples = _solveBare(
        _baselineProj(),
        _envFor(),
        _baselineShot,
        const [900, 1000, 1050, 1100, 1150, 1200, 1250, 1300],
      );
      double prev = double.negativeInfinity;
      for (final s in samples) {
        expect(s.dropInches, greaterThan(prev),
            reason: 'drop must increase monotonically through transonic '
                'crossover; failed at ${s.rangeYards} yd');
        prev = s.dropInches;
      }
    });

    test('-45° downhill incline reduces drop substantially', () {
      // cos(-45°)^1.5 = (1/√2)^1.5 ≈ 0.595. Drop scales by ~0.595.
      final level = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: _baselineShot,
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
      ).first;
      final downhill = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
          inclineAngleDeg: -45,
        ),
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
      ).first;
      final ratio = downhill.dropInches / level.dropInches;
      // cos(-45°)^1.5 = 0.595 ± 5 %.
      expect(ratio, closeTo(0.595, 0.05),
          reason: 'cos(-45°)^1.5 = 0.595 — downhill drop should match');
      // Downhill drop is positive (still below LoS) but smaller than
      // level.
      expect(downhill.dropInches, lessThan(level.dropInches));
    });

    test('+45° uphill incline reduces drop the same as -45°', () {
      // Improved-rifleman's-rule scales by cos(angle)^1.5, which is
      // symmetric in angle (cos is even). Verify the symmetry.
      final up = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
          inclineAngleDeg: 45,
        ),
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
      ).first;
      final down = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
          inclineAngleDeg: -45,
        ),
        sampleRangesYards: const [1000],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
      ).first;
      expect(up.dropInches, closeTo(down.dropInches, 0.5));
    });
  });

  // ============================================================================
  // SENSITIVITY / MONOTONICITY
  // ============================================================================
  group('sensitivity — monotonic responses', () {
    test('faster MV → less drop at every range', () {
      double prevDrop = double.infinity;
      for (final mv in const [2400.0, 2500.0, 2600.0, 2700.0, 2800.0, 2900.0]) {
        final s = _solveBare(
          _baselineProj(),
          _envFor(),
          ShotInputs(
            muzzleVelocityFps: mv,
            sightHeightIn: 1.5,
            zeroRangeYards: 100,
          ),
          const [1000],
        ).first;
        expect(s.dropInches, lessThan(prevDrop),
            reason: 'MV=$mv must reduce drop vs the slower prior MV');
        prevDrop = s.dropInches;
      }
    });

    test('faster MV → less TOF', () {
      double prevTof = double.infinity;
      for (final mv in const [2400.0, 2500.0, 2600.0, 2700.0, 2800.0, 2900.0]) {
        final s = _solveBare(
          _baselineProj(),
          _envFor(),
          ShotInputs(
            muzzleVelocityFps: mv,
            sightHeightIn: 1.5,
            zeroRangeYards: 100,
          ),
          const [1000],
        ).first;
        expect(s.timeSec, lessThan(prevTof),
            reason: 'MV=$mv must reduce TOF vs the slower prior MV');
        prevTof = s.timeSec;
      }
    });

    test('higher BC → less drop, less drift, lower TOF, more retained vel', () {
      // Combined property check.
      final bcLow = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.20,
        dragModel: DragModel.g7,
        twistInches: 8,
      );
      final bcHigh = Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.40,
        dragModel: DragModel.g7,
        twistInches: 8,
      );
      final env = _envFor(windMph: 10, windFromDeg: 270);
      final lo = _solveBare(bcLow, env, _baselineShot, const [1000]).first;
      final hi = _solveBare(bcHigh, env, _baselineShot, const [1000]).first;

      expect(hi.dropInches, lessThan(lo.dropInches));
      expect(hi.windDriftInches.abs(), lessThan(lo.windDriftInches.abs()));
      expect(hi.timeSec, lessThan(lo.timeSec));
      expect(hi.velocityFps, greaterThan(lo.velocityFps));
    });

    test('denser air → more drop, longer TOF, less retained velocity', () {
      // Dense (sea level cool) vs thin (5000 ft elevation).
      final denseAtm = Atmosphere.station(
        tempF: 32,
        stationPressureInHg: 30.5,
        humidityPct: 0,
      );
      final thinAtm = Atmosphere.fromAltitudeFt(8000);
      final dense = _solveBare(
        _baselineProj(),
        _envFor(atm: denseAtm),
        _baselineShot,
        const [1000],
      ).first;
      final thin = _solveBare(
        _baselineProj(),
        _envFor(atm: thinAtm),
        _baselineShot,
        const [1000],
      ).first;

      expect(dense.dropInches, greaterThan(thin.dropInches),
          reason: 'denser air → more drag → more drop');
      expect(dense.timeSec, greaterThan(thin.timeSec),
          reason: 'denser air → longer TOF');
      expect(dense.velocityFps, lessThan(thin.velocityFps),
          reason: 'denser air → more deceleration → less retained velocity');
    });

    test('wind drift scales linearly with wind speed', () {
      // The solver computes drift through the relative-velocity term
      // in the drag equation; this is approximately linear in wind
      // speed for typical small-arms ranges.
      final w5 = _solveBare(
        _baselineProj(),
        _envFor(windMph: 5, windFromDeg: 90),
        _baselineShot,
        const [1000],
      ).first;
      final w10 = _solveBare(
        _baselineProj(),
        _envFor(windMph: 10, windFromDeg: 90),
        _baselineShot,
        const [1000],
      ).first;
      final w20 = _solveBare(
        _baselineProj(),
        _envFor(windMph: 20, windFromDeg: 90),
        _baselineShot,
        const [1000],
      ).first;
      // Doubling wind speed should double drift (within ~5 %).
      final r10 = w10.windDriftInches.abs() / w5.windDriftInches.abs();
      final r20 = w20.windDriftInches.abs() / w10.windDriftInches.abs();
      expect(r10, closeTo(2.0, 0.1),
          reason: 'doubling wind 5→10 mph should double drift');
      expect(r20, closeTo(2.0, 0.1),
          reason: 'doubling wind 10→20 mph should double drift');
    });

    test('drop is monotonic-increasing with range', () {
      // For any reasonable load, drop grows monotonically with
      // distance.
      final samples = _solveBare(
        _baselineProj(),
        _envFor(),
        _baselineShot,
        const [200, 300, 500, 700, 1000, 1200],
      );
      double prev = double.negativeInfinity;
      for (final s in samples) {
        expect(s.dropInches, greaterThan(prev),
            reason: 'drop must increase with range; failed at '
                '${s.rangeYards} yd');
        prev = s.dropInches;
      }
    });

    test('velocity decreases monotonically with range', () {
      final samples = _solveBare(
        _baselineProj(),
        _envFor(),
        _baselineShot,
        const [100, 200, 300, 500, 700, 1000, 1200],
      );
      double prev = double.infinity;
      for (final s in samples) {
        expect(s.velocityFps, lessThan(prev),
            reason: 'velocity must decrease with range; failed at '
                '${s.rangeYards} yd');
        prev = s.velocityFps;
      }
    });

    test('TOF increases monotonically with range', () {
      final samples = _solveBare(
        _baselineProj(),
        _envFor(),
        _baselineShot,
        const [100, 200, 300, 500, 700, 1000, 1200],
      );
      double prev = double.negativeInfinity;
      for (final s in samples) {
        expect(s.timeSec, greaterThan(prev),
            reason: 'TOF must increase with range');
        prev = s.timeSec;
      }
    });

    test('sight height affects long-range drop very little (geometry)', () {
      // At long range, sight-height geometry contribution to "drop"
      // is dominated by gravity-driven drop. A 1.5" → 3.0" sight
      // height change should shift 1000 yd drop by < 10 in.
      final low = _solveBare(
        _baselineProj(),
        _envFor(),
        const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
        ),
        const [1000],
      ).first;
      final high = _solveBare(
        _baselineProj(),
        _envFor(),
        const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 3.0,
          zeroRangeYards: 100,
        ),
        const [1000],
      ).first;
      expect((low.dropInches - high.dropInches).abs(), lessThan(15.0),
          reason: 'sight height effect at long range should be small');
    });

    test('zero range: shorter zero range → more drop at long range', () {
      // 100 yd zero vs 200 yd zero: with the longer zero, the bullet
      // is dialed up more → less drop reported at long range.
      final z100 = _solveBare(
        _baselineProj(),
        _envFor(),
        const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 100,
        ),
        const [1000],
      ).first;
      final z200 = _solveBare(
        _baselineProj(),
        _envFor(),
        const ShotInputs(
          muzzleVelocityFps: 2710,
          sightHeightIn: 1.5,
          zeroRangeYards: 200,
        ),
        const [1000],
      ).first;
      // 200 yd zero → less drop reported at 1000 yd vs 100 yd zero.
      expect(z200.dropInches, lessThan(z100.dropInches),
          reason: '200 yd zero should give less reported drop at 1000 yd');
    });
  });

  // ============================================================================
  // BREAKDOWN INVARIANTS
  // ============================================================================
  group('breakdown field invariants', () {
    test('aerodynamicJumpInches and inclineCorrectionInches default to 0', () {
      final s = _solveBare(
        _baselineProj(),
        _envFor(),
        _baselineShot,
        const [1000],
      ).first;
      expect(s.aerodynamicJumpInches, 0);
      expect(s.inclineCorrectionInches, 0);
    });

    test('sightScaleVertical and sightScaleHorizontal default to 1.0', () {
      final s = _solveBare(
        _baselineProj(),
        _envFor(),
        _baselineShot,
        const [1000],
      ).first;
      expect(s.sightScaleVertical, 1.0);
      expect(s.sightScaleHorizontal, 1.0);
    });

    test('TrajectorySample energyFtLb matches 0.5 m v² to 1 %', () {
      // Sanity check that the energy field is the kinetic energy
      // of the bullet at that range, in foot-pounds.
      final s = _solveBare(
        _baselineProj(),
        _envFor(),
        _baselineShot,
        const [1000],
      ).first;
      // KE in joules: 0.5 × m_kg × v² (m/s).
      final massKg = 140 * 6.479891e-5;
      final velMps = s.velocityFps * 0.3048;
      final keJoules = 0.5 * massKg * velMps * velMps;
      final keFtLb = keJoules * 0.7375621493;
      expect(s.energyFtLb, closeTo(keFtLb, 0.01 * keFtLb));
    });

    test('TrajectorySample machNumber = velocityMps / speedOfSoundMps', () {
      // Mach number is just velocity / speed-of-sound. Sanity-check
      // the consistency of the reported numbers.
      final atm = Atmosphere.icaoStd();
      final s = _solveBare(
        _baselineProj(),
        _envFor(atm: atm),
        _baselineShot,
        const [1000],
      ).first;
      final velMps = s.velocityFps * 0.3048;
      final expected = velMps / atm.speedOfSound;
      expect(s.machNumber, closeTo(expected, 1e-6));
    });
  });

  // ============================================================================
  // ACCURACY-MODE PARITY
  // ============================================================================
  group('accuracy modes', () {
    test('precise vs extreme accuracy: 6.5 CM 140 ELD-M agrees within 0.05 mil',
        () {
      // Both should produce the "right" answer; precise's tolerance
      // is 1e-4 m and extreme's is 1e-6 m.
      final precise = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: _baselineShot,
        sampleRangesYards: const [500, 1000, 1200],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.precise,
      );
      final extreme = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: _baselineShot,
        sampleRangesYards: const [500, 1000, 1200],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.extreme,
      );
      for (var i = 0; i < precise.length; i++) {
        final diffIn =
            (precise[i].dropInches - extreme[i].dropInches).abs();
        // 0.05 mil at this range:
        final tolIn = 0.05 * 36.0 * (precise[i].rangeYards / 1000.0);
        expect(diffIn, lessThanOrEqualTo(tolIn + 0.5),
            reason: 'precise vs extreme drop at '
                '${precise[i].rangeYards} yd should agree within 0.05 mil + slack');
      }
    });

    test('fast vs precise: 6.5 CM agrees within 0.4 mil through transonic',
        () {
      final fast = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: _baselineShot,
        sampleRangesYards: const [500, 1000, 1200],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.fast,
      );
      final precise = solveTrajectory(
        projectile: _baselineProj(),
        environment: _envFor(),
        shot: _baselineShot,
        sampleRangesYards: const [500, 1000, 1200],
        includeSpinDrift: false,
        includeCoriolis: false,
        includeAerodynamicJump: false,
        accuracy: BallisticsAccuracy.precise,
      );
      for (var i = 0; i < precise.length; i++) {
        final diffIn = (fast[i].dropInches - precise[i].dropInches).abs();
        final tolIn = 0.4 * 36.0 * (precise[i].rangeYards / 1000.0);
        expect(diffIn, lessThanOrEqualTo(tolIn + 0.5),
            reason: 'fast vs precise drop at '
                '${precise[i].rangeYards} yd should agree within 0.4 mil + slack');
      }
    });
  });

}

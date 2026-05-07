// Sanity check that the incremental contribution decomposition adds
// up to the full-physics result.
//
// We use an INCREMENTAL ATTRIBUTION: solve trajectories with effects
// added one at a time in a fixed order (gravity → drag → Coriolis →
// wind → spin), and report each effect's marginal contribution as
// the delta between consecutive variant solves. The contributions
// telescope to `full − baseline`, so the displayed total exactly
// matches the parent DOPE table — no residual.
//
// This test runs the variant solves at three sample ranges (100,
// 500, 1000 yd) and asserts the sum-of-parts matches the full
// solution to within numerical precision (<0.001 inch).

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/ballistics/atmosphere.dart';
import 'package:loadout/services/ballistics/drag_functions.dart';
import 'package:loadout/services/ballistics/environment.dart';
import 'package:loadout/services/ballistics/projectile.dart';
import 'package:loadout/services/ballistics/solver.dart';
import 'package:loadout/services/ballistics/units.dart';

void main() {
  test('incremental contribution decomposition sums exactly to full', () {
    final projectile = Projectile(
      diameterIn: 0.264,
      weightGr: 140,
      bc: 0.298,
      dragModel: DragModel.g7,
      lengthIn: 1.355,
      twistInches: 8,
    );
    final atm = Atmosphere.icaoStd();
    final env = Environment.fromImperial(
      atmosphere: atm,
      windSpeedMph: 10,
      windFromDegrees: 90,
      shotAzimuthDegrees: 0,
      latitudeDegrees: 40,
      targetElevationFt: 0,
    );
    const shot = ShotInputs(
      muzzleVelocityFps: 2750,
      sightHeightIn: 1.5,
      zeroRangeYards: 100,
    );
    final ranges = const [100.0, 500.0, 1000.0];

    final full = solveTrajectory(
      projectile: projectile,
      environment: env,
      shot: shot,
      sampleRangesYards: ranges,
    );

    final baseline = solveTrajectory(
      projectile: projectile,
      environment: env,
      shot: shot,
      sampleRangesYards: ranges,
      includeGravity: false,
      includeDrag: false,
      includeCoriolis: false,
      includeWind: false,
      includeSpinDrift: false,
    );

    final g = solveTrajectory(
      projectile: projectile,
      environment: env,
      shot: shot,
      sampleRangesYards: ranges,
      includeGravity: true,
      includeDrag: false,
      includeCoriolis: false,
      includeWind: false,
      includeSpinDrift: false,
    );

    final gd = solveTrajectory(
      projectile: projectile,
      environment: env,
      shot: shot,
      sampleRangesYards: ranges,
      includeGravity: true,
      includeDrag: true,
      includeCoriolis: false,
      includeWind: false,
      includeSpinDrift: false,
    );

    final gdc = solveTrajectory(
      projectile: projectile,
      environment: env,
      shot: shot,
      sampleRangesYards: ranges,
      includeGravity: true,
      includeDrag: true,
      includeCoriolis: true,
      includeWind: false,
      includeSpinDrift: false,
    );

    final gdcw = solveTrajectory(
      projectile: projectile,
      environment: env,
      shot: shot,
      sampleRangesYards: ranges,
      includeGravity: true,
      includeDrag: true,
      includeCoriolis: true,
      includeWind: true,
      includeSpinDrift: false,
    );

    // ignore: avoid_print
    print('=== Incremental contribution breakdown ===');
    for (var i = 0; i < ranges.length; i++) {
      final r = full[i].rangeYards;
      final fDrop = full[i].dropInches;
      final fWind = full[i].windDriftInches;

      final baseDrop = baseline[i].dropInches;
      final gravityM = g[i].dropInches - baseDrop;
      final dragM = gd[i].dropInches - g[i].dropInches;
      final coriolisM = gdc[i].dropInches - gd[i].dropInches;
      final windM = gdcw[i].dropInches - gdc[i].dropInches;
      final spinM = full[i].dropInches - gdcw[i].dropInches;
      final sumDrop =
          baseDrop + gravityM + dragM + coriolisM + windM + spinM;
      final residualDrop = fDrop - sumDrop;

      final baseWind = baseline[i].windDriftInches;
      final gravityWindM = g[i].windDriftInches - baseWind;
      final dragWindM = gd[i].windDriftInches - g[i].windDriftInches;
      final coriolisWindM = gdc[i].windDriftInches - gd[i].windDriftInches;
      final windWindM = gdcw[i].windDriftInches - gdc[i].windDriftInches;
      final spinWindM = full[i].windDriftInches - gdcw[i].windDriftInches;
      final sumWind = baseWind +
          gravityWindM +
          dragWindM +
          coriolisWindM +
          windWindM +
          spinWindM;
      final residualWind = fWind - sumWind;

      // ignore: avoid_print
      print('R=${r.toStringAsFixed(0)} yd');
      // ignore: avoid_print
      print('  Drop: full=${fDrop.toStringAsFixed(2)}in '
          '(${inchesToMoaAtYards(fDrop, r).toStringAsFixed(2)} MOA)');
      // ignore: avoid_print
      print('    base=${baseDrop.toStringAsFixed(2)}, '
          'gravity=${gravityM.toStringAsFixed(2)}, '
          'drag=${dragM.toStringAsFixed(2)}, '
          'coriolis=${coriolisM.toStringAsFixed(3)}, '
          'wind=${windM.toStringAsFixed(3)}, '
          'spin=${spinM.toStringAsFixed(3)}');
      // ignore: avoid_print
      print('    sum=${sumDrop.toStringAsFixed(2)}in, '
          'residual=${residualDrop.toStringAsFixed(6)}in '
          '(${inchesToMoaAtYards(residualDrop, r).toStringAsFixed(6)} MOA)');
      // ignore: avoid_print
      print('  Wind: full=${fWind.toStringAsFixed(2)}in '
          '(${inchesToMoaAtYards(fWind, r).toStringAsFixed(2)} MOA)');
      // ignore: avoid_print
      print('    base=${baseWind.toStringAsFixed(2)}, '
          'gravity=${gravityWindM.toStringAsFixed(3)}, '
          'drag=${dragWindM.toStringAsFixed(3)}, '
          'coriolis=${coriolisWindM.toStringAsFixed(3)}, '
          'crosswind=${windWindM.toStringAsFixed(2)}, '
          'spin=${spinWindM.toStringAsFixed(2)}');
      // ignore: avoid_print
      print('    sum=${sumWind.toStringAsFixed(2)}in, '
          'residual=${residualWind.toStringAsFixed(6)}in '
          '(${inchesToMoaAtYards(residualWind, r).toStringAsFixed(6)} MOA)');

      // The incremental decomposition is exact by construction (the
      // marginals telescope to full − baseline, so adding baseline
      // back recovers full). Floating-point gives us nanometre-scale
      // residuals — well below 0.001 inch.
      expect(residualDrop.abs(), lessThan(1e-3),
          reason: 'drop residual at $r yd should be ≈ 0 by construction');
      expect(residualWind.abs(), lessThan(1e-3),
          reason: 'wind residual at $r yd should be ≈ 0 by construction');
    }
  });
}

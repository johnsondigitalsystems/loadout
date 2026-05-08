// FILE: test/wind_bracket_test.dart
//
// Wind-bracket regression tests. Verifies:
//   * The bracket returns three results with `low < mid < high` wind
//     holds (in absolute terms — wind drift sign tracks the wind
//     direction, but the magnitude monotonically increases with wind
//     speed).
//   * The mid result matches the standalone solver call at the same
//     mid-wind input — the bracket must not subtly perturb the
//     existing firing solution.
//   * Returns null when uncertainty is null / 0 / negative.
//   * Low-wind clamping at 0 mph works when uncertainty exceeds the
//     wind estimate.

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/ballistics/atmosphere.dart';
import 'package:loadout/services/ballistics/drag_functions.dart';
import 'package:loadout/services/ballistics/environment.dart';
import 'package:loadout/services/ballistics/projectile.dart';
import 'package:loadout/services/ballistics/solver.dart';
import 'package:loadout/services/ballistics/wind_bracket_service.dart';

void main() {
  // 6.5 Creedmoor 140gr ELD-M baseline used in ballistics_test.dart.
  Projectile makeProjectile() => Projectile(
        diameterIn: 0.264,
        weightGr: 140,
        bc: 0.298,
        dragModel: DragModel.g7,
        lengthIn: 1.355,
        twistInches: 8,
      );

  Environment makeEnvironment(double windMph) => Environment.fromImperial(
        atmosphere: Atmosphere.icaoStd(),
        windSpeedMph: windMph,
        // 9 o'clock — full crosswind from the shooter's left.
        windFromDegrees: 270,
        shotAzimuthDegrees: 0,
        latitudeDegrees: 40,
        targetElevationFt: 0,
      );

  const shot = ShotInputs(
    muzzleVelocityFps: 2710,
    sightHeightIn: 1.5,
    zeroRangeYards: 100,
  );

  test('wind bracket produces low < mid < high windage holds at 1000 yd',
      () {
    final result = computeWindBracket(
      projectile: makeProjectile(),
      environment: makeEnvironment(8),
      shot: shot,
      rangeYards: 1000,
      windEstimateMph: 8,
      windUncertaintyMph: 2,
    );
    expect(result, isNotNull);
    expect(result!.windLowMph, closeTo(6, 1e-9));
    expect(result.windMidMph, closeTo(8, 1e-9));
    expect(result.windHighMph, closeTo(10, 1e-9));

    // Wind drift magnitude should monotonically increase with wind
    // speed at a full-cross 9 o'clock wind. Sign is consistent
    // across the three (same wind direction), so we can compare
    // magnitudes directly.
    expect(result.low.windDriftInches.abs(),
        lessThan(result.mid.windDriftInches.abs()));
    expect(result.mid.windDriftInches.abs(),
        lessThan(result.high.windDriftInches.abs()));

    // For a 6.5 CM 140gr ELD-M at 1000 yd, 1 mph of crosswind is
    // ~0.09–0.11 mil of drift, so a 2 mph swing on either side of
    // the 8-mph mid should produce ~0.18–0.22 mil of envelope on
    // each side. Convert to inches at 1000 yd: 1 mil ≈ 36 in, so
    // each step should be roughly 6–8 inches.
    final lowToMid = (result.mid.windDriftInches - result.low.windDriftInches)
        .abs();
    final midToHigh =
        (result.high.windDriftInches - result.mid.windDriftInches).abs();
    expect(lowToMid, greaterThan(3));
    expect(lowToMid, lessThan(20));
    expect(midToHigh, greaterThan(3));
    expect(midToHigh, lessThan(20));
  });

  test('wind bracket mid result matches a standalone solver call at the same '
      'mid-wind input', () {
    final result = computeWindBracket(
      projectile: makeProjectile(),
      environment: makeEnvironment(8),
      shot: shot,
      rangeYards: 1000,
      windEstimateMph: 8,
      windUncertaintyMph: 2,
    );
    expect(result, isNotNull);

    final standalone = solveTrajectory(
      projectile: makeProjectile(),
      environment: makeEnvironment(8),
      shot: shot,
      sampleRangesYards: const [1000],
    );
    expect(standalone.length, 1);

    // The bracket mid solve and the standalone solve should produce
    // the same firing solution to floating-point tolerance — the
    // bracket service should not perturb the existing solver result.
    expect(result!.mid.dropInches,
        closeTo(standalone.first.dropInches, 1e-6));
    expect(result.mid.windDriftInches,
        closeTo(standalone.first.windDriftInches, 1e-6));
    expect(result.mid.velocityFps,
        closeTo(standalone.first.velocityFps, 1e-6));
  });

  test('wind bracket returns null when uncertainty is null or non-positive',
      () {
    final p = makeProjectile();
    final env = makeEnvironment(8);
    expect(
        computeWindBracket(
          projectile: p,
          environment: env,
          shot: shot,
          rangeYards: 1000,
          windEstimateMph: 8,
          windUncertaintyMph: null,
        ),
        isNull);
    expect(
        computeWindBracket(
          projectile: p,
          environment: env,
          shot: shot,
          rangeYards: 1000,
          windEstimateMph: 8,
          windUncertaintyMph: 0,
        ),
        isNull);
    expect(
        computeWindBracket(
          projectile: p,
          environment: env,
          shot: shot,
          rangeYards: 1000,
          windEstimateMph: 8,
          windUncertaintyMph: -1,
        ),
        isNull);
  });

  test('wind bracket clamps the low-wind side to 0 mph when uncertainty '
      'exceeds the estimate', () {
    final result = computeWindBracket(
      projectile: makeProjectile(),
      environment: makeEnvironment(2),
      shot: shot,
      rangeYards: 500,
      windEstimateMph: 2,
      windUncertaintyMph: 5,
    );
    expect(result, isNotNull);
    // mid - unc = -3, clamped to 0.
    expect(result!.windLowMph, closeTo(0, 1e-9));
    expect(result.windMidMph, closeTo(2, 1e-9));
    expect(result.windHighMph, closeTo(7, 1e-9));

    // The low-wind solve uses the same Environment.windFromDegrees /
    // shot azimuth as mid and high — only the wind speed varies — so
    // the high-wind drift contribution should always exceed the
    // low-wind drift contribution at the same range. The crosswind
    // term scales linearly with wind speed once spin drift is
    // separated out, so mid→high drift gap should be larger than
    // low→mid (mid is only 2 mph above low, but high is 5 mph above
    // mid).
    final lowToMid = (result.mid.windDriftInches -
            result.low.windDriftInches)
        .abs();
    final midToHigh = (result.high.windDriftInches -
            result.mid.windDriftInches)
        .abs();
    expect(midToHigh, greaterThan(lowToMid),
        reason:
            'high-wind step (mid → high = +5 mph) should produce a larger '
            'drift change than the low-wind step (low → mid = +2 mph).');
  });
}

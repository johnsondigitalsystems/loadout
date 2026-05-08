// FILE: test/bc_truing_test.dart
//
// Coverage for the BC truing service. The pattern: pick a "true" BC, run
// the solver to generate a *synthetic* observation, then ask the truing
// routine to back-solve. The trued BC must come back close to the true
// BC and the predicted drop under the trued BC must match the
// observation within tolerance.

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/ballistics/atmosphere.dart';
import 'package:loadout/services/ballistics/drag_functions.dart';
import 'package:loadout/services/ballistics/environment.dart';
import 'package:loadout/services/ballistics/projectile.dart';
import 'package:loadout/services/ballistics/solver.dart';
import 'package:loadout/services/ballistics/units.dart';
import 'package:loadout/services/bc_truing_service.dart';

const _service = BcTruingService();

Projectile _baselineProjectile({double bc = 0.298}) => Projectile(
      diameterIn: 0.264,
      weightGr: 140,
      bc: bc,
      dragModel: DragModel.g7,
      lengthIn: 1.355,
      twistInches: 8,
    );

Environment _baselineEnvironment() => Environment.fromImperial(
      atmosphere: Atmosphere.icaoStd(),
      windSpeedMph: 0,
      windFromDegrees: 90,
      shotAzimuthDegrees: 0,
      latitudeDegrees: 40,
      targetElevationFt: 0,
    );

const ShotInputs _baselineShot = ShotInputs(
  muzzleVelocityFps: 2710,
  sightHeightIn: 1.5,
  zeroRangeYards: 100,
);

/// Helper: predicts drop in mil at a given range under a given BC, using
/// the same solver settings the truing service uses.
double _predictDropMil({
  required double bc,
  required double rangeYd,
}) {
  final samples = solveTrajectory(
    projectile: _baselineProjectile(bc: bc),
    environment: _baselineEnvironment(),
    shot: _baselineShot,
    sampleRangesYards: [rangeYd],
    includeSpinDrift: false,
    includeCoriolis: false,
    includeAerodynamicJump: false,
    accuracy: BallisticsAccuracy.fast,
  );
  if (samples.isEmpty) return 0;
  return inchesToMilAtYards(samples.first.dropInches, samples.first.rangeYards);
}

void main() {
  group('BC truing — single observation', () {
    test('back-solves the synthetic true BC within 1%', () {
      // Step 1: pick a "true" BC slightly different from the catalog.
      const trueBc = 0.314;
      const catalogBc = 0.298;

      // Step 2: generate the synthetic observation by running the solver
      // at the true BC and pulling the drop at 1000 yd.
      final observedDropMil = _predictDropMil(bc: trueBc, rangeYd: 1000);

      // Step 3: back-solve from the catalog BC.
      final result = _service.trueBcFromSingleObservation(
        nominalBc: catalogBc,
        observation: BcTruingObservation(
          rangeYd: 1000,
          observedDropMil: observedDropMil,
        ),
        baselineProjectile: _baselineProjectile(bc: catalogBc),
        environment: _baselineEnvironment(),
        shot: _baselineShot,
      );

      expect(result.truedBc, closeTo(trueBc, 0.005),
          reason: 'trued BC should recover the synthetic true BC '
              'within ~0.005 (1.5%)');
      // Residual under the trued BC should be effectively zero.
      expect(result.rmsResidualMil, lessThan(0.05),
          reason: 'a single-observation truing should reproduce '
              'the observation within 0.05 mil');
    });

    test('observed-deeper-than-predicted → trued BC < nominal', () {
      // The shooter saw 0.3 mil more drop than the catalog predicted at
      // 1000 yd. The bullet is "bleeding more" → its real BC is lower
      // than catalog.
      const catalogBc = 0.298;
      final catalogDropMil = _predictDropMil(bc: catalogBc, rangeYd: 1000);

      final result = _service.trueBcFromSingleObservation(
        nominalBc: catalogBc,
        observation: BcTruingObservation(
          rangeYd: 1000,
          observedDropMil: catalogDropMil + 0.3,
        ),
        baselineProjectile: _baselineProjectile(bc: catalogBc),
        environment: _baselineEnvironment(),
        shot: _baselineShot,
      );
      expect(result.truedBc, lessThan(catalogBc),
          reason: 'an observation with MORE drop than the catalog '
              'predicts should reduce the BC');
      // Magnitude check: 0.3 mil / 36 in/mil at 1000 yd ≈ 0.83 inches
      // extra drop. Empirically this corresponds to ~3-8% BC reduction.
      final reductionPct = (catalogBc - result.truedBc) / catalogBc;
      expect(reductionPct, inInclusiveRange(0.02, 0.15),
          reason: 'a 0.3 mil at 1000 yd extra drop reduces BC by 2-15%');
    });

    test('observed-shallower-than-predicted → trued BC > nominal', () {
      const catalogBc = 0.298;
      final catalogDropMil = _predictDropMil(bc: catalogBc, rangeYd: 1000);

      final result = _service.trueBcFromSingleObservation(
        nominalBc: catalogBc,
        observation: BcTruingObservation(
          rangeYd: 1000,
          observedDropMil: catalogDropMil - 0.3,
        ),
        baselineProjectile: _baselineProjectile(bc: catalogBc),
        environment: _baselineEnvironment(),
        shot: _baselineShot,
      );
      expect(result.truedBc, greaterThan(catalogBc));
    });
  });

  group('BC truing — multi-observation', () {
    test('synthetic 3-distance dope back-solves to the true BC', () {
      const trueBc = 0.310;
      const catalogBc = 0.298;
      final observations = <BcTruingObservation>[];
      for (final r in [600.0, 800.0, 1000.0]) {
        final drop = _predictDropMil(bc: trueBc, rangeYd: r);
        observations.add(
          BcTruingObservation(rangeYd: r, observedDropMil: drop),
        );
      }

      final result = _service.trueBcFromObservations(
        nominalBc: catalogBc,
        observations: observations,
        baselineProjectile: _baselineProjectile(bc: catalogBc),
        environment: _baselineEnvironment(),
        shot: _baselineShot,
      );

      expect(result.truedBc, closeTo(trueBc, 0.005),
          reason: 'multi-observation truing should match true BC '
              'within ~0.005 when the synthetic dope is consistent');
      expect(result.rmsResidualMil, lessThan(0.05),
          reason: 'consistent synthetic dope should fit the trued BC '
              'with sub-0.05 mil RMS residual');
      expect(result.observations.length, 3);
      expect(result.residualsMil.length, 3);
      expect(result.maxObservationRangeYd, 1000);
    });

    test('inconsistent observations produce non-zero RMS', () {
      const catalogBc = 0.298;
      // Construct three observations where 600 and 800 are consistent
      // with one BC but 1000 is consistent with a different one. The
      // multi-observation truing has to compromise; RMS must reflect
      // that.
      final obs600 = _predictDropMil(bc: 0.305, rangeYd: 600);
      final obs800 = _predictDropMil(bc: 0.305, rangeYd: 800);
      final obs1000 = _predictDropMil(bc: 0.290, rangeYd: 1000);

      final result = _service.trueBcFromObservations(
        nominalBc: catalogBc,
        observations: [
          BcTruingObservation(rangeYd: 600, observedDropMil: obs600),
          BcTruingObservation(rangeYd: 800, observedDropMil: obs800),
          BcTruingObservation(rangeYd: 1000, observedDropMil: obs1000),
        ],
        baselineProjectile: _baselineProjectile(bc: catalogBc),
        environment: _baselineEnvironment(),
        shot: _baselineShot,
      );

      // The trued BC will land somewhere between 0.290 and 0.305.
      expect(result.truedBc, greaterThan(0.288));
      expect(result.truedBc, lessThan(0.310));
      // RMS should be measurably non-zero — the three observations
      // can't all be reproduced exactly by a single BC.
      expect(result.rmsResidualMil, greaterThan(0.01));
    });
  });

  group('BC truing — degenerate inputs', () {
    test('empty observations returns nominalBc with zero residual', () {
      final result = _service.trueBcFromObservations(
        nominalBc: 0.298,
        observations: const [],
        baselineProjectile: _baselineProjectile(),
        environment: _baselineEnvironment(),
        shot: _baselineShot,
      );
      expect(result.truedBc, 0.298);
      expect(result.rmsResidualMil, 0);
      expect(result.observations, isEmpty);
    });
  });

  group('BC truing — JSON round trip', () {
    test('observations serialize and deserialize losslessly', () {
      final result = _service.trueBcFromObservations(
        nominalBc: 0.298,
        observations: const [
          BcTruingObservation(
            rangeYd: 600,
            observedDropMil: 2.4,
            predictedDropMil: 2.3,
            notes: 'fouler',
          ),
          BcTruingObservation(rangeYd: 1000, observedDropMil: 6.8),
        ],
        baselineProjectile: _baselineProjectile(),
        environment: _baselineEnvironment(),
        shot: _baselineShot,
      );
      final json = result.observationJsonString();
      final restored = BcTruingResult.observationsFromJson(json);
      expect(restored.length, 2);
      expect(restored[0].rangeYd, 600);
      expect(restored[0].observedDropMil, 2.4);
      expect(restored[0].predictedDropMil, 2.3);
      expect(restored[0].notes, 'fouler');
      expect(restored[1].rangeYd, 1000);
      expect(restored[1].notes, isNull);
    });
  });

  group('BC truing — apply-and-verify roundtrip', () {
    test('feeding the trued BC back into the solver reproduces the dope', () {
      const trueBc = 0.320;
      const catalogBc = 0.298;
      final observations = [
        for (final r in [500.0, 700.0, 900.0])
          BcTruingObservation(
            rangeYd: r,
            observedDropMil: _predictDropMil(bc: trueBc, rangeYd: r),
          ),
      ];

      final result = _service.trueBcFromObservations(
        nominalBc: catalogBc,
        observations: observations,
        baselineProjectile: _baselineProjectile(bc: catalogBc),
        environment: _baselineEnvironment(),
        shot: _baselineShot,
      );

      // Apply trued BC: each observation should now match its predicted
      // drop within ~0.05 mil.
      for (var i = 0; i < observations.length; i++) {
        final predicted =
            _predictDropMil(bc: result.truedBc, rangeYd: observations[i].rangeYd);
        expect(predicted, closeTo(observations[i].observedDropMil, 0.05),
            reason: 'after truing, the predicted drop at '
                '${observations[i].rangeYd} yd should match '
                'the observation within 0.05 mil');
      }
    });
  });
}

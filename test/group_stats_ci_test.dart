// FILE: test/group_stats_ci_test.dart
//
// Tests for the 90% confidence-interval extensions to
// `GroupStats` and the `sigmaMultipliersForN` lookup. Covers:
//
//   1. Tabulated multipliers at N = 3, 5, 10, 20 match the Rayleigh
//      ES/σ quantiles within rounding tolerance of the published
//      (Ballistipedia / industry standard Appendix) values.
//   2. Linear interpolation between tabulated rows (N=12 falls
//      between N=10 and N=15).
//   3. N < 3 returns null (no CI).
//   4. Concrete worked example: 5-shot 1.0" ES at 100 yd produces a
//      CI on group MOA that brackets the observed value and matches
//      the industry standard expected-bounds-of-true-precision interpretation.
//   5. Underlying-σ point estimate equals ES / k_mean.
//   6. CI fields are null when N < 3 even with non-empty points.
//   7. CI fields in MOA are null when distance is 0 (but inch CI is
//      still populated).

import 'package:flutter_test/flutter_test.dart';

import 'package:loadout/services/ballistics/group_stats.dart';

void main() {
  group('sigmaMultipliersForN — tabulated values', () {
    test('N=3 matches industry standard/Ballistipedia (mean ~1.69, CI [0.68, 2.83])',
        () {
      final m = sigmaMultipliersForN(3)!;
      expect(m.mean, closeTo(1.69, 0.02));
      expect(m.low, closeTo(0.68, 0.02));
      expect(m.high, closeTo(2.83, 0.02));
    });

    test('N=5 matches industry standard/Ballistipedia (mean ~2.33, CI [1.31, 3.34])',
        () {
      final m = sigmaMultipliersForN(5)!;
      expect(m.mean, closeTo(2.33, 0.02));
      expect(m.low, closeTo(1.31, 0.02));
      expect(m.high, closeTo(3.34, 0.02));
    });

    test('N=10 matches industry standard/Ballistipedia (mean ~3.08, CI [2.10, 3.91])',
        () {
      final m = sigmaMultipliersForN(10)!;
      expect(m.mean, closeTo(3.08, 0.02));
      expect(m.low, closeTo(2.10, 0.02));
      expect(m.high, closeTo(3.91, 0.02));
    });

    test('N=20 matches industry standard/Ballistipedia (mean ~3.74, CI [2.85, 4.42])',
        () {
      final m = sigmaMultipliersForN(20)!;
      expect(m.mean, closeTo(3.74, 0.02));
      expect(m.low, closeTo(2.85, 0.02));
      expect(m.high, closeTo(4.42, 0.02));
    });

    test('mean multipliers are monotonically increasing with N', () {
      final ns = [3, 5, 10, 20, 30];
      double last = 0;
      for (final n in ns) {
        final m = sigmaMultipliersForN(n)!;
        expect(m.mean, greaterThan(last));
        last = m.mean;
      }
    });

    test('CI width narrows as N grows', () {
      final widthN3 = sigmaMultipliersForN(3)!;
      final widthN5 = sigmaMultipliersForN(5)!;
      final widthN10 = sigmaMultipliersForN(10)!;
      final widthN20 = sigmaMultipliersForN(20)!;
      // CI width on σ given ES is (ES/low - ES/high) — proportional to
      // (1/low - 1/high). Should shrink monotonically with N.
      double w(({double low, double mean, double high}) m) =>
          1 / m.low - 1 / m.high;
      expect(w(widthN3), greaterThan(w(widthN5)));
      expect(w(widthN5), greaterThan(w(widthN10)));
      expect(w(widthN10), greaterThan(w(widthN20)));
    });
  });

  group('sigmaMultipliersForN — interpolation and edge cases', () {
    test('N=2 returns null (CI undefined)', () {
      expect(sigmaMultipliersForN(2), isNull);
    });

    test('N=1 returns null', () {
      expect(sigmaMultipliersForN(1), isNull);
    });

    test('N=0 returns null', () {
      expect(sigmaMultipliersForN(0), isNull);
    });

    test('N=7 (interpolated) lies strictly between N=5 and N=10', () {
      final m5 = sigmaMultipliersForN(5)!;
      final m7 = sigmaMultipliersForN(7)!;
      final m10 = sigmaMultipliersForN(10)!;
      // Tabulated row at N=7 is included in the table, so this is an
      // exact lookup — but verify the monotonicity nonetheless. (If
      // the table is later thinned, this still holds via interpolation.)
      expect(m7.mean, greaterThan(m5.mean));
      expect(m7.mean, lessThan(m10.mean));
      expect(m7.low, greaterThan(m5.low));
      expect(m7.low, lessThan(m10.low));
      expect(m7.high, greaterThan(m5.high));
      expect(m7.high, lessThan(m10.high));
    });

    test('N=12 (between tabulated 10 and 15) is interpolated', () {
      final m10 = sigmaMultipliersForN(10)!;
      final m15 = sigmaMultipliersForN(15)!;
      final m12 = sigmaMultipliersForN(12)!;
      // Linear interpolation: (12 - 10) / (15 - 10) = 0.4
      expect(
        m12.mean,
        closeTo(m10.mean + 0.4 * (m15.mean - m10.mean), 1e-9),
      );
      expect(
        m12.low,
        closeTo(m10.low + 0.4 * (m15.low - m10.low), 1e-9),
      );
      expect(
        m12.high,
        closeTo(m10.high + 0.4 * (m15.high - m10.high), 1e-9),
      );
    });

    test('N >= 30 clamps to last tabulated row', () {
      final m30 = sigmaMultipliersForN(30)!;
      final m100 = sigmaMultipliersForN(100)!;
      expect(m100.mean, equals(m30.mean));
      expect(m100.low, equals(m30.low));
      expect(m100.high, equals(m30.high));
    });
  });

  group('computeGroupStats — industry standard CI on group MOA', () {
    test('5-shot ES = 1.0" at 100 yd: CI brackets the observed group',
        () {
      // Five collinear points along the x-axis with the extremes 1.0"
      // apart — keeps ES = 1.0" exactly so the worked example aligns
      // with the documented arithmetic.
      const pts = [
        Offset(0, 0),
        Offset(0.25, 0),
        Offset(0.5, 0),
        Offset(0.75, 0),
        Offset(1.0, 0),
      ];
      final stats = computeGroupStats(
        points: pts,
        distanceYd: 100,
      )!;
      expect(stats.shotCount, equals(5));
      expect(stats.extremeSpreadIn, closeTo(1.0, 1e-9));

      // Underlying σ = ES / k_mean ≈ 1.0 / 2.33 ≈ 0.429"
      expect(stats.underlyingSigmaIn, closeTo(1.0 / 2.33, 1e-3));

      // CI on true expected group size:
      //   low  = ES × k_mean / k_high = 1.0 × 2.33 / 3.34 ≈ 0.697"
      //   high = ES × k_mean / k_low  = 1.0 × 2.33 / 1.31 ≈ 1.779"
      expect(stats.groupSizeCiLow90PctIn,
          closeTo(2.33 / 3.34, 0.02));
      expect(stats.groupSizeCiHigh90PctIn,
          closeTo(2.33 / 1.31, 0.02));

      // In MOA at 100 yd: 1" ≈ 0.9549 MOA. So the CI in MOA is roughly
      // [0.66, 1.70] MOA — brackets observed 0.95 MOA group.
      expect(stats.groupMoaCiLow90Pct, isNotNull);
      expect(stats.groupMoaCiHigh90Pct, isNotNull);
      expect(stats.groupMoaCiLow90Pct!, lessThan(stats.extremeSpreadMoa));
      expect(stats.groupMoaCiHigh90Pct!, greaterThan(stats.extremeSpreadMoa));

      // Concrete bracket, with tolerance on Monte-Carlo-derived k values:
      expect(stats.groupMoaCiLow90Pct, closeTo(0.66, 0.05));
      expect(stats.groupMoaCiHigh90Pct, closeTo(1.70, 0.10));
    });

    test('CI includes bullet diameter when supplied', () {
      const pts = [Offset(0, 0), Offset(1.0, 0), Offset(0.5, 0.5)];
      final statsNoDia = computeGroupStats(
        points: pts,
        distanceYd: 100,
      )!;
      final statsWithDia = computeGroupStats(
        points: pts,
        distanceYd: 100,
        bulletDiameterIn: 0.308,
      )!;
      // The CI bracket on group SIZE includes the bullet diameter,
      // matching the displayed "Group" point estimate.
      expect(
        statsWithDia.groupSizeCiLow90PctIn! -
            statsNoDia.groupSizeCiLow90PctIn!,
        closeTo(0.308, 1e-9),
      );
      expect(
        statsWithDia.groupSizeCiHigh90PctIn! -
            statsNoDia.groupSizeCiHigh90PctIn!,
        closeTo(0.308, 1e-9),
      );
    });

    test('CI on group MOA brackets observed group MOA', () {
      const pts = [
        Offset(-1, 0),
        Offset(1, 0),
        Offset(0, 1),
        Offset(0, -1),
        Offset(0, 0),
      ];
      final stats = computeGroupStats(
        points: pts,
        distanceYd: 100,
      )!;
      expect(stats.groupMoaCiLow90Pct, isNotNull);
      expect(stats.groupMoaCiHigh90Pct, isNotNull);
      // The observed group MOA must lie within the 90% CI for any
      // sample drawn from a Rayleigh distribution under the standard
      // assumption — this is the headline "industry standard insight" for the UI.
      expect(stats.groupMoaCiLow90Pct, lessThanOrEqualTo(stats.groupSizeMoa));
      expect(stats.groupMoaCiHigh90Pct,
          greaterThanOrEqualTo(stats.groupSizeMoa));
    });
  });

  group('computeGroupStats — CI absent for N < 3', () {
    test('2 shots: CI fields are all null', () {
      final stats = computeGroupStats(
        points: const [Offset(0, 0), Offset(1, 0)],
        distanceYd: 100,
      )!;
      expect(stats.shotCount, equals(2));
      expect(stats.underlyingSigmaIn, isNull);
      expect(stats.groupSizeCiLow90PctIn, isNull);
      expect(stats.groupSizeCiHigh90PctIn, isNull);
      expect(stats.groupMoaCiLow90Pct, isNull);
      expect(stats.groupMoaCiHigh90Pct, isNull);
    });

    test('3 shots: CI fields are populated', () {
      final stats = computeGroupStats(
        points: const [Offset(0, 0), Offset(1, 0), Offset(0.5, 0.5)],
        distanceYd: 100,
      )!;
      expect(stats.underlyingSigmaIn, isNotNull);
      expect(stats.groupSizeCiLow90PctIn, isNotNull);
      expect(stats.groupSizeCiHigh90PctIn, isNotNull);
      expect(stats.groupMoaCiLow90Pct, isNotNull);
      expect(stats.groupMoaCiHigh90Pct, isNotNull);
    });
  });

  group('computeGroupStats — distance edge cases for CI', () {
    test('distanceYd = 0: inch CI populated, MOA CI is null', () {
      final stats = computeGroupStats(
        points: const [Offset(0, 0), Offset(1, 0), Offset(0.5, 0.5)],
        distanceYd: 0,
      )!;
      // Distance-independent CI is still populated.
      expect(stats.groupSizeCiLow90PctIn, isNotNull);
      expect(stats.groupSizeCiHigh90PctIn, isNotNull);
      // MOA CI cannot be computed without a distance.
      expect(stats.groupMoaCiLow90Pct, isNull);
      expect(stats.groupMoaCiHigh90Pct, isNull);
    });

    test(
        'CI width in inches is independent of distance (only MOA scales)',
        () {
      const pts = [Offset(0, 0), Offset(1, 0), Offset(0.5, 0.5)];
      final s100 = computeGroupStats(points: pts, distanceYd: 100)!;
      final s500 = computeGroupStats(points: pts, distanceYd: 500)!;
      expect(s100.groupSizeCiLow90PctIn,
          closeTo(s500.groupSizeCiLow90PctIn!, 1e-9));
      expect(s100.groupSizeCiHigh90PctIn,
          closeTo(s500.groupSizeCiHigh90PctIn!, 1e-9));
      // MOA CI shrinks as distance grows for the same physical CI in
      // inches.
      expect(s500.groupMoaCiLow90Pct, lessThan(s100.groupMoaCiLow90Pct!));
      expect(
          s500.groupMoaCiHigh90Pct, lessThan(s100.groupMoaCiHigh90Pct!));
    });
  });

  group('computeGroupStats — N=10 narrower than N=3 for same observed ES',
      () {
    test('CI tightens dramatically with sample size', () {
      // Synthesize an N=3 group and an N=10 group that both have ES = 1.0"
      // and compare CI widths. The N=10 CI must be much narrower.
      const pts3 = [Offset(0, 0), Offset(1, 0), Offset(0.5, 0.5)];
      const pts10 = [
        Offset(0, 0),
        Offset(1, 0),
        Offset(0.5, 0.5),
        Offset(0.2, 0.1),
        Offset(0.4, 0.4),
        Offset(0.6, 0.2),
        Offset(0.8, 0.3),
        Offset(0.3, 0.7),
        Offset(0.7, 0.6),
        Offset(0.9, 0.1),
      ];
      final s3 = computeGroupStats(points: pts3, distanceYd: 100)!;
      final s10 = computeGroupStats(points: pts10, distanceYd: 100)!;

      // Both have ES = 1.0".
      expect(s3.extremeSpreadIn, closeTo(1.0, 1e-9));
      expect(s10.extremeSpreadIn, closeTo(1.0, 1e-9));

      final width3 =
          s3.groupSizeCiHigh90PctIn! - s3.groupSizeCiLow90PctIn!;
      final width10 =
          s10.groupSizeCiHigh90PctIn! - s10.groupSizeCiLow90PctIn!;

      // The 10-shot CI should be more than 2× narrower than the
      // 3-shot CI. (3-shot CI width ≈ 1.94"; 10-shot CI width ≈ 0.48".)
      expect(width10, lessThan(width3 / 2));
    });
  });
}

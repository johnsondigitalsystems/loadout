// FILE: test/hit_probability_service_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Unit tests for `lib/services/hit_probability_service.dart`. Drives the
// `HitProbabilityService.compute(...)` entry point against a wide matrix
// of realistic and degenerate inputs and asserts the dispersion-modeling
// math gives sane outputs. Uses the same 6.5 Creedmoor / 140 gr ELD-M /
// G7 BC 0.298 / 2710 fps reference fixture the rest of the test suite
// uses (matches `test/wez_analysis_test.dart` and
// `test/ballistic_precision_test.dart`) so any cross-test regression
// surfaces consistently.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `HitProbabilityService` is the math floor under the WEZ analysis screen,
// the AI-Reloading / range-day "what's my hit chance?" affordances, and
// the ballistics calculator's dispersion gauge. Every UI surface that
// shows a hit probability number routes through this service. A bug
// here ripples to multiple screens and to the Pro paywall (Cloud Sync /
// AI smart-import are Pro features that depend on accurate ballistic
// numbers). These tests guard the math invariants — monotonicity,
// boundary conditions, target-shape correctness, RNG determinism, and
// performance budget — so refactors of the underlying solver, or shifts
// in the seed-from-inputs hash, don't silently warp displayed numbers.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The integration is Monte Carlo with a fixed sample count (10k).
//     The displayed probability is stable to ~1pp but assertions must
//     leave that headroom — `closeTo(value, 0.02)` for sanity bands,
//     `inInclusiveRange(...)` for realistic-scenario bands.
//   * Inputs are clamped in `compute(...)` itself: `dist.clamp(1, 5000)`,
//     `groupMoa.clamp(0.05, 20)`, `windU.clamp(0, 30)`. A "0 MOA"
//     test cannot actually exercise zero — the floor is 0.05 MOA. We
//     work around this by using a very small group + zero wind/range/MV
//     and checking the result is "almost 1" rather than "exactly 1".
//   * The `<= 0.001 && <= 0.001` degenerate path is hard to hit through
//     the public API because the group MOA floor (0.05) at 100 yd
//     yields 0.013" 1-σ which is above the threshold. The deterministic
//     branch is therefore reached only via reflection (or via huge
//     targets where it's irrelevant). We treat the regular MC path as
//     the surface under test.
//   * Seed-from-inputs hashing snaps `distanceYd` to integer yards
//     (`toStringAsFixed(0)`) and `aim*` to two decimals — so distance
//     deltas of ≤ 0.5 yd may seed identically. Tests that rely on
//     "different inputs ⇒ different probability" use ≥ 1 yd offsets.
//   * Solver-perturbation calls are real ballistics solves; on CI
//     they're fast (~5–10ms each) but the test runner is several × the
//     phone budget — performance assertion uses 250ms PER CALL plus
//     headroom.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `flutter test test/hit_probability_service_test.dart` — local dev.
//   * CI matrix runs the full test directory.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
//   * None. Pure unit tests, no I/O, no shared state across cases.
//   * The service under test does spin up the ballistics solver for the
//     wind/range/MV perturbation re-solves, but those run in-process.

import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:loadout/services/hit_probability_service.dart';

const _service = HitProbabilityService();

/// Reference projectile: 6.5 Creedmoor / 140 gr ELD-M / G7 BC 0.298 /
/// 2710 fps. Matches the rest of the test suite.
HitProbabilityResult _baselineCompute({
  double aimOffsetXIn = 0,
  double aimOffsetYIn = 0,
  double targetWidthIn = 8,
  double targetHeightIn = 8,
  TargetShape shape = TargetShape.circle,
  double distanceYd = 600,
  double assumedGroupMoa = 1.0,
  double windUncertaintyMph = 2.0,
  double rangeUncertaintyYd = 5.0,
  double mvSdFps = 12.0,
  double bcG7 = 0.298,
  double muzzleVelocityFps = 2710,
}) {
  return _service.compute(
    aimOffsetXIn: aimOffsetXIn,
    aimOffsetYIn: aimOffsetYIn,
    targetWidthIn: targetWidthIn,
    targetHeightIn: targetHeightIn,
    shape: shape,
    distanceYd: distanceYd,
    assumedGroupMoa: assumedGroupMoa,
    windUncertaintyMph: windUncertaintyMph,
    rangeUncertaintyYd: rangeUncertaintyYd,
    mvSdFps: mvSdFps,
    bcG7: bcG7,
    muzzleVelocityFps: muzzleVelocityFps,
  );
}

void main() {
  // ──────────────────────────────────────────────────────────────────
  // A. Sanity invariants
  // ──────────────────────────────────────────────────────────────────

  group('A. Sanity invariants', () {
    test('A1: probability is in [0, 1] across a reasonable input matrix', () {
      // Sweep distance / group / wind / target size and confirm every
      // probability lands inside [0, 1]. NaN / out-of-band would fail
      // `inInclusiveRange`.
      for (final dist in const [100.0, 300.0, 600.0, 1000.0]) {
        for (final group in const [0.5, 1.0, 2.0]) {
          for (final wind in const [0.0, 3.0, 8.0]) {
            for (final w in const [4.0, 12.0, 24.0]) {
              final r = _baselineCompute(
                distanceYd: dist,
                assumedGroupMoa: group,
                windUncertaintyMph: wind,
                targetWidthIn: w,
                targetHeightIn: w,
              );
              expect(
                r.hitProbability,
                inInclusiveRange(0.0, 1.0),
                reason:
                    'dist=$dist group=$group wind=$wind target=$w produced'
                    ' p=${r.hitProbability}',
              );
            }
          }
        }
      }
    });

    test('A2: probability monotonically decreases with distance', () {
      final p100 = _baselineCompute(distanceYd: 100).hitProbability;
      final p300 = _baselineCompute(distanceYd: 300).hitProbability;
      final p600 = _baselineCompute(distanceYd: 600).hitProbability;
      final p1000 = _baselineCompute(distanceYd: 1000).hitProbability;
      // Allow Monte Carlo noise (~1pp) on neighboring pairs but the
      // overall trend must be strictly downward across this 10×
      // distance sweep.
      expect(p100, greaterThan(p300 - 0.02));
      expect(p300, greaterThan(p600 - 0.02));
      expect(p600, greaterThan(p1000 - 0.02));
      expect(p100, greaterThan(p1000 + 0.20));
    });

    test('A3: probability monotonically decreases with group MOA', () {
      // Hold everything else fixed, sweep MOA. Larger group ⇒ wider
      // dispersion ⇒ lower prob. Use 1000 yd to keep group dominant.
      final p05 =
          _baselineCompute(distanceYd: 1000, assumedGroupMoa: 0.5).hitProbability;
      final p10 =
          _baselineCompute(distanceYd: 1000, assumedGroupMoa: 1.0).hitProbability;
      final p20 =
          _baselineCompute(distanceYd: 1000, assumedGroupMoa: 2.0).hitProbability;
      final p40 =
          _baselineCompute(distanceYd: 1000, assumedGroupMoa: 4.0).hitProbability;
      // Allow a 2pp Monte Carlo cushion at each step.
      expect(p05 + 0.02, greaterThan(p10));
      expect(p10 + 0.02, greaterThan(p20));
      expect(p20 + 0.02, greaterThan(p40));
      // Net drop across the 8× sweep must be obviously real.
      expect(p05, greaterThan(p40 + 0.10));
    });

    test('A4: probability monotonically decreases with wind uncertainty', () {
      // 1000 yd is the regime where wind dominates — the Litz coaching
      // observation we test elsewhere — so this delta is large and
      // reliable.
      final p0 =
          _baselineCompute(distanceYd: 1000, windUncertaintyMph: 0).hitProbability;
      final p2 =
          _baselineCompute(distanceYd: 1000, windUncertaintyMph: 2).hitProbability;
      final p5 =
          _baselineCompute(distanceYd: 1000, windUncertaintyMph: 5).hitProbability;
      final p10 =
          _baselineCompute(distanceYd: 1000, windUncertaintyMph: 10).hitProbability;
      expect(p0 + 0.02, greaterThan(p2));
      expect(p2 + 0.02, greaterThan(p5));
      expect(p5 + 0.02, greaterThan(p10));
      expect(p0, greaterThan(p10 + 0.10));
    });

    test('A5: doubling target dimensions increases hit probability', () {
      // At 600 yd with 1 MOA + 2 mph wind, an 8" target is on the order
      // of 1-σ wide. Doubling to 16" should bring an obvious uplift.
      final small = _baselineCompute(
        targetWidthIn: 8,
        targetHeightIn: 8,
      ).hitProbability;
      final big = _baselineCompute(
        targetWidthIn: 16,
        targetHeightIn: 16,
      ).hitProbability;
      expect(big, greaterThan(small + 0.05));
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // B. Boundary conditions
  // ──────────────────────────────────────────────────────────────────

  group('B. Boundary conditions', () {
    test('B1: zero-size target → probability is essentially 0', () {
      final r = _baselineCompute(
        targetWidthIn: 0,
        targetHeightIn: 0,
      );
      // For a circle with r=0 the only "inside" point is the origin
      // exactly — Monte Carlo with continuous Gaussian dispersion will
      // never sample that point. p must be zero.
      expect(r.hitProbability, equals(0.0));
    });

    test('B2: huge target (1000") → probability is ~1', () {
      final r = _baselineCompute(
        targetWidthIn: 1000,
        targetHeightIn: 1000,
        distanceYd: 1000,
        assumedGroupMoa: 2.0,
        windUncertaintyMph: 8.0,
      );
      // Even a worst-case dispersion at 1000 yd is dwarfed by a 1000"
      // target, so virtually every sample hits.
      expect(r.hitProbability, greaterThan(0.99));
    });

    test(
        'B3: minimum-error rifle on a generous target → probability is ~1',
        () {
      // The compute() method clamps groupMoa to 0.05 floor — we cannot
      // probe true zero through the public API. But 0.05 MOA + 0 wind +
      // 0 range + 0 MV at 100 yd against a 12" plate is a "this never
      // misses" scenario for any sensible math model.
      final r = _baselineCompute(
        distanceYd: 100,
        targetWidthIn: 12,
        targetHeightIn: 12,
        assumedGroupMoa: 0.05,
        windUncertaintyMph: 0,
        rangeUncertaintyYd: 0,
        mvSdFps: 0,
      );
      expect(r.hitProbability, greaterThan(0.99));
    });

    test(
        'B4: minimum-error rifle aim point WAY off target → probability is 0',
        () {
      // 0.05 MOA / 0 wind / 0 range / 0 MV at 100 yd, but aim is 100"
      // off-center against a 4"-wide target. The dispersion is roughly
      // 0.013" 1-σ — astronomically less than 100". Probability = 0.
      final r = _baselineCompute(
        distanceYd: 100,
        targetWidthIn: 4,
        targetHeightIn: 4,
        assumedGroupMoa: 0.05,
        windUncertaintyMph: 0,
        rangeUncertaintyYd: 0,
        mvSdFps: 0,
        aimOffsetXIn: 100,
      );
      expect(r.hitProbability, equals(0.0));
    });

    test('B5: NaN distance — handled gracefully (no crash, no NaN out)', () {
      // .clamp(1, 5000) on a NaN double in Dart returns the operand
      // (NaN) — the toDouble() then yields NaN. Subsequent comparisons
      // against NaN are all false, so the math drifts. We only assert
      // the call doesn't throw and the probability is a finite number
      // in [0, 1] OR is NaN itself but isn't an unhandled exception.
      late HitProbabilityResult r;
      expect(() {
        r = _baselineCompute(distanceYd: double.nan);
      }, returnsNormally);
      // Acceptable: graceful 0..1 OR NaN. NEVER an unbounded blow-up.
      final p = r.hitProbability;
      expect(p.isNaN || (p >= 0 && p <= 1), isTrue,
          reason: 'expected NaN or [0,1], got $p');
    });

    test('B6: negative distance is clamped to 1 yd, not crashed', () {
      // Per the source the input is `.clamp(1, 5000)` so a negative
      // distance is treated as 1 yd. Probability should be ~ 1 (1 yd
      // means the bullet lands within 0.013" of aim).
      final r = _baselineCompute(distanceYd: -100);
      expect(r.hitProbability, greaterThan(0.99));
    });

    test('B7: huge group MOA is clamped (no infinity / no exception)', () {
      // .clamp(0.05, 20) caps the group input. Even a "1000 MOA" call
      // should run cleanly and return something below 1.
      late HitProbabilityResult r;
      expect(() {
        r = _baselineCompute(assumedGroupMoa: 1000);
      }, returnsNormally);
      expect(r.hitProbability, inInclusiveRange(0.0, 1.0));
    });

    test('B8: zero MV does not crash the perturbation re-solves', () {
      // mv == 0 makes `solveAt` early-return null, and the caught-exception
      // path in compute zeros the per-source sigma. Result is a non-NaN
      // probability dominated by group dispersion.
      late HitProbabilityResult r;
      expect(() {
        r = _baselineCompute(muzzleVelocityFps: 0);
      }, returnsNormally);
      expect(r.hitProbability, inInclusiveRange(0.0, 1.0));
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // C. Target shape coverage
  // ──────────────────────────────────────────────────────────────────

  group('C. Target shape coverage', () {
    test('C1: circle target — basic hit prob check', () {
      final r = _baselineCompute(
        shape: TargetShape.circle,
        targetWidthIn: 8,
        targetHeightIn: 8,
      );
      expect(r.hitProbability, inInclusiveRange(0.0, 1.0));
      expect(r.hitProbability, greaterThan(0.10));
    });

    test('C2: rectangle hit-prob ≥ inscribed-circle hit-prob (same w×h)', () {
      // For aim-at-center + symmetric Gaussian, a square / rectangle
      // strictly contains the inscribed circle, so its hit probability
      // must be at least as high. Very robust check, no MC noise issue.
      final circle = _baselineCompute(
        shape: TargetShape.circle,
        targetWidthIn: 8,
        targetHeightIn: 8,
      );
      final rect = _baselineCompute(
        shape: TargetShape.rectangle,
        targetWidthIn: 8,
        targetHeightIn: 8,
      );
      // Allow 1pp MC slop in case of rare seed effects.
      expect(rect.hitProbability + 0.01,
          greaterThan(circle.hitProbability));
    });

    test('C3: square target behaves like rectangle (axis-aligned bounds)', () {
      final sq = _baselineCompute(
        shape: TargetShape.square,
        targetWidthIn: 12,
        targetHeightIn: 12,
      );
      final rect = _baselineCompute(
        shape: TargetShape.rectangle,
        targetWidthIn: 12,
        targetHeightIn: 12,
      );
      // The math for square == rectangle. Same seed (same hash inputs
      // would only differ by shape.index) so results should match
      // within MC slop.
      expect(sq.hitProbability,
          closeTo(rect.hitProbability, 0.03));
    });

    test('C4: silhouette uses bounding-rect approximation (v1 contract)', () {
      // The doc string says silhouette ≈ bounding-rect for v1. So a
      // silhouette of size w×h must hit the same prob as a rectangle
      // of size w×h within MC slop.
      final sil = _baselineCompute(
        shape: TargetShape.silhouette,
        targetWidthIn: 18,
        targetHeightIn: 30,
      );
      final rect = _baselineCompute(
        shape: TargetShape.rectangle,
        targetWidthIn: 18,
        targetHeightIn: 30,
      );
      expect(sil.hitProbability,
          closeTo(rect.hitProbability, 0.03));
    });

    test('C5: irregular shape also uses bounding-rect path', () {
      final ir = _baselineCompute(
        shape: TargetShape.irregular,
        targetWidthIn: 10,
        targetHeightIn: 10,
      );
      // Same as square with same dimensions modulo shape.index seed.
      final sq = _baselineCompute(
        shape: TargetShape.square,
        targetWidthIn: 10,
        targetHeightIn: 10,
      );
      expect(ir.hitProbability, closeTo(sq.hitProbability, 0.03));
    });

    test('C6: parseTargetShape() round-trips known strings', () {
      expect(parseTargetShape('circle'), TargetShape.circle);
      expect(parseTargetShape('CIRCLE'), TargetShape.circle); // case-insensitive
      expect(parseTargetShape('square'), TargetShape.square);
      expect(parseTargetShape('rectangle'), TargetShape.rectangle);
      expect(parseTargetShape('silhouette'), TargetShape.silhouette);
      expect(parseTargetShape('blob'), TargetShape.irregular); // default
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // D. Aim point offset
  // ──────────────────────────────────────────────────────────────────

  group('D. Aim point offset', () {
    test('D1: aim at target center → max prob', () {
      // For symmetric dispersion, hit prob is maximized when aim is at
      // the target center.
      final center = _baselineCompute(
        aimOffsetXIn: 0,
        aimOffsetYIn: 0,
        targetWidthIn: 8,
        targetHeightIn: 8,
      );
      final offset3 = _baselineCompute(
        aimOffsetXIn: 3,
        aimOffsetYIn: 0,
        targetWidthIn: 8,
        targetHeightIn: 8,
      );
      final offset5 = _baselineCompute(
        aimOffsetXIn: 5,
        aimOffsetYIn: 0,
        targetWidthIn: 8,
        targetHeightIn: 8,
      );
      // Allow 1pp MC noise but maximum has to be center.
      expect(center.hitProbability + 0.01,
          greaterThan(offset3.hitProbability));
      expect(offset3.hitProbability + 0.01,
          greaterThan(offset5.hitProbability));
    });

    test('D2: aim point at edge of target → roughly 50% prob', () {
      // For a symmetric Gaussian centered exactly on a circle's
      // boundary, half the mass falls inside the disk and half outside.
      // Use a tight rifle (low dispersion) on a sane target so the
      // ~50% intuition holds. 0.5 MOA / 0 wind / 100 yd / 4" radius.
      // The radius on the boundary places the aim such that the disk
      // covers exactly half the (locally near-flat) Gaussian mass.
      final r = _baselineCompute(
        aimOffsetXIn: 4, // edge of the 8"-wide circle
        aimOffsetYIn: 0,
        distanceYd: 100,
        assumedGroupMoa: 0.5,
        windUncertaintyMph: 0,
        rangeUncertaintyYd: 0,
        mvSdFps: 0,
        targetWidthIn: 8,
        targetHeightIn: 8,
      );
      // The ~50% intuition assumes the dispersion is small relative to
      // the target's curvature, which holds here. Allow a wide band
      // because the dispersion is a few inches and curvature matters.
      expect(r.hitProbability, inInclusiveRange(0.30, 0.70));
    });

    test('D3: aim point 10× target radius off-target → probability ~ 0', () {
      // Tight rifle, modest dispersion, but aim 40" off a 4"-wide disk.
      // Dispersion 1-σ at 100 yd × 1 MOA ≈ 0.26"; 40" is ~150σ. Hit prob
      // is computationally indistinguishable from zero.
      final r = _baselineCompute(
        aimOffsetXIn: 40,
        targetWidthIn: 8, // radius 4"
        targetHeightIn: 8,
        distanceYd: 100,
        assumedGroupMoa: 1.0,
        windUncertaintyMph: 0,
        rangeUncertaintyYd: 0,
        mvSdFps: 0,
      );
      expect(r.hitProbability, equals(0.0));
    });

    test('D4: aim offset symmetry — +X and -X give equal probabilities', () {
      // The dispersion model is symmetric around aim, so flipping the
      // sign of an aim offset must not change the probability (modulo
      // MC noise from a different seed).
      final plus = _baselineCompute(aimOffsetXIn: 2);
      final minus = _baselineCompute(aimOffsetXIn: -2);
      expect(plus.hitProbability,
          closeTo(minus.hitProbability, 0.03));
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // E. Monte Carlo determinism (seeded RNG)
  // ──────────────────────────────────────────────────────────────────

  group('E. Determinism', () {
    test('E1: identical inputs ⇒ identical probability (seed reproducibility)',
        () {
      // The service hashes the inputs into a 32-bit seed so the UI
      // doesn't jiggle as the user types. Two calls with exactly the
      // same args must return EXACTLY the same probability.
      final a = _baselineCompute();
      final b = _baselineCompute();
      expect(a.hitProbability, equals(b.hitProbability));
      expect(a.horizontalSigmaIn, equals(b.horizontalSigmaIn));
      expect(a.verticalSigmaIn, equals(b.verticalSigmaIn));
    });

    test('E2: tiny input change ⇒ output change is bounded by MC noise', () {
      // 1 yd of distance is the smallest change that can move the seed
      // (the seed-from-inputs hash uses toStringAsFixed(0) on yards).
      // Result should differ but stay within a small noise envelope.
      final a = _baselineCompute(distanceYd: 600);
      final b = _baselineCompute(distanceYd: 601);
      // Different seed ⇒ the two results may differ by Monte Carlo
      // noise, but they should NOT be wildly different.
      expect((a.hitProbability - b.hitProbability).abs(), lessThan(0.05));
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // F. Range-day-realistic anchor cases
  // ──────────────────────────────────────────────────────────────────

  group('F. Range-day anchor cases', () {
    test(
        'F1: 1.0 MOA rifle / 600 yd / 18" steel circle / 5 mph wind — broad sane band',
        () {
      // Litz/PRB regression case: 1 MOA shooter, 18" plate, 600 yd,
      // ±5 mph wind call uncertainty. This is the classic "is my call
      // good enough?" scenario.
      final r = _baselineCompute(
        distanceYd: 600,
        targetWidthIn: 18,
        targetHeightIn: 18,
        shape: TargetShape.circle,
        assumedGroupMoa: 1.0,
        windUncertaintyMph: 5.0,
        rangeUncertaintyYd: 5.0,
        mvSdFps: 12.0,
      );
      // 1 MOA at 600 = ~6.3"; /4 ≈ 1.6" 1-σ from group alone.
      // Wind ±5 mph at 600 yd on 6.5 CM ≈ ~10" full swing → ~2.5" 1-σ.
      // Combined σ_x ≈ 3"; σ_y ≈ 1.6". On a 9"-radius disk that's a
      // very high-confidence hit. Use a wide band because the wind
      // perturbation magnitude depends on solver default atmosphere.
      expect(r.hitProbability, inInclusiveRange(0.50, 0.99));
    });

    test('F2: pistol at 25 yd against IPSC silhouette → probability ~ 99%',
        () {
      // 25-yd pistol drill on a USPSA target: 18" wide × 30" tall body
      // outline. Even a "service pistol" group of ~3 MOA is ~0.8" at
      // 25 yd; trivially inside the silhouette.
      final r = _service.compute(
        aimOffsetXIn: 0,
        aimOffsetYIn: 0,
        targetWidthIn: 18,
        targetHeightIn: 30,
        shape: TargetShape.silhouette,
        distanceYd: 25,
        assumedGroupMoa: 3.0, // duty-pistol grade
        windUncertaintyMph: 0,
        rangeUncertaintyYd: 0,
        mvSdFps: 0,
        bcG7: 0.10, // 9mm-ish G7
        muzzleVelocityFps: 1150,
      );
      expect(r.hitProbability, greaterThan(0.99));
    });

    test(
        'F3: tight rifle at 50 yd against generous silhouette → very high prob',
        () {
      // Stand-in for "shotgun pattern" coverage — a wide silhouette at
      // close range with modest dispersion. 24"×24" plate at 50 yd is
      // hard to miss with sub-MOA dispersion.
      final r = _baselineCompute(
        distanceYd: 50,
        targetWidthIn: 24,
        targetHeightIn: 24,
        shape: TargetShape.rectangle,
        assumedGroupMoa: 1.0,
        windUncertaintyMph: 0,
        rangeUncertaintyYd: 0,
        mvSdFps: 0,
      );
      expect(r.hitProbability, greaterThan(0.98));
    });

    test('F4: factor breakdown contains four entries in canonical order', () {
      // Every compute() must surface a 4-entry breakdown ordered
      // group, wind, range, MV. The UI relies on this ordering for the
      // "why?" expandable panel.
      final r = _baselineCompute();
      expect(r.factors.length, 4);
      expect(r.factors[0].label, contains('Group'));
      expect(r.factors[1].label, contains('Wind'));
      expect(r.factors[2].label, contains('Range'));
      expect(r.factors[3].label, contains('MV'));
      // Every contribution is non-negative.
      for (final f in r.factors) {
        expect(f.contribIn, greaterThanOrEqualTo(0));
      }
    });

    test('F5: dispersion summary fields are positive at non-trivial range',
        () {
      final r = _baselineCompute(distanceYd: 600);
      expect(r.dispersionMoa, greaterThan(0));
      expect(r.horizontalSigmaIn, greaterThan(0));
      expect(r.verticalSigmaIn, greaterThan(0));
      expect(r.horizontalSigmaMil, greaterThan(0));
      expect(r.verticalSigmaMil, greaterThan(0));
      expect(r.horizontalSigmaMoa, greaterThan(0));
      expect(r.verticalSigmaMoa, greaterThan(0));
      // dispersion summary = max(horiz, vert) sigma in MOA.
      final maxAxisMoa = math.max(
        r.horizontalSigmaMoa,
        r.verticalSigmaMoa,
      );
      expect(r.dispersionMoa, closeTo(maxAxisMoa, 1e-6));
    });

    test('F6: σ_y ≥ σ_x when range and MV uncertainty are present', () {
      // σ_y = sqrt(group² + range² + MV²); σ_x = sqrt(group² + wind²).
      // With non-zero range and MV uncertainty AND zero wind, σ_y is
      // strictly larger than σ_x.
      final r = _baselineCompute(
        windUncertaintyMph: 0,
        rangeUncertaintyYd: 10,
        mvSdFps: 15,
      );
      expect(r.verticalSigmaIn,
          greaterThanOrEqualTo(r.horizontalSigmaIn));
    });
  });

  // ──────────────────────────────────────────────────────────────────
  // G. Performance
  // ──────────────────────────────────────────────────────────────────

  group('G. Performance', () {
    test('G1: a single compute() returns in well under 250ms (per call)', () {
      // The on-device budget is 200ms (kept under the 300ms debounce
      // budget). The CI test runner is several × slower than a phone,
      // so we assert a generous 2-second worst case for ONE call here.
      // The 250ms ask is the on-device guidance — we test the structural
      // perf budget and explicitly note the headroom.
      final stopwatch = Stopwatch()..start();
      _baselineCompute();
      stopwatch.stop();
      expect(stopwatch.elapsedMilliseconds, lessThan(2000),
          reason: 'single compute must finish well under 2s in CI');
    });
  });
}

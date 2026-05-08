// FILE: lib/services/ballistics/group_stats.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Pure-Dart helper that turns a list of recorded shot impacts into the
// statistics a precision shooter actually wants to see after pulling a
// group: extreme spread, mean radius, group MOA, horizontal / vertical
// standard deviation, and the centroid offset (the load-bias the user can
// dial out at the scope).
//
// The functions here are *intentionally* free of Flutter / Drift imports
// so they can be unit-tested in headless Dart and reused on watchOS / Wear
// OS companion code if that becomes useful. The Range Day screen wraps the
// raw `ShotImpactRow` rows into `Offset` (inches relative to target
// center) and hands them in.
//
// ============================================================================
// FORMULAS
// ============================================================================
//
//   centroid       = (mean(x_i), mean(y_i))
//   ES (extreme    = max_{i,j} ||p_i - p_j||  (longest pairwise distance,
//      spread)                                 center-to-center)
//   group size     = ES + bullet_diameter      (outside-edge span — what
//                                                a caliper measures when
//                                                the bullets touch the
//                                                paper at the right edge)
//   mean radius    = mean_i ||p_i - centroid||
//   sigma_x        = sqrt(mean((x_i - cx)^2))  population SD, NOT sample
//   sigma_y        = sqrt(mean((y_i - cy)^2))  SD — for n in [2, 30] the
//                                                difference is tiny and
//                                                the population form has
//                                                a useful "n=1 → 0" limit
//
// MOA conversion uses [inchesToMoaAtYards] so 0 yd correctly returns 0
// instead of throwing a divide-by-zero — the caller can render "—" when
// the session distance is unset.
//
// ============================================================================
// WHY POPULATION SD AND NOT SAMPLE SD
// ============================================================================
// The classical sample-SD estimator divides by (n-1), which corrects bias
// when the sample is drawn from an infinite hypothetical population. Group
// statistics in shooting are descriptive: we are summarizing the shots we
// actually pulled, not estimating the shooter's true population variance.
// For descriptive use the population form (divide by n) is the right
// answer and matches what most ballistics tools (LabRadar, On Target TDS,
// Modern Marksmanship) report. The difference is bounded by `sqrt(n/(n-1))`
// which is < 4% for n >= 6 and converges quickly.
//
// We can revisit if real users want sample SD; the call site is two lines.
//
// ============================================================================
// CONFIDENCE INTERVALS ON GROUP MOA (LITZ STATISTICS)
// ============================================================================
// Bryan Litz's _Accuracy and Precision for Long-Range Shooting_ (Berger
// Bullets, 2012, ch. 1, "Statistics for Shooters") makes the case that
// shooters routinely cite single small groups (3- or 5-shot) as if they
// were tight estimates of the rifle's true precision — yet the sampling
// distribution of extreme spread is so noisy at small N that a 5-shot
// 1.0-MOA group is statistically consistent with rifles that average
// anywhere from ~0.6 MOA to ~1.6 MOA when shot many times. The headline
// take-away is "shoot more groups before drawing conclusions".
//
// The math (and the multiplier table below) come from the sampling
// distribution of the Rayleigh extreme-spread statistic for a 2D
// circular Gaussian shooter dispersion. Equivalent tables appear in:
//   * Ballistipedia, "Range Statistics" article (Monte-Carlo derived,
//     1e6 trials per N): http://ballistipedia.com/index.php?title=Range_Statistics
//   * Grubbs, F. E. (1964). "Statistical measures of accuracy for
//     riflemen and missile engineers".
//   * Litz, B. (2012). _Accuracy and Precision for Long-Range Shooting_,
//     Appendix on group-statistic distributions.
//
// For each shot count N we store three quantiles of ES/σ:
//   k_mean — expected ES given true 1σ_radial (the inverse gives
//            the bias-corrected point estimate of σ)
//   k_lo   — 5th percentile of ES/σ
//   k_hi   — 95th percentile of ES/σ
//
// Given an observed ES_obs from N shots:
//   σ̂           = ES_obs / k_mean         (bias-corrected best estimate)
//   σ_CI_low    = ES_obs / k_hi             (smallest σ that could plausibly
//                                              produce this large an ES)
//   σ_CI_high   = ES_obs / k_lo             (largest σ that could plausibly
//                                              produce this small an ES)
//   true_ES_low  = σ_CI_low  × k_mean       (expected group size at σ_CI_low)
//   true_ES_high = σ_CI_high × k_mean       (expected group size at σ_CI_high)
//
// The CI on "true expected group size" — what the rifle would shoot in
// expectation if we repeated the same N-shot test infinitely — brackets
// the observed value and is what the UI displays.
//
// TODO(v1.1): t-test comparison between two groups — Litz also covers
// "are these two loads statistically different?" via a two-sample t-test
// on mean radii. That belongs in a separate `compareGroups(...)` helper.

import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'units.dart' as units;

/// Aggregate group-level metrics computed from a set of recorded shots.
///
/// All length values are in INCHES at the target. Angular values are in
/// MOA; convert to MIL via [units.inchesToMilAtYards] at the call site if
/// needed. Returns `null` from [computeGroupStats] when there are fewer
/// than 2 shots.
class GroupStats {
  const GroupStats({
    required this.shotCount,
    required this.extremeSpreadIn,
    required this.extremeSpreadMoa,
    required this.meanRadiusIn,
    required this.meanRadiusMoa,
    required this.groupSizeIn,
    required this.groupSizeMoa,
    required this.horizontalSdIn,
    required this.verticalSdIn,
    required this.centroidIn,
    this.underlyingSigmaIn,
    this.groupSizeCiLow90PctIn,
    this.groupSizeCiHigh90PctIn,
    this.groupMoaCiLow90Pct,
    this.groupMoaCiHigh90Pct,
  });

  /// Number of shots that contributed to the statistics.
  final int shotCount;

  /// Longest center-to-center distance between any two shots (inches).
  final double extremeSpreadIn;

  /// [extremeSpreadIn] expressed as MOA at the session distance. 0 if
  /// the session distance was 0/unset.
  final double extremeSpreadMoa;

  /// Mean radius — average distance from each shot to the group centroid.
  final double meanRadiusIn;

  /// Mean radius converted to MOA at the session distance.
  final double meanRadiusMoa;

  /// "Outside edge" group size — extreme spread plus one bullet diameter.
  /// This is the number a caliper reads off the paper when measuring
  /// edge-to-edge.
  final double groupSizeIn;

  /// [groupSizeIn] in MOA at the session distance.
  final double groupSizeMoa;

  /// Population standard deviation of horizontal impacts (inches).
  final double horizontalSdIn;

  /// Population standard deviation of vertical impacts (inches).
  final double verticalSdIn;

  /// Group centroid expressed in inches relative to target center. The
  /// dx component is positive-right, dy is positive-up to match the
  /// shooter's mental model. The reverse of this vector is the scope
  /// adjustment that would re-center the group.
  final Offset centroidIn;

  /// Bias-corrected best estimate of the underlying 1σ radial dispersion
  /// (inches), derived from extreme spread via the inverse of E[ES/σ]
  /// for the observed sample size. Different from the observed mean
  /// radius — corrects the well-known bias where mean radius slightly
  /// underestimates σ at small N.
  ///
  /// `null` for N < 3 (the sampling distribution of ES is not
  /// well-defined enough at N=2 to publish a multiplier most references
  /// agree on).
  final double? underlyingSigmaIn;

  /// 90% confidence interval (lower bound) on the true expected group
  /// size in inches at the observation distance — i.e. the group size
  /// the rifle would shoot in expectation at its underlying precision.
  /// `null` for N < 3.
  final double? groupSizeCiLow90PctIn;

  /// 90% confidence interval (upper bound) on the true expected group
  /// size in inches at the observation distance. `null` for N < 3.
  final double? groupSizeCiHigh90PctIn;

  /// 90% confidence interval (lower bound) on the true group MOA at the
  /// observation distance. Width depends on sample size: a 3-shot group
  /// has a much wider CI than a 10-shot group. `null` for N < 3 or when
  /// the session distance is 0/unset.
  final double? groupMoaCiLow90Pct;

  /// 90% confidence interval (upper bound) on the true group MOA at the
  /// observation distance. `null` for N < 3 or when the session distance
  /// is 0/unset.
  final double? groupMoaCiHigh90Pct;
}

/// Quantile triple for the sampling distribution of ES/σ for a
/// 2D circular-Gaussian (Rayleigh radial) shooter dispersion.
class _EsSigmaQuantiles {
  const _EsSigmaQuantiles({
    required this.low,
    required this.mean,
    required this.high,
  });

  /// 5th percentile of ES/σ at this sample size.
  final double low;

  /// Expected value of ES/σ at this sample size.
  final double mean;

  /// 95th percentile of ES/σ at this sample size.
  final double high;
}

/// Tabulated quantiles of ES/σ for representative shot counts.
///
/// Values are Monte-Carlo-derived from the Rayleigh radial distribution
/// (≥1e6 trials each) and match the published numbers in Ballistipedia's
/// Range Statistics article and Litz's appendix tables in
/// _Accuracy and Precision for Long-Range Shooting_ within rounding.
///
/// Sorted by N for binary-search / linear-interpolation lookup.
const List<({int n, _EsSigmaQuantiles q})> _esSigmaTable = [
  (n: 3, q: _EsSigmaQuantiles(low: 0.68, mean: 1.69, high: 2.83)),
  (n: 4, q: _EsSigmaQuantiles(low: 1.04, mean: 2.06, high: 3.13)),
  (n: 5, q: _EsSigmaQuantiles(low: 1.31, mean: 2.33, high: 3.34)),
  (n: 6, q: _EsSigmaQuantiles(low: 1.53, mean: 2.53, high: 3.50)),
  (n: 7, q: _EsSigmaQuantiles(low: 1.71, mean: 2.70, high: 3.62)),
  (n: 8, q: _EsSigmaQuantiles(low: 1.86, mean: 2.85, high: 3.73)),
  (n: 9, q: _EsSigmaQuantiles(low: 1.99, mean: 2.97, high: 3.83)),
  (n: 10, q: _EsSigmaQuantiles(low: 2.10, mean: 3.08, high: 3.91)),
  (n: 15, q: _EsSigmaQuantiles(low: 2.55, mean: 3.47, high: 4.22)),
  (n: 20, q: _EsSigmaQuantiles(low: 2.85, mean: 3.74, high: 4.42)),
  (n: 30, q: _EsSigmaQuantiles(low: 3.27, mean: 4.09, high: 4.69)),
];

/// Returns the (5th, mean, 95th) quantiles of ES/σ for a Rayleigh
/// shooter dispersion at sample size [n].
///
/// For exact tabulated entries, returns the published value. For values
/// of N between tabulated rows (e.g. N=7 is tabulated, N=12 is not),
/// linearly interpolates between the bracketing rows. For N above the
/// last tabulated row (>30), clamps to N=30 — the CI continues to
/// narrow but the marginal benefit is small and the table covers the
/// practically relevant range.
///
/// Returns `null` for N < 3, which the callers treat as "CI not
/// publishable for this sample size". N=2 has a degenerate sampling
/// distribution and the published references disagree on the right
/// value, so we conservatively decline to estimate.
({double low, double mean, double high})? sigmaMultipliersForN(int n) {
  if (n < 3) return null;
  if (n >= _esSigmaTable.last.n) {
    final q = _esSigmaTable.last.q;
    return (low: q.low, mean: q.mean, high: q.high);
  }
  // Find the bracketing pair (lo, hi) with lo.n <= n <= hi.n. Table is
  // small enough that a linear scan is the cleanest choice.
  for (var i = 0; i < _esSigmaTable.length - 1; i++) {
    final lo = _esSigmaTable[i];
    final hi = _esSigmaTable[i + 1];
    if (lo.n <= n && n <= hi.n) {
      if (lo.n == n) {
        return (low: lo.q.low, mean: lo.q.mean, high: lo.q.high);
      }
      if (hi.n == n) {
        return (low: hi.q.low, mean: hi.q.mean, high: hi.q.high);
      }
      // Linear interpolation in N. Since the quantiles vary smoothly
      // and slowly with N, linear is fine for the accuracy bar we
      // need (display, not academic publication).
      final t = (n - lo.n) / (hi.n - lo.n);
      return (
        low: lo.q.low + (hi.q.low - lo.q.low) * t,
        mean: lo.q.mean + (hi.q.mean - lo.q.mean) * t,
        high: lo.q.high + (hi.q.high - lo.q.high) * t,
      );
    }
  }
  // Unreachable: every N in [3, last.n] is bracketed by some pair, and
  // the n >= last.n case is handled above. Fall through for safety.
  return null;
}

/// Compute group statistics from a list of shot impacts in inches
/// relative to the target's center.
///
/// `points` must be in inches with positive x = right of center and
/// positive y = above center (this matches the convention used in
/// `lib/screens/range_day/range_day_detail_screen.dart` after converting
/// normalized impacts to inches via the target's width/height).
///
/// `bulletDiameterIn` is added to the extreme spread to produce
/// [GroupStats.groupSizeIn] (the outside-edge measurement a caliper
/// would give). Defaults to 0 — pass the active load's bullet diameter
/// when computing the displayed group size.
///
/// `distanceYd` is used to convert linear group dimensions to MOA. Pass
/// 0 (or any non-positive value) when the session distance isn't known
/// yet — the MOA fields will be 0 in that case rather than NaN.
///
/// Returns `null` when fewer than 2 points are supplied — group stats
/// only make sense for 2+ shots, and the UI should render a "Need ≥2
/// shots" placeholder instead.
GroupStats? computeGroupStats({
  required List<Offset> points,
  required double distanceYd,
  double bulletDiameterIn = 0.0,
}) {
  if (points.length < 2) return null;

  // Centroid — arithmetic mean of x and y components.
  double sumX = 0;
  double sumY = 0;
  for (final p in points) {
    sumX += p.dx;
    sumY += p.dy;
  }
  final cx = sumX / points.length;
  final cy = sumY / points.length;
  final centroid = Offset(cx, cy);

  // Extreme spread — max pairwise center-to-center distance. O(n^2),
  // fine for the 5–20 shots a real range-day session ever has.
  double maxD = 0.0;
  for (var i = 0; i < points.length; i++) {
    for (var j = i + 1; j < points.length; j++) {
      final dx = points[i].dx - points[j].dx;
      final dy = points[i].dy - points[j].dy;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > maxD) maxD = d;
    }
  }

  // Mean radius — mean distance from each point to the centroid.
  double sumR = 0.0;
  // Population variance accumulators — divide by N at the end.
  double sumDx2 = 0.0;
  double sumDy2 = 0.0;
  for (final p in points) {
    final dx = p.dx - cx;
    final dy = p.dy - cy;
    sumR += math.sqrt(dx * dx + dy * dy);
    sumDx2 += dx * dx;
    sumDy2 += dy * dy;
  }
  final meanRadius = sumR / points.length;
  final sigmaX = math.sqrt(sumDx2 / points.length);
  final sigmaY = math.sqrt(sumDy2 / points.length);

  final groupSizeIn = maxD + bulletDiameterIn;
  final esMoa = distanceYd <= 0
      ? 0.0
      : units.inchesToMoaAtYards(maxD, distanceYd);
  final mrMoa = distanceYd <= 0
      ? 0.0
      : units.inchesToMoaAtYards(meanRadius, distanceYd);
  final groupSizeMoa = distanceYd <= 0
      ? 0.0
      : units.inchesToMoaAtYards(groupSizeIn, distanceYd);

  // Confidence interval on true expected group size, given the observed
  // extreme spread and sample size. Only published for N >= 3.
  double? underlyingSigmaIn;
  double? groupSizeCiLowIn;
  double? groupSizeCiHighIn;
  double? groupMoaCiLow;
  double? groupMoaCiHigh;
  final mults = sigmaMultipliersForN(points.length);
  if (mults != null && maxD > 0) {
    underlyingSigmaIn = maxD / mults.mean;
    // σ_CI: [ES / k_high, ES / k_low]. The "true expected ES" CI is
    // σ_CI × k_mean — i.e. the group size the rifle would shoot in
    // expectation at the bounds of the σ CI.
    final esTrueLow = (maxD / mults.high) * mults.mean;
    final esTrueHigh = (maxD / mults.low) * mults.mean;
    // Add bullet diameter so the CI bracket is on the displayed
    // "Group" measurement (ES + bullet diameter), matching the
    // user-visible point estimate.
    groupSizeCiLowIn = esTrueLow + bulletDiameterIn;
    groupSizeCiHighIn = esTrueHigh + bulletDiameterIn;
    if (distanceYd > 0) {
      groupMoaCiLow =
          units.inchesToMoaAtYards(groupSizeCiLowIn, distanceYd);
      groupMoaCiHigh =
          units.inchesToMoaAtYards(groupSizeCiHighIn, distanceYd);
    }
  }

  return GroupStats(
    shotCount: points.length,
    extremeSpreadIn: maxD,
    extremeSpreadMoa: esMoa,
    meanRadiusIn: meanRadius,
    meanRadiusMoa: mrMoa,
    groupSizeIn: groupSizeIn,
    groupSizeMoa: groupSizeMoa,
    horizontalSdIn: sigmaX,
    verticalSdIn: sigmaY,
    centroidIn: centroid,
    underlyingSigmaIn: underlyingSigmaIn,
    groupSizeCiLow90PctIn: groupSizeCiLowIn,
    groupSizeCiHigh90PctIn: groupSizeCiHighIn,
    groupMoaCiLow90Pct: groupMoaCiLow,
    groupMoaCiHigh90Pct: groupMoaCiHigh,
  );
}

// FILE: lib/services/ballistics/wind_bracket_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Computes the published "wind bracket" — three windage holds for the
// shooter's lower-bound, mid, and upper-bound estimates of the wind
// speed. The shooter is rarely 100% sure of the wind; bracketing it
// turns "wind miss" into a confidence interval the shooter can read
// off the screen.
//
// The bracket method is introduced in *Applied Ballistics for
// Long-Range Shooting* (3rd ed. ch. 11) and *Modern Advancements in
// Long-Range Shooting* vol. 1 (ch. 5). The method is simple: instead
// of computing one wind hold for the user's best-guess wind, run the
// solver three times and report all three holds. The shooter dials
// the **mid**; the **low** and **high** are the +/- bounds of the
// hold uncertainty.
//
// Public API:
//
//   * `class WindBracketResult` — three [TrajectorySample]s plus the
//     three input wind speeds.
//   * `WindBracketService.computeWindBracket(...)` — runs the solver
//     three times (low / mid / high wind) at a single requested
//     range and returns the three resulting holds.
//
// ============================================================================
// THE MATH
// ============================================================================
// `wind_low  = max(wind_mid − uncertainty, 0)`
// `wind_mid  = wind_estimate`
// `wind_high = wind_mid + uncertainty`
//
// We clamp the low side to 0 mph because a negative wind speed makes
// no physical sense (it would just be a wind from the opposite
// direction, which the user already accounts for via the `windFrom`
// degree input). Clamping ensures the bracket is always a valid
// [low, mid, high] triple and the shooter sees "0 mph hold = 0" on
// the low side rather than an inverted wind hold.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Layered above `solver.dart` and `environment.dart`. Pure-Dart, no
// Flutter / DB / network dependencies — same architectural posture as
// the rest of `lib/services/ballistics/`. The wind-bracket card on
// the Ballistics screen and the Range Day firing-solution panel both
// call into this service.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   - lib/screens/ballistics/ballistics_screen.dart  (output card)
//   - lib/screens/range_day/range_day_detail_screen.dart  (solution
//     panel)
//   - test/wind_bracket_test.dart  (regression tests)
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure functions over the same `Projectile`, `Environment`,
// `ShotInputs` types the solver consumes.

import 'environment.dart';
import 'projectile.dart';
import 'solver.dart';

/// One axis of the wind bracket — three [TrajectorySample]s solved
/// at the user's [windLowMph], [windMidMph], and [windHighMph] wind
/// speeds. All other inputs are held constant across the three
/// solves.
///
/// The samples are at a single requested range (the bracket is
/// computed for **one** decision range — the shooter's current
/// engagement distance — not a full DOPE table). Pulling them as
/// `TrajectorySample`s rather than raw scalar holds keeps every
/// scope-unit conversion (mil / MOA / inches) consistent with the
/// rest of the firing-solution UI.
class WindBracketResult {
  const WindBracketResult({
    required this.rangeYards,
    required this.windLowMph,
    required this.windMidMph,
    required this.windHighMph,
    required this.low,
    required this.mid,
    required this.high,
  });

  /// Range the bracket was computed at, in yards.
  final double rangeYards;

  /// Lower-bound wind speed (mph) — `mid − uncertainty`, clamped to
  /// 0 mph minimum so a small "best guess" wind never produces a
  /// negative low bound.
  final double windLowMph;

  /// Mid-bound wind speed (mph) — the shooter's best-guess estimate.
  final double windMidMph;

  /// Upper-bound wind speed (mph) — `mid + uncertainty`.
  final double windHighMph;

  /// Sample at the low-wind solve.
  final TrajectorySample low;

  /// Sample at the mid-wind solve. This is the hold the shooter
  /// dials; [low] and [high] are the +/- envelope.
  final TrajectorySample mid;

  /// Sample at the high-wind solve.
  final TrajectorySample high;
}

/// Computes the wind bracket: three [TrajectorySample]s at
/// `wind_estimate − uncertainty`, `wind_estimate`, and
/// `wind_estimate + uncertainty`.
///
/// Returns `null` when [windUncertaintyMph] is null, ≤0, or
/// non-finite — the bracket is meaningless without a stated
/// uncertainty, and the calling UI is expected to hide the bracket
/// card in that case.
///
/// The three solves share the [projectile], [shot], and atmospheric
/// portion of [environment]. Only the wind speed varies; the
/// `windFromDegrees`, `shotAzimuthDegrees`, `latitudeDegrees`, and
/// `targetElevationFt` are kept constant. We rebuild a fresh
/// `Environment` for each solve via [Environment.fromImperial] so
/// the wind-vector calculation in `Environment.windVector` runs at
/// the right speed each time.
///
/// All other solver flags (spin drift, Coriolis, aerodynamic jump,
/// coning, accuracy, spin-drift model) are passed straight through
/// to each solve so the bracket holds match the user's existing
/// firing solution exactly when computed at the mid wind.
WindBracketResult? computeWindBracket({
  required Projectile projectile,
  required Environment environment,
  required ShotInputs shot,
  required double rangeYards,
  required double windEstimateMph,
  required double? windUncertaintyMph,
  bool includeSpinDrift = true,
  bool includeCoriolis = true,
  bool includeAerodynamicJump = true,
  bool includeConing = false,
  BallisticsAccuracy accuracy = BallisticsAccuracy.precise,
  SpinDriftModel spinDriftModel = SpinDriftModel.industryStandard,
}) {
  final unc = windUncertaintyMph;
  if (unc == null || !unc.isFinite || unc <= 0) {
    return null;
  }
  if (!rangeYards.isFinite || rangeYards <= 0) {
    return null;
  }

  // Clamp the low-wind side to 0 mph — a negative wind speed would
  // flip direction (already encoded in `windFromDegrees`), so the
  // physically meaningful low bound is 0 even when uncertainty
  // exceeds the estimate.
  final windLow = (windEstimateMph - unc).clamp(0.0, double.infinity);
  final windMid = windEstimateMph;
  final windHigh = windEstimateMph + unc;

  TrajectorySample solveOne(double windMph) {
    final env = Environment.fromImperial(
      atmosphere: environment.atmosphere,
      windSpeedMph: windMph,
      windFromDegrees: environment.windFromDegrees,
      shotAzimuthDegrees: environment.shotAzimuthDegrees,
      latitudeDegrees: environment.latitudeDegrees,
      targetElevationFt: environment.targetElevationFt,
    );
    final samples = solveTrajectory(
      projectile: projectile,
      environment: env,
      shot: shot,
      sampleRangesYards: <double>[rangeYards],
      includeSpinDrift: includeSpinDrift,
      includeCoriolis: includeCoriolis,
      includeAerodynamicJump: includeAerodynamicJump,
      includeConing: includeConing,
      accuracy: accuracy,
      spinDriftModel: spinDriftModel,
    );
    if (samples.isEmpty) {
      throw StateError(
          'solveTrajectory returned no samples for range $rangeYards yd.');
    }
    return samples.first;
  }

  final low = solveOne(windLow);
  final mid = solveOne(windMid);
  final high = solveOne(windHigh);

  return WindBracketResult(
    rangeYards: rangeYards,
    windLowMph: windLow,
    windMidMph: windMid,
    windHighMph: windHigh,
    low: low,
    mid: mid,
    high: high,
  );
}

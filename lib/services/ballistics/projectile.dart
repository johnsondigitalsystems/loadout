// FILE: lib/services/ballistics/projectile.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// This file defines `Projectile`, the immutable bundle of physical and
// aerodynamic properties that describes the bullet leaving the muzzle.
// The solver reads from a `Projectile` instance during every integration
// step. Construction takes American sporting units (inches, grains); the
// SI-projection getters convert to metres and kilograms once.
//
// Public class:
//
//   * `class Projectile` — required fields:
//       - `diameterIn` — bullet diameter in inches (e.g. 0.308 for a
//         30-caliber bullet, 0.224 for a 22-caliber).
//       - `weightGr`   — bullet mass in grains (1 grain = 1/7000 lb;
//         a 168 gr Sierra MatchKing is a typical .308 match bullet).
//       - `bc`         — ballistic coefficient (a single number that
//         scales the standard drag curve to match the real bullet's drag).
//       - `dragModel`  — which standard drag family the BC is referenced
//         against (G1, G7, etc. — see drag_functions.dart).
//
//     Optional fields:
//       - `lengthIn`     — bullet length in inches. Required for the
//         Miller stability calculation, optional otherwise.
//       - `twistInches`  — barrel twist rate, e.g. `8.0` means 1 turn
//         per 8 inches ("1:8 twist"). Required for spin drift and
//         stability.
//
//   * SI-projection getters (computed lazily, no allocation):
//       - `diameterM`         — diameter in meters.
//       - `massKg`            — mass in kilograms.
//       - `sectionalDensity`  — mass(lb) / diameter(in)². A core
//         dimensional quantity in ballistics — high SD = long, dense
//         bullet = retains velocity.
//       - `formFactor`        — sectionalDensity / BC. The "i" the
//         drag-equation literature uses; ~1.0 means the bullet matches
//         the reference shape well.
//
//   * Per-shot calculations:
//       - `initialSpinRadPerSec(muzzleVelocityFps)` — angular velocity
//         about the bore axis at the muzzle, in radians per second.
//         Returns 0 if `twistInches` is missing.
//       - `millerStability(muzzleVelocityFps)` — Miller stability factor
//         Sg with velocity correction. Returns null if either `lengthIn`
//         or `twistInches` is missing.
//
// ============================================================================
// THE PHYSICS / MATH
// ============================================================================
// ----------------------------------------------------------------------------
// SECTIONAL DENSITY (SD) AND FORM FACTOR (i)
// ----------------------------------------------------------------------------
// SECTIONAL DENSITY is just mass divided by frontal area, expressed in the
// ballistics convention as lb/in²:
//
//     SD = m_lb / D_in²
//
// A 168-grain .308 (D=0.308") has SD = (168/7000) / 0.308² ≈ 0.253. A
// short, fat 240-grain .44 Magnum (D=0.429") has SD ≈ 0.186. Higher SD
// means the bullet has more mass per unit of frontal area, so for a given
// drag-coefficient curve it decelerates more slowly.
//
// FORM FACTOR i = SD / BC. The form factor captures how the real bullet's
// shape differs from the reference standard (G1, G7, etc.). A perfectly
// shape-matched bullet has i ≈ 1. A typical 30-cal boat-tail VLD might
// have i_G7 ≈ 0.95 (slightly slipperier than the G7 standard) or
// i_G1 ≈ 0.46 (much slipperier than the G1 standard, which has a much
// blunter ogive). The drag literature writes the drag equation in terms
// of (i × Cd_std), where i scales the reference Cd up or down to fit the
// real bullet.
//
// ----------------------------------------------------------------------------
// SPIN RATE AT THE MUZZLE
// ----------------------------------------------------------------------------
// A rifled barrel has lands and grooves cut in a helix. Twist rate is
// expressed as inches PER turn: "1:8" means one full revolution every
// 8 inches of barrel length. As the bullet exits at velocity v (fps), it
// is spinning at:
//
//     revolutions/sec = v_fps × 12 / twist_in
//
// (the 12 converts the bullet's velocity from fps into in/sec, then
// dividing by twist gives turns per second). Multiplying by 2π gives
// angular velocity in rad/s. A 168gr .308 at 2700 fps from a 1:10 twist
// is spinning at 2700×12/10 = 3240 rev/sec = ~194 400 rpm.
//
// ----------------------------------------------------------------------------
// MILLER STABILITY FACTOR (Sg)
// ----------------------------------------------------------------------------
// A bullet is gyroscopically stable if it's spinning fast enough that
// aerodynamic disturbances cannot tumble it. Don Miller's empirical
// formula (Precision Shooting Magazine, March 2005) gives:
//
//                30 · m_gr
//     Sg =  ─────────────────────────
//           t² · d³ · l · (1 + l²)
//
// where:
//   m_gr = bullet mass in grains
//   t    = twist rate, expressed in CALIBERS per turn (twist_in / d_in)
//   d    = bullet diameter, inches
//   l    = bullet length in CALIBERS (length_in / d_in)
//
// The result is dimensionless. Rules of thumb:
//   Sg < 1.0   bullet will tumble (fail to stabilize)
//   Sg 1.0-1.4 marginal — accuracy may suffer, BC degrades
//   Sg > 1.5   solidly stable — good accuracy
//
// Miller's velocity correction adjusts Sg for muzzle velocity: the formula
// above assumes 2800 fps; for other velocities multiply by:
//
//     velCorr = (V_fps / 2800)^(1/3)
//
// because gyroscopic stability scales with spin rate (which scales with
// muzzle velocity for a fixed twist). The cube-root is empirical: it
// captures the weak dependence between MV and stability.
//
// We multiply the basic Sg by `velCorr` before returning, so the caller
// sees the realistic stability number at the rifle's actual muzzle
// velocity rather than a number that assumes 2800 fps.
//
// ----------------------------------------------------------------------------
// REFERENCES
// ----------------------------------------------------------------------------
//   * Don Miller, "A New Rule for Estimating Rifling Twist", Precision
//     Shooting Magazine, March 2005.
//   * industry-standard, "Applied Ballistics for Long-Range Shooting" — chapter
//     on stability has worked examples.
//   * McCoy, "Modern Exterior Ballistics" — chapter 9 derives the more
//     complete stability theory from the moments of inertia.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Layered above `units.dart` and `drag_functions.dart`. Has no knowledge
// of the environment (atmosphere, wind), only of the bullet itself.
// Imported by `solver.dart`. Keeping it independent from `Environment`
// lets the same `Projectile` be used across multiple atmospheric
// scenarios (the user can compare "shooting this load at 5000 ft elevation
// vs sea level" without reconstructing the bullet).
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Sectional density formula uses POUNDS / IN². Mixing kg or grams
//     here will give numerically reasonable but physically wrong values
//     (units don't cancel). The grain-to-lb conversion (÷ 7000) is the
//     right thing.
//
//   * Miller's twist `t` is in CALIBERS not inches. `t = twist_in / d_in`.
//     A 1:8 twist for a .308 (d=0.308) gives t = 8/0.308 ≈ 25.97 calibers.
//     We compute this internally; the constructor takes inches.
//
//   * `lengthIn` is OPTIONAL because not every bullet manufacturer
//     publishes length. Without length, we can't compute Miller stability,
//     so we return null and the solver falls back to a simpler spin-drift
//     approximation that doesn't require Sg.
//
//   * Spin drift requires both `lengthIn` AND `twistInches`. The solver's
//     `if (sg != null && projectile.twistInches != null)` guard catches
//     this — if either is missing, the trajectory comes out without spin
//     drift applied.
//
//   * `formFactor` is reported but never directly stored; it's derived on
//     each access. That's intentional — the user enters a BC, not a form
//     factor, and we want the form factor to track BC if the user changes
//     it.
//
//   * Sign convention: `initialSpinRadPerSec` returns a positive number
//     and assumes RIGHT-HAND TWIST (the dominant convention for American
//     rifles — barrels rifled to spin the bullet clockwise as viewed from
//     behind). Left-hand twist barrels exist but are rare; spin drift
//     direction in the solver assumes right-hand twist.
//
//   * Negative or zero twist values are guarded by the `if (t == null ||
//     t <= 0)` checks. A pathologically large twist (e.g. 1:100) would
//     give a numerically valid but physically silly Sg << 1.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   - lib/services/ballistics/solver.dart  (uses massKg, diameterM,
//                                            formFactor for the drag
//                                            constant; calls
//                                            millerStability and
//                                            initialSpinRadPerSec for
//                                            spin drift)
//   - any future UI screen that displays bullet stats / form factor /
//     stability factor.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. `Projectile` is immutable; all getters are pure computations.
// ============================================================================

/// Bullet definition consumed by the ballistic solver.
library;

import 'dart:math' as math;

import 'custom_drag.dart';
import 'drag_functions.dart';
import 'units.dart';

/// Physical and aerodynamic properties of the bullet leaving the muzzle.
class Projectile {
  Projectile({
    required this.diameterIn,
    required this.weightGr,
    required this.bc,
    required this.dragModel,
    this.lengthIn,
    this.twistInches,
    this.customDragCurve,
  });

  /// Bullet diameter, inches.
  final double diameterIn;

  /// Bullet weight, grains.
  final double weightGr;

  /// Ballistic coefficient in the [dragModel] family. Ignored when
  /// [customDragCurve] is non-null because the custom curve already
  /// expresses the bullet's actual Cd-vs-Mach relationship and there is
  /// no reference projectile to scale against.
  ///
  /// Typical values:
  ///   * G1: 0.3–0.7 for hunting bullets, up to ~0.8 for VLDs.
  ///   * G7: 0.15–0.4 — roughly half the G1 number for the same bullet.
  final double bc;

  /// Drag function family the [bc] is referenced against. Ignored when
  /// [customDragCurve] is non-null.
  final DragModel dragModel;

  /// Bullet length, inches. Optional — used only for the Miller spin
  /// stability formula. If null, the Miller calc is skipped (the user
  /// won't see a stability factor; spin drift falls back to the
  /// muzzle-twist-only industry standard approximation).
  final double? lengthIn;

  /// Barrel twist rate in inches per turn (e.g. `8.0` for "1:8").
  /// Required for spin drift.
  final double? twistInches;

  /// Optional custom drag curve (CDM / DSF). When non-null the solver
  /// uses this curve instead of the [dragModel] G-table, and treats
  /// [formFactor] as 1.0 (the curve already captures the bullet's
  /// real shape, so there is no reference projectile to scale against).
  final CustomDragCurve? customDragCurve;

  /// True when this projectile is configured with a custom drag curve.
  /// Convenience flag for the solver and UI.
  bool get hasCustomDrag => customDragCurve != null;

  // ─────────────────────── SI projections ───────────────────────

  double get diameterM => inchesToMeters(diameterIn);
  double get massKg => grainsToKg(weightGr);

  /// Sectional density (lb/in²). Standard form: SD = m_lb / D_in².
  double get sectionalDensity {
    final mLb = weightGr / 7000.0;
    return mLb / (diameterIn * diameterIn);
  }

  /// Form factor `i` used by the drag-equation literature.
  ///
  /// For the standard G1/G7-style path: `i = SD / BC` — the BC is
  /// referenced against a reference projectile, and `i` scales the
  /// reference Cd up or down to fit the real bullet.
  ///
  /// For a custom drag curve there is no reference projectile (the
  /// curve already represents the actual bullet), so the form-factor
  /// scaling collapses to 1.0. The drag-constant arithmetic in
  /// `solver.dart` treats `i = 1` correctly: `dragK = (π/8)·i·D²/m`,
  /// and the Cd value coming from the custom curve is the bullet's
  /// own Cd, not a scaled reference value.
  double get formFactor {
    if (customDragCurve != null) return 1.0;
    return sectionalDensity / bc;
  }

  /// Form factor referenced explicitly to the **G7 standard projectile**
  /// (i7).
  ///
  /// industry-standard argues form factor is a more honest single-number
  /// efficiency metric than BC, because BC normalizes by sectional
  /// density (mass / diameter²) and therefore makes a heavy bullet
  /// look "better" than a lighter bullet with identical drag. The
  /// form factor `i7 = SD / BC_G7` removes the SD weighting and
  /// directly compares the bullet's drag to the G7 reference shape:
  ///
  ///   * `i7 < 1.0` — bullet drags less than the G7 standard
  ///     (efficient match / VLD shape).
  ///   * `i7 ≈ 1.0` — bullet drags about the same as the G7 standard.
  ///   * `i7 > 1.0` — bullet drags more than the G7 standard (typical
  ///     of hunting bullets with wider meplat / less-tapered ogive).
  ///
  /// Worked example: a 6.5 mm 140 gr ELD-Match (G7 BC 0.326,
  /// D = 0.264″):
  ///   SD = 140 / 7000 / 0.264² ≈ 0.287
  ///   i7 = 0.287 / 0.326 ≈ 0.881 — about 12% slipperier than G7.
  ///
  /// Returns `double.nan` when the underlying G7 BC is unavailable
  /// (the projectile was built around a G1 BC, or the diameter /
  /// weight inputs are degenerate). Callers MUST check
  /// `formFactorI7.isNaN` before displaying — we never invent an i7
  /// for a G1-only load.
  double get formFactorI7 {
    if (diameterIn <= 0 || weightGr <= 0) return double.nan;
    if (customDragCurve != null) return double.nan;
    if (dragModel != DragModel.g7) return double.nan;
    if (bc <= 0) return double.nan;
    final sd = weightGr / 7000.0 / (diameterIn * diameterIn);
    return sd / bc;
  }

  /// Initial spin rate at the muzzle (rad/s) given [muzzleVelocityFps].
  /// Returns 0 if [twistInches] is null (we have no twist information).
  double initialSpinRadPerSec(double muzzleVelocityFps) {
    final t = twistInches;
    if (t == null || t <= 0) return 0;
    // 1 turn per `t` inches, bullet travels `v` fps → revolutions per
    // second = v(fps) × 12 / t. Multiply by 2π for rad/s.
    return muzzleVelocityFps * 12.0 / t * 2.0 * math.pi;
  }

  /// Miller stability factor (Sg). Returns null if [lengthIn] or
  /// [twistInches] is missing.
  ///
  /// Reference: Miller, "A New Rule for Estimating Rifling Twist",
  /// Precision Shooting Magazine, March 2005.
  double? millerStability(double muzzleVelocityFps) {
    final L = lengthIn;
    final T = twistInches;
    if (L == null || T == null || T <= 0) return null;
    final m = weightGr;
    final d = diameterIn;
    // Bullet length in calibers.
    final l = L / d;
    final sg = (30.0 * m) /
        (math.pow(T / d, 2) * math.pow(d, 3) * l * (1.0 + l * l));
    // Velocity correction (Miller): factor up by (V/2800)^(1/3).
    final velCorr = math.pow(muzzleVelocityFps / 2800.0, 1.0 / 3.0);
    return sg * velCorr;
  }

  /// Pejsa stability factor (Sg) — Pejsa's modified-Greenhill form
  /// re-cast in Miller's variables. Returns null if [lengthIn] or
  /// [twistInches] is missing or non-positive.
  ///
  /// Pejsa derives a stability rule in *Modern Practical Ballistics*
  /// (Kenwood Publishing, 1992; ch. on bullet stability) that uses
  /// the same geometric variables as Miller but with a reduced
  /// ogive-shape weight on the length term (`1 + 0.95 · l²` vs
  /// Miller's `1 + l²`). The reduction traces to Pejsa's
  /// derivation from steady-state yaw-of-repose data, where the
  /// tail of a long VLD contributes slightly less to gyroscopic
  /// stability than Miller's purely empirical tabular fit suggests:
  ///
  ///                    30 · m_gr
  ///     Sg = ────────────────────────────────────  · velCorr
  ///          t² · d³ · l · (1 + 0.95 · l²)
  ///
  /// where:
  ///   * t = T_in / d_in — twist rate in calibers per turn
  ///   * l = L_in / d_in — bullet length in calibers
  ///   * d = bullet diameter in inches (raw)
  ///   * m = bullet mass in grains
  ///   * velCorr = (V_fps / 2800)^(1/3) — same Miller velocity
  ///     correction so the two readouts are directly comparable on
  ///     the same muzzle-velocity axis.
  ///
  /// Empirically the two formulas agree to within ~5–10% for typical
  /// rifle bullets in their stable regime. Pejsa runs slightly higher
  /// than Miller across the typical match-bullet range because the
  /// reduced l² weight makes the length-induced de-stabilization a
  /// bit gentler. They diverge at the edges — very long VLDs,
  /// marginal twist, unusual mass-to-length ratios — where neither
  /// closed-form is fully reliable. Surfacing both lets the shooter
  /// cross-check: if both return Sg > 1.4 the load is confidently
  /// stable; if they disagree noticeably the bullet is in a regime
  /// where the loader should pull a longer test string before
  /// trusting the chrono.
  ///
  /// Worked example (6.5 mm 140 gr ELD-M, 1:8 twist, L = 1.355 in,
  /// MV = 2710 fps): Sg_pejsa ≈ 1.84, Sg_miller ≈ 1.75 — within
  /// ~5% as expected.
  ///
  /// References:
  ///   * Pejsa, A.J., *Modern Practical Ballistics*, Kenwood
  ///     Publishing, 1992 — chapter on bullet stability.
  ///   * industry-standard, *Applied Ballistics for Long-Range Shooting*,
  ///     ch. 10 — cross-references the Pejsa form against Miller
  ///     for an array of match bullets.
  double? pejsaStability(double muzzleVelocityFps) {
    final L = lengthIn;
    final T = twistInches;
    if (L == null || T == null || T <= 0) return null;
    if (diameterIn <= 0 || weightGr <= 0 || L <= 0) return null;
    final m = weightGr;
    final d = diameterIn;
    final t = T / d; // twist in calibers per turn
    final l = L / d; // bullet length in calibers
    final denom =
        (t * t) * (d * d * d) * l * (1.0 + 0.95 * l * l);
    if (denom <= 0) return null;
    final sg = (30.0 * m) / denom;
    // Same velocity correction as Miller — both formulas calibrate
    // at ~2800 fps muzzle, both scale weakly with spin rate, and we
    // want the two readouts comparable on the same axes.
    final velCorr = math.pow(muzzleVelocityFps / 2800.0, 1.0 / 3.0);
    return sg * velCorr;
  }
}

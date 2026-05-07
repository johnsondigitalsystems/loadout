// FILE: lib/services/ballistics/custom_drag.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Implements `CustomDragCurve` — a user- or manufacturer-supplied table of
// `(mach, cd)` pairs that the ballistic solver can use *in place of* the
// built-in G1/G2/G5/G6/G7/G8 reference curves in `drag_functions.dart`.
//
// "Custom drag" curves are how modern long-range bullet vendors deliver
// drag data with much higher fidelity than a single-number BC against a
// generic reference shape. Two flavours of custom curve exist in the wild:
//
//   * **CDM** — "Custom Drag Model". Berger publishes these as
//     downloadable files (e.g. for the Applied Ballistics solver). A CDM
//     file is essentially a (mach, Cd) table specific to one bullet, where
//     the Cd values come from Doppler radar measurements rather than a
//     standard projectile + form factor.
//
//   * **DSF** — "Drag Scale Factor", or sometimes "drag-scaled function".
//     Hornady's 4DOF tool publishes these. The numbers express the same
//     idea — a per-bullet Cd vs Mach curve sampled densely enough that
//     no separate BC is needed.
//
// Either way, the math the solver does is the same as for G1/G7: look up
// Cd at the current Mach number, plug it into
// `F_drag = (π/8) ρ v² i Cd D²`. The only difference is that with a
// custom curve there is no reference projectile to scale against, so the
// "form factor i" the solver uses collapses to 1.0 — the curve already
// captures the bullet's actual shape. That collapse is the reason the
// Projectile.bc field becomes a no-op when a CustomDragCurve is supplied;
// see `solver.dart`.
//
// Public API:
//
//   * `class CustomDragCurve` — immutable holder for a sorted list of
//     `(mach, cd)` pairs plus identifying metadata. Constructed by
//     reading the user's chosen drift `DragCurveRow` (loaded from
//     `assets/seed_data/drag_curves/*.json` at first launch).
//
//     - `factory CustomDragCurve.fromPoints({required name, required
//        List<({double mach, double cd})> points})` — the primary
//        constructor. Sorts the input by mach ascending and validates
//        that every Cd is positive and finite.
//     - `factory CustomDragCurve.fromDatapointsJson({required name,
//        required String json})` — parser for the `datapointsJson`
//        column in the `DragCurves` drift table.
//     - `dragCoefficient(double mach)` — same shape as
//       `dragCoefficient(DragModel, double)` from `drag_functions.dart`:
//       linearly interpolated, clamped at the table edges.
//     - `tabulatedRange()` — `({double low, double high})` of the table's
//       Mach extent, mirroring the helper in `drag_functions.dart`.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Lives next to `drag_functions.dart` so the solver can swap one for the
// other. The solver's `_derivative` method picks between
// `dragCoefficient(model, mach)` and `customCurve.dragCoefficient(mach)`
// based on whether the Projectile carries a `customDragCurve`. Keeping
// the API shapes identical means the conditional inside the integration
// loop is a single branch, not a redesign.
//
// Stored data flows: drift `DragCurves` table → `DragCurveRepository`
// → ballistics screen UI → `CustomDragCurve` factory → `Projectile`
// → solver.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Sort order matters. `_interp` binary-searches the table by Mach,
//     so the points list MUST be sorted ascending. The `fromPoints`
//     factory does this defensively in case a JSON file ships entries
//     out of order.
//
//   * Empty / single-point tables are guarded. An empty curve returns
//     0.0 for any Mach, a single-point curve returns that single Cd
//     for any Mach. Neither is physically meaningful but the solver
//     should not divide-by-zero or crash.
//
//   * Clamping at the table edges. Real Doppler data typically covers
//     Mach 0.0–3.0 or so — beyond that, manufacturers stop publishing
//     because subsonic bullets aren't useful and small arms don't
//     reach hypersonic. We clamp to the first / last sample, matching
//     what `drag_functions.dart` does for the G-tables. The solver's
//     existing 100-fps subsonic cutoff and 10-second flight cap handle
//     edge cases beyond that.
//
//   * The form-factor collapse. With a single-number BC against G7 you
//     get `i = SD/BC`; the solver multiplies the Cd from the G7 table
//     by `i`. With a custom curve, the table already represents the
//     real bullet — there is no separate reference shape to scale
//     against — so the effective `i` is 1.0. The Projectile class
//     handles this by returning `1.0` from `formFactor` whenever a
//     CustomDragCurve is set; see `projectile.dart`.
//
//   * BCs and custom curves are mutually exclusive on a given shot.
//     The UI hides the BC field when a custom curve is selected,
//     specifically so the user can't enter a BC that does nothing.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   - lib/services/ballistics/projectile.dart  (Projectile.customDragCurve
//                                                field)
//   - lib/services/ballistics/solver.dart      (calls dragCoefficient
//                                                inside `_derivative`)
//   - lib/repositories/drag_curve_repository.dart (loads rows + builds
//                                                  CustomDragCurve from
//                                                  drift)
//   - lib/screens/ballistics/ballistics_screen.dart (custom curve picker
//                                                    UI)
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure data + interpolation. No I/O, no globals, no allocations
// beyond the stored point list (which is itself unmodifiable).
// ============================================================================

/// User- or manufacturer-supplied drag curve. Mirrors the API shape of
/// `dragCoefficient(DragModel, double)` so the solver can swap in either
/// flavour without touching its integration loop.
library;

import 'dart:convert';

class CustomDragCurve {
  CustomDragCurve._({
    required this.name,
    required this.manufacturer,
    required this.line,
    required this.weightGr,
    required this.diameterIn,
    required List<({double mach, double cd})> points,
  }) : _points = points;

  /// Primary constructor. Sorts the supplied points by Mach ascending
  /// and rejects entries with non-finite or non-positive Cd values.
  factory CustomDragCurve.fromPoints({
    required String name,
    String? manufacturer,
    String? line,
    double? weightGr,
    double? diameterIn,
    required List<({double mach, double cd})> points,
  }) {
    // Defensive copy so the caller can't mutate the table after
    // construction. We sort by Mach so `_interp` can binary-search.
    final sorted = List<({double mach, double cd})>.of(points)
      ..sort((a, b) => a.mach.compareTo(b.mach));
    for (final p in sorted) {
      if (!p.cd.isFinite || p.cd <= 0) {
        throw ArgumentError(
          'CustomDragCurve "$name" has non-finite or non-positive Cd '
          '${p.cd} at Mach ${p.mach}',
        );
      }
      if (!p.mach.isFinite || p.mach < 0) {
        throw ArgumentError(
          'CustomDragCurve "$name" has invalid Mach ${p.mach}',
        );
      }
    }
    return CustomDragCurve._(
      name: name,
      manufacturer: manufacturer,
      line: line,
      weightGr: weightGr,
      diameterIn: diameterIn,
      points: List.unmodifiable(sorted),
    );
  }

  /// Parses a `datapointsJson` column from the [DragCurves] drift table.
  /// The expected shape is a JSON array of `{"mach": x, "cd": y}` objects.
  factory CustomDragCurve.fromDatapointsJson({
    required String name,
    String? manufacturer,
    String? line,
    double? weightGr,
    double? diameterIn,
    required String datapointsJson,
  }) {
    final raw = json.decode(datapointsJson) as List<dynamic>;
    final points = <({double mach, double cd})>[];
    for (final entry in raw) {
      final m = entry as Map<String, dynamic>;
      final mach = (m['mach'] as num).toDouble();
      final cd = (m['cd'] as num).toDouble();
      points.add((mach: mach, cd: cd));
    }
    return CustomDragCurve.fromPoints(
      name: name,
      manufacturer: manufacturer,
      line: line,
      weightGr: weightGr,
      diameterIn: diameterIn,
      points: points,
    );
  }

  /// Human-readable name (e.g. "Berger 6.5mm 140gr Hybrid Target").
  final String name;

  /// Manufacturer / brand. Optional; informational only.
  final String? manufacturer;

  /// Bullet line / model name. Optional; informational only.
  final String? line;

  /// Bullet mass in grains. Optional; informational only — the solver
  /// reads mass from the Projectile, not from here.
  final double? weightGr;

  /// Bullet diameter in inches. Optional; informational only — the
  /// solver reads diameter from the Projectile, not from here.
  final double? diameterIn;

  /// Sorted list of `(mach, cd)` pairs. Unmodifiable.
  final List<({double mach, double cd})> _points;

  /// Read-only accessor for the underlying table — useful for charting
  /// and debugging.
  List<({double mach, double cd})> get points => _points;

  /// Returns the drag coefficient at the supplied [mach] number, linearly
  /// interpolated between adjacent samples. Clamps below the first and
  /// above the last sample.
  ///
  /// Mirrors the API shape of
  /// `dragCoefficient(DragModel, double)` from `drag_functions.dart`.
  double dragCoefficient(double mach) {
    if (_points.isEmpty) return 0.0;
    if (_points.length == 1) return _points.first.cd;
    if (mach <= _points.first.mach) return _points.first.cd;
    if (mach >= _points.last.mach) return _points.last.cd;
    // Binary search for the bracketing pair.
    var lo = 0;
    var hi = _points.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (_points[mid].mach <= mach) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final m0 = _points[lo].mach;
    final cd0 = _points[lo].cd;
    final m1 = _points[hi].mach;
    final cd1 = _points[hi].cd;
    final t = (mach - m0) / (m1 - m0);
    return cd0 + t * (cd1 - cd0);
  }

  /// Mach range the table covers. Useful for sanity checks and for the
  /// UI to show "this curve is valid Mach 0.5 – 3.0".
  ({double low, double high}) tabulatedRange() {
    if (_points.isEmpty) return (low: 0.0, high: 0.0);
    return (low: _points.first.mach, high: _points.last.mach);
  }
}

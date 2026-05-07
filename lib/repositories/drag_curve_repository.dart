// FILE: lib/repositories/drag_curve_repository.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Bridges the `DragCurves` drift table with the ballistics screen UI and
// the solver. Provides:
//
//   * `allCurves()` — every drag curve in the catalog, ordered by
//     (manufacturer, line, diameter, weight). Used by the calculator's
//     "Custom drag curve" picker.
//   * `watchCurves()` — live stream of the same set, for any future UI
//     that wants to react to seed-loader updates.
//   * `getById(id)` — single-row lookup. The picker stores only the id
//     of the user's selected curve in app state; this getter resolves
//     that back to a row when the user taps Calculate.
//   * `findCurveForBullet({manufacturer, line, weightGr, diameterIn})`
//     — returns the curve (if any) that matches a `BulletRow`. Used by
//     the bullet picker to surface a "Custom drag available" badge
//     when the user selects a bullet that has a published CDM/DSF.
//   * `toCustomDragCurve(DragCurveRow)` — static helper that constructs
//     a `CustomDragCurve` from a drift row by JSON-decoding
//     `datapointsJson`.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Mirror of `OpticsRepository` and `ReticleRepository` — a thin layer
// that owns all queries against one reference table. Keeping the
// JSON-decode + `CustomDragCurve` build in one place means the screen
// can call `repo.toCustomDragCurve(row)` and not know anything about
// the storage shape.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None beyond drift query I/O. All reads.

library;

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../services/ballistics/custom_drag.dart';

class DragCurveRepository {
  DragCurveRepository(this.db);
  final AppDatabase db;

  /// All curves in the catalog, ordered for the picker dropdown.
  Future<List<DragCurveRow>> allCurves() async {
    final rows = await (db.select(db.dragCurves)
          ..orderBy([
            (t) => OrderingTerm(expression: t.manufacturer),
            (t) => OrderingTerm(expression: t.line),
            (t) => OrderingTerm(expression: t.diameterIn),
            (t) => OrderingTerm(expression: t.weightGr),
          ]))
        .get();
    return rows;
  }

  /// Live stream variant of [allCurves].
  Stream<List<DragCurveRow>> watchCurves() {
    return (db.select(db.dragCurves)
          ..orderBy([
            (t) => OrderingTerm(expression: t.manufacturer),
            (t) => OrderingTerm(expression: t.line),
            (t) => OrderingTerm(expression: t.diameterIn),
            (t) => OrderingTerm(expression: t.weightGr),
          ]))
        .watch();
  }

  /// Single-row lookup by primary key.
  Future<DragCurveRow?> getById(int id) async {
    return (db.select(db.dragCurves)..where((t) => t.id.equals(id)))
        .getSingleOrNull();
  }

  /// Returns the catalog curve (if any) that matches a bullet's
  /// (manufacturer, line, weight, diameter). The matching is loose on
  /// diameter (±0.0015 in) to handle the small rounding differences
  /// between the bullets seed (`bcG7=0.327`) and the drag-curve seed
  /// (`diameter_in=0.264`). Returns null if no match exists.
  Future<DragCurveRow?> findCurveForBullet({
    required String manufacturer,
    required String line,
    required double weightGr,
    required double diameterIn,
  }) async {
    final rows = await (db.select(db.dragCurves)
          ..where((t) =>
              t.manufacturer.equals(manufacturer) & t.line.equals(line)))
        .get();
    if (rows.isEmpty) return null;
    DragCurveRow? best;
    var bestDelta = double.infinity;
    for (final r in rows) {
      final dWeight = (r.weightGr - weightGr).abs();
      final dDiam = (r.diameterIn - diameterIn).abs();
      // Hard filter: diameter must match within 0.0015" — diameters
      // jump in cartridge-family steps (0.243, 0.264, 0.284, ...) so a
      // mismatch here is almost certainly a different cartridge.
      if (dDiam > 0.0015) continue;
      // Weight should match within 0.5 gr — bullet weights are usually
      // integer grains, occasionally x.5 gr.
      if (dWeight > 0.5) continue;
      final delta = dDiam * 1000.0 + dWeight; // dimensional combine
      if (delta < bestDelta) {
        bestDelta = delta;
        best = r;
      }
    }
    return best;
  }

  /// Construct a [CustomDragCurve] from a drift row by JSON-decoding
  /// `datapointsJson`. Pure conversion — no I/O.
  static CustomDragCurve toCustomDragCurve(DragCurveRow row) {
    final name = '${row.manufacturer} ${row.line} '
        '${_caliberLabel(row.diameterIn)} ${_formatWeight(row.weightGr)}gr';
    return CustomDragCurve.fromDatapointsJson(
      name: name,
      manufacturer: row.manufacturer,
      line: row.line,
      weightGr: row.weightGr,
      diameterIn: row.diameterIn,
      datapointsJson: row.datapointsJson,
    );
  }

  /// Compose the display label for a curve in the calculator dropdown.
  static String displayLabel(DragCurveRow row) {
    return '${row.manufacturer} ${row.line} '
        '${_caliberLabel(row.diameterIn)} ${_formatWeight(row.weightGr)}gr';
  }

  static String _caliberLabel(double diameterIn) {
    bool nearly(double a, double b) => (a - b).abs() < 0.0015;
    if (nearly(diameterIn, 0.172)) return '.17';
    if (nearly(diameterIn, 0.204)) return '.204';
    if (nearly(diameterIn, 0.224)) return '.224';
    if (nearly(diameterIn, 0.243)) return '6mm';
    if (nearly(diameterIn, 0.257)) return '.257';
    if (nearly(diameterIn, 0.264)) return '6.5mm';
    if (nearly(diameterIn, 0.277)) return '.277';
    if (nearly(diameterIn, 0.284)) return '7mm';
    if (nearly(diameterIn, 0.308)) return '.308';
    if (nearly(diameterIn, 0.338)) return '.338';
    return diameterIn.toStringAsFixed(3);
  }

  static String _formatWeight(double w) {
    return w.toStringAsFixed(w.truncateToDouble() == w ? 0 : 1);
  }
}

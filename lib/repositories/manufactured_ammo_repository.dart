// FILE: lib/repositories/manufactured_ammo_repository.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Read-only repository over the [ManufacturedAmmo] reference table
// (schema v23). Surfaces the curated subset of factory loads — the
// ~17-row catalog that feeds the Range Day "Pick a common factory
// load" empty-state picker. Public API:
//
//   * `allRows()` — every row in the catalog, sorted in source order
//     (id ascending, which is also the JSON-file order). The picker
//     groups by cartridge for display, so we don't pre-sort by
//     cartridge here.
//   * `byId(id)` — single-row lookup by primary key.
//
// Distinct from [FactoryLoadRepository], which talks to the much
// larger [FactoryLoads] table (3 000+ rows scraped from manufacturer
// spec sheets and surfaced in the ballistics calculator's "Factory
// Ammo" picker). The two surfaces are intentionally separate — see
// the table-level comment on [ManufacturedAmmo] in `database.dart`.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Mirror of [DragCurveRepository] / [TargetRepository] — a thin layer
// owning queries against one reference table. Separating it from
// [FactoryLoadRepository] keeps the two factory-ammo surfaces honest:
//
//   * [Bullets] ↔ [ComponentRepository] — bullets-only entries (no
//     factory-ammo data). Drives recipes (which need a powder) and
//     ballistic profiles.
//   * [ManufacturedAmmo] ↔ this repository — full factory cartridges
//     with manufacturer-published MV / SD / BC. Drives ballistic
//     profiles + the Range Day common-loads picker. NEVER consumed
//     by recipe-form code.
//
// Callers consuming `Bullets` SHOULD NOT see [ManufacturedAmmo] rows,
// and vice versa. This repository's existence makes that contract
// surface-level rather than convention-level.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// Nothing tricky here — pure read-only queries, no caching, no joins.
// The catalog is small enough (~17 rows) that we don't bother with a
// `Stream` API; callers use one-shot reads and rebuild on the next
// frame.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/services/common_loads_catalog.dart` — the legacy
//   `CommonLoadsCatalog` API now reads from this repository instead
//   of the in-Dart constant list it used to ship.
// - `lib/screens/range_day/range_day_detail_screen.dart` — through
//   `CommonLoadsCatalog` (transitively).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Reads only. No INSERT / UPDATE / DELETE on the table.

import 'package:drift/drift.dart';

import '../database/database.dart';

class ManufacturedAmmoRepository {
  ManufacturedAmmoRepository(this.db);
  final AppDatabase db;

  /// Snapshot of every manufactured-ammo row, in source order
  /// (insertion order = JSON-file order). Soft-fail: returns an
  /// empty list rather than throwing if the underlying read fails
  /// (e.g. closed-DB during teardown). The picker tolerates an
  /// empty catalog by rendering an empty-state hint.
  Future<List<ManufacturedAmmoRow>> allRows() async {
    try {
      return await (db.select(db.manufacturedAmmo)
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();
    } catch (_) {
      // Soft-fail — see file header.
      return const <ManufacturedAmmoRow>[];
    }
  }

  /// Single-row lookup by primary key. Returns null when the id is
  /// not in the catalog (e.g. the user persisted an id that was
  /// later removed by a re-seed).
  Future<ManufacturedAmmoRow?> byId(int id) =>
      (db.select(db.manufacturedAmmo)..where((t) => t.id.equals(id)))
          .getSingleOrNull();
}

// FILE: lib/repositories/target_repository.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Owns reads against the [Targets] reference catalog AND the
// [TargetRacks] catalog. Both are seeded from JSON in
// `assets/seed_data/` on first launch (see `seed_loader.dart`); this
// repository never writes to either table.
//
// Single-target methods:
//   * `watchAll()` — live `Stream<List<TargetRow>>` of every seeded
//     target, naturally sorted by name (so "AR500 12 in" lands after
//     "AR500 8 in").
//   * `allTargets()` — one-shot snapshot version of `watchAll`.
//   * `getById(id)` — one-shot lookup of a single target.
//   * `getByShape(category)` — list filtered to one of the v9.5
//     category enum values (`circle | square | rectangle | ipsc |
//     animal | special`). Used by the Range Day filter chips above
//     the picker.
//
// Target-rack methods:
//   * `allRacks()` — every seeded rack, naturally sorted by name.
//   * `rackById(id)` — one-shot lookup of a single rack.
//   * `childrenOf(rackId)` — the rack's [RackSlot] list (read off the
//     inline `slotsJson` column on `TargetRacks`). Already sorted by
//     `position`. Used by the visual renderer + the active-slot picker.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The Range Day workspace renders both individual targets and multi-target
// racks. Keeping all of those reads behind one repository keeps the call
// sites short and the test seams obvious — every screen takes an
// `AppDatabase`-backed `TargetRepository` from `app.dart` and calls these
// methods directly, never `db.select(...)` inline.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// Before v40 the rack catalog had two physical tables (parent + children
// with an FK). Phase 9.5 Group C collapsed those into a single
// `TargetRacks` table where each rack's slot list rides inline as a
// JSON array (`RackSlotsConverter`). The rack envelope is still queried
// independently of the slots — but the slots are now a column read on
// the loaded row, not a separate SQL query. `childrenOf` is therefore
// `await rackById(id)` + a field read, which keeps the call shape
// identical for consumers but cuts one DB round-trip per rack render.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/screens/range_day/range_day_detail_screen.dart` — target + rack
//   pickers.
// - Anywhere a screen needs to display the seeded target / rack catalog.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Reads only. No INSERT / UPDATE / DELETE on either catalog table.

import '../database/database.dart';
import '../database/rack_slot.dart';
import '../utils/natural_sort.dart';

export '../database/rack_slot.dart' show RackSlot;

class TargetRepository {
  TargetRepository(this.db);
  final AppDatabase db;

  /// Streams every seeded target, naturally sorted by name. Re-emits
  /// when (rare) inserts happen via SeedLoader.
  Stream<List<TargetRow>> watchAll() {
    return db.select(db.targets).watch().map((rows) {
      final list = [...rows];
      list.sort((a, b) => naturalCompare(a.name, b.name));
      return list;
    });
  }

  /// Snapshot of every target, naturally sorted by name. Used by callers
  /// that just need the list once (e.g. the picker dropdown that renders
  /// inside a [DropdownMenu]).
  Future<List<TargetRow>> allTargets() async {
    final rows = await db.select(db.targets).get();
    final list = [...rows];
    list.sort((a, b) => naturalCompare(a.name, b.name));
    return list;
  }

  /// One-shot lookup by primary key.
  Future<TargetRow?> getById(int id) =>
      (db.select(db.targets)..where((t) => t.id.equals(id)))
          .getSingleOrNull();

  /// Filters by SHAPE (`circle | square | rectangle | silhouette |
  /// star | bear | boar | deer | elk | coyote`), naturally sorted by
  /// name. Used by the Range Day filter chips. Replaces the legacy
  /// `getByCategory` which keyed off the `category` column dropped in
  /// schema v28 (per user feedback: reloaders pick by geometry, not
  /// material).
  Future<List<TargetRow>> getByShape(String category) async {
    final rows = await (db.select(db.targets)
          ..where((t) => t.category.equals(category)))
        .get();
    final list = [...rows];
    list.sort((a, b) => naturalCompare(a.name, b.name));
    return list;
  }

  // ─────────────────────── Target racks ───────────────────────

  /// Every seeded rack, naturally sorted by name. Naturally-sorted so
  /// "10-Plate KYL" lands after "5-Plate KYL" — ASCII-sort would put
  /// it first because '1' < '5'.
  Future<List<TargetRackRow>> allRacks() async {
    final rows = await db.select(db.targetRacks).get();
    final list = [...rows];
    list.sort((a, b) => naturalCompare(a.name, b.name));
    return list;
  }

  /// One-shot lookup of a single rack by primary key. Returns null if
  /// the rack id was deleted (e.g. a stale id persisted on a session
  /// row that got re-seeded).
  Future<TargetRackRow?> rackById(int id) =>
      (db.select(db.targetRacks)..where((r) => r.id.equals(id)))
          .getSingleOrNull();

  /// Every slot in `rackId`, in position order (the rack's intended
  /// engagement sequence). Empty list when the rack has no slots OR
  /// when the rack id was deleted (e.g. a stale id persisted on a
  /// session row that got re-seeded) — caller should treat the empty
  /// case as a malformed seed entry, since every seeded rack ships
  /// at least one slot.
  ///
  /// v40 (Phase 9.5 Group C) — formerly an SQL query against the
  /// dropped `TargetRackChildren` table; now reads `slotsJson` off
  /// the rack row. The drift TypeConverter does the JSON parse + sort
  /// inline. Result is an unmodifiable `List<RackSlot>`.
  Future<List<RackSlot>> childrenOf(int rackId) async {
    final rack = await rackById(rackId);
    return rack?.slotsJson ?? const <RackSlot>[];
  }
}

// FILE: lib/repositories/atmosphere_preset_repository.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Owns all database operations for [AtmospherePresets], the user-saved
// atmospheric profile catalog (the "Applied Ballistics" pattern of
// named environment snapshots — "Camp Atterbury summer", "Big Sandy",
// "Cold dry day"). The underlying
// drift table is `AtmospherePresets` (defined in
// `lib/database/database.dart`); this file is the only Dart code that
// reads or writes it.
//
// Public methods on `AtmospherePresetRepository`:
//   * `watchAll()` — returns a live `Stream<List<AtmospherePresetRow>>` of
//     every preset, naturally sorted by name. The picker dropdowns and the
//     Manage Presets list view subscribe via `StreamBuilder` and rebuild
//     whenever a row is inserted, updated, or deleted.
//   * `getAll()` — one-shot snapshot of every preset, naturally sorted by
//     name. Used by callers that just need a snapshot rather than a live
//     stream (e.g. picker dropdowns embedded in screens that refresh
//     state on dispose / push).
//   * `getById(id)` — one-shot lookup of a single preset row. Returns
//     `null` if no row matches. Used by the form screen when the user
//     opens an existing preset to edit it, and by the Range Day detail
//     screen to resolve the saved `atmospherePresetId` back to a row.
//   * `insert(entry)` — insert a new preset; returns the new row's
//     primary key.
//   * `update(id, entry)` — update an existing preset. Auto-bumps the
//     `updatedAt` timestamp on the way through. Returns `true` if a row
//     was actually changed.
//   * `delete(id)` — hard-delete by primary key. Returns the number of
//     rows deleted (0 or 1).
//
// Note: the repository does NOT cascade-clear the
// `RangeDaySessions.atmospherePresetId` foreign key when a preset is
// deleted. The picker logic on the Range Day screen handles a missing /
// dangling preset id by resolving to "Custom" — an explicit cascade
// would needlessly bump every session's `updatedAt` and confuse Cloud
// Sync's last-writer-wins reconciliation.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Same repository pattern as the rest of the app. The screen widgets
// (`atmosphere_presets_screen.dart`, the picker rows on
// `ballistics_screen.dart` + `range_day_detail_screen.dart`) never call
// drift APIs directly — they call this repository, which centralizes
// the query construction (natural-sort by name) and the `updatedAt`
// bump rules.
//
// Constructed once in `lib/app.dart` and provided to the widget tree
// via `Provider<AtmospherePresetRepository>`. Screens read it with
// `context.read<AtmospherePresetRepository>()`.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * **Natural-sort happens in Dart, not SQL.** Drift's SQL ORDER
//     BY can't express the natural comparator (which treats embedded
//     numbers numerically: "Camp #2" sorts after "Camp #1" not
//     before "Camp #10"). The repository fetches unordered and
//     sorts in Dart — same pattern as `FirearmRepository.watchAll`.
//   * **No FK cascade on delete.** Deleting a preset deliberately
//     does NOT clear `RangeDaySessions.atmospherePresetId` — the
//     Range Day picker resolves a dangling id to "Custom" and the
//     session's `updatedAt` doesn't bump for an unrelated change.
//     Cascading would create cross-table churn that confuses Cloud
//     Sync's last-writer-wins reconciler.
//   * **Insert / update bump `updatedAt` automatically.** Cloud
//     Sync reads this column. A future "silent update" path that
//     bypasses the bump would stop the row from syncing.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/atmosphere/atmosphere_presets_screen.dart — the
//   manage-presets list + edit form.
// - lib/widgets/atmosphere_preset_picker.dart — picker sheet
//   embedded on Ballistics + Range Day Environment cards.
// - lib/screens/ballistics/ballistics_screen.dart + Range Day —
//   subscribe to `watchAll()` for the inline picker dropdown.
// - lib/app.dart — constructs and provides the singleton.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// Reads / writes against the local SQLite database via drift. No
// JSON encoding (every column is typed). No network. No shared
// preferences.

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../utils/natural_sort.dart';

/// CRUD over [AtmospherePresets], the user-saved atmospheric-profile
/// catalog. Sorted naturally by name so "Camp Atterbury #2" comes
/// after "Camp Atterbury #1", and "Big Sandy" sorts before
/// "Camp Atterbury" rather than between two letter-based names.
class AtmospherePresetRepository {
  AtmospherePresetRepository(this.db);
  final AppDatabase db;

  /// Streams every atmosphere preset, naturally sorted by name. Drift
  /// can't express the natural-sort comparator in SQL, so we fetch
  /// unordered and sort in Dart — same pattern as
  /// `FirearmRepository.watchAll()`.
  Stream<List<AtmospherePresetRow>> watchAll() {
    return db.select(db.atmospherePresets).watch().map(_naturalSorted);
  }

  /// One-shot snapshot of every atmosphere preset, naturally sorted by
  /// name. Used by callers (e.g. the inline picker in the Environment
  /// section) that need a synchronous snapshot rather than a live
  /// stream.
  Future<List<AtmospherePresetRow>> getAll() async {
    final rows = await db.select(db.atmospherePresets).get();
    return _naturalSorted(rows);
  }

  static List<AtmospherePresetRow> _naturalSorted(
      List<AtmospherePresetRow> rows) {
    final list = [...rows];
    list.sort((a, b) => naturalCompare(a.name, b.name));
    return list;
  }

  Future<AtmospherePresetRow?> getById(int id) =>
      (db.select(db.atmospherePresets)..where((p) => p.id.equals(id)))
          .getSingleOrNull();

  Future<int> insert(AtmospherePresetsCompanion entry) =>
      db.into(db.atmospherePresets).insert(entry);

  Future<bool> update(int id, AtmospherePresetsCompanion entry) =>
      (db.update(db.atmospherePresets)..where((p) => p.id.equals(id)))
          .write(entry.copyWith(updatedAt: Value(DateTime.now())))
          .then((rows) => rows > 0);

  Future<int> delete(int id) =>
      (db.delete(db.atmospherePresets)..where((p) => p.id.equals(id))).go();
}

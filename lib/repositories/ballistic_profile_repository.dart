// FILE: lib/repositories/ballistic_profile_repository.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Owns all database operations for `BallisticProfiles`, the table added in
// schema v8 that stores the user's named, reusable ballistics-calculator
// configurations. A "profile" is one labeled bundle of projectile,
// muzzle/zero, environment defaults, and range-output preferences — e.g.
// "6.5 CM 140gr ELD-M Tikka" or "300 PRC 225gr Hornady".
//
// Public methods:
//   * `watchAll()` — live `Stream<List<BallisticProfileRow>>`,
//     naturally sorted by name so "Profile 2" sorts after "Profile 1".
//   * `getById(id)` — one-shot lookup.
//   * `insert(entry)` — insert; returns the new row id.
//   * `update(id, entry)` — update; auto-bumps `updatedAt`. Returns true
//     when a row changed.
//   * `delete(id)` — hard delete; returns row count.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Same repository pattern as `FirearmRepository`. The ballistics screen
// and any future profile-list UI never call drift APIs directly — they
// reach into this repository, which centralizes the natural-sort
// ordering and `updatedAt` bump rules.
//
// Constructed in `lib/app.dart` and provided to the widget tree via
// `Provider<BallisticProfileRepository>`. Screens reach it with
// `context.read<BallisticProfileRepository>()`.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/screens/ballistics/ballistics_screen.dart — the profile picker
//   above the calculator inputs reads `watchAll()` for its dropdown
//   options and writes new/updated profiles via `insert` / `update` /
//   `delete`.
// - lib/app.dart — constructs and provides the singleton.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// Reads and writes against the local SQLite database via drift. No JSON
// encoding. No cross-table cascades. No network. No shared preferences.

import 'package:drift/drift.dart';

import '../database/database.dart';
import '../utils/natural_sort.dart';

class BallisticProfileRepository {
  BallisticProfileRepository(this.db);
  final AppDatabase db;

  /// Streams every saved profile, naturally sorted by name (so
  /// "Profile 2" lands after "Profile 1" rather than between
  /// "Profile 10" and "Profile 11"). Drift can't express the
  /// natural-sort comparator in SQL, so we fetch unordered and sort
  /// in Dart.
  Stream<List<BallisticProfileRow>> watchAll() {
    return db.select(db.ballisticProfiles).watch().map((rows) {
      final list = [...rows];
      list.sort((a, b) => naturalCompare(a.name, b.name));
      return list;
    });
  }

  Future<BallisticProfileRow?> getById(int id) =>
      (db.select(db.ballisticProfiles)..where((p) => p.id.equals(id)))
          .getSingleOrNull();

  Future<int> insert(BallisticProfilesCompanion entry) =>
      db.into(db.ballisticProfiles).insert(entry);

  Future<bool> update(int id, BallisticProfilesCompanion entry) =>
      (db.update(db.ballisticProfiles)..where((p) => p.id.equals(id)))
          .write(entry.copyWith(updatedAt: Value(DateTime.now())))
          .then((rows) => rows > 0);

  Future<int> delete(int id) =>
      (db.delete(db.ballisticProfiles)..where((p) => p.id.equals(id))).go();

  /// Flip the per-row [BallisticProfiles.isFavorite] boolean (added
  /// schema v24). Returns the new state (`true` = now favorited,
  /// `false` = now un-favorited). Returns `false` if no row matches
  /// [id]. Auto-bumps `updatedAt` so the profile picker re-sorts to
  /// keep the freshly-toggled row visible. Powers the star icon the
  /// picker UI agent will wire up.
  Future<bool> toggleFavorite(int id) async {
    final row =
        await (db.select(db.ballisticProfiles)..where((p) => p.id.equals(id)))
            .getSingleOrNull();
    if (row == null) return false;
    final next = !row.isFavorite;
    await (db.update(db.ballisticProfiles)..where((p) => p.id.equals(id)))
        .write(
      BallisticProfilesCompanion(
        isFavorite: Value(next),
        updatedAt: Value(DateTime.now()),
      ),
    );
    return next;
  }
}

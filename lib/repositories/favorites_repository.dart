// FILE: lib/repositories/favorites_repository.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Owns all database operations for [UserFavorites], the join table added
// in schema v24 that stores the user's "starred" reference-data rows.
// Reference data (cartridges, reticles, targets, and any future read-only
// catalog) ships as seed-loaded rows the user can't mutate, so its
// favorite flag can't live on the row itself. Instead, every (entityType,
// entityId) pair the user has favorited gets one row in this table; the
// uniqueness constraint on that pair keeps duplicates out and lets
// `toggleFavorite` round-trip a read-then-write under a single
// transaction without race-condition risk.
//
// User-data tables (UserLoads, UserFirearms, BallisticProfiles) keep
// their own per-row `isFavorite` boolean column, exposed via
// `RecipeRepository.toggleFavorite`, `FirearmRepository.toggleFavorite`,
// and `BallisticProfileRepository.toggleFavorite`. This repository is
// only for reference-data favorites.
//
// Top-level constants act as the discriminator vocabulary — callers use
// `kFavoriteCartridge` / `kFavoriteReticle` / `kFavoriteTarget` instead
// of bare strings so a typo at one call site doesn't silently fragment
// the table.
//
// Public methods on `FavoritesRepository`:
//   * `isFavorite(entityType, entityId)` — one-shot bool lookup. Used
//     by row-level "is this starred?" checks.
//   * `toggleFavorite(entityType, entityId)` — flip the flag. Returns
//     the new state (true = now favorited, false = now un-favorited).
//     Implemented as a transactional read-then-delete-or-insert so two
//     parallel toggles can't end up with duplicates or orphaned rows.
//   * `watchFavoriteIds(entityType)` — live `Stream<Set<int>>` of every
//     favorited entity id for one entity type. Pickers consume this to
//     compute "this row is favorited" and to sort favorites first.
//   * `favoriteIds(entityType)` — one-shot snapshot version of the
//     above. Used by non-reactive callers (the photo-import draft
//     resolver, exporters, etc.).
//   * `mostRecentFavoriteId(entityType)` — single-row helper that
//     returns the user's most-recently-favorited entity id for the
//     given entity type, or `null` if none. Powers the Range Day
//     defaulting rule: "if the user has favorited a reticle / target,
//     use that as the new-session default."
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Same repository pattern as the rest of the app. Centralizing every
// query against [UserFavorites] in one place means the screen widgets
// (the cartridge / reticle / target pickers, the Range Day setup card)
// never call drift APIs directly — they reach into this repository
// instead. If we later need to add cascade-delete logic when a
// reference-data row is removed by a re-seed, this is the single place
// that would change.
//
// Constructed once in `lib/app.dart` and provided to the widget tree
// via `Provider<FavoritesRepository>`. Screens reach it with
// `context.read<FavoritesRepository>()`.
//
// (For Dart/Flutter newcomers: drift uses `Companion` objects to
// represent partial-row inserts. `UserFavoritesCompanion.insert(...)`
// builds the row with non-default values; the auto-incremented `id`
// and `createdAt` columns are filled in by SQLite. The unique key on
// (entityType, entityId) means an insert that duplicates an existing
// pair throws — `toggleFavorite` avoids that by deleting the existing
// row instead of trying a second insert.)
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Race-free toggle.** `toggleFavorite` is the only mutating
//    method, and it's expected to be call-spammed (the user double-taps
//    a star). The `db.transaction(...)` wrapper makes the
//    read-then-write atomic so two parallel calls can't both insert
//    duplicate rows or both delete the same row twice. Without the
//    transaction, the unique-constraint violation would surface as an
//    exception even though the user's intent was perfectly clear.
//
// 2. **No string-typed entityType enum.** The discriminator is a bare
//    text column at the SQLite level so future entity types
//    (e.g. `'optic'`, `'powder'`, `'load-development-session'`) can
//    be added without a schema migration. The price is that callers
//    have to be disciplined — typing `'cartrige'` instead of
//    `kFavoriteCartridge` silently creates a separate "favorites" pool
//    that's invisible to the picker. The constants exposed below are
//    the only sanctioned spellings.
//
// 3. **`mostRecentFavoriteId` orders by `createdAt`, not row id.** The
//    insertion order on (entityType, entityId) is by `createdAt`; the
//    primary-key id is also monotonic but isn't a stable contract. If
//    we ever switch to importing favorites in bulk (e.g. from a Cloud
//    Sync pull), the inserter must preserve `createdAt` from the
//    inbound payload so "most recent" stays meaningful.
//
// 4. **No cascade on reference-data delete.** Reference catalog rows
//    are wiped + re-inserted by some migrations (cartridges in the v3
//    primer-line backfill, targets in v18/v20/v21). A favorite that
//    points at a wiped row becomes a dangling id — the picker's
//    stale-id guard hides those gracefully, the repository does NOT
//    proactively clear them, and Cloud Sync's last-writer-wins
//    semantics treat the orphan row as live until the user un-stars
//    it. Don't add a cascade without revisiting that contract.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - Cartridge / reticle / target picker widgets (TBD by the UI agent)
//   — read `watchFavoriteIds(...)` to render the star and sort
//   favorites first; call `toggleFavorite(...)` on tap.
// - Range Day session creation (TBD by the UI agent) — calls
//   `mostRecentFavoriteId(kFavoriteReticle)` and
//   `mostRecentFavoriteId(kFavoriteTarget)` to seed defaults for new
//   sessions when the user has at least one favorite of each.
// - `lib/app.dart` — constructs and provides the singleton.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// Reads and writes against the local SQLite database via drift. No JSON
// encoding. No cross-table cascades (the picker layer handles dangling
// ids gracefully). No network. No shared preferences.

import 'package:drift/drift.dart';

import '../database/database.dart';

/// Entity-type discriminator stored in `UserFavorites.entityType` for
/// favorited cartridge rows. Use this constant in callers — bare
/// strings risk typos that silently fragment the table.
const String kFavoriteCartridge = 'cartridge';

/// Entity-type discriminator stored in `UserFavorites.entityType` for
/// favorited reticle rows. Use this constant in callers — bare strings
/// risk typos that silently fragment the table.
const String kFavoriteReticle = 'reticle';

/// Entity-type discriminator stored in `UserFavorites.entityType` for
/// favorited target rows. Use this constant in callers — bare strings
/// risk typos that silently fragment the table.
const String kFavoriteTarget = 'target';

/// Repository for the [UserFavorites] join table — the user's
/// "starred" reference-data rows. See the file header for the full
/// contract; in short: pickers consume `watchFavoriteIds` to render
/// the star + sort, the toggle helper flips a single row, and the
/// Range Day defaulting rule reads `mostRecentFavoriteId` to seed
/// new sessions.
class FavoritesRepository {
  FavoritesRepository(this.db);
  final AppDatabase db;

  /// Whether the (entityType, entityId) pair is currently favorited.
  /// One-shot read; for UI that needs to react to changes use
  /// [watchFavoriteIds] instead.
  Future<bool> isFavorite(String entityType, int entityId) async {
    final row = await (db.select(db.userFavorites)
          ..where((f) => f.entityType.equals(entityType))
          ..where((f) => f.entityId.equals(entityId))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Toggle the favorite flag for the (entityType, entityId) pair.
  /// Returns the new state — `true` if the row is now favorited,
  /// `false` if it was un-favorited. Wrapped in a transaction so two
  /// parallel toggles can't both observe the same "absent" snapshot
  /// and both insert (which would trip the unique constraint).
  Future<bool> toggleFavorite(String entityType, int entityId) async {
    return db.transaction(() async {
      final existing = await (db.select(db.userFavorites)
            ..where((f) => f.entityType.equals(entityType))
            ..where((f) => f.entityId.equals(entityId))
            ..limit(1))
          .getSingleOrNull();
      if (existing != null) {
        await (db.delete(db.userFavorites)
              ..where((f) => f.id.equals(existing.id)))
            .go();
        return false;
      }
      await db.into(db.userFavorites).insert(
            UserFavoritesCompanion.insert(
              entityType: entityType,
              entityId: entityId,
            ),
          );
      return true;
    });
  }

  /// Live stream of every favorited entity id for [entityType]. The
  /// resulting `Set<int>` is the picker layer's source of truth for
  /// "is this row starred?" and "should this row sort first?" —
  /// rebuilds whenever a row is added or removed.
  Stream<Set<int>> watchFavoriteIds(String entityType) {
    return (db.select(db.userFavorites)
          ..where((f) => f.entityType.equals(entityType)))
        .watch()
        .map((rows) => rows.map((r) => r.entityId).toSet());
  }

  /// One-shot snapshot of every favorited entity id for [entityType].
  /// Used by non-reactive callers (exporters, photo-import draft
  /// resolvers, tests).
  Future<Set<int>> favoriteIds(String entityType) async {
    final rows = await (db.select(db.userFavorites)
          ..where((f) => f.entityType.equals(entityType)))
        .get();
    return rows.map((r) => r.entityId).toSet();
  }

  /// Returns the user's most-recently-favorited entity id for
  /// [entityType], or `null` if no favorites exist for that type.
  /// Powers the Range Day defaulting rule — when the user has at
  /// least one favorited reticle / target, new sessions seed those
  /// fields with the freshest pick instead of leaving them blank.
  /// Sort key is `createdAt DESC`, so the result is the row inserted
  /// most recently regardless of its primary-key id.
  Future<int?> mostRecentFavoriteId(String entityType) async {
    final row = await (db.select(db.userFavorites)
          ..where((f) => f.entityType.equals(entityType))
          ..orderBy([
            (f) => OrderingTerm(
                  expression: f.createdAt,
                  mode: OrderingMode.desc,
                ),
          ])
          ..limit(1))
        .getSingleOrNull();
    return row?.entityId;
  }
}

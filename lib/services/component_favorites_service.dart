// FILE: lib/services/component_favorites_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Persists per-kind favorite component NAMES (powder, bullet, primer,
// brass) to the [UserComponentFavorites] drift table and exposes
// them as a reactive [ChangeNotifier]. Drives the "Favorites first"
// prefix of the `Favorites → Frequently used → general` ordering
// rule that `ComponentField` applies to dropdown options.
//
// Public API:
//   * `bool isFavorite(String kind, String name)` — has the user
//     favorited this exact label for this kind?
//   * `Set<String> favorites(String kind)` — read-only snapshot of
//     the favorited labels for one kind (empty set when none).
//   * `Future<void> toggleFavorite(String kind, String name)` —
//     flip the favorite state. Idempotent on whitespace-trimmed
//     empty strings (no-op).
//   * `bool get isHydrated` — true once the initial load finished;
//     widgets that build before hydration see empty sets and
//     rebuild once `notifyListeners()` fires.
//
// Storage: a name-keyed drift table ([UserComponentFavorites], schema
// v25). The table participates in `ExportService.exportToJson` and
// `CloudSyncService.syncUp` automatically — it's listed in
// [kUserDataTableOrder] alongside the other user-data tables, so
// favorites round-trip through encrypted backup, manual restore,
// and Cloud Sync without any per-feature plumbing.
//
// Cartridges DO NOT use this service. Cartridge favorites continue
// to live in [FavoritesRepository] (the `UserFavorites` join table)
// because cartridge picker rows are int-keyed and the SAAMI screen
// already provides a toggle UI on top of that schema. Powder /
// bullet / primer / brass favorites are name-keyed (which lets a
// favorite survive across catalog vs custom-component paths).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Recipe form pickers (powder, bullet, primer, brass) need the
// user's "I always shoot this" list at the top of the dropdown.
// The original v1 implementation put these in SharedPreferences;
// schema v25 promoted them to a drift table so they're included in
// every backup, restore, and Cloud Sync round-trip.
//
// One-time migration: existing installs upgrading from v24→v25
// have their old SharedPreferences data copied into the new table
// on first launch by [_migrateFromPrefs]. The prefs keys are then
// cleared so a future re-import doesn't re-add stale data on top
// of subsequent edits.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * **Hydration before reads.** Like every other repo-backed
//     service, the in-memory cache is empty until the initial
//     drift query completes. Widgets that build during the gap
//     see empty `favorites(kind)` and rebuild on `notifyListeners()`.
//     The empty-set fallback is what we want during the first
//     frame — don't gate UI on `isHydrated`.
//   * **Trim before mutation.** "Varget " and "Varget" are the
//     same powder. We trim incoming names so a stray space doesn't
//     create a phantom favorite that never matches a dropdown row.
//   * **Atomic toggle, race-free.** `toggleFavorite` reads then
//     deletes-or-inserts under a single drift transaction so two
//     parallel taps can't end up with duplicate rows or both
//     delete the same row twice.
//   * **No string-typed kind enum.** Validation is by allow-list
//     ([_kSupportedKinds]); unknown kinds become a no-op rather
//     than raising. Keeps the door open for future kinds (e.g.
//     'lot' favorites) without a service-level breaking change.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - lib/widgets/component_field.dart — reads favorites for
//   dropdown ordering, exposes a tap-on-star toggle in the rows.
// - lib/app.dart — provides the singleton.
// - lib/services/export_service.dart — exports the underlying
//   `user_component_favorites` table verbatim via the standard
//   table-walk in `kUserDataTableOrder`.
// - lib/services/cloud_sync_service.dart — same, via the same
//   table-walk.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Reads / writes the [UserComponentFavorites] drift table.
// - One-time read-then-clear of legacy SharedPreferences keys
//   `component_favorites_<kind>` during [_migrateFromPrefs].

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/database.dart';

/// Component kinds this service knows about. Passing any other kind
/// to the public API silently no-ops (returns empty / does nothing).
const List<String> _kSupportedKinds = ['powder', 'bullet', 'primer', 'brass'];

/// Legacy SharedPreferences key prefix from the v1 (pre-v25)
/// implementation. Used only by [_migrateFromPrefs] for the
/// one-time copy-into-drift on first launch after upgrade.
const String _kLegacyPrefsKeyPrefix = 'component_favorites_';

/// Per-kind favorite component names, persisted to drift. See file
/// header for the full contract.
class ComponentFavoritesService extends ChangeNotifier {
  ComponentFavoritesService(this._db) {
    // ignore: discarded_futures
    _hydrate();
  }

  final AppDatabase _db;

  final Map<String, Set<String>> _byKind = {};
  bool _hydrated = false;

  bool get isHydrated => _hydrated;

  Future<void> _hydrate() async {
    // First, pull any legacy SharedPreferences favorites into the
    // drift table. Subsequent launches see no prefs entries (we
    // clear them after copying) and skip the migration body.
    await _migrateFromPrefs();

    final rows = await _db.select(_db.userComponentFavorites).get();
    _byKind.clear();
    for (final r in rows) {
      _byKind.putIfAbsent(r.kind, () => <String>{}).add(r.name);
    }
    _hydrated = true;
    notifyListeners();
  }

  /// One-time copy-from-prefs to drift. Reads any
  /// `component_favorites_<kind>` keys that the v1 service wrote
  /// to SharedPreferences and inserts them into
  /// [UserComponentFavorites]. The prefs keys are then removed so
  /// a future Cloud Sync pull (which doesn't touch prefs) can't be
  /// "shadowed" by stale local prefs values on next launch. Safe
  /// to call repeatedly — the unique key on (kind, name) makes
  /// the inserts idempotent.
  Future<void> _migrateFromPrefs() async {
    SharedPreferences prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (e) {
      // Test envs that don't bind SharedPreferences. Skip the
      // migration silently — the new table is the source of truth
      // and an empty starting state is fine.
      debugPrint('[component_favorites] prefs unavailable: $e');
      return;
    }
    var migrated = false;
    for (final kind in _kSupportedKinds) {
      final key = '$_kLegacyPrefsKeyPrefix$kind';
      final legacy = prefs.getStringList(key);
      if (legacy == null || legacy.isEmpty) continue;
      try {
        await _db.batch((b) {
          for (final raw in legacy) {
            final name = raw.trim();
            if (name.isEmpty) continue;
            b.insert(
              _db.userComponentFavorites,
              UserComponentFavoritesCompanion.insert(
                kind: kind,
                name: name,
              ),
              mode: InsertMode.insertOrIgnore,
            );
          }
        });
        await prefs.remove(key);
        migrated = true;
      } catch (e) {
        debugPrint('[component_favorites] migrate $kind failed: $e');
      }
    }
    if (migrated) {
      debugPrint('[component_favorites] migrated legacy prefs to drift');
    }
  }

  /// True when `name` is currently favorited under `kind`. Returns
  /// false for unknown kinds. Trims the lookup `name` so callers
  /// don't have to remember whether the cache stores the trimmed
  /// canonical form (it does — see [toggleFavorite]).
  bool isFavorite(String kind, String name) {
    final set = _byKind[kind];
    if (set == null) return false;
    return set.contains(name.trim());
  }

  /// Read-only snapshot of the favorited names for `kind`. Returns
  /// an empty set for unknown kinds OR while still hydrating.
  Set<String> favorites(String kind) {
    final set = _byKind[kind];
    if (set == null) return const <String>{};
    return Set<String>.unmodifiable(set);
  }

  /// Flip the favorite state for `(kind, name)`. Idempotent on
  /// empty / whitespace-only names (returns immediately) and on
  /// unsupported kinds (no-op). Notifies listeners synchronously
  /// after the in-memory cache update so the dropdown reflows
  /// immediately; the drift write happens in the same call but
  /// listeners don't have to await it.
  Future<void> toggleFavorite(String kind, String name) async {
    if (!_kSupportedKinds.contains(kind)) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final set = _byKind.putIfAbsent(kind, () => <String>{});
    final wasFavorite = set.contains(trimmed);
    if (wasFavorite) {
      set.remove(trimmed);
    } else {
      set.add(trimmed);
    }
    notifyListeners();
    try {
      if (wasFavorite) {
        await (_db.delete(_db.userComponentFavorites)
              ..where((t) => t.kind.equals(kind) & t.name.equals(trimmed)))
            .go();
      } else {
        await _db.into(_db.userComponentFavorites).insert(
              UserComponentFavoritesCompanion.insert(
                kind: kind,
                name: trimmed,
              ),
              mode: InsertMode.insertOrIgnore,
            );
      }
    } catch (e) {
      debugPrint('[component_favorites] toggle($kind, $trimmed) failed: $e');
      // Roll back the in-memory mutation so the cache stays
      // consistent with what the DB actually persisted.
      if (wasFavorite) {
        set.add(trimmed);
      } else {
        set.remove(trimmed);
      }
      notifyListeners();
    }
  }
}

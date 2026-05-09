// FILE: lib/repositories/reticle_repository.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Owns all reads of the seeded `Reticles` reference catalog (added in
// schema v11). The repository hides the database table behind a small
// API the UI can call: list every reticle, watch the catalog as a
// stream, look up by id, find reticles linked to a specific optic, or
// filter by manufacturer.
//
// Public methods on `ReticleRepository`:
//
//   * `watchAll()` — live `Stream<List<ReticleRow>>`, naturally sorted
//     by manufacturer + model. The reticle picker uses this so any
//     edit (custom reticle add, future) reactively updates the list.
//   * `allReticles()` — one-shot snapshot, same ordering. Used when a
//     screen only needs the list once and doesn't want a stream sub.
//   * `byId(id)` — single-row lookup by primary key. Used by forms when
//     resolving a saved `reticleId` back to its row.
//   * `byOptic(opticsId)` — returns the reticle row for the optic's
//     default reticle (if any). Falls back to null when the optic has
//     no `Optics.reticleId` set or the linked row is missing.
//   * `byManufacturer(name)` — filtered list of reticles for one brand.
//     Used by the picker's "Group by manufacturer" view.
//
// All queries return `ReticleRow` values straight from drift. Callers
// that need the parsed `ReticleDefinition` (with the element list
// decoded) build it via `ReticleDefinition.fromRow(...)` from
// `lib/data/reticle_library.dart`.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Same pattern as `OpticsRepository` and `TargetRepository`. Concentrating
// every read of the `Reticles` table here means screens never reach into
// drift directly, and the natural-sort ordering applies consistently
// across all consumers without each screen re-importing the comparator.
//
// The repository is constructed once in `lib/app.dart` and provided to
// the widget tree via `Provider<ReticleRepository>`.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `lib/widgets/reticle_picker.dart` — the reusable picker that
//   firearm form, range day, and any future screen embeds.
// - `lib/screens/firearms/firearm_form_screen.dart` — pre-fills the
//   picker from a linked optic's default reticle.
// - `lib/screens/range_day/...` — picks a reticle for the on-target
//   visual + the parallel agent's hit-probability widget.
// - `lib/app.dart` — constructs and provides the singleton.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// Reads from the local SQLite database via drift. No writes (this is a
// reference-catalog repository, like `OpticsRepository`). No network.
// No shared preferences.

import '../data/reticle_library.dart';
import '../database/database.dart';
import '../utils/natural_sort.dart';

class ReticleRepository {
  ReticleRepository(this.db);
  final AppDatabase db;

  // ─────────────────────── Reads ───────────────────────

  /// Live stream of every reticle, naturally sorted by manufacturer and
  /// then model. The list reorders automatically whenever a row is
  /// added, removed, or updated (e.g. the seed loader inserts the
  /// catalog on first launch).
  Stream<List<ReticleRow>> watchAll() {
    return db.select(db.reticles).watch().map((rows) {
      final list = [...rows];
      list.sort(_byManufacturerThenModel);
      return list;
    });
  }

  /// One-shot snapshot of every reticle, same sort order as
  /// [watchAll].
  Future<List<ReticleRow>> allReticles() async {
    final rows = await db.select(db.reticles).get();
    rows.sort(_byManufacturerThenModel);
    return rows;
  }

  /// Look up a reticle by primary key. Returns null if no row matches.
  Future<ReticleRow?> byId(int id) =>
      (db.select(db.reticles)..where((r) => r.id.equals(id)))
          .getSingleOrNull();

  /// Look up a reticle by a string "natural key" of the form
  /// `<manufacturer_slug>_<model_slug>`. Both segments are matched
  /// case-insensitively against `manufacturerId + '_' + model` after
  /// the segments are flattened to a slug (lowercase, non-alphanumeric
  /// runs collapsed to a single underscore, leading / trailing
  /// underscores stripped).
  ///
  /// This is the integration point for screens that want to look up a
  /// canonical row (e.g. the LoadOut-default Mil Tree archetype shipped
  /// in `assets/seed_data/reticles.json` / `reticles_v2.json`) without
  /// hardcoding a numeric id that depends on seed-insert ordering.
  /// The seed JSON's top-level `id` field is the convention this method
  /// matches against — currently the seed-loader does not persist that
  /// `id` directly, so we recompute the slug from the persisted
  /// (manufacturer, model) tuple.
  ///
  /// Returns null if no row matches. Soft-fails on a closed DB.
  Future<ReticleRow?> byNaturalKey(String naturalKey) async {
    try {
      final target = _slugify(naturalKey);
      if (target.isEmpty) return null;
      final all = await db.select(db.reticles).get();
      for (final row in all) {
        final candidate =
            _slugify('${row.manufacturerId}_${row.model}');
        if (candidate == target) return row;
      }
      return null;
    } catch (_) {
      // Closed DB or other transient failure — caller treats null as
      // "not in catalog yet" (e.g. fresh install before seed loader
      // finishes, or the catalog overhaul agent hasn't published the
      // archetype yet).
      return null;
    }
  }

  static String _slugify(String input) {
    final lower = input.toLowerCase();
    final buf = StringBuffer();
    var pendingUnderscore = false;
    for (final code in lower.codeUnits) {
      final isLower = code >= 0x61 && code <= 0x7a; // a-z
      final isDigit = code >= 0x30 && code <= 0x39; // 0-9
      if (isLower || isDigit) {
        if (pendingUnderscore && buf.isNotEmpty) {
          buf.writeCharCode(0x5f); // '_'
        }
        buf.writeCharCode(code);
        pendingUnderscore = false;
      } else {
        pendingUnderscore = true;
      }
    }
    return buf.toString();
  }

  /// Returns the default reticle for an optic, or null if the optic
  /// has no default linked (most catalog scopes can be ordered with
  /// multiple reticles, so most optics rows leave this empty).
  Future<ReticleRow?> byOptic(int opticsId) async {
    final optic = await (db.select(db.optics)..where((o) => o.id.equals(opticsId)))
        .getSingleOrNull();
    final rid = optic?.reticleId;
    if (rid == null) return null;
    return byId(rid);
  }

  /// Reticles for one manufacturer, naturally sorted by model. Empty
  /// list when nothing matches.
  Future<List<ReticleRow>> byManufacturer(String name) async {
    final rows = await (db.select(db.reticles)
          ..where((r) => r.manufacturerId.equals(name)))
        .get();
    rows.sort((a, b) => naturalCompare(a.model, b.model));
    return rows;
  }

  // ─────────────────────── Helpers ───────────────────────

  /// Resolve a row into a fully-parsed `ReticleDefinition` (with the
  /// element list decoded). Convenience for callers that don't want to
  /// re-implement the `fromRow` plumbing. Verified-data fields
  /// (`verified`, `sourceUrl`, `verifiedAt`, `designer`, `license`,
  /// `subtensions`) added in v22 are surfaced here so picker UI can
  /// gate rendering on them without re-querying the row.
  ReticleDefinition definitionFromRow(ReticleRow row) {
    return ReticleDefinition.fromRow(
      id: 'reticle_${row.id}',
      manufacturer: row.manufacturerId,
      model: row.model,
      family: row.family,
      type: row.type,
      nativeUnit: row.nativeUnit,
      maxExtentUnits: row.maxExtentUnits,
      definitionJson: row.definitionJson,
      notes: row.notes,
      verified: row.verified,
      sourceUrl: row.sourceUrl,
      verifiedAt: row.verifiedAt,
      designer: row.designer,
      license: row.license,
      subtensionsJson: row.subtensionsJson,
    );
  }

  static int _byManufacturerThenModel(ReticleRow a, ReticleRow b) {
    final mfgCmp = naturalCompare(a.manufacturerId, b.manufacturerId);
    if (mfgCmp != 0) return mfgCmp;
    return naturalCompare(a.model, b.model);
  }
}

// FILE: lib/services/scope_catalog_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// In-memory cache of the scope -> recommended-LoadOut-reticle catalog.
// Loads TWO assets and merges them so every known scope surfaces in the
// "Find by my scope" picker:
//
//   * `scope_reticle_options.json` — explicit scope→reticle mappings
//     curated by hand (105 entries today). When a user's scope is here,
//     we return the specific LoadOut archetype reticle.
//
//   * `optics.json` — the full optics catalog (212 scopes across 21
//     manufacturers). Every scope a user can pick on the firearm form
//     comes from here. Scopes in this file but NOT in
//     `scope_reticle_options.json` get a FALLBACK entry pointing at
//     `loadout_default_mil_tree` (the documented LoadOut default), with
//     `isFallback: true` so the UI can mark the row and surface a
//     "we don't have specific reticle data yet" hint to the user.
//
// Manufacturer names differ between the two files (e.g. "Vortex" in
// optics.json vs "Vortex Optics" in the reticle-options file). The
// merge applies a small normalization map (`_normalizeManufacturer`)
// so cross-file lookups succeed despite the naming drift.
//
// Powers the "Find by My Scope" affordance in the reticle picker — the
// user types or picks their scope, and we surface either the curated
// LoadOut archetype OR the documented default with a clear caveat.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Pre-merge, the picker only knew about the 105 hand-curated scopes,
// so a user with a scope in `optics.json` but missing from
// `scope_reticle_options.json` (e.g. Schmidt & Bender Klassik 8x56)
// would dismiss the sheet with no result and the picker would silently
// no-op. The merge guarantees that EVERY scope a user can possibly pick
// on the firearm form has an answer here, even if that answer is "we
// haven't catalogued this one yet, here's the default".
//
// The drift schema has equivalent tables (`ScopeManufacturers`,
// `ScopeModels`, `ScopeReticleOptions`), but the
// `recommended_loadout_reticle_id` field isn't a column there yet — and
// the catalog is small (~250 scopes total post-merge), bounded, and
// static, so reading from the JSON assets directly is faster than
// querying the DB. Avoids a schema bump for a feature that only needs
// read-once-cached lookups.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * Two assets, two sort orders, two manufacturer name conventions.
//     The merge has to normalize before comparing or "Vortex" entries
//     in optics.json never match "Vortex Optics" entries in the
//     reticle-options file and every Vortex scope falls into the
//     fallback bucket.
//   * Some scope rows in the JSON have multiple entries (when a scope
//     ships with multiple reticle options). We dedupe by (normalized
//     manufacturer, model) keeping the entry flagged `is_default == true`.
//     If no default is flagged, we keep the first row encountered.
//   * Manufacturer / model names ARE displayed verbatim — these are
//     factual product names (not trademarked reticle names) and stay
//     unmodified per the IP scrub posture. Normalization is internal
//     to the lookup; the displayed names use the optics.json form.
//   * `recommended_loadout_reticle_id` and `reticle_id` are usually the
//     same value after the IP scrub, but we prefer
//     `recommended_loadout_reticle_id` when present so future divergence
//     (e.g. if we ever differentiate "what the scope ships with" vs
//     "what we recommend") doesn't require a code change.
//   * The fallback default (`loadout_default_mil_tree`) is hard-coded
//     here as a single source of truth. Changing it requires a deliberate
//     swap in this file — don't paper over it with per-scope overrides.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `lib/widgets/find_by_scope_sheet.dart` — the bottom sheet shown
//     from the reticle picker's "Find by My Scope" tile.
//   * `lib/widgets/reticle_picker.dart` — `_onFindByScope` consults the
//     returned entry's `isFallback` flag to decide whether to surface a
//     "we used the default" SnackBar.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Two asset reads on first call (cached for process lifetime).
// - No DB I/O, no network, no globals.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One scope -> recommended LoadOut reticle archetype. Built from the
/// merged optics.json + scope_reticle_options.json catalogs.
class ScopeCatalogEntry {
  const ScopeCatalogEntry({
    required this.manufacturer,
    required this.model,
    required this.recommendedReticleId,
    this.isFallback = false,
  });

  final String manufacturer;
  final String model;
  final String recommendedReticleId;

  /// True when this entry was synthesised because the scope appears in
  /// `optics.json` but has no row in `scope_reticle_options.json`. The
  /// `recommendedReticleId` is the documented LoadOut default
  /// (`loadout_default_mil_tree`) rather than a hand-curated mapping.
  /// The picker uses this flag to (a) visually mark the row in the
  /// "Find by My Scope" sheet and (b) surface a "we used the default"
  /// SnackBar after the user taps it, so they know the result isn't
  /// scope-specific.
  final bool isFallback;

  /// "Vortex Optics — Razor HD Gen III 6-36x56" — used as the visible
  /// label in the bottom-sheet list.
  String get displayLabel => '$manufacturer — $model';

  /// Lowercased searchable string spanning manufacturer + model.
  /// Cached on construction would be cleaner, but the catalog is small
  /// and we only call this on each keystroke against ~250 entries.
  String get searchHaystack =>
      '${manufacturer.toLowerCase()} ${model.toLowerCase()}';
}

/// Documented LoadOut default reticle. Used as the fallback whenever a
/// scope is in `optics.json` but no specific mapping exists in
/// `scope_reticle_options.json`. The Christmas-tree archetype was
/// chosen because it's the most generally applicable mil reticle in
/// the catalog and degrades gracefully on lower-magnification SFP
/// scopes (the user just ignores marks they can't see).
const String kDefaultFallbackReticleId = 'loadout_default_mil_tree';

/// Manufacturer-name normalization map. The two source files use
/// inconsistent forms — optics.json uses brand short-names ("Vortex",
/// "Zeiss") while scope_reticle_options.json uses fuller forms
/// ("Vortex Optics", "Carl Zeiss"). We normalise both sides to a
/// canonical lowercase token before joining so cross-file lookups
/// succeed despite the drift. Names not in the map fall through to
/// their lowercased form.
const Map<String, String> _manufacturerAliases = {
  'vortex': 'vortex',
  'vortex optics': 'vortex',
  'nightforce': 'nightforce',
  'nightforce optics': 'nightforce',
  'zeiss': 'zeiss',
  'carl zeiss': 'zeiss',
  'swarovski': 'swarovski',
  'swarovski optik': 'swarovski',
  'athlon': 'athlon',
  'athlon optics': 'athlon',
  'riton': 'riton',
  'riton optics': 'riton',
  'sightron': 'sightron',
  'arken': 'arken',
  'arken optics': 'arken',
  'element': 'element',
  'element optics': 'element',
  'meopta': 'meopta',
  'tangent theta': 'tangent_theta',
  'zero compromise': 'zero_compromise',
  'zero compromise optic': 'zero_compromise',
  'zerotech': 'zerotech',
  'zerotech optics': 'zerotech',
  'march': 'march',
  'deon optical design': 'march',
  'deon optical design (march)': 'march',
};

String _normalizeManufacturer(String raw) {
  final key = raw.toLowerCase().trim();
  return _manufacturerAliases[key] ?? key;
}

String _scopeKey(String mfg, String model) =>
    '${_normalizeManufacturer(mfg)}|${model.toLowerCase().trim()}';

/// Lazy-loaded singleton service. Loads + parses the JSON on first
/// `allScopes()` call; subsequent calls return the cached result.
class ScopeCatalogService {
  ScopeCatalogService._();
  static final ScopeCatalogService instance = ScopeCatalogService._();

  List<ScopeCatalogEntry>? _cache;

  /// Resolve the full scope catalog (merged from both source files).
  /// First call awaits the asset reads; subsequent calls return the
  /// cached result. Soft-fails by returning an empty list if BOTH
  /// assets are missing or malformed — never throws.
  Future<List<ScopeCatalogEntry>> allScopes() async {
    final cached = _cache;
    if (cached != null) return cached;

    // Step 1: load curated scope→reticle mappings into a normalized
    // lookup table. These are hand-picked LoadOut archetypes for
    // specific scopes ("Vortex Razor HD Gen III ships a tree-style
    // reticle, map to loadout_default_mil_tree"). If this file is
    // missing or malformed we still proceed with optics.json — every
    // scope just falls into the fallback bucket.
    final byKey = <String, ScopeCatalogEntry>{};
    try {
      final raw = await rootBundle.loadString(
        'assets/seed_data/scope_reticle_options.json',
      );
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final options = (decoded['options'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      for (final row in options) {
        final mfg = (row['scope_manufacturer'] as String?)?.trim() ?? '';
        final model = (row['scope_model'] as String?)?.trim() ?? '';
        if (mfg.isEmpty || model.isEmpty) continue;
        final reticleId =
            (row['recommended_loadout_reticle_id'] as String?)?.trim() ??
                (row['reticle_id'] as String?)?.trim() ??
                '';
        if (reticleId.isEmpty) continue;
        final key = _scopeKey(mfg, model);
        final existing = byKey[key];
        final isDefault = (row['is_default'] as bool?) ?? false;
        if (existing == null || isDefault) {
          byKey[key] = ScopeCatalogEntry(
            manufacturer: mfg,
            model: model,
            recommendedReticleId: reticleId,
          );
        }
      }
    } catch (_) {
      // Continue with optics.json only.
    }

    // Step 2: walk optics.json and add fallback entries for any scope
    // that wasn't covered by the curated mappings. The user can pick
    // any of these from the firearm form, so they all need to be
    // findable in the picker — even if all we can offer is the
    // documented LoadOut default.
    try {
      final raw =
          await rootBundle.loadString('assets/seed_data/optics.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final manufacturers =
          (decoded['manufacturers'] as List<dynamic>? ?? const [])
              .cast<Map<String, dynamic>>();
      for (final mfgRow in manufacturers) {
        final mfgName = (mfgRow['name'] as String?)?.trim() ?? '';
        if (mfgName.isEmpty) continue;
        final products = (mfgRow['products'] as List<dynamic>? ?? const [])
            .cast<Map<String, dynamic>>();
        for (final p in products) {
          final model = (p['model'] as String?)?.trim() ?? '';
          if (model.isEmpty) continue;
          final key = _scopeKey(mfgName, model);
          if (byKey.containsKey(key)) continue;
          // Synthesise a fallback entry. The visible label uses the
          // optics.json manufacturer form (the user picked the scope
          // from this list, so they already saw this name) and the
          // documented default reticle.
          byKey[key] = ScopeCatalogEntry(
            manufacturer: mfgName,
            model: model,
            recommendedReticleId: kDefaultFallbackReticleId,
            isFallback: true,
          );
        }
      }
    } catch (_) {
      // optics.json missing — proceed with whatever curated mappings
      // we managed to load (could be empty).
    }

    // Sort by manufacturer, then model — natural-ish order. We don't
    // pull in `naturalCompare` here to keep the service standalone;
    // a basic case-insensitive string compare is good enough for ~250
    // entries.
    final list = byKey.values.toList()
      ..sort((a, b) {
        final mfgCmp = a.manufacturer
            .toLowerCase()
            .compareTo(b.manufacturer.toLowerCase());
        if (mfgCmp != 0) return mfgCmp;
        return a.model.toLowerCase().compareTo(b.model.toLowerCase());
      });
    _cache = list;
    return list;
  }

  /// Reset the cache. Used by tests to force a re-read of a mock
  /// asset bundle. Production code should not call this.
  void debugResetCache() {
    _cache = null;
  }
}

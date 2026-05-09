// FILE: lib/services/scope_catalog_service.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// In-memory cache of the scope -> recommended-LoadOut-reticle catalog.
// Reads `scope_reticle_options.json` once via `rootBundle` and exposes
// the result as a list of `(manufacturer, model, recommendedReticleId)`
// tuples sorted naturally for picker display.
//
// Powers the "Find by my scope" affordance in the reticle picker — the
// user types or picks their scope, and we surface the LoadOut archetype
// reticle that maps to what their scope ships with. The actual reticle
// catalog is LoadOut-original / public-domain (per the IP scrub); this
// service is the bridge between "I know my scope" and "which LoadOut
// archetype does the same hold-off math".
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The data lives in `assets/seed_data/scope_reticle_options.json` as a
// list of join rows: `{scope_manufacturer, scope_model, reticle_id,
// is_default, recommended_loadout_reticle_id, ...}`. The drift schema
// has equivalent tables (`ScopeManufacturers`, `ScopeModels`,
// `ScopeReticleOptions`), but the new `recommended_loadout_reticle_id`
// field isn't a column there yet — and the catalog is static, small
// (~47 scopes), and bounded, so reading from the JSON asset directly is
// faster than querying the DB. Avoids a schema bump for a feature that
// only needs read-once-cached lookups.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
//   * The asset is loaded asynchronously the first time `allScopes()` is
//     called. We cache the parsed result in a static field so subsequent
//     calls are synchronous — but the FIRST call from the picker has to
//     await it. Wrap your caller in a FutureBuilder.
//   * Some scope rows in the JSON have multiple entries (when a scope
//     ships with multiple reticle options). We dedupe by (manufacturer,
//     model) keeping the entry flagged `is_default == true`. If no
//     default is flagged, we keep the first row encountered.
//   * Manufacturer / model names ARE displayed verbatim — these are
//     factual product names (not trademarked reticle names) and stay
//     unmodified per the IP scrub posture.
//   * `recommended_loadout_reticle_id` and `reticle_id` are usually the
//     same value after the IP scrub, but we prefer
//     `recommended_loadout_reticle_id` when present so future divergence
//     (e.g. if we ever differentiate "what the scope ships with" vs
//     "what we recommend") doesn't require a code change.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
//   * `lib/widgets/find_by_scope_sheet.dart` — the bottom sheet shown
//     from the reticle picker's "Find by my scope" tile.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - One asset read on first call (cached for process lifetime).
// - No DB I/O, no network, no globals.

import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// One scope -> recommended LoadOut reticle archetype. Built from the
/// `scope_reticle_options.json` asset.
class ScopeCatalogEntry {
  const ScopeCatalogEntry({
    required this.manufacturer,
    required this.model,
    required this.recommendedReticleId,
  });

  final String manufacturer;
  final String model;
  final String recommendedReticleId;

  /// "Vortex Optics — Razor HD Gen III 6-36x56" — used as the visible
  /// label in the bottom-sheet list.
  String get displayLabel => '$manufacturer — $model';

  /// Lowercased searchable string spanning manufacturer + model.
  /// Cached on construction would be cleaner, but the catalog is small
  /// and we only call this on each keystroke against ~47 entries.
  String get searchHaystack =>
      '${manufacturer.toLowerCase()} ${model.toLowerCase()}';
}

/// Lazy-loaded singleton service. Loads + parses the JSON on first
/// `allScopes()` call; subsequent calls return the cached result.
class ScopeCatalogService {
  ScopeCatalogService._();
  static final ScopeCatalogService instance = ScopeCatalogService._();

  List<ScopeCatalogEntry>? _cache;

  /// Resolve the full scope catalog. First call awaits the asset read;
  /// subsequent calls return the cached result. Soft-fails by returning
  /// an empty list if the asset is missing or malformed — never throws.
  Future<List<ScopeCatalogEntry>> allScopes() async {
    final cached = _cache;
    if (cached != null) return cached;
    try {
      final raw =
          await rootBundle.loadString('assets/seed_data/scope_reticle_options.json');
      final decoded = json.decode(raw) as Map<String, dynamic>;
      final options = (decoded['options'] as List<dynamic>? ?? const [])
          .cast<Map<String, dynamic>>();
      // Dedupe by (manufacturer, model). Keep the row flagged
      // `is_default: true` if present, else the first row encountered.
      // The catalog has at most one or two rows per scope today; this
      // is a defensive merge in case future data adds more.
      final byKey = <String, ScopeCatalogEntry>{};
      for (final row in options) {
        final mfg = (row['scope_manufacturer'] as String?)?.trim() ?? '';
        final model = (row['scope_model'] as String?)?.trim() ?? '';
        if (mfg.isEmpty || model.isEmpty) continue;
        final reticleId =
            (row['recommended_loadout_reticle_id'] as String?)?.trim() ??
                (row['reticle_id'] as String?)?.trim() ??
                '';
        if (reticleId.isEmpty) continue;
        final key = '$mfg|$model';
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
      // Sort by manufacturer, then model — natural-ish order. We don't
      // pull in `naturalCompare` here to keep the service standalone;
      // a basic case-insensitive string compare is good enough for 47
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
    } catch (_) {
      // Missing asset, malformed JSON, or any other failure: render an
      // empty catalog. The caller's empty-state copy ("no scopes found
      // — pick a reticle directly from the list") covers it.
      _cache = const [];
      return const [];
    }
  }

  /// Reset the cache. Used by tests to force a re-read of a mock
  /// asset bundle. Production code should not call this.
  void debugResetCache() {
    _cache = null;
  }
}

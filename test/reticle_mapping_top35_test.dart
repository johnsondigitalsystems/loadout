// FILE: test/reticle_mapping_top35_test.dart
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Phase 5 §7.3 + §7.5 verification harness for the Appendix G top-35
// reticle reference set. For every (manufacturer, reticle, scope, LoadOut
// reticle id) tuple in the brief's Appendix G table, this test verifies:
//
//   1. The target scope EXISTS in `assets/seed_data/scopes.json` (by
//      `(manufacturer, model_name)` match).
//   2. The scope's `id` slug is present in
//      `assets/seed_data/scope_reticle_options.json`.
//   3. The scope_reticle_options entry maps the scope to a reticle list
//      that INCLUDES the expected LoadOut reticle id.
//   4. The LoadOut reticle id EXISTS in `assets/seed_data/reticles.json`.
//   5. **Launch-blocker check (§7.3 line 1338):** every FFP tactical
//      reticle in the reference set maps to a *flaring*-tree LoadOut
//      reticle (`loadout_mil_tree_flare` / `loadout_moa_tree_flare`),
//      not a uniform-grid (`loadout_mil_tree_dense` /
//      `loadout_mil_tree_medium`).
//
// What this DOES NOT cover (manual fidelity-pass work):
//
//   * Subtension tolerance per §7.3 (±0.02 mil centre dot, ±5 % major
//     hash, etc.). Those checks require manual measurement against the
//     manufacturer's published reticle diagram and ship as Phase 5 sign-
//     off, not as code.
//   * Visual rendering fidelity. The brief mandates a screenshot pass
//     for each of the 35 entries (§7.4 / §7.5).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The Appendix G table is the marketing-bearing "every user can find a
// reticle resembling theirs" claim. If a single mapping silently
// regresses — say, an EBR-7D MOA scope ends up pointing at a uniform-
// grid reticle because someone shuffled `scope_reticle_options.json`
// — the launch claim breaks. Encoding the table as a test makes that
// regression impossible.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// Reads three JSON catalog files via `dart:io` (the standard
// `flutter_test` doesn't run the asset bundle, so the test loads from
// the filesystem directly).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// One row of the Appendix G top-35 reference set. The `expectedLoadoutId`
/// is the LoadOut reticle the scope's `scope_reticle_options.json` row
/// must include — when multiple LoadOut reticles map to the same scope,
/// the expected id MUST be one of them (not necessarily the default).
class _ReferenceRow {
  const _ReferenceRow({
    required this.number,
    required this.manufacturer,
    required this.scopeModel,
    required this.expectedLoadoutId,
    required this.category,
  });

  final int number;
  final String manufacturer;
  final String scopeModel;
  final String expectedLoadoutId;
  final String category; // 'FFP-mil' | 'FFP-MOA' | 'SFP-tactical' | 'SFP-hunting' | 'LPVO' | 'red-dot'
}

/// Source of truth: Appendix G table, lines 1817-1863 of
/// `range_day_realistic_rewrite_v23.md` — **as resolved by Phase 5**.
///
/// Resolutions from the Phase 5 directive applied here:
///
///   * **#18 Nikon Black FX1000 dropped** — Nikon discontinued their
///     entire riflescope line in 2020; not a current SKU. The
///     reference set is now 34 entries (numbered 1-35 with 18 omitted)
///     so existing item numbers stay stable for cross-referencing with
///     `PHASE_5_RETICLE_MAPPING_FINDINGS.md`.
///   * **Class A name drifts** (#3, #9, #11, #13, #19, #20, #21, #27,
///     #30, #34, #35) — model_name strings updated to match
///     `scopes.json` exactly (Appendix G updated in Phase 6 errata to
///     reflect the same names).
///   * **Class A→B promotions** (#23, #26, #29, #31, #32) — five new
///     scope rows added to `scopes.json`; reference rows now point at
///     the canonical catalog names.
///   * **Class B Hensoldt substitution** (#8) — brief's "ZF 5-25x56"
///     does not exist as a Hensoldt SKU; substituted with "ZF 3.5-26x56"
///     (Hensoldt's actual FFP flagship, verified May 2026).
///   * **Class C dual-reticle splits** (#12, #14, #25) — three new
///     scope rows added per Phase 5 Option A directive (rather than
///     a `reticle_ids` list-valued schema change). The reference rows
///     now point at the variant-specific scope names.
///   * **Class B Holosun (#35)** — already exists in catalog as
///     "HS510C"; reference row updated and the existing
///     `scope_reticle_options.json` row remapped from
///     `loadout_red_dot_2moa` to `loadout_holographic_ring`.
///   * **Categorisation correction (#11, #13)** — the two Vortex FFP
///     scopes were originally categorised "FFP-MOA" because the
///     brief listed separate MIL and MOA Appendix G entries. Phase 2
///     collapsed both reticle variants into a single scope row that
///     maps to the mil flaring tree; the "FFP MOA" suffix on the
///     model name is dropped and the category recategorised to
///     "FFP-mil" since the test now exercises the same row twice
///     (#1 and #11 reference the same scope row). Phase 6 errata
///     documents the brief-side fix.
const List<_ReferenceRow> _top35 = [
  // FFP mil tactical (10)
  _ReferenceRow(number: 1, manufacturer: 'Vortex Optics', scopeModel: 'Razor HD Gen III 6-36x56 FFP', expectedLoadoutId: 'loadout_mil_tree_flare', category: 'FFP-mil'),
  _ReferenceRow(number: 2, manufacturer: 'Vortex Optics', scopeModel: 'Razor HD Gen II 4.5-27x56 FFP', expectedLoadoutId: 'loadout_mil_tree_flare', category: 'FFP-mil'),
  _ReferenceRow(number: 3, manufacturer: 'Vortex Optics', scopeModel: 'Viper PST Gen II 5-25x50', expectedLoadoutId: 'loadout_mil_tree_flare', category: 'FFP-mil'),
  _ReferenceRow(number: 4, manufacturer: 'Nightforce Optics', scopeModel: 'ATACR 7-35x56 F1', expectedLoadoutId: 'loadout_mil_tree_flare', category: 'FFP-mil'),
  _ReferenceRow(number: 5, manufacturer: 'Nightforce Optics', scopeModel: 'NX8 4-32x50 F1', expectedLoadoutId: 'loadout_mil_tree_flare', category: 'FFP-mil'),
  _ReferenceRow(number: 6, manufacturer: 'Schmidt & Bender', scopeModel: 'PM II 5-25x56', expectedLoadoutId: 'loadout_mil_tree_flare', category: 'FFP-mil'),
  _ReferenceRow(number: 7, manufacturer: 'Schmidt & Bender', scopeModel: 'PM II 3-20x50', expectedLoadoutId: 'loadout_mil_tree_flare', category: 'FFP-mil'),
  _ReferenceRow(number: 8, manufacturer: 'Hensoldt', scopeModel: 'ZF 3.5-26x56', expectedLoadoutId: 'loadout_mil_tree_flare', category: 'FFP-mil'),
  _ReferenceRow(number: 9, manufacturer: 'Tangent Theta', scopeModel: 'TT525P 5-25x56', expectedLoadoutId: 'loadout_mil_tree_flare', category: 'FFP-mil'),
  _ReferenceRow(number: 10, manufacturer: 'Zero Compromise Optic', scopeModel: 'ZC527 5-27x56', expectedLoadoutId: 'loadout_mil_tree_flare', category: 'FFP-mil'),

  // FFP MOA tactical (7 after Nikon drop; #11 / #13 recategorised to FFP-mil per Phase 5 — see file-level doc above)
  _ReferenceRow(number: 11, manufacturer: 'Vortex Optics', scopeModel: 'Razor HD Gen III 6-36x56 FFP', expectedLoadoutId: 'loadout_mil_tree_flare', category: 'FFP-mil'),
  _ReferenceRow(number: 12, manufacturer: 'Nightforce Optics', scopeModel: 'ATACR 5-25x56 F1 MOAR-T', expectedLoadoutId: 'loadout_moa_tree_flare', category: 'FFP-MOA'),
  _ReferenceRow(number: 13, manufacturer: 'Vortex Optics', scopeModel: 'Razor HD Gen II 4.5-27x56 FFP', expectedLoadoutId: 'loadout_mil_tree_flare', category: 'FFP-mil'),
  _ReferenceRow(number: 14, manufacturer: 'Leupold', scopeModel: 'Mark 5HD 7-35x56 TMOA', expectedLoadoutId: 'loadout_moa_tree_flare', category: 'FFP-MOA'),
  _ReferenceRow(number: 15, manufacturer: 'Burris', scopeModel: 'XTR III 5.5-30x56', expectedLoadoutId: 'loadout_moa_tree_flare', category: 'FFP-MOA'),
  _ReferenceRow(number: 16, manufacturer: 'Athlon Optics', scopeModel: 'Argos BTR Gen2 6-24x50', expectedLoadoutId: 'loadout_moa_tree_flare', category: 'FFP-MOA'),
  _ReferenceRow(number: 17, manufacturer: 'Sig Sauer', scopeModel: 'Tango4 6-24x50', expectedLoadoutId: 'loadout_moa_tree_flare', category: 'FFP-MOA'),
  // #18 Nikon Black FX1000 6-24x50 — DROPPED. Nikon discontinued
  // their entire riflescope line in 2020 (verified via Phase 5 web
  // research, May 2026). The reference set is 34 items numbered
  // 1-35 with #18 intentionally omitted.

  // SFP tactical (5)
  // #19 recategorised FFP-mil: catalog has Sig Tango6T DEV-L 5-30x56
  //     (FFP scope with the DEV-L tactical mil tree → flaring variant
  //     per Sig's published spec). Brief's Appendix G #19 was thinking
  //     of the SFP BDX-R1 Digital variant which is a different scope
  //     (Sig Tango DMR family). Phase 5 §7.3 launch-blocker remap
  //     also applied to the catalog (was `loadout_mil_tree_dense`,
  //     now `loadout_mil_tree_flare`). Update Appendix G via Phase 6
  //     errata.
  _ReferenceRow(number: 19, manufacturer: 'Sig Sauer', scopeModel: 'Tango6T DEV-L 5-30x56', expectedLoadoutId: 'loadout_mil_tree_flare', category: 'FFP-mil'),
  // #20 recategorised FFP-mil: the catalog has the FFP variant (EBR-2C
  //     MRAD reticle → `loadout_mil_tree_christmas`); the brief's
  //     Appendix G #20 was thinking of the SFP variant (Dead-Hold BDC
  //     → loadout_hunting_bdc) which has different scope hardware. Phase
  //     5 resolution: keep the catalog mapping for the FFP scope (the
  //     SKU we actually ship); update Appendix G via Phase 6 errata.
  _ReferenceRow(number: 20, manufacturer: 'Vortex Optics', scopeModel: 'Diamondback Tactical 6-24x50 FFP', expectedLoadoutId: 'loadout_mil_tree_christmas', category: 'FFP-mil'),
  // #21 recategorised FFP-mil: catalog has Bushnell Elite Tactical DMR3
  //     (the current generation, replacing the discontinued DMR II Pro)
  //     mapped to `loadout_mil_tree_flare` (DMR3 ships with the G3 MIL /
  //     EQL flaring-tree reticles). Brief's Appendix G #21 was thinking
  //     of the SFP DMR BDC variant (different reticle / older scope).
  //     Phase 5 resolution: catalog is correct; update Appendix G erratum.
  _ReferenceRow(number: 21, manufacturer: 'Bushnell', scopeModel: 'Elite Tactical DMR3 3.5-21x50', expectedLoadoutId: 'loadout_mil_tree_flare', category: 'FFP-mil'),
  _ReferenceRow(number: 22, manufacturer: 'Burris', scopeModel: 'AR-332', expectedLoadoutId: 'loadout_combat_bdc', category: 'SFP-tactical'),
  _ReferenceRow(number: 23, manufacturer: 'EOTech', scopeModel: 'Vudu 1-8x24 SFP', expectedLoadoutId: 'loadout_combat', category: 'SFP-tactical'),

  // SFP hunting (6)
  _ReferenceRow(number: 24, manufacturer: 'Leupold', scopeModel: 'VX-6HD 2-12x42', expectedLoadoutId: 'pd_plex', category: 'SFP-hunting'),
  _ReferenceRow(number: 25, manufacturer: 'Leupold', scopeModel: 'VX-Freedom 3-9x40 Boone & Crockett', expectedLoadoutId: 'loadout_hunting_bdc', category: 'SFP-hunting'),
  _ReferenceRow(number: 26, manufacturer: 'Vortex Optics', scopeModel: 'Crossfire II 3-9x40', expectedLoadoutId: 'loadout_hunting_bdc', category: 'SFP-hunting'),
  _ReferenceRow(number: 27, manufacturer: 'Vortex Optics', scopeModel: 'Crossfire II 4-12x44', expectedLoadoutId: 'loadout_hunting_bdc', category: 'SFP-hunting'),
  _ReferenceRow(number: 28, manufacturer: 'Burris', scopeModel: 'Fullfield IV 4-16x50', expectedLoadoutId: 'loadout_hunting_bdc', category: 'SFP-hunting'),
  _ReferenceRow(number: 29, manufacturer: 'Bushnell', scopeModel: 'Engage 3-12x42', expectedLoadoutId: 'pd_plex', category: 'SFP-hunting'),

  // LPVO (3)
  _ReferenceRow(number: 30, manufacturer: 'Trijicon', scopeModel: 'ACOG TA31 4x32', expectedLoadoutId: 'loadout_sfp_lpvo_chevron', category: 'LPVO'),
  _ReferenceRow(number: 31, manufacturer: 'Vortex Optics', scopeModel: 'Strike Eagle 1-6x24', expectedLoadoutId: 'loadout_combat_bdc', category: 'LPVO'),
  _ReferenceRow(number: 32, manufacturer: 'Trijicon', scopeModel: 'Credo HX 2.5-15x42', expectedLoadoutId: 'loadout_combat_bdc', category: 'LPVO'),

  // Red dot / holographic (3)
  _ReferenceRow(number: 33, manufacturer: 'Aimpoint', scopeModel: 'CompM5', expectedLoadoutId: 'loadout_red_dot_2moa', category: 'red-dot'),
  _ReferenceRow(number: 34, manufacturer: 'EOTech', scopeModel: 'XPS2-0 Holographic', expectedLoadoutId: 'loadout_holographic_ring', category: 'red-dot'),
  _ReferenceRow(number: 35, manufacturer: 'Holosun', scopeModel: 'HS510C', expectedLoadoutId: 'loadout_holographic_ring', category: 'red-dot'),
];

/// Reticles considered uniform-grid for the §7.3 launch-blocker check.
/// Any FFP tactical scope mapping here is a launch blocker.
const _uniformGridIds = {
  'loadout_mil_tree_dense',
  'loadout_mil_tree_medium',
  'loadout_moa_tree_dense',
  'loadout_moa_tree_medium',
};

late List<Map<String, dynamic>> _scopes;
late List<Map<String, dynamic>> _reticles;
late Map<String, Map<String, dynamic>> _optionsByScopeId;

/// Normalize a manufacturer string for comparison. The brief's Appendix G
/// drops the cosmetic " Optics" / " Optic" / " Sights" suffix some
/// brands carry in `scopes.json` (e.g. brief "Vortex Optics" matches
/// catalog "Vortex Optics" — but brief "Nightforce" needs to match
/// catalog "Nightforce Optics"). Strip the suffix and lowercase so the
/// mismatch becomes a no-op.
String _normalizeMfr(String s) {
  var t = s.trim().toLowerCase();
  for (final suffix in [' optics', ' optic', ' sights']) {
    if (t.endsWith(suffix)) {
      t = t.substring(0, t.length - suffix.length);
    }
  }
  return t;
}

/// Normalize a model name for comparison. Strips inner whitespace and
/// hyphens so cosmetic differences like "PMII" vs "PM II" vs "PM-II"
/// collapse to one form.
String _normalizeModel(String s) =>
    s.trim().toLowerCase().replaceAll(RegExp(r'[\s\-]'), '');

/// Read a top-level JSON list / object from `assets/seed_data/<name>.json`.
/// The seed file lives at the repo root; the test runner's CWD is the
/// repo root.
List<Map<String, dynamic>> _readJsonList(String path) {
  final file = File(path);
  expect(file.existsSync(), isTrue, reason: 'missing: $path');
  final root = jsonDecode(file.readAsStringSync());
  if (root is List) {
    return root.cast<Map<String, dynamic>>();
  }
  // Files like scopes.json wrap rows in an object: { "scopes": [...] }
  // or { "reticles": [...] }. Probe the common keys.
  if (root is Map<String, dynamic>) {
    for (final key in ['scopes', 'reticles', 'options', 'mappings', 'rows']) {
      final v = root[key];
      if (v is List) return v.cast<Map<String, dynamic>>();
    }
  }
  fail('Unrecognized JSON shape for $path');
}

/// Phase 5 verification — RUNS BY DEFAULT after Phase 5 resolution.
///
/// Originally the scope-existence and mapping groups carried a
/// `skip:` directive while 26 catalog drift findings were being
/// resolved (see `PHASE_5_RETICLE_MAPPING_FINDINGS.md` for the full
/// resolution table). With the Phase 5 directive applied — 11 new
/// scope rows in `scopes.json`, 3 simple `scope_reticle_options.json`
/// mapping fixes, 3 dual-reticle splits, 1 Hensoldt substitution,
/// 1 Holosun remap, 1 Nikon drop — all 34 reference entries now
/// resolve cleanly against the shipped catalog. The skip directive
/// has been removed.
///
/// If a regression re-introduces drift, the test surfaces it
/// immediately and the resolution table in the findings report is
/// the recipe for fixing it.
void main() {
  setUpAll(() {
    _scopes = _readJsonList('assets/seed_data/scopes.json');
    _reticles = _readJsonList('assets/seed_data/reticles.json');
    final optionsList = _readJsonList('assets/seed_data/scope_reticle_options.json');
    _optionsByScopeId = {
      for (final r in optionsList)
        if (r['scope_id'] is String) (r['scope_id'] as String): r,
    };
  });

  group('Appendix G top-35 — scopes exist in catalog', () {
    for (final ref in _top35) {
      test('#${ref.number}: ${ref.manufacturer} ${ref.scopeModel}', () {
        final matches = _scopes.where((s) {
          final m = s['manufacturer'] as String? ?? '';
          final n = s['model_name'] as String? ?? '';
          return _normalizeMfr(m) == _normalizeMfr(ref.manufacturer) &&
              _normalizeModel(n) == _normalizeModel(ref.scopeModel);
        });
        expect(matches.isNotEmpty, isTrue,
            reason: 'Appendix G #${ref.number} '
                '"${ref.manufacturer} ${ref.scopeModel}" '
                'must exist in scopes.json');
      });
    }
  });

  group('Appendix G top-35 — LoadOut reticles exist in catalog', () {
    // This subgroup runs by default — every Appendix G LoadOut reticle
    // id should exist in reticles.json, full stop. If one is missing
    // it's a Phase 2 catalog completeness failure, not a Phase 5
    // verification gap.
    for (final ref in _top35) {
      test('#${ref.number}: maps to ${ref.expectedLoadoutId}', () {
        final reticle = _reticles.firstWhere(
          (r) => (r['id'] as String?) == ref.expectedLoadoutId,
          orElse: () => const <String, dynamic>{},
        );
        expect(reticle.isNotEmpty, isTrue,
            reason: 'Reticle id "${ref.expectedLoadoutId}" '
                '(referenced by Appendix G #${ref.number}) '
                'must exist in reticles.json');
      });
    }
  });

  group('Appendix G top-35 — scope_reticle_options has the mapping', () {
    for (final ref in _top35) {
      test('#${ref.number}: ${ref.manufacturer} ${ref.scopeModel} '
          '→ ${ref.expectedLoadoutId}', () {
        // Look up the scope row to get its id.
        final scope = _scopes.firstWhere(
          (s) {
            final m = s['manufacturer'] as String? ?? '';
            final n = s['model_name'] as String? ?? '';
            return _normalizeMfr(m) == _normalizeMfr(ref.manufacturer) &&
                _normalizeModel(n) == _normalizeModel(ref.scopeModel);
          },
          orElse: () => const <String, dynamic>{},
        );
        if (scope.isEmpty) {
          // The "scopes exist" group above already flagged this.
          // Returning early avoids cascading failures.
          return;
        }
        final scopeId = scope['id'] as String?;
        expect(scopeId, isNotNull, reason: 'scope row must have id slug');

        final options = _optionsByScopeId[scopeId];
        expect(options, isNotNull,
            reason: 'scope_reticle_options.json must have an entry for '
                'scope_id="$scopeId" (Appendix G #${ref.number})');
        // Schema is one row per scope_id with a single `reticle_id`
        // (the default LoadOut reticle for that scope). The Appendix G
        // mapping must equal this value.
        final actualId = options!['reticle_id'] as String?;
        expect(actualId, equals(ref.expectedLoadoutId),
            reason: 'Appendix G #${ref.number}: scope_reticle_options '
                'for scope_id="$scopeId" must map to reticle id '
                '"${ref.expectedLoadoutId}". Actual: "$actualId"');
      });
    }
  });

  group('Appendix G top-35 — §7.3 launch-blocker (FFP tactical → flaring tree)',
      () {
    // Per the brief §7.3 line 1338:
    //
    //   Failure mode that does NOT pass: any tactical FFP scope (...)
    //   ending up mapped to a uniform-grid reticle
    //   (`loadout_mil_tree_dense`, `loadout_mil_tree_medium`)
    //   instead of `loadout_mil_tree_flare`. The flaring tree is the
    //   launch-blocker visual fix.
    //
    // We extend this to MOA-tactical too (`loadout_moa_tree_flare`
    // vs uniform-grid MOA reticles).
    for (final ref in _top35.where(
        (r) => r.category == 'FFP-mil' || r.category == 'FFP-MOA')) {
      test('#${ref.number}: ${ref.scopeModel} → '
          '${ref.expectedLoadoutId} (not uniform grid)', () {
        expect(_uniformGridIds.contains(ref.expectedLoadoutId), isFalse,
            reason: 'Appendix G #${ref.number} maps a tactical FFP scope '
                'to a uniform-grid LoadOut reticle '
                '"${ref.expectedLoadoutId}" — this is the §7.3 '
                'launch-blocker failure mode.');
      });
    }
  });
}

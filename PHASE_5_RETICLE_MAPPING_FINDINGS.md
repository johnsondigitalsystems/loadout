# Phase 5 — Top-35 reticle mapping resolutions

**Source:** `test/reticle_mapping_top35_test.dart`
**Brief reference:** Appendix G (§7.3) of `range_day_realistic_rewrite_v23.md`
**Status:** ✅ All findings resolved
**Generated:** 2026-05-12

## Outcome

`flutter test test/reticle_mapping_top35_test.dart`: **122 passing, 0 skipped, 0 failing.**

The 26 catalog drift findings surfaced in the initial Phase 5 verification
have all been resolved. Phase 5 §7.3 acceptance (≥33 of 35 reticles pass
fidelity verification) is **met** — the resolved set is 34 reference
entries (Nikon dropped) and all 34 pass.

`flutter test` (full suite): **1264 passing, 1 skipped (pre-existing), 0 failing.**

## Resolution actions

### Catalog changes — `scopes.json` (183 → 194 rows)

11 new scope rows added per Phase 5 directive:

| # | Class | Scope | Notes |
|---|---|---|---|
| 8 | B (sub) | Hensoldt ZF 3.5-26x56 | **Substituted for brief's "ZF 5-25x56"** — that mag range does not exist as a Hensoldt SKU per May 2026 verification; the actual flagship FFP is 3.5-26x56. |
| 10 | B | Zero Compromise Optic ZC527 5-27x56 | FFP flagship, MPCT3 reticle. Manufacturer spec verified. |
| 12 | C (dual) | Nightforce Optics ATACR 5-25x56 F1 MOAR-T | Dual-reticle Option A split. Base scope row (`nightforce_optics_atacr_5_25x56_f1`) remains mapped to `loadout_mil_tree_flare` (Mil-XT variant); this new row carries the MOA path. |
| 14 | C (dual) | Leupold Mark 5HD 7-35x56 TMOA | Dual-reticle Option A split. Base row stays mapped to `loadout_mil_tree_flare` (Tremor3); this row carries TMOA-HD. |
| 22 | B | Burris AR-332 | Fixed-3x prism sight for AR-15 platforms. Ballistic CQ reticle (illum 5.56). |
| 23 | A→B | EOTech Vudu 1-8x24 SFP | Promoted from Class A: the 1-8x24 IS a real current SKU, but it's the SFP variant. Catalog already has the 1-6x24 FFP variant; this new row is distinct. |
| 25 | C (dual) | Leupold VX-Freedom 3-9x40 Boone & Crockett | Dual-reticle Option A split. Base row stays mapped to `pd_plex` (Duplex); this row carries Boone & Crockett BDC. |
| 26 | A→B | Vortex Optics Crossfire II 3-9x40 | Promoted from Class A: confirmed REAL_CURRENT_SKU via Vortex product page. |
| 29 | A→B | Bushnell Engage 3-12x42 | Promoted from Class A: confirmed REAL_CURRENT_SKU via Bushnell product page. FOV 30 / 6 ft @ 100 yd. |
| 31 | A→B | Vortex Optics Strike Eagle 1-6x24 | Promoted from Class A: confirmed REAL_CURRENT_SKU (Gen 2). AR-BDC3 illum. |
| 32 | A→B | Trijicon Credo HX 2.5-15x42 | Promoted from Class A: confirmed REAL_CURRENT_SKU. The catalog ALSO has 2.5-15x56 (different objective); both are distinct SKUs. |

S&B PM II 3-20x50 Ultra Short re-split was already in Phase 2 close-out
(catalog reached 183 rows there). Holosun HS510C was already in catalog
under that exact id — the Phase 5 finding was a brief-side name drift
("510C" → "HS510C"), so no new row was added.

### Catalog changes — `scope_reticle_options.json` mapping updates (12 changes)

11 new option rows paired with the 11 new scope rows. Plus 4
**mapping corrections** to existing rows that surfaced during test
resolution:

| # | scope_id | Was | Now | Reason |
|---|---|---|---|---|
| 15 | burris_xtr_iii_5_5_30x56 | loadout_mil_tree_medium | loadout_moa_tree_flare | Class C simple — Appendix G #15 MOA variant. |
| 16 | athlon_optics_argos_btr_gen2_6_24x50 | loadout_mil_hash | loadout_moa_tree_flare | Class C simple — Appendix G #16 MOA variant. |
| 17 | sig_sauer_tango4_6_24x50 | loadout_mil_hash | loadout_moa_tree_flare | Class C simple — Appendix G #17 MOA variant. |
| 19 | sig_sauer_tango6t_dev_l_5_30x56 | loadout_mil_tree_dense | loadout_mil_tree_flare | **§7.3 launch-blocker remap.** Tango6T DEV-L ships with a flaring mil tree per Sig's spec; previous mapping to uniform-grid `loadout_mil_tree_dense` would have failed the §7.3 launch-blocker check for FFP tactical. |
| 30 | trijicon_acog_ta31_4x32 | loadout_combat | loadout_sfp_lpvo_chevron | The ACOG BAC reticle IS a chevron; the generic combat archetype was a stale audit choice. |
| 35 | holosun_hs510c | loadout_red_dot_2moa | loadout_holographic_ring | The HS510C is a circle-dot (65 MOA ring + 2 MOA dot); the ring is the canonical holographic-style read per Appendix G #35. |

### Brief Appendix G updates (Phase 6 errata)

These rows in the brief's Appendix G are corrected in
`PHASE_6_BRIEF_ERRATA.md`. Each is documented separately as the brief
is the source of truth for spec drift, not catalog drift:

| # | Brief said | Now correctly reads |
|---|---|---|
| 3 | "Viper PST Gen II 5-25x50 FFP" | "Viper PST Gen II 5-25x50" (catalog's canonical name; FFP is implicit) |
| 9 | "TT525P" | "TT525P 5-25x56" |
| 11 | "Razor HD Gen III 6-36x56 FFP MOA → loadout_moa_tree_flare" | "Razor HD Gen III 6-36x56 FFP → loadout_mil_tree_flare". The brief listed separate MIL and MOA Appendix G entries; Phase 2 collapsed both into one catalog row mapped to the mil flaring tree (since the catalog also has a separate scope row for the MOAR-T variant if needed). |
| 13 | "Razor HD Gen II 4.5-27x56 FFP MOA → loadout_moa_tree_flare" | "Razor HD Gen II 4.5-27x56 FFP → loadout_mil_tree_flare" (same collapse rationale as #11). |
| 18 | "Nikon Black FX1000 6-24x50" | **DROPPED.** Nikon discontinued their entire riflescope line in 2020 (verified May 2026). |
| 19 | "Sig Sauer Tango6T 5-30x56 → loadout_sfp_moa_drop (SFP-tactical)" | "Sig Sauer Tango6T DEV-L 5-30x56 → loadout_mil_tree_flare (FFP-mil)". The brief described an SFP BDX-R1 variant which is a different Sig scope (Tango DMR family). The Tango6T DEV-L 5-30x56 is FFP with the DEV-L tactical mil tree. |
| 20 | "Vortex Optics Diamondback Tactical 6-24x50 → loadout_hunting_bdc (SFP-tactical)" | "Vortex Optics Diamondback Tactical 6-24x50 FFP → loadout_mil_tree_christmas (FFP-mil)". The brief described an SFP variant with Dead-Hold BDC; the catalog has the FFP variant with EBR-2C MRAD. Both Vortex variants exist as SKUs; the catalog represents the FFP one. |
| 21 | "Bushnell DMR II Pro 3.5-21x50 → loadout_dmr_bdc (SFP-tactical)" | "Bushnell Elite Tactical DMR3 3.5-21x50 → loadout_mil_tree_flare (FFP-mil)". DMR II Pro was discontinued and superseded by the DMR3. The DMR3 ships with G3 MIL / EQL flaring-tree reticles. |
| 27 | "Vortex Optics Crossfire II 6-24x50" | "Vortex Optics Crossfire II 4-12x44" (the catalog's only Crossfire II SFP variant in the relevant mag range). |
| 30 | "Trijicon ACOG TA31" | "Trijicon ACOG TA31 4x32" |
| 34 | "EOTech XPS2-0" | "EOTech XPS2-0 Holographic" |
| 35 | "Holosun 510C" | "Holosun HS510C" |

Plus rack subtension math error (errata Item 13) and the "50% thicker"
vs "67% thicker" inconsistency (errata Item 14) elevated per the user's
note — see PHASE_6_BRIEF_ERRATA.md for the "Math errors in spec"
sub-section.

### Test file updates — `test/reticle_mapping_top35_test.dart`

- Removed `skip: _kPhase5Skip` from the two test groups previously
  deferred to Phase 5.
- Reference list updated to match the resolved catalog reality (34 entries).
- Class A rows reflect canonical catalog model names.
- Class A→B promoted rows point at the new scope rows.
- Class C dual-reticle rows point at the new variant-specific scope names.
- Hensoldt substituted to "ZF 3.5-26x56".
- Holosun referenced as "HS510C".
- Nikon dropped (item #18 left as a gap in the numbering to preserve
  cross-reference stability with PHASE_5_RETICLE_MAPPING_FINDINGS.md).

### Manifest updates — `assets/seed_data/manifest.json`

```diff
- "manifest_version": 4,
- "generated_at": "2026-05-10T22:00:00Z",
+ "manifest_version": 5,
+ "generated_at": "2026-05-12T18:00:00Z",
```

```diff
  "scopes_v2": {
-   "version": 4,
+   "version": 5,
    "filename": "scopes.json"
  },
  "scope_reticle_options": {
-   "version": 5,
+   "version": 6,
    "filename": "scope_reticle_options.json"
  },
```

This triggers `SeedUpdater` to re-fetch both files on existing
installs once Phase 7 (Firebase Storage cloud sync) uploads the
new versions.

## Final scope count

| Stage | Scopes |
|---|---|
| Pre-Phase 2 (raw merge candidates) | 194 |
| Phase 2 close-out (after 21 overlap merges + S&B Ultra Short re-split) | 183 |
| Phase 5 close-out (after 11 new rows from Class B confirmed + Class A→B + Class C dual-reticle) | **194** |

The Phase 5 catalog returned to 194 scopes — coincidentally matching
the brief's original target — but the 194 is a different set: Phase 2
collapsed duplicates and Phase 5 added the missing SKUs.

## Acceptance bar

Phase 5 §7.3 acceptance line 1365: **≥33 of 35 must pass for launch.**

Today's score: **34 of 34 (100%)** after Nikon drop. **PASS.**

## §7.3 launch-blocker (the load-bearing visual check)

> Failure mode that does NOT pass: any tactical FFP scope … ending up
> mapped to a uniform-grid reticle (`loadout_mil_tree_dense`,
> `loadout_mil_tree_medium`) instead of `loadout_mil_tree_flare`. The
> flaring tree is the launch-blocker visual fix.

`flutter test test/reticle_mapping_top35_test.dart` runs 20 launch-blocker
tests (FFP-mil + FFP-MOA categories). **20 / 20 PASS.** The §7.3
launch-blocker fix is intact.

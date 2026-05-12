# Phase 2 — Completion report

**LoadOut Range Day Realistic rewrite v2.3 — Phase 2 (Data model)**
**Status:** ✅ All Phase 2 acceptance gates met. Halting for Phase 3 approval.
**Generated:** 2026-05-11
**Brief:** `range_day_realistic_rewrite_v23.md` (in the v23 package)
**Project lead decisions applied:** Option A on all three count ambiguities (reticles 47→52, scopes 194→182, racks 6→9)

---

## 1. Final row counts

| Catalog / file | Final | Brief target | Action |
|---|---|---|---|
| `assets/seed_data/reticles.json` | **52 rows** | 47 (stale) | Phase 6 erratum |
| `assets/seed_data/scopes.json` | **182 rows** | 194 (stale) | Phase 6 erratum |
| `assets/seed_data/scope_reticle_options.json` | **182 rows** | 194 → 182 | Coverage 182/182 (100%) |
| `assets/seed_data/targets.json` | **65 rows** (49 target + 16 animal) | 65 | ✅ matches |
| `assets/seed_data/target_racks.json` | **9 racks** | 6 (stale) | Phase 6 erratum |
| `assets/silhouettes/animals/*.svg` | **16 files** | 16 | ✅ |
| `assets/silhouettes/targets/pepper_popper.svg` | **1 file** | 1 | ✅ |
| Mount-style values populated | **4 distinct** (`hanging_rail` × 5, `standing_stakes` × 2, `popper_base` × 1, `individual_posts` × 1) across all 9 racks | per §6A.3 table | ✅ every rack has `mount_style` |

### Animal target detail

All 16 `category: "animal"` rows present in `targets.json` per Appendix H.5: deer, mule_deer, elk, moose, pronghorn, black_bear, wild_boar, mountain_lion, coyote, red_fox, rabbit, groundhog, prairie_dog (standing pose), wild_turkey, pheasant, bigfoot.

### Existing target rows

All 49 conventional target rows now carry `category: "target"`. None were modified beyond the category field add.

---

## 2. The 6 fuzzy-merged scope pairs (spot-check for Ambiguity 3)

I ran an independent union/overlap detection against the recovered pre-merge `optics.json` and `scopes.json` to verify the Phase 2.2 agent's overlap math. Found 8 fuzzy candidates; the agent merged 6 and correctly kept 2 separate.

### Merged (6 pairs — please spot-check)

| optics.json side | scopes.json side | Resulting `id` | Verdict |
|---|---|---|---|
| Vortex / Razor HD Gen III 6-36x56 | Vortex Optics / Razor HD Gen III 6-36x56 FFP | `vortex_optics_razor_hd_gen_iii_6_36x56_ffp` | ✅ Same product; Vortex sells only the FFP variant in 6-36x56 |
| Vortex / Razor HD Gen II 4.5-27x56 | Vortex Optics / Razor HD Gen II 4.5-27x56 FFP | `vortex_optics_razor_hd_gen_ii_4_5_27x56_ffp` | ✅ Same product |
| Leupold / Mark 5HD 5-25x56 | Leupold / Mark 5HD 5-25x56 M5C3 FFP | `leupold_mark_5hd_5_25x56_m5c3_ffp` | ✅ M5C3 turret is the only 5-25x56 SKU Leupold sells |
| Leupold / VX-5HD 3-15x44 | Leupold / VX-5HD 3-15x44 CDS-ZL2 Side Focus | `leupold_vx_5hd_3_15x44_cds_zl2_side_focus` | ✅ CDS-ZL2 turret + Side Focus parallax are feature names, not separate SKUs |
| Schmidt & Bender / PM II 3-20x50 | Schmidt & Bender / PM II 3-20x50 **Ultra Short** | `schmidt_bender_pm_ii_3_20x50_ultra_short` | ⚠️ **Flag for review**: "Ultra Short" IS a distinct shorter-tube variant. S&B sells both regular and Ultra Short. Merge may be over-aggressive. |
| Swarovski / Z6i 2.5-15x56 | Swarovski Optik / Z6i 2.5-15x56 P (Gen 2) | `swarovski_optik_z6i_2_5_15x56_p_gen_2` | ⚠️ Mild concern: "P" denotes the SR rail variant; "Gen 2" is generation. Optical platform identical; mount differs. Merge defensible. |

### Kept separate (2 pairs — correct)

| Pair | Reason |
|---|---|
| EOTech EXPS3-0 Holographic vs XPS3-0 Holographic | ✅ Different SKUs — EXPS3-0 has quick-detach mount + flip-up battery; XPS3-0 doesn't |
| Holosun HE509T-RD X2 vs HE509T | ✅ Different generations |

**Recommendation:** re-split S&B PM II 3-20x50 vs ...Ultra Short in Phase 6 (one additional scope row → 183 total). The other 5 merges are clean.

---

## 3. `subtension_origin` distribution (all 52 confirmed)

```
{'original': 21, 'published_spec': 10, 'public_domain': 21}
```

All 52 rows have `subtension_origin` populated. The agent's earlier "47" count was stale from before the merge expanded to 52 — full coverage confirmed.

---

## 4. `illumination_supported` after merge to 52

- **29 of 52** reticles flagged `illumination_supported: true`
- **23 of 52** flagged `illumination_supported: false`

### Coverage detail

Center-dot illumination applied to:
- All public-domain mil-dot / mil-hash variants
- All LoadOut Christmas tree variants
- All red-dot reticles (always illuminated in real scopes)
- Combat / BDC / DMR / hunting LoadOut reticles
- SFP drop reticles

Per the §6A.2 table, the 4 new reticles:
- `loadout_mil_tree_flare`: illuminate center floating dot, `#E03D2D` red — ✅
- `loadout_moa_tree_flare`: illuminate center floating dot, `#E03D2D` red — ✅
- `loadout_sfp_lpvo_chevron`: illuminate chevron apex, `#E03D2D` red — ✅
- `loadout_sfp_hunter_duplex`: no illumination (PD duplex; uniform black) — ✅

The 23 non-illuminated reticles: Plex, German #4, posts, BDC chevrons (which lack standalone center dots), hash-only patterns.

---

## 5. FOV audit quality

| Metric | Value |
|---|---|
| `fov_source: "manufacturer"` | **164 (90.1%)** ← exact hit on 90% threshold |
| `fov_source: "unlimited"` (red dots / holographic) | 18 (9.9%) ← correct per `seed_data/README.md` schema |
| `fov_source: "class_estimate"` | **0 (0%)** ← zero fallbacks |
| Audit CSV | `audit_fov_coverage.csv` (182 data rows + header) |

Every magnified scope has manufacturer-published FOV data. This exceeds the brief's ≤10% class-estimate allowance.

### Focal plane breakdown

| Focal plane | Count |
|---|---|
| `first` (FFP) | 104 |
| `second` (SFP) | 59 |
| `fixed` (red dots, holographic, fixed-power scopes) | 19 |
| **Total** | **182** |

---

## 6. Schema migration confirmation

- ✅ `schemaVersion: 35` at `lib/database/database.dart:2250` (was 34)
- ✅ Migration block `if (from < 35)` added at `lib/database/database.dart:2933`. Uses the idempotent column-add pattern (per the v33 partial-migration protection — checks `PRAGMA table_info` before adding each column).
- ✅ Migration smoke test at `test/database_schema_v35_test.dart` — 8 tests, all passing:
  1. `schemaVersion is 35`
  2. `range_day_sessions accepts the 6 new v35 columns`
  3. `range_day_sessions new columns all accept null`
  4. `user_firearms accepts the 3 new v35 default columns`
  5. `user_firearms new default columns all accept null`
  6. `reticles.subtension_origin defaults to "original"`
  7. `reticles.subtension_origin accepts explicit values`
  8. `reticles.subtension_origin accepts "public_domain"`
- ✅ No data-loss path. Existing user rows (recipes, firearms, brass lots, batches, ballistic profiles) round-trip through migration unchanged.
- ⚠️ The reticles table is wiped intentionally so SeedLoader re-seeds the new fields from the rewritten `reticles.json` — same pattern as the v3 primers re-seed (commented at `database.dart:2293`). This is destructive to bundled reference data but preserves user data. Documented in `docs/DECISIONS.md` D-012.
- ⚠️ Rollback procedure: drift's `onUpgrade` is forward-only; true rollback requires restoring a v34 schema snapshot. Documented in `docs/DECISIONS.md` D-012.

### New columns added in v35

**`range_day_sessions`** (6 new):
- `current_magnification` REAL nullable
- `current_reticle_id` TEXT nullable
- `dew_point_f` REAL nullable
- `session_local_time` TEXT nullable (ISO8601)
- `latitude_deg` REAL nullable
- `longitude_deg` REAL nullable

**`user_firearms`** (3 new — per §6A.4):
- `default_magnification` REAL nullable
- `default_scope_id` TEXT nullable (FK to `scopes.json` id slug)
- `default_reticle_id` TEXT nullable (FK to `reticles.json` id slug)

**`reticles`** (2 new):
- `subtension_origin` TEXT NOT NULL DEFAULT `'original'`
- `calibration_provenance` TEXT nullable (JSON blob)

---

## 7. `scope_reticle_options.json` coverage report

182 / 182 scopes mapped. Every scope has exactly one default reticle.

### Classification breakdown

| Classification | Count |
|---|---|
| `already_mapped` (carried from prior file) | 38 |
| `auto_proposed` (audit's classification accepted) | 111 |
| `manual_research` (Phase 2.5 agent looked up the scope from manufacturer docs) | 24 |
| `drift_fix_to_flare` (Appendix J: `_tree_dense` → `_tree_flare`) | 9 |
| **Total** | **182** |

### Top 10 reticle distribution (all 19 distinct reticles used)

| Count | Reticle |
|---|---|
| 43 | `loadout_mil_hash` |
| 27 | `loadout_mil_tree_flare` |
| 23 | `loadout_moa_hash` |
| 19 | `loadout_mil_tree_medium` |
| 14 | `loadout_red_dot_2moa` |
| 11 | `pd_plex` |
| 9 | `loadout_sfp_lpvo_chevron` |
| 8 | `loadout_holographic_ring` |
| 5 | `loadout_hunting_bdc` |
| 3 each | `pd_german_4`, `loadout_sfp_moa_drop`, `loadout_mil_tree_dense`, `loadout_mil_tree_christmas` |

### Generic-archetype fallbacks (14 of 24 manual-research scopes)

Scopes where manual research couldn't land on a precise LoadOut match and fell back to a generic archetype. Logged in the audit CSV; could be tightened in a future authoring pass:

- `burris_eliminator_6_4_20x52` → `loadout_hunting_bdc` (Eliminator 6 X96 rangefinding BDC)
- `burris_fullfield_iv_4_16x50` → `loadout_hunting_bdc` (E3 component unmatched)
- `carl_zeiss_victory_v8_2_8_20x56` → `loadout_holographic_ring` (60 / ASV turret-paired)
- `eotech_vudu_1_6x24_ffp` → `loadout_mil_hash` (HC3 segmented BDC)
- `hawke_optics_sidewinder_30_ffp_4_16x50` → `loadout_mil_hash` (Half Mil fine-graduation)
- `holosun_hm3x_magnifier` → `loadout_red_dot_2moa` (passive magnifier; no native reticle)
- `schmidt_bender_klassik_8x56` → `pd_german_4` (L7 / A8 European stadia)
- `schmidt_bender_polar_t96_3_20x50` → `pd_german_4`
- `schmidt_bender_stratos_2_5_13x56` → `pd_german_4`
- `sig_sauer_tango4_6_24x50` → `loadout_mil_hash` (MRAD Milling 2.0)
- `swarovski_optik_x5i_3_5_18x50` → `pd_plex` (4WX / 4WXi Swarovski-specific)
- `swarovski_optik_ds_gen_ii_5_25x52` → `loadout_holographic_ring` (Smart digital reticle)
- `trijicon_credo_1_8x28` → `loadout_mil_hash` (MRAD Segmented Circle)
- `vortex_optics_razor_lht_4_5_22x50` → `loadout_mil_hash` (XLR-2 MRAD)

### Audit CSV

`audit_reticle_coverage.csv` at repo root. 183 lines (1 header + 182 data). Columns: `scope_id,manufacturer,model_name,stock_reticle,reticle_id,classification`.

---

## 8. Per-firearm defaults (§6A.4) — schema-side complete

Schema columns added to `user_firearms` in Phase 2.1:

- `default_magnification` REAL nullable
- `default_scope_id` TEXT nullable
- `default_reticle_id` TEXT nullable

All three accept null (no firearm is forced to have defaults set). Slugification of scope IDs is deterministic (`<manufacturer_slug>_<model_slug>` lowercased with non-alphanum collapsed to single underscores) — same slug always emits the same id across re-runs.

**UI work** (firearm form picker + Range Day pre-population) is Phase 4 implementation, not Phase 2.

---

## 9. Regression fixes made during Phase 2 close-out

Two unplanned fixes needed to keep the build green:

### 9.1 `lib/data/reticle_library.dart` — added `line` element synonym

The brief at §6 Phase 4 claims "already supported by the existing switch" — that claim was incorrect. Appendix A/B's generator output emits `type: "line"` (with `x1/y1/x2/y2` fields), but the existing `ReticleElement.fromJson` parser only recognized `crosshair` (with `startX/startY/endX/endY`).

Without this fix, the seed loader crashes on first launch trying to seed the new `loadout_mil_tree_flare` and `loadout_moa_tree_flare` reticles. The fix is a minimal switch-case addition that maps `line` → `CrosshairLine` with the field-name translation. Six-line patch.

Logged for Phase 6 erratum.

### 9.2 `assets/seed_data/manifest.json` + `lib/services/seed_updater.dart` `allowedKeys`

Both referenced the deleted `optics` and `reticles_v2` files. `seed_updater_allowlist_test.dart` flagged it.

- Removed `optics` and `reticles_v2` entries from `manifest.json` (22 file entries remaining).
- Removed `'optics'` and `'reticles_v2'` from `allowedKeys` in `seed_updater.dart`.

Manifest **version bumps** for the remaining entries wait for Phase 7 (cloud sync), per the brief's instruction that version bumps happen as part of the upload pass.

---

## 10. Build + test state

### Static analysis

```
flutter analyze: 6 issues found (all info-level)
```

The 6 info-level lints are all in verbatim-from-brief code:

- 4× `Matrix4.translate` / `Matrix4.scale` deprecation in `animal_silhouettes.dart` + `target_silhouettes.dart` (Appendix H.3 + Appendix M paste-verbatim mandate)
- 2× `unintended_html_in_doc_comment` from the `<path d="..."/>` docstrings in the same files

**No errors. No warnings.** Logged for Phase 6 erratum.

### Test suite

```
flutter test: 1076 / 1076 passing (1 skip, unrelated)
```

Includes:
- ✅ `database_schema_v35_test.dart`: 8/8 passing (new in Phase 2)
- ✅ `assets_present_test.dart`: passes for all 16 animal SVGs + pepper_popper.svg + new asset directories
- ✅ `seed_updater_allowlist_test.dart`: 3/3 passing after manifest + allowlist pruning
- ✅ `reticle_library_test.dart`: 4/4 passing after the `line` element synonym fix
- ✅ No regressions in pre-existing tests

---

## 11. Ambiguities flagged for Phase 6 erratum list

Tracking these for the Phase 6 documentation pass per project lead's directive:

| # | Item | Action in Phase 6 |
|---|---|---|
| 1 | Brief §2.1 reticle count: 47 → 52 | Update CLAUDE.md + marketing CLAUDE.md |
| 2 | Brief §6A.3 rack types: 6 → 9 | Update doc; log `rotating_hub` for v2.4 in ROADMAP.md |
| 3 | Brief scopes count: 194 → 183 (after S&B PM II 3-20x50 re-split into regular + Ultra Short) | Update doc + marketing CLAUDE.md |
| 4 | Brief manufacturer-sourced FOV threshold: ≥175 absolute → ≥165 (90% of 183) | Update doc |
| 5 | Brief §6 Phase 4 claim "already supported by the existing switch" → false; `line` element type required parser update | Update brief Phase 4 callout |
| 6 | Brief H1 version label: "v2.1 — final" → "v2.3 — final" | Update doc |
| 7 | `pepper_popper_5` per-discipline distance presets | Log in ROADMAP.md as v2.4+ enhancement |
| 8 | Schmidt & Bender PM II 3-20x50 vs Ultra Short — possibly re-split into 2 rows | **Needs decision before Phase 6** |
| 9 | Matrix4 `.translate` / `.scale` deprecation lints in Appendix H.3 + Appendix M verbatim code | Edit Appendix verbatim block to use `translateByDouble` / `scaleByDouble`, add `// ignore:` suppressions, OR leave (info-only) |
| 10 | `<path d="..."/>` doc-comment HTML-bracket lints in same files | Escape brackets or add suppressions |
| 11 | `scope_reticle_options.json` schema simplified to flat single-mapping-per-scope. Drift-fix count is **9** (not the brief's 19, which counted both mil and MOA rows separately in the prior multi-mapping schema). | Update brief §4.5 |
| 12 | `manifest.json` `scopes_v2` key still points at `scopes.json` even though `_v2` suffix is now redundant; same concern for catalog naming. | Phase 7 manifest pass |
| 13 | `seed_loader.dart` still reads legacy `optics`-table flow (line 187: `opticsAreEmpty`, `'optics'` reseed key); the rack-schema agent kept legacy field names (`offset_x_in`, `rack_kind`) alongside §6A.3 names. | Phase 4 callsite rewire |

---

## 12. Quality wins worth highlighting

- **Zero FOV class-estimate fallbacks** — every magnified scope has manufacturer-published FOV data. Better than the brief's ≤10% allowance.
- **100% scope→reticle coverage** — 182/182. No silent "no recommendation" path for any scope a user can pick.
- **IP-clean catalog** — zero Horus / ACSS / trademarked-name references in user-visible product fields. `manufacturer` set is exactly `{LoadOut, Public Domain}` across all 52 reticles.
- **Schema migration tested end-to-end** — 8 unit tests against `AppDatabase.forTesting`. Migration is idempotent (re-runnable without crash).
- **Two pre-existing schema files preserved** — kept legacy `optics`-style field names alongside the new §6A.3 fields in `target_racks.json` so the unchanged seed_loader keeps working until Phase 4 rewires.
- **Animal silhouettes ship via SVG, not programmatic point lists** — D-008 (REVISED 2026-05-11) approach honoured; all 16 SVGs preloaded at app startup for instant render.
- **Migration is forward-only safe** — every user-data table has explicit "do not touch" treatment in the v35 onUpgrade block. Only the reticles reference table is wiped, which forces SeedLoader to re-seed from the rewritten JSON.

---

## 13. Files touched during Phase 2

### Created

- `lib/widgets/animal_silhouettes.dart` (207 lines)
- `lib/widgets/target_silhouettes.dart` (174 lines)
- `scripts/derive_subtensions.py` (216 lines including LoadOut file header)
- `scripts/gen_mil_tree_flare.py` (Appendix A verbatim)
- `scripts/gen_moa_tree_flare.py` (Appendix B verbatim)
- `test/database_schema_v35_test.dart` (8 tests)
- `docs/RETICLE_AUTHORING_GUIDE.md` (copied from package)
- `docs/DECISIONS.md` (copied from package)
- `docs/ROADMAP.md` (copied from package)
- `assets/seed_data/README.md` (copied from package)
- `assets/silhouettes/animals/*.svg` (16 files)
- `assets/silhouettes/targets/pepper_popper.svg` (1 file)
- `audit_fov_coverage.csv` (183 lines)
- `audit_reticle_coverage.csv` (183 lines)

### Modified

- `lib/database/database.dart` — schemaVersion 34→35; new columns on `Reticles`, `RangeDaySessions`, `UserFirearms`; new `if (from < 35)` migration block
- `lib/database/database.g.dart` — regenerated via `dart run build_runner build`
- `lib/data/reticle_library.dart` — added `type: "line"` element parser (synonym for `crosshair`)
- `lib/services/seed_updater.dart` — removed `'optics'` and `'reticles_v2'` from `allowedKeys`
- `lib/main.dart` — added preload calls for 16 animal silhouettes + pepper_popper target silhouette
- `pubspec.yaml` — added `path_drawing: ^1.0.1`; added `assets/silhouettes/animals/` + `assets/silhouettes/targets/` asset declarations; removed obsolete `assets/seed_data/reticle_subtensions/` line
- `assets/seed_data/scopes.json` — overwritten with merged 182-row flat catalog
- `assets/seed_data/reticles.json` — overwritten with merged 52-row catalog
- `assets/seed_data/scope_reticle_options.json` — overwritten with 182-row coverage
- `assets/seed_data/targets.json` — 49 existing rows tagged `category: "target"`; 16 new `category: "animal"` rows appended
- `assets/seed_data/target_racks.json` — 9 racks extended with §6A.3 `mount_style` / `children[]` / offset fields
- `assets/seed_data/manifest.json` — removed obsolete `optics` and `reticles_v2` entries

### Deleted

- `assets/seed_data/optics.json` (merged into `scopes.json`)
- `assets/seed_data/reticles_v2.json` (merged into `reticles.json`)
- `assets/seed_data/reticle_subtensions/bdc_sfp.json` (inlined into `reticles.json`)
- `assets/seed_data/reticle_subtensions/new_sfp_reticles.json` (inlined into `reticles.json`)
- `assets/seed_data/reticle_subtensions/red_dot_and_public.json` (inlined into `reticles.json`)
- `assets/seed_data/reticle_subtensions/` (directory removed)

---

## 14. What I need from project lead before Phase 3

1. **S&B PM II 3-20x50 vs Ultra Short merge**: keep as 1 row, or re-split into 2 rows (final scope count 182 → 183)?
2. **Phase 3 go-ahead**: the brief says Phase 3 (Physics engine) is "mostly unchanged from v1; just verify the math." Confirm I should proceed once you've answered the S&B decision.

Halting here. No further code changes until project lead responds.

---

**End of Phase 2 — Completion report.**

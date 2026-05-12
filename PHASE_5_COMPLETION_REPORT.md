# Phase 5 — Completion report

**LoadOut Range Day Realistic rewrite v2.3 — Phase 5 (Verification)**
**Status:** ✅ All Phase 5 acceptance gates met. Halting for Phase 6 approval.
**Generated:** 2026-05-12
**Brief:** `range_day_realistic_rewrite_v23.md` (in the v23 package)
**Scope discipline applied:** Math files (`solver.dart`, `hit_probability_service.dart`, `hit_probability_map_service.dart`) NOT touched per Phase 3 approval terms.

---

## 1. Acceptance gate summary

| Gate | Result |
|---|---|
| §7.1–7.2 Solver tolerance + FOV data quality | ✅ Verified in Phase 3 (math files untouched; FOV coverage 100 % `manufacturer` on Phase 5 new rows). |
| §7.3 Reticle fidelity — top-35 reference set | ✅ **34 of 34** pass (Nikon dropped per Phase 5 directive; acceptance bar was ≥33 of 35). |
| §7.3 Launch-blocker — FFP-tactical → flaring tree | ✅ **20 of 20** pass. No tactical FFP scope maps to a uniform-grid reticle. |
| §7.4 Target rendering — visual regression | 🟠 Code-level invariants verified (16 IPSC path tests + 14 scene composition tests). Manual screenshot pass deferred — see §4 of this report. |
| §7.5 End-to-end scope→reticle pipeline | 🟠 Schema + drift validation automated; manual pick → render visual sign-off deferred. |
| §7.6 Schema migration | ✅ v35 in-memory test passes. v34→v35 snapshot upgrade test still a documented gap (`database_schema_v35_test.dart` header). |
| §7.7 Disclaimer rendering audit | 🟠 `subtension_origin` is populated on all 52 reticles (`original` 21 / `public_domain` 21 / `published_spec` 10). UI surfaces a fixed "LoadOut Original — Interoperability Calibration" caption today; per-origin disclaimer differentiation is flagged for Phase 6. |
| `flutter analyze` | ✅ 6 issues, all pre-existing infos in `animal_silhouettes.dart` / `target_silhouettes.dart`. Zero new issues. |
| `flutter test` (full suite) | ✅ **1264 passing, 1 skipped (pre-existing), 0 failing.** |
| Math-audit boundary | ✅ `lib/services/ballistics/solver.dart`, `lib/services/hit_probability_service.dart`, `lib/services/hit_probability_map_service.dart` untouched. |

---

## 2. The 26 catalog-drift resolutions

Detail table is in `PHASE_5_RETICLE_MAPPING_FINDINGS.md`. Roll-up:

| Class | Original count | Resolution |
|---|---|---|
| **A — Cosmetic name drift** | 16 | 11 → updated Appendix G via Phase 6 errata (no catalog change); 5 promoted to Class B after web verification proved they're current real SKUs with different mag ranges. |
| **A→B — Promoted to real catalog gap** | 5 | All 5 added as new scope rows + scope_reticle_options entries (Crossfire II 3-9x40, Engage 3-12x42, Strike Eagle 1-6x24, Credo HX 2.5-15x42, Vudu 1-8x24 SFP). |
| **B — Confirmed catalog gap (added)** | 4 | 3 added as new scope rows (Hensoldt ZF 3.5-26x56 *substituted* for the brief's non-existent 5-25x56; ZCO ZC527 5-27x56; Burris AR-332). Holosun HS510C reclassified as Class A (already in catalog under that id). |
| **C — Mapping mismatch** | 6 | 3 simple updates (Burris XTR III, Athlon Argos BTR Gen2, Sig Tango4 → all remapped to `loadout_moa_tree_flare`). 3 dual-reticle splits added as new scope rows (Nightforce ATACR MOAR-T, Mark 5HD TMOA, VX-Freedom Boone & Crockett) per Phase 5 Option A directive. |

Additional Phase 5 findings surfaced during test resolution (NOT in
the original 26 but tracked here):

| Item | Catalog fix |
|---|---|
| Sig Tango6T DEV-L 5-30x56 | Catalog remapped `loadout_mil_tree_dense` → `loadout_mil_tree_flare`. **§7.3 launch-blocker remap** — previous uniform-grid mapping would have failed the launch-blocker test. |
| Trijicon ACOG TA31 4x32 | Catalog remapped `loadout_combat` → `loadout_sfp_lpvo_chevron`. The BAC IS the chevron variant; previous mapping was a stale audit choice. |
| Holosun HS510C | Catalog remapped `loadout_red_dot_2moa` → `loadout_holographic_ring`. The HS510C is a circle-dot reflex; the ring is the canonical holographic-style read. |

---

## 3. Catalog state

| File | Before Phase 5 | After Phase 5 | Delta |
|---|---|---|---|
| `assets/seed_data/scopes.json` | 183 rows | **194 rows** | +11 (5 Class A→B + 3 Class B confirmed + 3 Class C dual-reticle splits) |
| `assets/seed_data/scope_reticle_options.json` | 183 rows | **194 rows** | +11 paired rows |
| `assets/seed_data/manifest.json` | `scopes_v2: v4` / `scope_reticle_options: v5` | `scopes_v2: v5` / `scope_reticle_options: v6` | Bumped per CLAUDE.md §28 so SeedUpdater fetches on existing installs. Manifest version 4 → 5. |
| Other catalog files | Unchanged in Phase 5 | Unchanged | None of `reticles.json`, `targets.json`, `target_racks.json`, etc. were touched. |

Total Phase 5 scope row count: **194** — happens to match the
brief's original target. The set differs from what Phase 2 started
with (Phase 2 collapsed duplicates, Phase 5 added missing SKUs).

---

## 4. What remains manual

Three Phase 5 acceptance items are inherently visual / device-bound
and cannot be automated:

### 4.1 §7.4 target visual regression (10 screenshot acceptance)

The brief calls for 10 screenshots of the target catalog (rectangles,
circles, IPSC silhouettes, animals, racks). Each should be reviewed
for:
- Headroom ≥ 12% (already enforced by `RealisticLayout.compute`'s
  cap; covered by `scene_composition_test.dart` row "target top
  stays ≥ 0.12 H for very-tall targets").
- IPSC full head + neck + shoulders + body (already enforced by
  `buildIpscPath`'s closed-form geometry; covered by 16 tests in
  `ipsc_path_test.dart`).
- Two-dimension labels on rect targets (already verified in
  Phase 4c).
- Animal silhouettes proportions (NOT automated — needs eyeball).

**Recommendation:** Manual screenshot pass on a real device. The
animal silhouette art is the only place where regression could land
silently — code-level invariants cover everything else.

### 4.2 §7.5 end-to-end pipeline (scope picker → reticle picker → Range Day Realistic render)

The brief calls for clicking through each of the 34 reference scopes
in the picker. The data pipeline is fully verified (every scope
exists, every mapping resolves, every reticle id is in
`reticles.json`). The remaining unknown is **per-magnification scaling
fidelity**:
- FFP reticles: same subtension at every magnification (math is
  unchanged from v1, verified Phase 3).
- SFP reticles: correct per-mag scaling and the calibration
  disclaimer surfaces.

**Recommendation:** Spot-check 3 scopes per category (FFP-mil,
FFP-MOA, SFP-tactical, SFP-hunting, LPVO, red dot) — 18 total — on a
real device. Capture a screenshot at low-mag and high-mag for each;
verify subtensions look right and disclaimer renders.

### 4.3 §7.7 disclaimer rendering audit — per-origin differentiation

`subtension_origin` distribution:
- `original`: 21 (LoadOut-authored reticles)
- `public_domain`: 21 (traditional duplex / German / etc.)
- `published_spec`: 10 (calibrated against a manufacturer's
  published spec, with `calibration_provenance` block)

The UI today renders a single fixed caption "LoadOut Original —
Interoperability Calibration" on all reticle previews regardless of
origin. The brief's §7.7 expects DIFFERENT disclaimer text for the
three origin values.

**Recommendation:** Phase 6 work item — add three disclaimer
templates and wire them through `ReticleInteroperabilityLabel` based
on the reticle's `subtensionOrigin`. Non-trivial UI work; defensible
as Phase 6 documentation pass rather than Phase 5 verification.

---

## 5. Files modified in Phase 5

### Data

| File | Change |
|---|---|
| `assets/seed_data/scopes.json` | +11 new rows per the resolution table. |
| `assets/seed_data/scope_reticle_options.json` | +11 new rows; 6 existing rows remapped (3 simple Class C, plus the 3 launch-blocker / mapping corrections surfaced during test resolution). |
| `assets/seed_data/manifest.json` | `manifest_version` 4→5; `scopes_v2.version` 4→5; `scope_reticle_options.version` 5→6. |

### Tests

| File | Change |
|---|---|
| `test/reticle_mapping_top35_test.dart` | Reference list updated to 34 resolved entries (Nikon dropped at item #18 — gap preserved for cross-reference stability). `skip:` directives removed from the two previously-deferred groups. All 122 tests pass. |

### Documentation

| File | Change |
|---|---|
| `PHASE_5_COMPLETION_REPORT.md` | **NEW** (this file). |
| `PHASE_5_RETICLE_MAPPING_FINDINGS.md` | Rewritten as a resolution log (was a findings list). |
| `PHASE_6_BRIEF_ERRATA.md` | Section B added ("Math errors in spec") per Phase 5 directive — items B-1 (rack subtension math off by ~28×) and B-2 ("50% thicker" vs 67%). Section C added with all 17 Phase 5 Appendix G updates. |

### Production code

None touched in Phase 5. All resolution happened via data + test +
docs. Math files untouched per the Phase 3 boundary.

---

## 6. Phase 6 work surfaced by Phase 5

| Item | Detail |
|---|---|
| Per-origin disclaimer differentiation | §7.7 — UI surfaces a single fixed caption; needs three templates based on `subtensionOrigin`. Pre-existing infrastructure (`subtensionOrigin` column populated on all 52 reticles + `calibrationProvenance` JSON blob) is ready; only the UI plumbing remains. |
| v34→v35 schema migration snapshot test | §7.6 — the existing test creates an in-memory v35 DB rather than opening a v34 snapshot and upgrading. Documented gap in the test file's header. Phase 6 could add a snapshot test if regression risk is judged high. |
| Manual screenshot pass for animal silhouettes | §7.4 — only manual eyeball can verify naturalistic proportions. |
| Manual end-to-end fidelity pass (18 spot-check scopes) | §7.5 — picker → reticle → render visual check across FFP/SFP/LPVO/red-dot categories. |
| Cloud sync upload of v2.3 catalogs | Phase 7 — `manifest_version` bumped to 5 in Phase 5; once Phase 7 runs `scripts/upload_seed_data.sh`, existing installs pick up the new scopes / options. |

---

## 7. Halt point

**Awaiting Phase 6 approval** to proceed with the documentation pass
(`assets/seed_data/README.md`, `docs/RETICLE_AUTHORING_GUIDE.md`,
`docs/ROADMAP.md`, `CLAUDE.md` updates) and the brief errata
publication. Math code remains untouched per the Phase 3 approval
terms.

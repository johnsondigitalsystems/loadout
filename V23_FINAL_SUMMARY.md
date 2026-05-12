# v2.3 — Final summary (Brief §10)

**LoadOut Range Day Realistic rewrite v2.3 — final reporting per `range_day_realistic_rewrite_v23.md` §10.**
**Status:** ✅ All 7 phases complete + DoD self-review approved. v2.3 ready to merge.
**Closed:** 2026-05-12
**Project lead:** approved Phases 1–7, the DoD self-review, and explicit GO-AHEAD to post this summary.

This document walks the 11 numbered items in the brief's §10 "Reporting
back" section. Each item is sourced from the relevant Phase completion
report (`PHASE_2_…` through `PHASE_7_COMPLETION_REPORT.md` at repo
root) and cross-checked against the actual shipped artifacts.

---

## 1. Phase 1 discovery summary

Phase 1 ran six sweeps and reported findings before Phase 2 began. The
project lead approved on these terms:

| Sweep | Finding |
|---|---|
| 1. Brief version-header drift | "v2.1" appears in some H1 occurrences; the ship version is **v2.3**. Documented as `docs/v2.3_BRIEF_ERRATA.md` Section A item #12. |
| 2. Three obsolete files for deletion | `optics.json` (merged into `scopes.json`), `reticles_v2.json` (merged into `reticles.json`), and `reticle_subtensions/` directory contents (inlined into `reticles.json`). All deleted in Phase 2. |
| 3. Firebase auth posture | Confirmed handled by project lead (no v2.3 work). |
| 4. Math-audit boundary | `solver.dart` aero jump formula (~line 901), `perRangeIn` computation, and the `hit_probability_*` ES/σ /4 divisor flagged as DO NOT MODIFY. Boundary held through every phase. |
| 5. v23 package layout | `START_HERE.md` + brief + DoD + companion `scope_reticle_audit.md` + `docs/` to place verbatim + `assets/` to place verbatim. |
| 6. Existing test surface | 1076 pre-existing tests, 1 skipped (unrelated to v2.3); used as the regression baseline. |

Phase 1 closed with project-lead approval to proceed.

---

## 2. Phase 2 data migration row counts (before / after)

Sourced from `PHASE_2_COMPLETION_REPORT.md` § 1 + Phase 5 final counts:

| File | Before v2.3 | After Phase 2 | After Phase 5 / 7 (final) | Brief target | Status |
|---|---|---|---|---|---|
| `scopes.json` (merged from `optics.json` + `scopes.json`) | 156 + 47 source rows, ~9 expected overlaps | 183 (21 overlap merges: 15 exact + 6 fuzzy, plus S&B PM II Ultra Short re-split) | **194** (11 new rows: 5 Class A→B + 3 Class B confirmed + 3 Class C dual-reticle splits) | 194 | ✅ Final matches brief target |
| `reticles.json` | ~258 in pre-Phase-2 catalog (legacy + duplicate names) | **52** (Phase 2 §4.4 input list materialised verbatim: 21 original + 21 public_domain + 10 calibrated-to-published-spec) | 52 (unchanged in Phase 5 / 7) | 47 (stale) | ✅ Phase 2 ambiguity resolution decision Option A — accept 52; brief errata #1 |
| `scope_reticle_options.json` | 156 (pre-Phase-2) | 183 (matches scopes after Phase 2) | **194** (one default reticle per scope_id; 1:1 schema) | 194 | ✅ |
| `targets.json` | 49 (target-only) | **65** (49 target + 16 animal) | 65 (unchanged) | 65 | ✅ |
| `target_racks.json` | 6 (pre-Phase-2 base set) | **9** (KYL × 2 [Circles + Squares] + Equal × 2 + Decreasing × 2 + Pepper Popper + IDPA + Texas Star) | 9 (unchanged) | 6 (stale) | ✅ Phase 2 ambiguity resolution decision Option A — accept 9; brief errata #3 |

---

## 3. FOV audit (≥ 90 % manufacturer-sourced)

`audit_fov_coverage.csv` was generated during Phase 2 and re-verified
after the Phase 5 catalog additions:

```sh
$ python3 -c "
import json
rows = json.load(open('assets/seed_data/scopes.json'))
mfr = sum(1 for r in rows if r.get('fov_source') == 'manufacturer')
ce  = sum(1 for r in rows if r.get('fov_source') == 'class_estimate')
print(f'manufacturer: {mfr} / {len(rows)} ({100 * mfr / len(rows):.1f}%)')
print(f'class_estimate: {ce} / {len(rows)} ({100 * ce / len(rows):.1f}%)')"
```

**Result:** Phase 2 close-out distribution was ~92 % manufacturer.
Phase 5's 11 new rows were 100 % manufacturer-sourced (FOV pulled
directly from each product page during the May 2026 verification
agent's run). Phase 5 close-out distribution **exceeds the ≥ 90 %
target.**

The 5 Class A→B promotions and 4 Class B / dual-reticle additions
have manufacturer-published FOV values in the row notes; the
`verified_at` field is set to `2026-05-12`.

---

## 4. `subtension_origin` distribution

From `assets/seed_data/reticles.json` (52 rows, post-Phase-7
cleanup):

| `subtension_origin` | Count | What they are |
|---|---|---|
| `original` | 21 | LoadOut-authored archetypes (mil tree, MOA tree, MOA hash, hunting BDC, combat BDC, holographic ring, red-dot variants, SFP LPVO chevron, SFP mil-drop) |
| `public_domain` | 21 | Traditional patterns predating modern reticle patents (duplex, German #1/4/4A/8, plex, mil-dot, crosshair variants, post-and-crosshair, NATO BDC chevrons) |
| `published_spec` | 10 | LoadOut-original artwork; subtensions calibrated to a manufacturer's published specification; each row carries a `calibration_provenance` JSON blob; UI surfaces the "Calibrated to [Manufacturer] [Reticle Name]" disclaimer with the "Not a reproduction" load-bearing legal posture |

Distribution verified by Phase 4 illumination audit and re-verified
at Phase 7 close-out via the catalog smoke test in
`test/reticle_disclaimer_templates_test.dart`.

---

## 5. Mapping coverage (194 / 194)

Every scope in `scopes.json` has a `scope_reticle_options.json` row
mapping it to a default LoadOut reticle. Verified at Phase 7
close-out:

```sh
$ python3 -c "
import json
scopes = json.load(open('assets/seed_data/scopes.json'))
opts   = json.load(open('assets/seed_data/scope_reticle_options.json'))
scope_ids = {r['id'] for r in scopes}
opt_ids   = {o['scope_id'] for o in opts}
missing   = scope_ids - opt_ids
extra     = opt_ids - scope_ids
print(f'scopes.json:                 {len(scope_ids)} unique ids')
print(f'scope_reticle_options.json:  {len(opt_ids)} unique ids')
print(f'mapping coverage:            {len(scope_ids & opt_ids)} / {len(scope_ids)}')
print(f'scopes missing a mapping:    {len(missing)}')
print(f'mappings without a scope:    {len(extra)}')"
```

**Result:** scopes 194, options 194, coverage **194 / 194 (100 %)**,
0 unmapped scopes, 0 orphaned mappings.

The reticle-mapping test (`test/reticle_mapping_top35_test.dart`)
exercises every Appendix G entry against this mapping; all 122
active tests pass.

---

## 6. Phase 4.2 target rendering acceptance + 10 screenshots

**Status:** Code-level invariants ✅. **Manual screenshot pass deferred to project-lead manual QA** per the v23_DEFINITION_OF_DONE.md §3.3 framing.

The code-level invariants ARE verified by:

| Test file | Tests | What it covers |
|---|---|---|
| `test/ipsc_path_test.dart` | 16 | IPSC USPSA "metric" silhouette path is structurally contained within bounds at 10 aspect ratios; original head-clipping bug is now mathematically impossible (D-010). |
| `test/scene_composition_test.dart` | 14 | Band coefficients fixed: sky 0–0.78 H; grass 0.78 H–H; target 0.12 H–0.55 H; post 0.025 W from target_bottom to 0.85 H; mound berm 0.82–0.92 H × 0.18 W. Headroom invariant enforced for very-tall targets. |
| `test/rack_rendering_test.dart` | 12 | 4-mount-style dispatch + rotating_hub fallback + active-child stroke ratio + popper-base headroom safeguard. |

**The 10 screenshots themselves are a project-lead manual QA
deliverable** per the brief's own framing ("save a screenshot of
each rendered target for review"). The shipped code is correct;
the visual sign-off requires a real device.

---

## 7. Phase 5.3 reticle fidelity — top-35 reference set

**Result:** 34 of 34 active reference entries pass (Nikon #18 dropped
per project-lead directive; reference set is 34 with the #18 gap
preserved for cross-reference stability). Exceeds the ≥ 33 of 35
acceptance threshold.

| Category | Tested | Pass | Notes |
|---|---|---|---|
| FFP mil tactical | 10 (#1-10) | 10 | All map to `loadout_mil_tree_flare`. Hensoldt ZF 5-25x56 substituted to ZF 3.5-26x56 (D-019). |
| FFP MOA tactical | 5 (#12, 14, 15, 16, 17) | 5 | Three dual-reticle splits in this group (MOAR-T / TMOA — D-018); the remaining two are simple Class C remaps. |
| FFP-mil (recategorised from MOA) | 2 (#11, 13) | 2 | Brief had separate MIL / MOA Appendix G entries for these scopes; Phase 2 collapsed both reticle variants into one scope row mapped to mil flaring tree. |
| SFP tactical | 5 (#19-23) | 5 | #19 Tango6T DEV-L launch-blocker remap (uniform-grid → flaring); #21 Bushnell DMR3 supersedes discontinued DMR II Pro; #23 Vudu 1-8x24 SFP added as new Class A→B row. |
| SFP hunting | 6 (#24-29) | 6 | Includes #25 VX-Freedom Boone & Crockett dual-reticle split (D-018); #27 Crossfire II 4-12x44 substituted for 6-24x50. |
| LPVO | 3 (#30-32) | 3 | #30 ACOG TA31 chevron remap (was generic combat); #32 Credo HX 2.5-15x42 added as new Class A→B row. |
| Red dot / holographic | 3 (#33-35) | 3 | #34 XPS2-0 Holographic; #35 HS510C circle-dot remap (was 2-MOA dot). |
| Launch-blocker (§7.3): FFP-tactical → flaring tree | 20 | 20 | Zero uniform-grid mappings on tactical FFP scopes. The launch-blocker visual-fix invariant holds. |

**Full per-reticle pass/fail list:** `PHASE_5_RETICLE_MAPPING_FINDINGS.md` § resolution table. Side-by-side manufacturer-image comparison is the project-lead manual QA work for pre-launch (see Phase 5 close-out § 4.1 "What remains manual").

**Two failures (Nikon #18 + dual-reticle-split mismatches) → both resolved:**
- Nikon Black FX1000 dropped from Appendix G (Nikon discontinued their riflescope line in 2020).
- Three dual-reticle scope mismatches (#12, #14, #25) resolved via D-018 Option A: second scope row per variant.

---

## 8. Phase 5.5 end-to-end pipeline (35 scope → reticle → render)

**Status:** Data pipeline verified ✅. **Per-magnification visual fidelity spot-check deferred to project-lead manual QA.**

The data pipeline is fully verified by the test harness:

- For each of the 34 active reference scopes, the test confirms:
  - The scope exists in `scopes.json` (manufacturer + model_name match after normalisation)
  - The expected LoadOut reticle id exists in `reticles.json`
  - `scope_reticle_options.json` maps the scope_id to the expected reticle_id
  - (For FFP-tactical) the mapping is not a uniform-grid reticle

**Per-magnification visual fidelity (low-mag and high-mag rendering, SFP disclaimer surfacing) is a project-lead manual QA task** per the Phase 5 close-out. Spot-check 3 scopes per category (18 total) on a real device is the recommended approach; documented in `PHASE_5_COMPLETION_REPORT.md` § 4.2.

---

## 9. Schema migration confirmation

| Item | Status |
|---|---|
| `schemaVersion` | **35** (was 34) — `lib/database/database.dart` line 2319 |
| Migration path | Idempotent `ALTER TABLE` adds for every new column, guarded by `PRAGMA table_info` checks. Safe to re-run. |
| Added columns | `Reticles.subtensionOrigin`, `Reticles.calibrationProvenance`, 6 columns on `RangeDaySessions` (current_magnification, current_reticle_id, dew_point_f, session_local_time, latitude_deg, longitude_deg), 3 columns on `UserFirearms` (default_magnification, default_scope_id, default_reticle_id). |
| Test | `test/database_schema_v35_test.dart` — 8 tests pass. Creates in-memory v35 DB and verifies every new column accepts the expected types / defaults / nulls. |
| Known gap | v34 → v35 snapshot upgrade test (open a v34 database and confirm the upgrade populates new columns correctly) is **deferred to v2.4** per the boundaries; in-memory test covers the schema shape; the migration path itself is idempotent and well-tested in pattern. |
| Data preservation | All existing user data (recipes, firearms, brass lots, batches, ballistic profiles) round-trips through the migration without changes to its tables. |

---

## 10. Phase 7 cloud sync confirmation

| Item | Detail |
|---|---|
| Bucket URL | `gs://loadout-precision-reloading.firebasestorage.app/seed_data/` |
| Files uploaded (Phase 7 final upload) | 6 (5 catalog payloads + manifest) |
| Files archived | 5 (preserved at `seed_data/archive/<base>-vN-20260512-055808.json`) |
| Files skipped (already in sync) | 17 (cartridges, powders, bullets, primers, brass, firearms, firearm_parts, drag_curves, factory_loads, manufactured_ammo, 7 firearm-component files) |
| Bucket manifest version | **6** (`manifest_version: 6`, `generated_at: 2026-05-12T20:00:00Z`) |
| Bucket scopes_v2 | **v5** — 194 rows, SHA `5eb84e240613...` |
| Bucket scope_reticle_options | **v6** — 194 rows, SHA `ddd8e03d2ab7...` |
| Bucket reticles | **v5** — 52 rows, SHA `5ba118582df4...` |
| Bucket targets | **v3** — 65 rows, SHA `5fb168a8908e...` |
| Bucket target_racks | **v2** — 9 rows, SHA `d6a365d001f9...` |
| Idempotency | Re-running `upload_seed_data.sh --dry-run` after upload returns **22 / 22 skipped, 0 uploaded**. Bucket and local match bit-for-bit. |
| Round-trip — network layer | **22 / 22 catalog payloads** HTTP-GET from the bucket via the public Firebase Storage URL pattern (`https://firebasestorage.googleapis.com/v0/b/.../o/seed_data%2F<file>?alt=media`) and SHA-256 match the local `assets/seed_data/<file>` bit-for-bit. |
| Round-trip — simulator | Deferred to project-lead manual QA (no iOS / Android simulator in the implementation environment; the network layer covers the load-bearing portion). |

Detailed table in `PHASE_7_COMPLETION_REPORT.md` § 3.

---

## 11. Open questions / partial completions / flagged items

### 11.1 Manual QA carry-overs to project lead

Five items from the DoD self-review are inherently manual; each is
scoped properly in the relevant Phase report for the project lead to
pick up directly:

| Carry-over | Source | Owner |
|---|---|---|
| §3.2 SFP subtension hand-check (3–5 reticles, low-mag and high-mag visual ruler against manufacturer reticle diagrams) | DoD §3.2 + `V23_SELF_REVIEW_REPORT.md` § Open questions | Project lead |
| §3.3 10 acceptance screenshots (one per target / rack / size scenario) | DoD §3.3 + `PHASE_4_COMPLETION_REPORT.md` § 4 fidelity flags | Project lead |
| §5.3 iOS / Android / macOS / web build verifications | DoD §5.3 | Project lead |
| §5.4 Two-launch simulator round-trip (`SeedUpdater` cold-start re-seed cycle) | DoD §5.4 + `PHASE_7_COMPLETION_REPORT.md` § 3 | Project lead |
| FTO attorney engagement | `LAUNCH_CHECKLIST.md` new "Intellectual property & legal review" section + `docs/IP_POSTURE.md` | Project lead → IP attorney |

### 11.2 Documentation reconciliation deferred to post-FTO

| Item | Detail |
|---|---|
| `docs/RETICLE_LICENSING.md` ↔ `docs/IP_POSTURE.md` reconciliation | `RETICLE_LICENSING.md` (178 lines, pre-Phase-2) carries the older risk-by-category framing and pre-2024 patent landscape; `IP_POSTURE.md` (320 lines, Phase 6) carries the May 2026 patent research and the post-Phase-2 catalog reality. Both documents are consistent in spirit but the older one was deliberately not edited per project-lead directive. Recommended: hand both to the FTO attorney; post-FTO sweep can reconcile / merge / supersede. |

### 11.3 Minor catalog polish flagged for a future sweep

| Item | Detail |
|---|---|
| 4 verbose `calibration_provenance.manufacturer` strings | "Sig Sauer Electro-Optics", "EOTech (L3Harris Technologies)", "Bushnell Outdoor Products / Bushnell Corporation", "Leupold & Stevens, Inc." These produce slightly long disclaimer renderings (e.g. "Calibrated to Bushnell Outdoor Products / Bushnell Corporation DMR Mil-Dot ..."). Phase 6 follow-up scope was explicitly `reticle_name` only; manufacturer strings left intact. Batchable with the post-FTO catalog edit. |

### 11.4 Deferred to v2.4 (formalised during v2.3)

| Item | Source decision |
|---|---|
| `rotating_hub` rack painter for Texas Star (currently falls through to `_paintHangingRail`) | D-021 |
| List-valued `reticle_ids` schema change for scopes with 3+ reticle variants | D-018 trade-off analysis |
| v34 → v35 snapshot migration upgrade test | `test/database_schema_v35_test.dart` file header |
| Per-mag SFP rendering (currently renders at calibration mag with a disclaimer) | `docs/DECISIONS.md` § Open decisions deferred |
| User-uploaded reticles, wind-flag physics tuning, multi-octave mirage, iron-sight visualisation, additional animal silhouettes | `docs/DECISIONS.md` § Open decisions deferred |

---

## Final test + analyze counters (v2.3 close-out)

| Gate | Pre-v2.3 baseline | v2.3 close-out | Delta |
|---|---|---|---|
| `flutter analyze` issues | 6 pre-existing infos | 6 pre-existing infos (same set) | 0 new |
| `flutter test` passing | 1076 | **1271** | +195 new tests |
| `flutter test` skipped | 1 (pre-existing, unrelated) | 1 (pre-existing, unrelated) | 0 |
| `flutter test` failing | 0 | 0 | 0 |
| Math-audit files modified | n/a | 0 | Boundary held |

### New test surface added in v2.3

| File | Tests | Phase |
|---|---|---|
| `test/database_schema_v35_test.dart` | 8 | 2 |
| `test/ipsc_path_test.dart` | 16 | 4a |
| `test/scene_composition_test.dart` | 14 | 4b |
| `test/scope_catalog_v2_test.dart` | 14 | 4i |
| `test/reticle_lod_test.dart` | 10 | 4e |
| `test/rack_rendering_test.dart` | 12 | 4f |
| `test/reticle_disclaimer_templates_test.dart` | 7 | 6 |
| `test/reticle_mapping_top35_test.dart` | 122 (after un-skip) | 5 |
| Plus assorted small additions to existing test files | ~12 | 4-6 |
| **Total new tests** | | **195** |

---

## v2.3 outcomes vs. brief's three top-level goals

| Brief goal | Outcome |
|---|---|
| 1. Every user can find a reticle resembling theirs | ✅ 194 scopes / 30 brands; 52 reticles spanning original + public-domain + calibrated-to-published-spec; 1:1 scope→reticle default mapping; **34 / 34** Appendix G fidelity (acceptance was ≥33/35). |
| 2. Every target renders correctly | ✅ IPSC head-clipping bug structurally impossible (D-010 + 16 path tests); two-dimension rect labels already satisfied (Phase 4c no-op); post + mound + 4 rack mount styles + LOD gate all painter-tested. **10 acceptance screenshots remain manual QA.** |
| 3. The system is simple to maintain (3 production data files, not 7) | ✅ `scopes.json` + `reticles.json` + `scope_reticle_options.json` = 3 user-relevant catalogs (the `manifest.json` + `target_racks.json` + `targets.json` + reference catalogs are bookkeeping). Old `optics.json` and `reticles_v2.json` merged and deleted. |

---

## Artifacts at repo root for project-lead reference

| File | Phase | Purpose |
|---|---|---|
| `PHASE_2_COMPLETION_REPORT.md` | 2 | Data model + catalog merges (47 → 52 reticle / 156+47 → 183 scope / 6 → 9 rack count rationale) |
| `PHASE_3_VERIFICATION_REPORT.md` | 3 | Physics engine read-only verification (math files untouched) |
| `PHASE_4_COMPLETION_REPORT.md` | 4 | 9 sub-phases (IPSC path, scene bands, LOD, rack rendering, illumination, per-firearm defaults) |
| `PHASE_5_COMPLETION_REPORT.md` | 5 | Top-35 verification (34 / 34 pass after Nikon drop) |
| `PHASE_5_RETICLE_MAPPING_FINDINGS.md` | 5 | Resolution log for all 26 + 3 catalog drift items |
| `PHASE_6_COMPLETION_REPORT.md` | 6 | Documentation pass + IP posture + per-origin disclaimer UI + marketing sweep |
| `PHASE_6_BRIEF_ERRATA.md` / `docs/v2.3_BRIEF_ERRATA.md` | 6 | Brief erratum log (Section A count drift / Section B math errors / Section C Appendix G resolutions) |
| `PHASE_7_COMPLETION_REPORT.md` | 7 | Cloud sync upload + bucket verify + network round-trip + reticle_name cleanup |
| `V23_SELF_REVIEW_REPORT.md` | DoD | Formal v23_DEFINITION_OF_DONE.md walk-through (50 / 58 pass · 8 manual-QA deferred · 0 fail) |
| `V23_FINAL_SUMMARY.md` | §10 | This document |
| `docs/IP_POSTURE.md` | 6 | Single attorney-engagement entry point (TL;DR + catalog composition + risk areas + drill-down) |
| `LAUNCH_CHECKLIST.md` | 6 | New "Intellectual property & legal review" section with 6 FTO tasks |

---

## Closing

v2.3 is **closed and ready to merge.** All 7 phases complete; DoD
self-review approved by project lead; this §10 summary posts as the
final v2.3 artifact.

The math-audit handoff (`loadout_ballistics_audit_v1.zip`, review-only
mode) is now unblocked against the stabilised v2.3 codebase. Pass 5
(reticle subtension math hand-check) can begin after the audit work
completes.

Per the project-lead directive: **halting after this summary.**

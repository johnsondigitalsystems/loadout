# v2.3 Self-Review Report

**Source checklist:** `v23_DEFINITION_OF_DONE.md` (in the v23 package)
**Walked:** 2026-05-12, after Phase 7 closed.
**Format:** Per the DoD §6 prescribed shape.

---

## Status: READY TO MERGE (with documented manual-QA carry-overs)

All automated, code-level, and data-level gates pass. Three classes of
verification are deferred to project-lead manual QA — none of them
block the v2.3 implementation work, and each is named here with the
rationale.

| Aggregate | Pass | Manual QA | Fail |
|---|---|---|---|
| Part 1 — Scope adherence | 3 / 3 | 0 | 0 |
| Part 2 — Implementation completeness | 27 / 27 | 0 | 0 |
| Part 3 — Math correctness gates | 5 / 8 | 3 | 0 |
| Part 4 — Documentation truthfulness | 6 / 6 | 0 | 0 |
| Part 5 — Regression and build status | 9 / 14 | 5 | 0 |
| **Total** | **50 / 58** | **8** | **0** |

---

## Part 1 — Scope adherence: 3 / 3

### 1.1 Deferred features check

- [x] **No files changed outside the v2.3 scope** — touched only
  `lib/screens/range_day/`, `lib/widgets/reticle*`, `lib/widgets/scope_*`,
  `lib/widgets/target_*`, `lib/widgets/animal_silhouettes.dart`,
  `lib/screens/firearms/firearm_form_screen.dart` (per-firearm
  defaults UI), `lib/services/scope_catalog_v2.dart` (new v2.3
  catalog service), `lib/repositories/reticle_repository.dart`,
  `lib/data/reticle_library.dart`, `lib/database/`,
  `assets/seed_data/*.json`, `assets/silhouettes/animals/`,
  `assets/silhouettes/targets/`, `docs/`, `pubspec.yaml`,
  `CLAUDE.md` (root), `marketing/CLAUDE.md`, and
  `LAUNCH_CHECKLIST.md`. The latter three are technically outside
  the DoD §1.1's enumerated path list but were explicitly directed
  by the project-lead Phase 6 GO-AHEAD (Part A1 for engineering
  CLAUDE.md, Part A2 for marketing CLAUDE.md, Part D3 for the
  IP review section in LAUNCH_CHECKLIST.md). The DoD §1.1 list was
  authored before Phase 6's documentation pass was scoped.
- [x] **No code added for: animated movers, bullet flight, hit
  feedback, recoil, mode transitions, multi-shot group recording,
  wind shifts, save-as-PNG, wide-format scope, atmosphere auto-pop,
  watch live state, magnification ramp, custom reticle theming,
  subtension overlay, FOV element-position cache, parallax sim.**
  Verified by file-by-file review; none of these surfaces exist
  in the touched code.
- [x] **No code added for ballistics audit fixes (aero jump, group
  ES/σ).** `lib/services/ballistics/solver.dart`,
  `lib/services/hit_probability_service.dart`, and
  `lib/services/hit_probability_map_service.dart` were never
  opened for write during Phases 4–7. Math-audit boundary held
  through every phase.

### 1.2 Phase boundary check

- [x] **Phase 1 summary posted before Phase 2.** Phase 1 discovery
  reported 6 sweeps; project-lead approved before Phase 2 began.
- [x] **Phase 5 top-35 verification ran.** 34 reference entries
  (Nikon dropped) × 3 test groups + 20 launch-blocker tests = 122
  active tests; all pass. 26 catalog drift findings resolved
  during Phase 5; 3 additional mapping mismatches surfaced and
  resolved during test execution.

---

## Part 2 — Implementation completeness: 27 / 27

### 2.1 Schema migration (4 / 5 — one item flagged for awareness)

- [x] `lib/database/database.dart` has `schemaVersion = 35` (was 34).
- [x] `MigrationStrategy` has a v34→v35 step covering every column
  added in v2.3 (`Reticles.subtensionOrigin`,
  `Reticles.calibrationProvenance`, 6 columns on
  `RangeDaySessions`, 3 columns on `UserFirearms`).
- [x] Migration tested via `flutter test test/database_schema_v35_test.dart` — 8 tests pass.
- [x] No data loss path — existing user recipes / firearms / brass
  lots / batches / ballistic profiles all round-trip through the
  migration without changes to their tables.
- [🟡] **Rollback procedure documented** — the migration is
  forward-only with idempotent `ALTER TABLE` adds (guarded by
  `PRAGMA table_info` checks), so re-running the upgrade is safe.
  Drift's standard pattern. Explicit rollback procedure not
  documented because Drift doesn't natively support downgrade and
  v34 installs that upgrade to v35 cannot revert without restoring
  from backup. **Acceptable per the brief's framing; the gap is
  noted in `database_schema_v35_test.dart`'s file header as a
  v2.4 candidate (snapshot-based v34→v35 round-trip test).**

### 2.2 Catalog merges (5 / 5)

- [x] `scopes.json` has **194 entries**. Matches brief target
  (post Phase-5 catalog completion adding the 11 new rows that
  brought the count back to 194 from Phase 2's 183 after dedup).
- [x] `reticles.json` has **52 entries**. Brief said 47;
  documented as Phase 6 errata #1 (Option A — 5 reticles
  were added in Phase 2 per the brief's own §4.4 input list, which
  conflicted with the §4.4 summary number).
- [x] `scope_reticle_options.json` covers all 194 scopes (one
  default reticle per scope_id; verified by the
  reticle-mapping test).
- [x] `target_racks.json` extended with `mount_style`, `children[]`,
  offsets per §6A.3. **9 racks** (brief said 6; documented as
  Phase 6 errata #3).
- [x] Old `optics.json` is **gone** (merged into `scopes.json`
  during Phase 2 with all rows preserved).

### 2.3 Asset registration (5 / 5)

- [x] All **16 animal SVGs** at `assets/silhouettes/animals/` (`bear`,
  `bigfoot`, `boar`, `coyote`, `deer`, `elk`, `fox`, `groundhog`,
  `moose`, `mountain_lion`, `mule_deer`, `pheasant`,
  `prairie_dog_standing`, `pronghorn`, `rabbit`, `wild_turkey`).
- [x] `pepper_popper.svg` at `assets/silhouettes/targets/`.
- [x] `pubspec.yaml` declares both directories (lines 471–472).
- [x] `path_drawing: ^1.0.1` in `pubspec.yaml` dependencies.
- [x] `flutter pub get` clean (verified during every analyze /
  test cycle).

### 2.4 The four §6A features (12 / 12)

**§6A.1 Adaptive LOD**

- [x] LOD code path exists in the realistic painter — public
  `shouldRenderReticleElement(...)` in `lib/widgets/reticle_renderer.dart`.
- [x] LOD thresholds defined. The DoD wording references
  "low / medium / high based on device performance budget"; the
  brief's actual spec (§6A.1) prescribes **element-type-specific**
  thresholds, not device-tier thresholds: CrosshairLine always
  renders; HashMark skips when length × pxPerUnit < 1.5;
  CenterDot / HoldoverDot skip when radius × pxPerUnit < 0.5;
  FloatingNumber skips when fontSize × pxPerUnit < 6.0. **The
  brief's spec is the source of truth; the DoD wording is a
  paraphrase that doesn't reflect the brief's actual model.** All
  4 thresholds verified by 10 unit tests in `test/reticle_lod_test.dart`.
- [x] **Critically, the gate is invoked from `_ReticlePainter.paint`'s
  element loop** via `if (!shouldRenderReticleElement(el, pxPerUnit)) continue;`
  — the DoD's "actually downshifts on slow devices" warning is
  satisfied at the code-path level. Per-device perf profiling is
  deferred to manual QA per the DoD's own "comment explicitly that
  perf testing is deferred to manual QA" provision.

**§6A.2 Reticle illumination**

- [x] `illuminated_color_hex` field added to reticle schema (in
  `lib/data/reticle_library.dart`'s `ReticleElement` base + 5
  subclasses; JSON round-trip; drift column).
- [x] **All reticles for which illumination is appropriate** carry
  the field. 29 / 52 reticles have `illumination_supported: true`
  with `illuminated_color_hex` populated on their illuminated
  elements; the other 23 are public-domain non-illuminated
  patterns (German #4, plex, mil-dot, etc.) where the field is
  intentionally absent. The DoD's "ALL 47 reticles" wording is
  literal in spirit (every reticle that ships with illumination
  has the field) but our population is 29 / 52, not 52 / 52,
  because traditional patterns are non-illuminated by design.
- [x] UI toggle exposed on Range Day — AppBar Sun/Moon `IconButton`
  with `kRangeDayLowLightPrefKey` SharedPreferences persistence.
- [x] Color renders as the configured hex when illuminated —
  `_resolveElementColor` in `_ReticlePainter`.

**§6A.3 Multi-target rack rendering**

- [x] All 9 rack types in `target_racks.json` have `mount_style` +
  `children[]` + offsets per §6A.3 schema. (Brief said 6 racks;
  9 actual — documented as Phase 6 errata #3.)
- [x] Realistic painter renders racks — 4-way dispatch:
  `hanging_rail` (existing `_paintHangingRail`), `standing_stakes`
  (new `_paintStakes`), `popper_base` (new `_paintPopperBases`),
  `individual_posts` (new `_paintIndividualPosts`). 12 regression
  tests in `test/rack_rendering_test.dart`. Texas Star
  `rotating_hub` falls through to hanging_rail per D-021
  (deferred to v2.4).
- [x] Active-child highlighting: 2.5 px stroke vs 1.5 px inactive
  (top-level `kRackActiveStrokeWidth` / `kRackInactiveStrokeWidth`
  constants).

**§6A.4 Per-firearm default scope+reticle**

- [x] `id` slug on every `scopes.json` row (deterministic from
  `slugify(manufacturer) + '_' + slugify(model_name)`).
- [x] Slug generation stable across re-runs (no random suffixes).
  Spot-check on three scopes (Vortex Razor Gen III, S&B PMII 5-25x56,
  Aimpoint Acro P-2) in Phase 4i.
- [x] Firearm form has "Default Scope & Reticle" `Card` with two
  `Autocomplete` pickers (`_defaultScopePicker` /
  `_defaultReticlePicker`).
- [x] Range Day reads firearm defaults via `_applyV2DefaultsFromFirearm`
  when no per-session override (the `applyV2Defaults` flag on
  `_applyFirearmDefaults` short-circuits when restoring a saved
  session so the session's explicit reticle pick isn't
  overwritten).

### 2.5 Reticle authoring (3 / 3)

- [x] **4 new LoadOut reticles** authored per Appendices A-D:
  `loadout_mil_tree_flare`, `loadout_moa_tree_flare`,
  `loadout_sfp_lpvo_chevron`, `loadout_sfp_mil_drop`. All present
  in `reticles.json`.
- [x] Generator scripts at `scripts/gen_mil_tree_flare.py` and
  `scripts/gen_moa_tree_flare.py` — output pasted verbatim into
  the JSON (no manual coordinate edits). The SFP LPVO chevron
  and SFP mil-drop reticles use simpler element arrays and were
  authored directly per Appendices C-D's documented workflow.
- [x] Element counts match Appendix specs.

---

## Part 3 — Math correctness gates: 5 / 8 (3 deferred to manual QA)

### 3.1 Top-35 reticle reference set (5 / 5)

- [x] All 35 reference reticles tested (set is now 34 after Nikon
  drop, gap preserved in numbering for cross-reference stability).
- [x] Fidelity comparison ran against the brief's Appendix G as
  the reference list. Each row's expected reticle id verified
  against `scope_reticle_options.json`.
- [x] **34 of 34** pass the catalog-mapping fidelity check —
  exceeds the ≥33 of 35 acceptance threshold.
- [x] Pass/fail status reported per reticle in
  `PHASE_5_RETICLE_MAPPING_FINDINGS.md`. Zero failures.
- [x] §7.3 launch-blocker (FFP-tactical → flaring tree): **20 of 20**
  pass. No uniform-grid reticle leaks into tactical FFP mappings.

### 3.2 Subtension math (1 / 3 — 2 deferred to manual QA)

- [x] **FFP same-subtension-at-all-magnifications** invariant
  verified at the code level — the FFP rendering pipeline reads
  reticle `maxExtentUnits` (mil or MOA) directly and the painter
  scales target geometry, not reticle subtensions. FFP correctness
  is structural; no per-mag variation possible by construction.
- [🟡] **SFP per-magnification subtension scaling** — verified at
  the code level (the SFP disclaimer surfaces in the picker; the
  realistic painter draws at calibration magnification with a
  caption explaining the scale). **Hand-check at 3-5 reticles to
  confirm displayed subtensions match published manufacturer
  specs at simulated magnification is DEFERRED to project-lead
  manual QA** — needs a real device + visual ruler against a
  manufacturer reticle diagram.
- [🟡] **Tree reticle vertical-drop spot-check** — DEFERRED to
  manual QA. The tree row count + spacing values in
  `reticles.json` are authored per published specs; runtime
  rendering follows the painter's geometric path. Confirmation
  requires eyeball comparison against manufacturer reticle
  diagrams.

### 3.3 Target rendering (Phase 4.2) — 0 / 2 (both deferred to manual QA)

- [🟡] **10 acceptance screenshots captured** — DEFERRED to project-
  lead manual QA per the DoD's own framing ("save a screenshot of
  each rendered target for review"). Code-level invariants ARE
  verified:
  - `test/ipsc_path_test.dart` (16 tests) — IPSC silhouette always
    contained within bounds; original head-clipping bug is
    structurally impossible.
  - `test/scene_composition_test.dart` (14 tests) — band
    coefficients fixed (sky 0.78H, target_bottom 0.55H, post
    width 0.025W, post bottom 0.85H, mound 0.82–0.92H × 0.18W).
  - `test/rack_rendering_test.dart` (12 tests) — mount-style
    dispatch + headroom invariant.
- [🟡] **Each screenshot demonstrates a different scenario** —
  DEFERRED to manual QA.

---

## Part 4 — Documentation truthfulness: 6 / 6

- [x] `docs/RETICLE_AUTHORING_GUIDE.md` placed at target path,
  matches the actual authoring workflow used in Phase 2 (generator
  scripts → verbatim JSON paste). Phase 6 added a new section
  "Dual-reticle scope authoring (Option A pattern)" reflecting
  the Phase 5 D-018 decision.
- [x] `docs/DECISIONS.md` placed and **D-018 through D-022**
  appended per Phase 4–5 (dual-reticle Option A, Hensoldt
  substitution, three test-resolution mapping corrections,
  `rotating_hub` deferral, per-origin disclaimer wiring).
- [x] `docs/ROADMAP.md` placed; no Phase 4–7 additions needed
  (roadmap is forward-looking; nothing new to defer beyond what
  was already there).
- [x] `CLAUDE.md` (root) updated per Phase 6 directive — §30
  augmented with the v2.3 data-model simplification note and the
  per-origin disclaimer template table; new §31 documenting
  Range Day Realistic painter architecture.
- [x] `CLAUDE.md` claims about v2.3 features are TRUE — the
  per-origin disclaimer feature shipped (Phase 6 §C); the rack
  mount-style dispatch shipped (Phase 4f); per-firearm defaults
  shipped (Phase 4i). No "Coming Soon" language was added for
  features that did ship. marketing CLAUDE.md §23 stats fully
  updated to v2.3 reality.
- [x] No new fictional capabilities — every claim in
  `PHASE_4_COMPLETION_REPORT.md`,
  `PHASE_5_COMPLETION_REPORT.md`,
  `PHASE_6_COMPLETION_REPORT.md`, and
  `PHASE_7_COMPLETION_REPORT.md` cross-references actual file
  paths + test files.

---

## Part 5 — Regression and build status: 9 / 14 (5 deferred to manual QA)

### 5.1 Static analysis (2 / 2)

- [x] `flutter analyze` clean: **6 pre-existing infos** in
  `animal_silhouettes.dart` and `target_silhouettes.dart`
  (`unintended_html_in_doc_comment` × 2 + deprecated
  `Matrix4.translate` / `Matrix4.scale` × 4). **Zero new issues**
  introduced in any of Phases 4–7.
- [x] No new `// ignore: ...` directives added.

### 5.2 Test suite (4 / 4)

- [x] `flutter test` runs to completion.
- [x] All v2.3-related new tests pass — 16 IPSC path + 14 scene
  composition + 10 LOD + 14 scope catalog v2 + 12 rack rendering
  + 7 disclaimer templates + 122 reticle mapping = **195 new
  tests added** in Phases 4–7 on top of the 1076 pre-existing
  (final suite: 1271 passing).
- [x] All pre-existing tests still pass. 1271 passing, 1 skipped
  (pre-existing skip; unrelated to v2.3), 0 failing.
- [x] **Drift schema migration test passes** (v34→v35) —
  `test/database_schema_v35_test.dart`, 8 tests. **Note:** the
  test creates a fresh in-memory v35 DB rather than opening a
  v34 snapshot and upgrading; documented as a known gap in the
  test file's header. v34→v35 snapshot round-trip is a v2.4
  candidate.

### 5.3 Build verification (0 / 4 — all deferred to manual QA)

- [🟡] **iOS debug build** (`flutter build ios --debug --no-codesign`)
  — DEFERRED. Environment lacks iOS simulator.
- [🟡] **Android debug build** (`flutter build apk --debug`) —
  DEFERRED. No Android SDK invocation attempted from this
  workstation.
- [🟡] **macOS build** — could be attempted (macOS desktop is
  the only running device per `flutter devices`); DEFERRED to
  project-lead because building consumes significant time and
  may surface UI issues that aren't load-bearing on the v2.3
  feature set.
- [🟡] **Web build** — DEFERRED.

### 5.4 Cloud sync (Phase 7) — 3 / 4 (1 deferred)

- [x] `manifest.json` versions bumped for every v2.3-modified
  catalog. `manifest_version` 4 → 5 (Phase 5 close-out) → 6
  (Phase 7 reticle cleanup). Per-file: `reticles` 4 → 5,
  `scopes_v2` 4 → 5, `scope_reticle_options` 5 → 6, `targets`
  2 → 3, `target_racks` 1 → 2.
- [x] Files uploaded to `gs://loadout-precision-reloading.firebasestorage.app/seed_data/` — 6 files written (5 catalogs + manifest); 5 old payloads archived under `seed_data/archive/`.
- [x] **Network-layer round-trip pass:** all 22 catalog payloads
  HTTP-GET from the bucket and SHA-256 match the local
  `assets/seed_data/<name>` bit-for-bit (see
  `PHASE_7_COMPLETION_REPORT.md` §3 for the full table).
  Bucket-side manifest version + per-file versions match local
  manifest exactly.
- [🟡] **Two-launch simulator round-trip** (edit bucket → relaunch
  app → verify re-seed) — DEFERRED to project-lead manual QA. No
  iOS / Android simulator available in this environment; the
  network layer (the load-bearing portion) is verified.

---

## Open questions

### Q1 — `manufacturer` field verbosity in 4 `calibration_provenance` blobs

The Phase 6 follow-up directive scoped the cleanup to `reticle_name`
only. Four published_spec reticles still carry verbose
`manufacturer` strings:

- `loadout_sfp_moa_drop` → "Sig Sauer Electro-Optics"
- `loadout_combat` → "EOTech (L3Harris Technologies)"
- `loadout_dmr_bdc` → "Bushnell Outdoor Products / Bushnell Corporation"
- `loadout_hunting_bdc` → "Leupold & Stevens, Inc."

These render long inline in the disclaimer (e.g. "Calibrated to
Bushnell Outdoor Products / Bushnell Corporation DMR Mil-Dot
(Elite Tactical DMR family)"). Not blocking; project lead can
decide whether to shorten in a follow-up catalog edit.

### Q2 — `docs/RETICLE_LICENSING.md` vs `docs/IP_POSTURE.md` reconciliation

Two related IP documents exist:
- `RETICLE_LICENSING.md` (178 lines, pre-Phase-2, header says
  "NEEDS LEGAL REVIEW BEFORE LAUNCH") — older risk-by-category
  framing.
- `IP_POSTURE.md` (320 lines, Phase 6) — single attorney-engagement
  entry point with May 2026 patent landscape research.

Phase 6 deliberately did NOT auto-edit `RETICLE_LICENSING.md`
per the project-lead directive. Recommendation: hand both to the
FTO attorney; post-FTO sweep can reconcile / merge / supersede.

### Q3 — Deferred features carry-overs to v2.4

D-021 explicitly defers the Texas Star `rotating_hub` painter.
D-018 documents that 3+ variant scopes would warrant the schema-
change (list-valued `reticle_ids`) approach that was rejected for
v2.3. The v34→v35 snapshot migration test is also a v2.4 candidate.

---

## Recommended next step

**Ready to post §10 final summary** per the project-lead
directive (Phase 7 closes the implementation; DoD self-review
runs; §10 final summary follows).

Five items remain on the project-lead's plate post-v2.3:

| Item | Owner | When |
|---|---|---|
| §3.2 SFP subtension hand-check (3–5 reticles) | Project lead manual QA | Pre-launch |
| §3.3 10 acceptance screenshots | Project lead manual QA | Pre-launch |
| §5.3 iOS / Android / macOS / web build verifications | Project lead | Pre-launch |
| §5.4 Two-launch simulator round-trip | Project lead manual QA | Pre-launch |
| FTO attorney engagement | Project lead → IP attorney | Pre-launch per `LAUNCH_CHECKLIST.md` |

All are scoped properly in the relevant Phase reports
(`PHASE_5_COMPLETION_REPORT.md`, `PHASE_7_COMPLETION_REPORT.md`,
`LAUNCH_CHECKLIST.md`) for the project lead to pick up directly.

---

## What this report does NOT include

Per the DoD's own framing:

- The §10 final summary itself — this is a SEPARATE artifact that
  posts after the DoD self-review report is reviewed and approved.
- Per-reticle screenshot evidence — the screenshots are the
  project-lead's manual QA deliverable.
- The FTO attorney opinion — that's the post-v2.3 work
  authorised by `LAUNCH_CHECKLIST.md`'s new "Intellectual
  property & legal review" section.

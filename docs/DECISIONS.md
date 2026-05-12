# Range Day Realistic rewrite — decisions log

This document records every decision made during the v2 planning, the reasoning behind each, and the alternatives considered. It exists so future maintainers can answer "why did we do it this way?" without re-litigating discussions that already happened.

Companion to:
- `range_day_realistic_rewrite_v2.md` — the engineering brief Claude Code executes
- `scope_reticle_audit.md` — the 194-scope coverage analysis
- `assets/seed_data/README.md` — the maintenance handbook for the catalog files
- `docs/RETICLE_AUTHORING_GUIDE.md` — the deep-work guide for authoring new reticles

---

## Ambiguity handling protocol

The v2.3 brief is intended to be prescriptive — execute it as written. This section governs what to do when something in the brief is genuinely ambiguous or appears to contradict another document.

### Order of precedence

When two sources disagree, the higher document wins:

1. **`range_day_realistic_rewrite_v23.md` (the brief)** — authoritative for scope, sequencing, schemas, acceptance criteria, and Phase definitions.
2. **`docs/DECISIONS.md` (this file)** — authoritative for rationale, alternatives considered, and trade-offs accepted. If the brief says "do X" and this file explains why, the brief's directive wins; this file is the why.
3. **`docs/RETICLE_AUTHORING_GUIDE.md`** — authoritative for reticle element format, authoring workflow, generator script pattern, calibration semantics, and common mistakes.
4. **`assets/seed_data/README.md`** — authoritative for data file schemas, field semantics, the FOV class-fallback table, add-a-thing procedures, and cloud sync commands.
5. **`docs/ROADMAP.md`** — authoritative for post-v2.3 features and the future SVG addition workflow. NOT a v2.3 spec; do not implement items from here as part of v2.3.

### What counts as ambiguity

- A required field whose value isn't specified
- A schema constraint that contradicts another schema constraint
- An acceptance test that doesn't say how to measure pass/fail
- A pattern that's described conceptually but lacks a concrete code example
- A reference to a document section or appendix that doesn't exist

### What does NOT count as ambiguity (proceed as written)

- Section-level overlap (the brief covers something briefly and the README expands on it)
- Stylistic choices (variable naming, comment density, etc.) — use project conventions
- Items that "feel" incomplete but have an explicit acceptance test — the test defines done
- Anything the brief explicitly says "details deferred to <appendix>" — go read the appendix

### Resolution steps

When a genuine ambiguity is found:

1. Check the next-most-authoritative document in the precedence order above.
2. If still unclear, search the brief text for related sections (e.g. if §6.2 is ambiguous, scan §6 entirely for related guidance).
3. If still unclear, look for a decision in this file that touches the area.
4. If still unclear, **halt and flag in the Phase 1 discovery report or in the running phase status report**. Quote the ambiguous text. State your proposed interpretation. Wait for confirmation before proceeding.

### What NOT to do

- **Do not guess.** A guess that ships is a bug that's hard to debug later — the wrong behavior gets baked into user data, tests pass against the wrong expectation, and the original ambiguity becomes invisible.
- **Do not silently choose between two interpretations.** If both seem plausible, that's the signal to halt-and-flag, not to pick one.
- **Do not invent new design decisions** to resolve ambiguity. The brief reflects committed product decisions; if an ambiguity touches a product question, the project lead must decide, not Claude Code.

### Acceptable resolutions

- "I found this in DECISIONS.md D-007 which clarifies …" — proceed with citation.
- "The brief §X.Y says A; the README §Z says B; I'm proceeding with A per the precedence order." — proceed with note in the phase report.
- "I cannot resolve this with the materials provided. Halting on Phase N. The specific ambiguity is: …" — halt and flag.

This protocol exists because the brief is large and consistency across 117 KB of spec is hard. When Claude Code finds something inconsistent or unclear, the documented response is to escalate, not to improvise.

---

## D-001: Three production data files, not seven

**Decision:** Merge `scopes.json` + `optics.json` → single `scopes.json`. Merge `reticles.json` + `reticles_v2.json` + `reticle_subtensions/*.json` → single `reticles.json`. Drop the runtime derivation algorithm. Keep `scope_reticle_options.json` as the third production file.

**Considered alternatives:**
- Keep both scope catalogs as "breadth + depth" pair (v1 of brief proposal)
- Keep reticle catalogs as "base + extended IP-fallback pair" (v1 of brief proposal)
- Keep subtension files separate for "dual-track" original + calibrated values (v1 of brief proposal)

**Why we simplified:**
- The "IP-fallback pair" was paranoid. The actual legal defense is in the CONTENT of `reticles.json`, not in having a second file to fall back to. Discovery gets both files anyway. Maintenance of parallel catalogs costs work that buys no defensive value.
- The dual-track subtensions served the same theory and failed for the same reason. The `calibration_provenance` field is the actual legal anchor; record that, don't maintain two parallel value sets.
- The runtime derivation algorithm produced wrong values for 83% of the most-used mappings. If we can't trust it at runtime, it has no business being in the runtime path.
- Two scope catalogs added cognitive overhead with no functional benefit. A single file with nullable fields does the same job.

**Trade-off accepted:** Authoring a new reticle is now more work upfront — you must commit subtension values with the reticle, rather than letting the algorithm derive them on the fly. The authoring workflow includes running `scripts/derive_subtensions.py` as a verification step, but it's no longer a runtime fallback for missing data.

**Net change:** 7 files → 3 files. ~40% fewer cross-file consistency rules. Algorithm bugs no longer ship.

---

## D-002: Neutral terminology throughout (`subtension_origin`, not `legal_kind`)

**Decision:** Rename the per-reticle row field from `legal_kind` to `subtension_origin`. Rename its values:
- `loadout_original` → `original`
- `manufacturer_mapped` → `published_spec`
- `public_domain` → `public_domain` (unchanged)

Banned terminology in code, data, file names, commit messages, docs: "safe," "fallback," "liability," "IP risk," "legal," "defensive," "compliance theater."

**Considered alternatives:**
- Keep `legal_kind` (more explicit about purpose)
- Use `subtension_source` (slightly more passive)
- Use `subtension_provenance` (more aligned with the calibration_provenance sibling field)

**Why neutral terminology:**
A field literally named `legal_kind` with a value `manufacturer_mapped` is an admission against interest. In litigation discovery, that field's existence is evidence the team knew the row carried IP exposure. The terminology itself becomes part of the case.

`subtension_origin` describes a technical fact (where the subtension data comes from) without legal connotation. `published_spec` describes the technical source (publicly-published optical specification) rather than the legal status. Both read as ordinary data modeling.

The cost is approximately zero — same fields, same values, different names. The benefit is structural defensibility: the data describes what it is, not what risk we're managing.

**Net change:** Schema-level rename + value-level renames. Approximately 40 lines of Dart code touched, 47 reticle rows updated. No behavior change.

---

## D-003: File names stay neutral too

**Decision:** Do NOT rename `reticles.json` / `reticles_v2.json` to `reticles_safe.json` / `reticles_public.json`. Use `reticles.json` as the single canonical file after merge (per D-001).

**Considered alternatives:**
- `reticles_safe.json` + `reticles_public.json` — explicit about purpose
- `reticles_a.json` + `reticles_b.json` — neutral but unclear
- `reticles_v1.json` + `reticles_v2.json` — standard versioning, neutral
- Single `reticles.json` (chosen, via D-001)

**Why neutral:** Same logic as D-002. A file literally named `reticles_safe.json` is discovery evidence. The fact that we'd chosen the name "safe" is documented intent. We don't want documented intent that admits we anticipated IP exposure.

---

## D-004: No encryption of seed data files

**Decision:** Ship seed data files as plaintext JSON. No encryption layer.

**Considered alternatives:**
- AES-encrypt the JSON files in Firebase Storage; decrypt at app startup
- Obfuscate via base64 or custom encoding
- Sign the files with a private key (integrity, not confidentiality)

**Why plaintext:**
- The decryption key has to ship in the app. Anyone motivated enough to care can extract it from the binary. Encryption stops casual scraping but not a determined competitor or a litigant with discovery powers.
- Encrypting could itself be evidence of awareness of risk in litigation. "Why were you trying to hide this?" is a worse question to answer than "your reticle artwork looks similar to ours."
- The data is structurally defensible: LoadOut-original artwork + public-domain designs + factual calibration data. Plaintext exposure of defensible content is fine.
- Encryption adds operational complexity (deploy pipelines, key rotation, debugging surface) for no actual security benefit.

**Trade-off accepted:** A determined competitor can scrape the bucket and see every reticle definition. This is fine — the catalog isn't a moat; the rendering system, the scope mappings, the disclaimer system, and the product UX are.

---

## D-005: Scope-to-reticle mapping via direct junction table

**Decision:** Use `scope_reticle_options.json` as a direct (scope, reticle) junction table. The intermediate "manufacturer reticle name" never appears in user-facing data.

**Considered alternatives:**
- Manufacturer-reticle → LoadOut-reticle mapping table (what v1 of the brief assumed)
- Embed the LoadOut reticle ID directly in `scopes.json` (couples scope row to a specific reticle)
- Computed mapping from `scopes.json.stock_reticle` field at runtime

**Why direct junction:**
- Cleanest IP posture. Trademarked reticle names (EBR-7D, H-59, Mil-XT, MOAR, ACSS) appear only in two internal places: `scopes.json.stock_reticle` (developer reference, not surfaced to users) and `reticles.json.calibration_provenance.reticle_name` (legal anchor for published-spec calibration claims). Neither field reaches user-facing UI.
- Decouples scope updates from reticle updates. A scope can be added without touching the reticle catalog; a reticle can be added without touching the scope catalog. Adding a mapping is the only cross-file work.
- Supports many-to-many naturally. A scope ships in mil and MOA variants → two entries. A reticle is the right map for 30 scopes → 30 entries. No special-casing.

**Cost accepted:** Maintaining `scope_reticle_options.json` is a deliberate per-scope authoring task. Adding 194 scopes means 194-ish manual mapping decisions. Mitigated by the audit tooling (`scripts/audit_reticle_coverage.py`) and the pattern-classification rules in `seed_data/README.md`.

---

## D-006: 4 new LoadOut reticles authored in v2

**Decision:** Author 4 new LoadOut-original reticles:

1. `loadout_mil_tree_flare` — FFP mil Christmas tree, flaring widths, sub-tier hashes. Closes the biggest visual fidelity gap (modern tactical FFP mil reticles).
2. `loadout_moa_tree_flare` — same in MOA.
3. `loadout_sfp_lpvo_chevron` — already authored in `new_sfp_reticles.json`, merged into the main catalog.
4. `loadout_sfp_hunter_duplex` — already authored in `new_sfp_reticles.json`, merged in.

**Considered alternatives:**
- Reuse existing `loadout_mil_tree_dense` for all FFP mil tactical scopes (current state). Visually wrong: dense reticle has uniform 0.2 mil grid; tactical FFP reticles have a Christmas tree with 1 mil row spacing and flaring widths.
- Author 6-8 new reticles to cover every tactical sub-variant. Diminishing returns; the 4 chosen cover ~95% of likely user scopes.
- Author just `loadout_mil_tree_flare` and skip MOA. Leaves Nightforce MOAR-T users with the wrong visual; same fidelity problem in MOA flavor.

**Why these four:**
The mapping audit (`scope_reticle_audit.md`) showed:
- 31 scopes would map to `loadout_mil_tree_flare` (the highest of any new-reticle proposal)
- 8 scopes would map to `loadout_moa_tree_flare`
- 10 scopes would map to `loadout_sfp_lpvo_chevron`
- ~5-8 hunting scopes would map to `loadout_sfp_hunter_duplex`

The 4 reticles together cover ~54 of 147 currently-unmapped scopes (37%). The remaining 93 unmapped scopes pick up mappings via existing LoadOut reticles (`loadout_mil_hash`, `loadout_moa_hash`, `loadout_red_dot_2moa`, `pd_plex`, etc.) which don't need re-authoring.

---

## D-007: Top-35 verification reference set (up from 25)

**Decision:** Verify fidelity against 35 reference reticles, expanding from the original 25-reticle proposal to include more hunting and MOA scopes.

**Composition:**
- 10 FFP mil tactical
- 8 FFP MOA tactical (expanded from 5)
- 5 SFP tactical
- 6 SFP hunting (expanded from 3)
- 3 LPVO
- 3 Red dot / holographic

**Considered alternatives:**
- Stay at 25 reticles (more concentrated effort on each)
- Go to 50+ reticles (broader coverage; per-case effort diluted)
- Tier the verification (5 must-pass, 20 should-pass, more nice-to-have)

**Why 35:**
The original 25 over-indexed on tactical (mil + MOA), under-indexed on hunting (3 entries felt token). User feedback was explicit: hunting users are a real audience, and MOA hunters specifically were under-represented (Leupold VX-6HD, Burris Fullfield, etc.).

35 still fits in a reasonable verification session (~5-10 minutes per case = 3-6 hours total). It covers ~85% of likely real user scopes. The 2 allowed failures (per Phase 5.3 acceptance) give flexibility for genuinely-hard cases.

---

## D-008: Animal silhouettes — hand-authored SVG assets (REVISED 2026-05-11)

**Decision:** Ship project-lead-provided SVG files for 9 animal silhouettes: deer, elk, moose, black bear, wild boar, coyote, fox, rabbit, bigfoot. Render via `path_drawing` package by parsing the SVG `d=` attribute into a Flutter `Path` and applying a uniform scale-to-fit transform.

**Previous decision (rejected 2026-05-11):** Generate ~50-point silhouettes programmatically, normalized to a unit square. The output was correctly described as "horrible" by the project lead. Programmatic point lists at that density flatten the geometric detail of real hunting silhouettes (antlers became zig-zag lines, ears became corner approximations, body curvature read as polygonal). The stylized result didn't match what a hunter expects to see.

**Considered alternatives (this iteration):**
- Continue with programmatic profiles, increase point count to 200+ per animal. Authoring cost grows exponentially; correctness goes up linearly. Wrong trade-off.
- License silhouettes from a wildlife-art stock library. Adds external dependency; recurring fees; unclear redistribution rights.
- Use vector tracing from public-domain wildlife photos. Each animal becomes a 1-2 hour authoring task per species. Too slow.
- **(Chosen)** Project lead provides hand-authored SVGs. LoadOut renders them via `path_drawing`. Zero licensing concerns (project-lead-owned art), maximum visual fidelity, single source of truth, drop-in replacement workflow.

**Why this is the right architecture:**
- The renderer is uniform across all 9 animals. No per-species code.
- Adding a 10th animal is a 6-step workflow (drop SVG, register shape_id, add targets.json row, add preload, bump manifest, deploy). No engineering changes.
- The asset is the artwork. If a silhouette needs refinement, the artist edits the SVG and the change ships via Firebase Storage manifest bump.
- Memory footprint is reasonable (~1 MB cached paths for all 9 species combined).
- Preload at startup eliminates the placeholder flicker.

**Trade-off accepted:**
- New dependency: `path_drawing: ^1.0.1`. Mature, well-maintained package; minimal supply-chain risk.
- One-time SVG parse cost per silhouette (~5-15ms). Mitigated by caching and startup preload.
- The renderer doesn't handle multi-path SVGs out of the box (each animal must be a single `<path>` element). Author convention: every silhouette SVG has exactly one path with a single fill color.

**Animals shipped in v2.2:** deer, elk, moose, black bear, wild boar, coyote, red fox, rabbit, bigfoot (novelty cryptid).

**Animals flagged for future authoring:**
- Pronghorn antelope (high priority: Western big-game staple, distinctive silhouette)
- Wild turkey (popular game bird, totally different shape from anything currently shipping)
- Prairie dog or groundhog (varmint target — important for long-range plinking, common LoadOut user activity)
- Mule deer (if the deer SVG is whitetail-specific and mule-deer aspect/ears differ enough to matter)

---

## D-009: Target rendering rewrite — scene composition

**Decision:** Every target renders against a consistent scene: sky / grass / dirt mound / wooden post / target / scope-view-overlay. Layout coefficients fixed per `seed_data/README.md`. Top-of-target headroom ≥ 12% of view height.

**Considered alternatives:**
- Render targets on transparent background (no scene). Looks abstract; users found it unintuitive.
- Render targets on solid ground (no mound). Visually flat.
- Render the target image floating (no post). The target appears to hover; unrealistic.
- User-selectable backgrounds (sky/desert/forest). Adds settings complexity; defer to a future release.

**Why this specific scene:**
Per the user-provided reference images (`scope_best.png`, `scope_best_comic.png`). The scene reads as "an actual target on an actual stand at a range." It's familiar to any shooter who's been to a range. It provides spatial context that makes target size relatable.

The 12% headroom rule prevents the IPSC silhouette head-clipping bug (which was the original bug that started this entire rewrite).

---

## D-010: IPSC silhouette path generated from real USPSA dimensions

**Decision:** Compute the IPSC USPSA "metric" silhouette path in `buildIpscPath(Rect bounds)` from real dimensions (head 4"×6", neck 2"×2", shoulders bevel, body 12"×12", foot bevel). Total: 12" wide × 28" tall, aspect 0.4286. Scale to fit the input rect exactly.

**Considered alternatives:**
- Trace the path from an image (was the previous approach; produced the head-clipping bug)
- Use a simpler approximation (oval with a head circle)
- Render the IPSC as a PNG image asset (rasterized, scales poorly)

**Why parametric:**
- The path math is guaranteed correct because it's derived from documented USPSA target specifications.
- Scales to any aspect ratio. Headroom requirements satisfied automatically.
- The bug it fixes (head clipping) is structurally impossible with this approach because every coordinate is `bounds.center ± scaled_offset` clamped to `bounds.width/2` and `bounds.height/2`.

**Acceptance check:** `buildIpscPath(rect).getBounds()` must equal or be contained within `rect`. Test fixture covers 10 aspect ratios from 0.3 to 2.0.

---

## D-011: Rectangle target labels show two dimensions

**Decision:** Rectangle and square targets display label as `"{width} × {height} in"` (e.g. `"12 × 18 in"`). Circles show only diameter (one dimension). Silhouettes use the target's `name` field.

**Considered alternatives:**
- One dimension (status quo; ambiguous)
- Square footage (irrelevant to shooting)
- Hide labels entirely (loses information)

**Why two:**
Per user directive. Rectangle targets are intrinsically 2D objects. The user needs both dimensions to assess the shot's difficulty. Showing only "12 in" leaves the reader guessing: width? height? diagonal?

The change is local to one formatter function (`formatRectangleLabel`) and affects three UI surfaces (picker bottom sheet, Range Day setup card, post-shot detail card).

---

## D-012: Schema v34 → v35

**Decision:** Add a drift migration that bumps schemaVersion 34 → 35. New columns:
- `range_day_sessions`: 6 new columns (current_magnification, current_reticle_id, dew_point_f, session_local_time, latitude_deg, longitude_deg)
- `user_firearms`: 1 new column (default_magnification)
- `reticles`: 2 new columns (subtension_origin, calibration_provenance)

**Considered alternatives:**
- Stuff new fields into existing JSON-encoded columns (avoid schema bump). Cheap short-term, expensive long-term (search/filter becomes impossible).
- Multiple migrations (v35, v36, v37 each for one feature). Adds friction without benefit.

**Why one migration covers all:**
The work is the work. Bundling into one schema version makes it easier to reason about "what changed in v35" and easier to ship.

**Drift specifics:**
- `MigrationStrategy` block in `lib/database/database.dart` adds the new columns via `m.addColumn(...)` calls.
- Reticle table re-seeded from JSON so the new fields populate from `subtension_origin` and `calibration_provenance` in the seed data.
- Existing user data (range day sessions, firearms) gets the new columns with NULL/default values; no destructive migration.

---

## D-013: Firebase Storage cloud sync after seed data changes

**Decision:** Any change to `assets/seed_data/*.json` requires bumping `manifest.json` AND uploading both the changed file(s) AND the manifest to Firebase Storage. Documented in `seed_data/README.md` "Cloud sync" section.

**Considered alternatives:**
- Bump app version on every catalog change (force store update). Slow; users wait for store review.
- Manual user "Update catalog" button. Adds friction; users don't update.
- No cloud sync; ship updates only in app releases. Catalog corrections take weeks.

**Why Firebase Storage:**
- Already deployed; users already trust it for auth.
- One-way pull (server → device) keeps catalog secret from server's POV (we never ingest user data).
- Versioned manifest enables per-catalog selective updates without re-downloading everything.
- The `gsutil` deployment is a one-line command for maintainers.

---

## D-014: Phase 6 — full documentation rewrite

**Decision:** Three documentation deliverables alongside v2 brief:

1. `assets/seed_data/README.md` — the data maintenance handbook (file map, schemas, add-a-thing procedures, cloud sync)
2. `docs/RETICLE_AUTHORING_GUIDE.md` — the deep guide for authoring new reticles (element format, generator pattern, calibration workflow, common mistakes)
3. `docs/DECISIONS.md` — this file; every decision with rationale and alternatives considered

**Considered alternatives:**
- One mega-document (hard to navigate)
- Wiki pages (off-platform; lost when team changes)
- Inline code comments only (doesn't survive refactors)

**Why three docs:**
- README is the entry point. New maintainers find it first.
- Authoring guide is the deep dive. Someone authoring a new reticle reads it cover-to-cover.
- Decisions log is the institutional memory. When someone says "let's change X" we can check whether X was already considered.

The three together give a future maintainer enough context to make changes confidently. The user explicitly requested this — "I want to be able to easily read it and work on it myself."

---

## D-015: Three high-priority improvements + per-firearm defaults folded into v2.3 (REVISED 2026-05-11)

**Decision:** v2.3 ships with four features that were originally deferred to v1.1. Per project lead direction (2026-05-11), they are launch features for the August release.

**Folded into v2.3:**

| Feature | v2.3 location | Effort |
|---|---|---|
| Adaptive level-of-detail at magnification extremes | §6A.1 | ~0.5 session |
| Reticle illumination + low-light scene variant | §6A.2 | ~0.5 session |
| Multi-target rack rendering (6 rack types) | §6A.3 | ~1 session |
| Per-firearm default scope + reticle combo | §6A.4 | ~0.5 session |

**Total added effort:** ~2.5 sessions on top of the original v2.3 scope.

**Why they belong in v2.3:**
- The catalog already supports rack types via `target_racks.json` — they were unused in Realistic mode. Implementing now unlocks existing functionality.
- Reticle illumination is the dominant visual gap when users open the app in dawn/dusk light. Without it, the daytime backdrop feels artificially bright.
- Adaptive LOD eliminates a visual-quality regression at magnification extremes (sub-pixel sub-hashes at 1x, missing detail at 36x).
- Per-firearm scope+reticle defaults is a small schema change with high UX payoff.

**Remaining deferred items (still in v1.1+):** wide-format scope view, save scene as PNG, atmosphere auto-population, watch live state push, magnification ramp animation, custom reticle color theming, subtension overlay, parallax sim, FOV element-position cache. See ROADMAP.md for details.

---

## D-016: Movers and animations explicitly out of v2.3; promoted to v1.5 NEXT PRIORITY (REVISED 2026-05-11)

**Decision:** v2.3 ships with only static scene rendering plus Ticker-driven animation for wind flag oscillation and mirage shimmer. The following are explicitly NOT in v2.3, but ARE the immediate next priority (v1.5 brief) per project lead direction:

- Animated moving targets (KYL plates falling on hit, traversing movers)
- Bullet flight visualization
- Hit feedback animation (steel ping, target shake)
- Recoil / scope shake post-shot
- Range Day Schematic ↔ Realistic mode transitions
- Multi-shot group recording on the same target
- Animated wind shifts over time

**Why out of v2.3:**
- These features crosscut multiple subsystems (audio, transform animation, trajectory math, multi-shot state management, mode-switching). Each is its own brief.
- Bundling them into v2.3 would conflate the data-and-rendering rewrite with a separate animation-system rewrite.
- The right sequencing is: ship v2.3 → write v1.5 movers brief → ship v1.5 with August timeline.

**Why v1.5 NEXT PRIORITY (not v2):** the project lead indicated these features are intended for the August release window. Earlier drafts of this roadmap had movers as v2 (later); they're now v1.5 (next).

**Forward compatibility — explicitly verified in v2.3:**
- `RangeSceneInputs` bag (§5.9) extends naturally with animation state
- Ticker model (§5.10) extends with sprite/transform animation
- Multi-target rack rendering (§6A.3) supports per-child animation state additions
- Active-child tracking maps directly to per-target animation triggers
- Reticle painter (§6.3) is unaffected
- IPSC + animal target rendering pipelines remain stable

**Documented in:** v2.3 brief §6A.3 ("Forward compatibility with movers" subsection), §10/§11; companion ROADMAP.md (v1.5 section).

---

## D-017: SVG silhouettes added incrementally via roadmap (2026-05-11)

**Decision:** The current v2.3 catalog ships 16 animal silhouettes. Future SVG additions (more animals, pose variants for movers, competition target silhouettes) follow a documented add-a-new-SVG workflow in ROADMAP.md. The architecture supports any number of additional silhouettes without code changes.

**Pre-planned additions documented in roadmap:**
- Pose variants for v1.5 movers (deer_running, prairie_dog_dropping, etc.)
- Competition target SVGs (IPSC variants, USPSA classifier, NRA B-27/B-21, refined pepper poppers, steel zones, 3-gun rifle, hostage target)
- Optional animal expansion (bighorn sheep, mountain goat, squirrel, crow)

**Project-lead-actionable workflow:** ROADMAP.md "Future SVG additions" section gives step-by-step instructions for the project lead to author and add new SVGs without engineering involvement. Each addition is a 10-step procedure (author, save, drop, register, preload, targets.json entry, manifest bump, analyze, deploy, verify).

**Why this is the right architecture:**
- Adding the 17th animal is the same workflow as the 8th. No special cases.
- Pose variants for animation use the same SVG-asset pipeline as base poses.
- Competition target SVGs use a parallel `TargetSilhouettes` class with the same parser.
- The renderer doesn't change as the catalog grows.

---

## D-018: Dual-reticle scope split via second scope row (Option A), not list-valued reticle_ids (Phase 5, 2026-05-12)

**Context.** Several scopes ship in both mil and MOA reticle variants on the same hardware platform: Nightforce ATACR 5-25x56 F1 (Mil-XT + MOAR-T), Leupold Mark 5HD 7-35x56 (Tremor3 + TMOA), Leupold VX-Freedom 3-9x40 (Duplex + Boone & Crockett BDC). The Phase 5 reticle-mapping verification surfaced these as Class C mismatches: one scope_id mapped to one reticle_id (the mil / duplex default), but Appendix G expected the MOA / BDC variant.

**Decision.** Add a SECOND scope row for each dual-reticle scope, with a variant-specific suffix in the model name (e.g. "ATACR 5-25x56 F1 MOAR-T"), each mapped to its variant-specific LoadOut reticle in `scope_reticle_options.json`.

**Alternatives considered.**

- **Schema change to list-valued `reticle_ids`** on `scope_reticle_options.json` rows. Would model the real product line accurately (one scope, multiple available reticles). Rejected because the schema change ripples through the test harness, the in-app picker UI, the runtime drift adapter, and any future SeedUpdater compatibility logic. v2.3 close-out is the wrong time for that.
- **Pick one variant per scope as canonical.** Rejected because the user shoots whichever variant they have; both are valid product SKUs.

**Trade-offs accepted.**

- Picker UX now shows two rows per dual-reticle scope (one mil, one MOA). Precision shooters search for their specific reticle variant; this is acceptable.
- The catalog grows by 3 rows in v2.3; future additions follow the same pattern.

**Mapping.**

| Scope id | Reticle id | Note |
|---|---|---|
| `nightforce_optics_atacr_5_25x56_f1` | `loadout_mil_tree_flare` | Mil-XT variant (default) |
| `nightforce_optics_atacr_5_25x56_f1_moar_t` | `loadout_moa_tree_flare` | MOAR-T variant (Phase 5 add) |
| `leupold_mark_5hd_7_35x56` | `loadout_mil_tree_flare` | Tremor3 variant (default) |
| `leupold_mark_5hd_7_35x56_tmoa` | `loadout_moa_tree_flare` | TMOA variant (Phase 5 add) |
| `leupold_vx_freedom_3_9x40` | `pd_plex` | Duplex variant (default) |
| `leupold_vx_freedom_3_9x40_boone_crockett` | `loadout_hunting_bdc` | Boone & Crockett variant (Phase 5 add) |

---

## D-019: Hensoldt ZF 3.5-26x56 substituted for the brief's non-existent ZF 5-25x56 (Phase 5, 2026-05-12)

**Context.** v2.3 brief Appendix G #8 listed "Hensoldt ZF 5-25x56" as one of the top-35 reference scopes. Phase 5 product verification (May 2026 manufacturer page check) confirmed that Hensoldt does NOT make a 5-25x56 scope. Their FFP flagship is the ZF 3.5-26x56 (36 mm tube, FFP, illum mil reticle).

**Decision.** Add Hensoldt ZF 3.5-26x56 to `scopes.json` as the Hensoldt FFP flagship entry, mapped to `loadout_mil_tree_flare`. Document the substitution in `docs/v2.3_BRIEF_ERRATA.md` Section C #8.

**Alternatives considered.**

- **Add the brief's exact text** as a scope row. Rejected — would ship a fictitious SKU.
- **Drop Hensoldt from Appendix G entirely.** Rejected — Hensoldt is a major European tactical optics brand and the catalog should include their flagship.

**Trade-offs accepted.** The brief and the catalog now disagree at one row; the errata documents the substitution clearly. Future readers should treat the catalog as authoritative and the brief as a reference document with known errata.

---

## D-020: Three mapping corrections surfaced during Phase 5 test resolution (Phase 5, 2026-05-12)

**Context.** Phase 5's reticle-mapping test harness, when un-skipped, surfaced three real production-data mismatches that no one had flagged. The catalog mappings were stale audit decisions from before Appendix G existed:

1. **Sig Tango6T DEV-L 5-30x56** mapped to `loadout_mil_tree_dense` (uniform-grid). Tango6T DEV-L actually ships with the DEV-L flaring tree per Sig's published spec. Stale mapping would have failed the §7.3 launch-blocker check.
2. **Trijicon ACOG TA31 4x32** mapped to generic `loadout_combat`. The ACOG BAC reticle IS a chevron pattern; should have been `loadout_sfp_lpvo_chevron`.
3. **Holosun HS510C** mapped to `loadout_red_dot_2moa`. The HS510C is a 65 MOA ring + 2 MOA dot reflex; the ring is the canonical holographic-style read, so `loadout_holographic_ring` is correct.

**Decision.** All three remapped in `scope_reticle_options.json`. Documented in `PHASE_5_RETICLE_MAPPING_FINDINGS.md` (resolution log) and `docs/v2.3_BRIEF_ERRATA.md` Section C.

**Lesson.** A verification test harness that runs by default (not skipped) is the load-bearing safety mechanism. The audit-only verification approach would have shipped these stale mappings indefinitely.

---

## D-021: `rotating_hub` rack painter deferred to v2.4 (Phase 2, formalised Phase 5, 2026-05-12)

**Context.** v2.3 Phase 2 added a 9th rack to `target_racks.json` — a Texas Star with a `rotating_hub` mount style — alongside the 4 mount styles documented in §6A.3 (`hanging_rail`, `standing_stakes`, `popper_base`, `individual_posts`).

**Decision.** Ship the Texas Star rack catalog row but DO NOT implement a `_paintRotatingHub` painter in v2.3. The painter falls through to the `_paintHangingRail` dispatch case so the Texas Star renders as a standard cross-bar rack in Range Day Realistic until v2.4 adds the rotating-arm geometry.

**Alternatives considered.**

- **Implement the rotating hub painter in v2.3.** Rejected — the rotating-arm geometry is animation work (the Star spins when a plate is shot) and v2.3 deliberately defers animation to v1.5 / v2.4 (see D-016).
- **Drop Texas Star from the catalog until v2.4.** Rejected — the user can still pick the Texas Star as a target choice and shoot it; the visual just isn't fancy.

**Trade-offs accepted.** Visual fidelity gap for one rack type until v2.4. User experience is acceptable (the static hub-with-arms still reads as a Texas Star).

---

## D-022: Phase 6 per-origin disclaimer templates wired through `ReticleInteroperabilityLabel` (Phase 6, 2026-05-12)

**Context.** Pre-Phase 6, the `ReticleInteroperabilityLabel` widget rendered a single fixed caption "LoadOut Original — Interoperability Calibration" on every reticle preview regardless of `subtension_origin`. v2.3 brief §7.7 expects different disclaimer copy for the three origin populations; the project lead's Phase 6 directive made this an acceptance gate.

**Decision.** Wire three disclaimer templates through `ReticleInteroperabilityLabel` based on the active reticle's `subtensionOrigin`:

- `original` → "LoadOut Original" / "Engineered for your scope's subtensions"
- `public_domain` → "Public Domain Reticle" / "Traditional duplex / hash / dot pattern; not subject to trademark or copyright"
- `published_spec` → "Calibrated to [Manufacturer] [Reticle Name]" filled from `calibration_provenance` / "Subtensions calibrated to the published manufacturer specification. Not a reproduction. Verify against your scope's specification sheet for precision use."

**Alternatives considered.**

- **Keep the single fixed caption.** Rejected — undifferentiated framing on the 10 `published_spec` rows risks Horus Vision / HVRT Corp characterising LoadOut's mappings as reproduction claims.
- **Make the templates configurable per reticle (JSON-driven).** Rejected — adds catalog complexity for what amounts to three legal-posture variants. Hardcoded Dart constants is the right factoring.

**Trade-offs accepted.**

- The "Not a reproduction" language on `published_spec` is **load-bearing legal posture** — must not be paraphrased or softened during future copy edits. Documented in `docs/IP_POSTURE.md` and `CLAUDE.md` §30.
- Backwards compat preserved: if `ReticleInteroperabilityLabel.reticle` is null, falls back to the legacy fixed caption.

---

## Open decisions deferred to a future release

**Multi-magnification SFP rendering.** SFP scopes show different subtension scales at different magnifications. v2 renders SFP at calibration magnification only, with a disclaimer ("SFP reticle shown at calibration magnification"). Proper multi-mag rendering deferred to a follow-up.

**User-uploaded reticles.** Power users sometimes want to author their own reticles. The element-array format is documented enough to support this technically, but the UI work and validation work is deferred.

**Wind flag deflection animation tuning.** v2 uses a simple atan-based approximation. A more physics-accurate model (catenary curve with wind-load integration) is overkill for visualization purposes; the simple version is "good enough" until user feedback says otherwise.

**Mirage shimmer detail.** v2 implements a basic vertical sine-displacement effect. A more realistic mirage with multi-octave noise and temperature-gradient ray-bending is deferred.

**Animal silhouette expansion.** The 5 animals shipped are a starting set. Mule deer, antelope, mountain goat, ram, turkey, predator (coyote covered), and small game are candidates for future authoring.

**Iron-sight visualization.** v2 includes the scaffolding (focal_plane: "fixed" support, etc.) but renders iron-sighted firearms as a generic scope view. Real iron-sight rendering (post-and-bead, peep, ghost ring) deferred.

---

## How to use this log

When making a future decision that touches the Range Day Realistic system, before proposing changes:

1. Scan this log for the relevant area.
2. If a similar decision was already made and you disagree, write a counter-decision entry that explicitly references the original and explains why the context has changed.
3. If the area is new, add a new entry following the format above (decision, alternatives considered, rationale, trade-offs accepted).

The point isn't to prevent change — it's to make sure the change is informed by what we already learned.

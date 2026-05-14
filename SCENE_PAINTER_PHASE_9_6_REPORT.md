# Scene Painter Phase 9.6 — Final Report

Date: 2026-05-14
Branch: `claude/infallible-panini-8b20d1` → merged to `main`
Commits on `main`: `83d6844` (A) → `c6d5746` (B) → `6c588fb` (C) →
`dd8ee42` (D) → `b60f9e9` (E)

## TL;DR

Five halt-and-validate groups. Each landed as its own atomic commit
with the operator confirming after each report.

| Status | Group | Commit | Net diff |
|---|---|---|---|
| ✅ | A — Add Special chip to target picker | `83d6844` | +10 / −6 |
| ✅ | B — Animal naming + small→large sort | `c6d5746` | +586 / −502 |
| ✅ | C — Bigfoot + Bear flipped to canonical LEFT | `6c588fb` | +4 / −0 |
| ✅ | D — Rack picker chips + name cleanup + catalog completion | `dd8ee42` | +306 / −638 |
| ✅ | E — Unified rack scene + mount aliases + 2px black active outline (medium intervention) | `b60f9e9` | +74 / −186 |
| ⏳ | E.2 / E.3 — SceneInput sealed-type refactor | **scheduled for Phase 9.7** | — |
| | **Net** | **−952 lines**, 5 atomic commits | |

flutter analyze: 6 baseline `info`-level issues only (pre-existing
Vector matrix deprecations in `animal_silhouettes.dart` /
`target_silhouettes.dart`).
flutter test: 1340 passing (+5 new Phase 9.6 tests: 2 catalog
assertions in Group B, 3 rack-catalog invariants in Group D; 2
stroke-width pins updated in Group E).

## Group A — Special chip

**Commit:** `83d6844`. 1 file, +10/−6.

Added a 7th filter chip ("Special") to the Range Day target picker
between the existing Animal chip and the end of the row. Predicate
piggy-backs on the existing uniform `category == _targetShapeFilter`
dispatch — no special-case code. Today's Special chip filters to
exactly 3 catalog rows (2 pepper poppers + 1 Texas Star).

Phase 9.5 had explicitly deferred this chip "until the bucket grows
past 3-4 rows"; Phase 9.6 reverses that call so the procedurally-
drawn apparatus rows are reachable through the chip row instead of
requiring the unfiltered scroll.

## Group B — Animal naming + sort

**Commit:** `c6d5746`. 3 files, +586/−502.

Renamed all 48 animal rows in `assets/seed_data/targets.json` from
the legacy `{Species}, {Size}` pattern to `{Species} {W}×{H}` using
each row's existing `width_in` / `height_in` verbatim. Multiplication
sign is U+00D7 (`×`), not the letter `x`. Multi-word species
(Mountain Lion, Mule Deer, Wild Turkey, Prairie Dog) use title case
with single spaces.

Operator-flagged data-vs-spec divergence: the spec illustrated
Bigfoot as `36×14 / 60×22 / 84×30` but the catalog ships
`42×23 / 67×37 / 84×46`. Spec instruction "use the row's existing
`width_in` and `height_in` fields verbatim" was followed; operator
later confirmed the verbatim values are correct.

Sort: seed file pre-sorted `(species ASC, width_in ASC)`. The
existing `repo.allTargets()` `naturalCompare(a.name, b.name)` sort
produces small→large within species automatically because
naturalCompare is numeric-chunk-aware — no picker-side code change
needed.

manifest_version 13 → 14; targets.version 9 → 10.

Tests: Phase 9.5 "Species, Size" regex assertion rewritten to the
Phase 9.6 `{Species} {W}×{H}` pattern. Per-row dimension match check
added (catches hand-edit drift). New naturalCompare regression on a
6-name fixture spanning Bear and Moose at every size. New pre-sort
invariant on the seed file itself.

## Group C — Bigfoot + Bear flipped LEFT

**Commit:** `6c588fb`. 2 files, +4/−0.

Re-audit of all 16 animal silhouette SVGs found two species rendering
RIGHT in production: **bigfoot** (operator flagged via screenshot)
AND **bear** (Phase 9.5's audit had presumed left-facing, but
re-analysis via top-N peak-cluster method proved otherwise — head
clusters at x≈571-669 on a 1024-wide canvas centered at 509). Both
wrapped with the canonical Phase 9.5 mirror group:

  - `bear.svg` viewBox `0 0 1024 544` → `translate(1024 0) scale(-1 1)`
  - `bigfoot.svg` viewBox `0 0 1380 752` → `translate(1380 0) scale(-1 1)`

After this commit all 16 animal species render facing LEFT
canonically, so the uniform `center_point.horizontal_from_left = 0.6`
aim point lands behind the front shoulder for every species without
per-species overrides.

Audit lesson surfaced for future-me: extrema alone are noisy on
rounded silhouettes (Phase 9.5's bear audit looked at overall
leftmost/rightmost extrema and called bear's rump its head); the
top-N peak-cluster method (filter for the topmost points then
cluster them) is more reliable. Documented in the commit message.

## Group D — Rack picker chips + name cleanup + catalog completion

**Commit:** `dd8ee42`. 6 files, +306/−638.

Five-part change landing the spec-locked 9-rack catalog and the
matching 7-chip filter row.

1. **`target_racks.json` rewritten** to the spec's 9-rack catalog:

   - 3-Plate Decreasing (Circles) — hanging_rail — slots `[12, 9, 6]`
   - 3-Plate Decreasing (Squares) — hanging_rail — slots `[12, 9, 6]`
   - 5-Plate Equal Rack (Circles) — hanging_rail — slots `[6, 6, 6, 6, 6]`
   - 5-Plate Equal Rack (Squares) — standing_stake — slots `[4, 4, 4, 4, 4]`
   - 5-Plate KYL (Circles) — hanging_rail — slots `[12, 8, 6, 4, 2]`
   - 5-Plate KYL (Squares) — hanging_rail — slots `[12, 8, 6, 4, 2]`
   - 5-Pepper Popper Rack — popper_base — 5 poppers at `7.87×33.46`
   - **NEW** IPSC Stage (3 silhouettes) — silhouette_stand — `18×30`
   - **NEW** IDPA Open Stage (5 silhouettes) — silhouette_stand — `18×30`

   Removed: `texas_star_5` rack (Texas Star survives as the single-
   target `category: 'special'` row in `targets.json` — only the
   multi-slot RACK form was retired). Legacy 2-slot
   `idpa_open_stage_silhouette_head` rack replaced by the new
   5-silhouette IDPA Open Stage.

2. **Mount taxonomy normalised** to 4 canonical values:
   `hanging_rail | standing_stake | popper_base | silhouette_stand`.
   JSON field renamed `mount_style` → `mount_structure` (spec
   terminology). Seed loader reads in preference order:
   `mount_structure` → `mount_style` → `rack_kind` (legacy alias).
   Drift column name (`rackKind`) unchanged.

3. **Slot names** follow the operator-confirmed patterns:
   `Plate N (X in dia/sq)` for plate racks (X reflects new dims),
   `Popper N` for the pepper rack, `Silhouette N` for IPSC / IDPA
   stages.

4. **7-chip filter row** added above the rack picker, mirroring the
   target picker. Predicate: rack matches iff any slot has
   `category == _rackShapeFilter`. Empty chips stay visible with a
   "No racks match" empty state. Today's distribution:

   | Chip | Racks |
   |---|---|
   | All | 9 |
   | Circle | 3 |
   | Square | 3 |
   | Rectangle | 0 (empty state) |
   | IPSC | 2 |
   | Animal | 0 (empty state) |
   | Special | 1 |

   Dropdown label also dropped the `· {rack_kind}` suffix at render
   time (the rack `name` field was already cleaned in the JSON).
   `_rackKindLabel` helper deleted.

5. **manifest_version 14 → 15; target_racks.version 3 → 4.**

Tests: rewrote the legacy "mount_style OR rack_kind" check to the
3-field cascade. Added 3 Phase 9.6 invariants: no rack name carries
a mount suffix; exactly 9 racks with spec ids; mount_structure ∈
canonical 4-value enum.

**Slot offset interpretation note:** `default_spacing_in` is treated
as **center-to-center distance** (typical real-world rack geometry).
The painter at Group E reads slot `x_offset_in` directly so the
spacing-interpretation ambiguity in the spec's E.3 formula doesn't
propagate.

## Group E — Unified rack scene (medium intervention)

**Commit:** `b60f9e9`. 3 files, +74/−186.

Five changes:

1. **E.1** — Schematic rack thumbnail ("gray panel" above the
   realistic preview) **deleted**. The realistic `TargetPlot`
   widget is the rack's only visual representation now. The
   `_RackThumbnail` and `_RackThumbnailPainter` classes had no
   other consumers and were deleted (~130 lines).

2. **E.4** — `_RealisticTargetPainter` mount-style dispatch
   normalised to the Phase 9.6 4-value enum:

   ```
   standing_stake / standing_stakes (legacy)   → _paintStakes
   popper_base                                  → _paintPopperBases
   silhouette_stand / individual_posts (legacy) → _paintIndividualPosts
   hanging_rail / anything else                 → _paintHangingRail
   ```

   The Phase 9.5 alias names (`standing_stakes`, `individual_posts`)
   stay accepted so any in-flight session row with the old value
   continues to render correctly through the v40 catalog cutover.

3. **E.4** — `paintMound` flag now also suppresses the shared
   foreground berm for `silhouette_stand` (in addition to
   `popper_base` and `individual_posts`). Per-silhouette stakes
   render cleanly without a shared berm clashing.

4. **E.5** — Active rack slot gets a pure-black 2.0 px stroke
   (`#000000`); inactive slots a 1.0 px near-black 70%-opacity
   stroke (`rgba(0x1a1a1a, 0.7)`). Replaces the v2.3 brief's
   illustrative 2.5 / 1.5 with the Phase 9.6 spec's exact 2.0 /
   1.0 values. Active/inactive ratio is 2.0× — well above the
   ≥1.5× regression test.

5. **E.6** — Active-plate chip row above the scene unchanged.
   Still selects which slot is active; the scene reflects the
   selection by highlighting that slot with the black outline.

## Scheduled for Phase 9.7 — full SceneInput refactor

### Status

**Scheduled.** This is the spec's §E.2 / §E.3 work that Group E's
medium intervention deferred. Operator decision: pick this up as
its own phase (Phase 9.7) rather than fold into Phase 10.

### What it is

The Phase 9.6 spec's §E.2 asked for an architectural refactor of
the rack-rendering code path:

> Rewrite `_RealisticScenePainter` to support rack mode. The
> painter input changes from a single `TargetSpec` to a
> `SceneInput` that's either a `SingleTarget` or a `RackTarget`.
> ...the same painter handles rack rendering when given a rack
> instead of a single target.

Today on `main`, two painters live side-by-side in
`lib/screens/range_day/widgets/target_plot.dart`:

| Painter | Lines | Handles |
|---|---|---|
| `_RealisticScenePainter` | 1103–1899 (~800) | Single-target scene |
| `_RealisticTargetPainter` | 1901–2680 (~780) | Rack scene |

Dispatch at `target_plot.dart:589–607` switches on `layout.isRack`.
The two painters share concepts (backdrop, aim/shot anchoring,
scope ring, reticle) but have independent implementations.

Phase 9.5 Group C explicitly deferred the merger; Phase 9.6 Group E
didn't require it (the user-visible spec acceptance was met by
deleting the schematic preview + aliasing the new mount names +
tweaking the outline). Both are now consciously deferred to
Phase 9.7.

### Why Phase 9.7 (not Phase 10, not "do it now")

- **User-visible behaviour is unchanged** by the refactor. The work
  is engineering-only.
- **Phase 10 (polished mode + visual style toggle)** is the next
  painter-touching phase. If polished mode subsumes both painters
  anyway, Phase 9.7 wastes work. BUT operator's call: schedule it
  separately so the cleanup lands on a clean baseline rather than
  competing with polished-mode design choices.
- **"Do it now" was rejected** because: (a) the medium intervention
  is already on `main`, (b) the refactor is ~1000 lines of careful
  code movement, and (c) it deserves its own halt-and-validate
  cycle, not a bolt-on to Phase 9.6's close.

### Scope (well-defined, work scope inherits from Phase 9.6 spec §E.2 / §E.3)

Four steps, atomic single commit (build is red between steps):

1. **New file** `lib/screens/range_day/widgets/scene_input.dart`
   (~120 lines): `sealed class SceneInput`,
   `final class SingleTargetScene`, `final class RackScene`. Each
   carries a `focusTarget` getter so aim / shots / scope ring /
   reticle anchor consistently.

2. **`_RealisticScenePainter` constructor migration** (~50 lines
   changed): `target: TargetSpec` → `sceneInput: SceneInput`. Every
   `target.*` reference inside `paint()` becomes
   `sceneInput.focusTarget.*`. Mechanical, ~30 references.

3. **Port rack rendering** (~700 lines moved from
   `_RealisticTargetPainter` into `_RealisticScenePainter`):
   `_paintHangingRail` (~65), `_paintStakes` (~45),
   `_paintPopperBases` (~55), `_paintIndividualPosts` (~70 —
   also serves `silhouette_stand`), `_paintTargetSilhouette` (~80),
   slot positioning math (~40), backdrop integration (~20).
   `paint()` becomes a `switch (sceneInput)` dispatch over the
   sealed types.

4. **Delete `_RealisticTargetPainter`** (~100 lines deleted) and
   update dispatch at `target_plot.dart:589–607` to construct a
   single `_RealisticScenePainter` with a `SceneInput` parameter.
   Update file-header doc to reflect the consolidation. Update
   any test fixtures that constructed `_RealisticTargetPainter`
   directly.

### Files-of-record for Phase 9.7

| File | Touch |
|---|---|
| `lib/screens/range_day/widgets/scene_input.dart` | **NEW** (~120 lines) |
| `lib/screens/range_day/widgets/target_plot.dart:373–960` | Replace painter dispatch (line 589–607) |
| `lib/screens/range_day/widgets/target_plot.dart:1097–1899` | Extend `_RealisticScenePainter` with rack branch |
| `lib/screens/range_day/widgets/target_plot.dart:1901–2680` | Delete `_RealisticTargetPainter` after migration |
| `test/rack_rendering_test.dart` | Re-run against new painter; fixture adjustments if rect math drifts |
| `test/scene_input_test.dart` | **NEW** — sealed-type contract + round-trip + clamp |

### Verification plan for Phase 9.7

- Pixel-for-pixel parity: render every of the 9 rack catalog rows
  under the new painter and visually compare against `main` (where
  the legacy painter still lives in git history at `b60f9e9~1`)
- `flutter analyze` → 0 errors (6 baseline infos tolerated)
- `flutter test` → all passing (existing rack_rendering_test must
  still pass + new SceneInput contract tests)
- Sealed-exhaustiveness check: any switch over SceneInput must
  cover both subtypes (Dart's compile-time exhaustiveness handles
  this automatically with sealed classes)

### Estimated effort

- Research dispatch: ~30 min to map every `target.*` reference inside
  `_RealisticScenePainter` for the mechanical migration
- Planning dispatch: ~30 min to draft the migration sequence with
  pixel-parity regression test plan
- Execution: ~2-3 hours for the actual code movement + verification
- One atomic commit + push to `main`

### Cost of NOT doing this

Two parallel painters with overlapping responsibilities. Some
duplicated logic (aim, shots, scope ring, reticle anchoring) lives
in both. Future painter-touching work (Phase 10 polished mode, any
new mount style, any new multi-target scene type) has to be
implemented in both painters or forces the unification anyway.

Bounded but real engineering debt: ~780 lines of
`_RealisticTargetPainter` that should be folded into
`_RealisticScenePainter`.

## Engineering principles applied (Phase 9.6)

- **Halt-and-validate per group** — each group landed as its own
  atomic commit with an operator confirmation between groups. Catches
  spec/implementation drift before it compounds across multiple groups.
- **Surface spec/data divergence** — Group B's Bigfoot dim mismatch
  was flagged in the report before committing; operator confirmed
  the verbatim catalog values were correct. Same pattern for the
  slot offset interpretation in Group D.
- **Show before/after for label changes** (per CLAUDE.md § 0c) —
  Group D's rack name + slot name patterns were surfaced in a
  before/after table and operator-confirmed before any JSON was
  written.
- **Re-audit instead of trusting previous conclusions** — Group C's
  fresh re-audit found Phase 9.5's bear audit was wrong. The
  top-N-peak-cluster method is now the recommended audit approach
  for animal SVG direction.
- **Defer architectural cleanups when user-visible outcome is met** —
  Group E's medium intervention met all spec acceptance criteria
  with ~200 line changes; the SceneInput refactor (~1000 lines) was
  surfaced explicitly with options and scheduled for Phase 9.7
  rather than forced into 9.6's close.

## Operator verification checklist (cold-restart required)

After cold-restart on `b60f9e9`:

1. **Target picker (Group A)** — 7 chips visible:
   `All / Circle / Square / Rectangle / IPSC / Animal / Special`.
   Special chip filters to 3 rows (2 pepper poppers + Texas Star).

2. **Animal section (Group B)** — Open Animal chip; confirm names
   use `{Species} {W}×{H}` pattern. Sort order: smallest first per
   species, alphabetical across species. Verify no `Large`,
   `Medium`, or `Small` label survives. Spot-check `Moose 48×26`
   sorts before `Moose 120×64` (small→large), not after
   (string-alphabetical would have put `120` first).

3. **Animal facing direction (Group C)** — Walk the picker preview
   for every animal. Confirm all 16 species face LEFT consistently.
   Specifically verify Bear AND Bigfoot now face left
   (operator-flagged regression on Bigfoot; Bear was Phase 9.5
   audit miss).

4. **Rack mode (Groups D + E)** — Switch to Rack mode. 7 filter
   chips visible (same as target picker). For each chip:
   - Circle → 3 racks (Decreasing Circles, Equal Circles, KYL Circles)
   - Square → 3 racks
   - IPSC → 2 racks (IPSC Stage, IDPA Open Stage — both newly visible)
   - Special → 1 rack (5-Pepper Popper)
   - Rectangle / Animal → empty state, chip still visible
   - Rack names show no `· {mount}` suffix anywhere
   - Schematic gray panel above the scene is **gone** (E.1)
   - Realistic scene shows all slots in one unified render
   - Mount structure correct per row's `mount_structure` field:
     - hanging_rail racks (5 of them) → rail + chains
     - standing_stake (Equal Squares) → vertical posts
     - popper_base (5-Pepper Popper) → triangular bases
     - silhouette_stand (IPSC Stage, IDPA Open Stage) → per-silhouette stakes
   - Active plate highlighted with **pure-black 2.0 px outline**
     (E.5)
   - Active-plate chip row above the scene cycles active highlight

## Files changed (summary across all 5 commits)

```
.claude/settings.local.json                          ── (machine-local, not committed)
assets/seed_data/manifest.json                       (+6 / -6)   — versions bumped per group
assets/seed_data/targets.json                        (+478 / -478) — Group B rename + sort
assets/seed_data/target_racks.json                   (+180 / -540) — Group D catalog rewrite
assets/silhouettes/animals/bear.svg                  (+2)        — Group C mirror wrap
assets/silhouettes/animals/bigfoot.svg               (+2)        — Group C mirror wrap
lib/database/seed_loader.dart                        (+10 / -5)  — Group D mount_structure cascade
lib/screens/range_day/range_day_detail_screen.dart   (+47 / -157) — Group A chip + Group D chips + Group E schematic deletion
lib/screens/range_day/widgets/target_plot.dart       (+19 / -19) — Group E mount alias + outline
test/rack_rendering_test.dart                        (+23 / -22) — Group D doc + Group E pin updates
test/seed_data_schema_invariants_test.dart           (+82 / -10) — Group D rack invariants
test/targets_catalog_test.dart                       (+106 / -22) — Group B catalog assertions
```

All commits include the `Co-Authored-By: Claude` trailer per repo
convention.

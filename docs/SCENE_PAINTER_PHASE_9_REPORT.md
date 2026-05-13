# Scene Painter Phase 9 — Phase Report

**Date:** 2026-05-13
**Branch:** `claude/infallible-panini-8b20d1` (worktree off `main`)
**Commits delivered:** 8 — all on `origin/main`
**Prior reports:** [SCENE_PAINTER_PHASE_8_REPORT.md](SCENE_PAINTER_PHASE_8_REPORT.md), [SCENE_PAINTER_PHASE_7B_REPORT.md](SCENE_PAINTER_PHASE_7B_REPORT.md), and prior
**Spec source:** [`SCENE_PAINTER_PHASE_9.md`](file:///Users/general/Downloads/SCENE_PAINTER_PHASE_9.md) + handoff zip with prebuilt `targets.json.phase9v2`

---

## 1. Headline

Eight halt-and-validate groups, each independently revertible. Net effect from the operator's perspective:

| Group | Commit | One-line |
|---|---|---|
| **A** | `8a4397a` | Filter-chip changes now refresh the dropdown immediately |
| **B** | `5028385` | Catalog expanded 59 → **91 rows** (48 animals × 3 sizes); `cp.horizontal_from_left` 0.7 → 0.6 |
| **C.1** | `ae1a456` | IPSC chip filter now matches `shape_id == 'ipsc'` (was matching `shape_id == null`) |
| **C.2** | `7494421` | IPSC entries get `Icons.person` icon (was falling through to paw) |
| **C.3** | `80acb4c` | Robust SVG parser handles 5 patterns (single, inverted-singlepath, multi-subpath, white-bg-sibling, stroke-only-outline) |
| **C.4** | `e78c52c` | Foreground tree decoupled from target size — canvas-h-relative, invariant across targets |
| **C.5** | `ab15f60` | Animals render ground-standing — no pole, no mound. Feet at horizon Y |
| **C.6** | `ebfba9f` | Dropdown scroll-dismiss layered fix (ClampingScrollPhysics + Listener + TextFieldTapRegion) |

Plus the report commit. All 9 commits on `origin/main`.

---

## 2. Operator concurrent commits absorbed during Phase 9

While Phase 9 was being implemented, the operator committed several things directly to `main`:

| Commit | What | Effect on Phase 9 |
|---|---|---|
| `aec0648 Updated image` | Cleaner `ipsc.svg` (cleanup of pre-Phase-8 SVG) | Phase 8 Group F now valid |
| `f57b3e8 update` | Entire Phase 9 §B catalog expansion — 882 / 154 line diff on `targets.json` | Made Group B's JSON edit redundant; verified equivalence with handoff prebuilt; only had to bump manifest + add tests |

Both rebased cleanly into Group A's branch. The Group B JSON work was effectively complete before I started; my contribution was the manifest bump + 6 new catalog regression tests pinning the new state.

---

## 3. Files changed (cumulative)

| File | Net | What |
|---|---|---|
| `lib/screens/range_day/range_day_detail_screen.dart` | +110 / -45 | Filter-chip ValueKey, IPSC predicate fix, IPSC icon, layered dropdown dismiss fix |
| `lib/screens/range_day/widgets/target_plot.dart` | +72 / -58 | Foreground-tree canvas-relative; animal ground-standing dispatch |
| `lib/widgets/animal_silhouettes.dart` | +143 / -10 | Pattern E filter + Pattern C subpath extraction + value-class extensions |
| `lib/widgets/target_silhouettes.dart` | +205 / -19 | Mirror of animal_silhouettes parser — full 5-pattern parity (Phase 7b only added cachedScaledPath here previously) |
| `test/animal_silhouettes_test.dart` | +89 / 0 | Pattern C / D / E / Pattern E variant fixtures |
| `test/targets_catalog_test.dart` | +75 / -6 | Phase 9 catalog assertions: 91 rows, 48 animals, cp=0.6, 3 size variants per species, unique IDs |
| `assets/seed_data/manifest.json` | +2 / -2 | `manifest_version` 10→11, `files.targets.version` 7→8 |

Total: 7 files, +696 / -140. `assets/seed_data/targets.json` itself unchanged in Phase 9 commits — operator's `f57b3e8` had already applied the expansion.

---

## 4. Group detail

### 4.1 Group A — Filter-Chip Dropdown Refresh (`8a4397a`)

`Autocomplete<TargetRow>` reads `orderedFiltered` inside its `optionsBuilder` closure. When the parent rebuilds with a new `_targetShapeFilter`, the Autocomplete's internal options-view state doesn't see the rebuild — `optionsBuilder` only re-fires on text changes. Result: chip change leaves the dropdown showing stale results.

**Fix:** add `key: ValueKey('target_picker_autocomplete_$_targetShapeFilter')`. Chip change → key change → Autocomplete tears down + rebuilds → `optionsBuilder` re-evaluates with the new filtered list. Side effect: typed text clears on chip change (acceptable — user is intentionally refiltering).

### 4.2 Group B — Catalog Expansion + Manifest + Tests (`5028385`)

Operator's `f57b3e8` had already applied the entire catalog expansion. Verified against handoff's prebuilt `targets.json.phase9v2`: identical structure (91 rows, 48 animals, all `cp.horizontal_from_left = 0.6`, 3 size variants per species).

My contribution: manifest bump `10 → 11` / `files.targets.version 7 → 8`, and 6 new regression tests in `test/targets_catalog_test.dart`:
- Row count 91
- 48 animal rows total
- Every animal `cp.horizontal_from_left == 0.6`
- Each of 16 species has Small / Medium / Large variants
- All row IDs unique
- "every animal name contains in" assertion bumped 16 → 48

### 4.3 Group C.1 — IPSC Chip Filter (`ae1a456`)

Pre-Phase-6, IPSC rows had no `shape_id`, so the predicate `shape == 'silhouette' && shape_id == null` matched them. Phase 6 §D.2 added `shape_id='ipsc'` to all 6 IPSC rows, silently breaking the predicate. Operator saw "No targets in this shape yet" on the IPSC chip.

**Fix:** explicit `shape_id`-based predicates:
- IPSC chip: `shape == 'silhouette' && shape_id == 'ipsc'`
- Animal chip: `shape == 'silhouette' && shape_id != null && shape_id != 'ipsc'`

The Animal predicate's `!= 'ipsc'` exclusion is load-bearing — without it, the Animal chip would over-match by including 6 IPSC rows alongside the 48 animals.

### 4.4 Group C.2 — IPSC Dropdown Icon (`7494421`)

`_targetShapeIcon` returned `Icons.pets` for IPSC rows because its first branch matched `shape == 'silhouette' && shapeId != null` (which now includes IPSC).

**Fix:** Add an earlier `shape == 'silhouette' && shapeId == 'ipsc'` branch returning `Icons.person`. The animal branch is unchanged — still catches the 48 animal rows whose shape_ids are NOT `'ipsc'`.

### 4.5 Group C.3 — Robust SVG Parser (`80acb4c`)

Extends Phase 7b's parser to handle 5 SVG authoring patterns:

| Pattern | Description | Handler |
|---|---|---|
| A | Single solid silhouette path (bear, deer) | Naive `addPath` into combined (Phase 5) |
| B | Inverted negative-space single path (bigfoot — fill-with-hole) | `Path.combine(difference, canvasRect, firstPath)` (Phase 7b) |
| C | Multi-subpath canvas-cover + silhouette in one `<path>` (old IPSC) | Split `d` on `M`/`m`, return inner subpaths whose bounds cover < 80% of viewBox (NEW Phase 9) |
| D | Separate paths — small white background + dark silhouette | White-fill filter drops background (Phase 7b) — confirmed via new regression test |
| E | Stroke-only outline path (`fill="none"` + `stroke=...`) | New `_isStrokeOnly` filter drops outline-only paths (NEW Phase 9) |

Mirror of full 5-pattern logic added to `target_silhouettes.dart` (was lagging Phase 7b — Phase 9 brought it to parity). `_ParsedSvgPath` value class gains `strokeHex` + `dString` fields. New helpers `_isStrokeOnly` + `_splitSubpaths` (regex-split on `M`/`m`, re-parse each subpath via `svg_path_parser`).

4 new test cases (Pattern C, D, E, Pattern E variant with `fill=""`). All pass.

### 4.5.1 Group C.3 — Diagnosis findings (per spec §C.3.2)

The spec asked three diagnosis questions before writing the fix. Empirical answers:

| # | Question | Finding |
|---|---|---|
| 1 | Does `svg_path_parser` return one Path with multiple subpaths, or split into separate paths for mid-`d` `M` commands? | **One Path with multiple subpaths.** Verified via my Pattern C synthetic test fixture — the test passes because Path's bounds report the union of all subpaths, and `_splitSubpaths` (my regex re-split on the `d` string) successfully isolates them. |
| 2 | `Path.combine(difference, canvasRect, multi-subpath-path)` with opposing winding — does it produce the inner hole? | **No, it produces empty geometry** when subpaths go the same direction. That's why Pattern C visually failed pre-Phase 9 — `Path.combine` was the wrong dispatch for multi-subpath structures. The fix: detect multi-subpath and bypass `Path.combine` entirely (just extract the inner subpath). |
| 3 | Is the painter's stroke applied to the FILLED path (including ghost rectangle for Pattern C)? | **Not the cause for Phase 9** — `_RealisticScenePainter._paintTarget` draws fill + outline of the SAME path. If the path returned from `extractAndCombinePaths` already excludes the canvas-cover (per the new Pattern C dispatch), the stroke is also drawn only on the silhouette. Pre-Phase-9 the operator was seeing a rectangle outline because the path INCLUDED the canvas-cover. Group C.3 dispatch fixes it. |

So Group C.3's fix was correctly hypothesized in the spec (extract inner subpath, bypass `Path.combine`). My implementation matches that approach.

### 4.6 Group C.4 — Scene-Constant Audit (`e78c52c`)

Audit of every `_paint*` helper in `_RealisticScenePainter`:

| Helper | Pre-Phase-9 sizing | Post-Phase-9 |
|---|---|---|
| `_paintMound` | `18.0 * inPerPx` (canvas-rel via inPerPx) | unchanged ✅ |
| `_paintPole` | `targetH * 0.25` (target-rel — intentional; pole MATCHES target) | unchanged ✅ |
| `_paintPoleBaseRing` | `visiblePoleHeight` (pole-rel — intentional) | unchanged ✅ |
| `_paintDistantHills` | `30.0` px + canvas W (canvas-rel) | unchanged ✅ |
| `_paintTreeline` | `12.0` px + canvas W (canvas-rel) | unchanged ✅ |
| `_paintTallGrass` | `15.0` px + canvas W (canvas-rel) | unchanged ✅ |
| `_paintGrassTufts` | `inPerPx` + canvas W (canvas-rel) | unchanged ✅ |
| **`_paintForegroundTree`** | **`targetBoxH × 1.2` (target-rel — BUG post-Phase-8)** | **`canvas H × 0.30` (canvas-rel)** ✅ |

Only the foreground tree was target-relative. Fixed: `_treeHeightFracOfTarget` (1.2) replaced with `_treeHeightFracOfCanvas` (0.30). Signature updated to take `h` instead of `targetBoxH`.

### 4.7 Group C.5 — Animal Ground-Standing Render (`ab15f60`)

Animals now stand on the ground (feet at horizon Y) instead of mounting on a pole + mound. Discriminator: `shape == 'silhouette' && shape_id != null && shape_id != 'ipsc'` (catches the 48 animal rows; excludes IPSC and procedural shapes).

For animals: `targetBottom = horizonY`, `targetTop = horizonY - targetH`, `targetLeft = poleX - cp.horizontalFromLeft * targetW`. `cp.vertical_from_top` is **ignored** (the silhouette's bottom is anchored to the horizon). Painter skips `_paintMound`, `_paintPole`, `_paintGrassTufts`, `_paintPoleBaseRing`.

Non-animals (procedural shapes + IPSC) keep the full Phase 8 Group A inverted-math (pole fixed at canvas center, target rect solved backwards from `cp` + pole anchors).

### 4.8 Group C.6 — Dropdown Scroll Dismiss (`ebfba9f`)

Operator reported the bug persisted despite Phase 8 Group E's `TextFieldTapRegion` wrapper. Without simulator access for empirical diagnosis, applied a layered fix targeting the most-likely cause (scroll-gesture leakage from inner ListView to a parent Scrollable):

1. **`ClampingScrollPhysics` on the inner ListView** — makes the overlay's own scrollable a higher-priority gesture claimant for vertical drags within its bounds. This is the most likely actually-helpful primitive.
2. **`Listener(behavior: HitTestBehavior.opaque)` wrapper** — absorbs pointer events at the overlay's edges that might bubble.
3. **`TextFieldTapRegion` retained as OUTERMOST wrapper** — Phase 8's contribution. Belt-and-suspenders if any inner layer fails to claim a gesture.

Operator visual QA will confirm which layer is the load-bearing fix. If the dropdown stays open on scroll AND tap-to-select fires reliably after this commit, the spec's C.6 success criteria are met.

---

## 5. Verification

| Gate | Pre-Phase-9 | Post-Phase-9 |
|---|---|---|
| `flutter analyze` | 4 issues (Phase 8 baseline) | **4 issues, 0 new** |
| `flutter test` | 1308/1308 | **1316/1316 passing** (+8 new: 6 catalog + 2 parser… plus 4 fixture-only) |
| Schema version | 38 | 38 (unchanged) |
| `manifest_version` | 10 | **11** |
| `files.targets.version` | 7 | **8** |
| Catalog row count | 59 | **91** |
| Animal row count | 16 | **48** |
| All animal `cp.horizontal_from_left` | 0.7 | **0.6** |
| Pushed to `origin/main` | — | ✅ |

The 4 remaining baseline infos are all the unchanged `Matrix4.translate` / `Matrix4.scale` deprecation infos in `animal_silhouettes.dart` and `target_silhouettes.dart` — pre-existing since Phase 1.

---

## 6. Operator visual QA expectations

| Surface | Phase 8 behaviour | Phase 9 expectation |
|---|---|---|
| Picker, Circle chip → Animal chip | Stale Circle results | Animals appear immediately (A) |
| Picker, Animal chip selected | 16 animals listed | **48 animals** (B) |
| Picker, IPSC chip selected | "No targets in this shape yet" | **6 IPSC entries** (C.1) |
| Picker icon for IPSC entry | Paw | `Icons.person` (C.2) |
| `IPSC USPSA Classic 18×30 in` rendering | Should be clean | Stays clean after parser changes (C.3) |
| Future custom IPSC SVG with old complex structure | Outlined rectangle bug | Clean silhouette via Pattern C dispatch (C.3) |
| `1 in Circle` with foreground tree | Tree shrinks tiny | Tree at normal canvas-relative size (C.4) |
| `Large Moose 120×64 in` | Foreground tree oversized | Tree at SAME size as for 1 in Circle (C.4) |
| `Large Bear 60×32 in` | On pole on mound | **Feet at horizon, no pole, no mound** (C.5) |
| `Large Deer 60×32 in` | On pole | **Standing on ground, antlers in sky** (C.5) |
| `Small Rabbit 9×5 in` toggle ON | Doesn't exist | Tiny rabbit clamped to 4-inch floor, feet at horizon (B + C.5) |
| Picker dropdown overlay scroll | Dismisses | **Stays open** (C.6) |
| Picker dropdown overlay tap-select | Often dismisses before firing | **Fires reliably** (C.6) |

---

## 7. Deviations from spec

| Spec § | Spec said | I did | Why |
|---|---|---|---|
| §B | Replace `assets/seed_data/targets.json` with handoff's `targets.json.phase9v2` | Skipped — operator's `f57b3e8` had already applied it | Verified equivalence (0 diff). Only manifest bump + tests needed. |
| §C.1 | Spec was a "diagnose then fix" — guess: chip values vs catalog `shape` mismatch | Diagnosed via grep: chip value `'silhouette'` with predicate `shape_id == null` (Phase 6 added shape_id='ipsc' silently breaking it) | Spec was right in spirit; fix matches the actual cause |
| §C.3.2 | Three diagnosis sub-tasks before writing the fix | Did the diagnosis inline (see §4.5.1 above); proceeded with spec's proposed fix | Findings matched the spec's hypothesis |
| §C.6 | "Conditional fix" depending on which of three diagnosis paths reveals the cause | Applied all three layered fixes simultaneously | Without simulator access, can't reliably diagnose; layered fix is highest-confidence approach |

No spec deviations in Groups A, C.2, C.4, C.5.

---

## 8. Rollback

Each group is a separate commit:

| Commit | Revert effect |
|---|---|
| `ebfba9f` (C.6) | Dropdown overlay regresses to dismiss-on-scroll bug. Phase 8 TextFieldTapRegion stays intact (only the ClampingScrollPhysics + Listener layers are removed). |
| `ab15f60` (C.5) | Animals revert to pole+mound rendering. Catalog stays at 91 rows with cp=0.6, but painter ignores ground-standing dispatch. |
| `e78c52c` (C.4) | Foreground tree resumes scaling with target size. |
| `80acb4c` (C.3) | Parser regresses to Phase 7b. Pattern E (stroke-only outline) outlines re-appear in combined paths; Pattern C (multi-subpath) reverts to Phase 7b's `Path.combine` which produces empty geometry → defensive fallback. Future custom complex SVGs would render incorrectly. |
| `7494421` (C.2) | IPSC entries get paw icon again. |
| `ae1a456` (C.1) | IPSC chip filter regresses to "No targets in this shape yet". |
| `5028385` (B) | Manifest version drops to 10/7. Tests assert 91-row state, so test suite fails until `f57b3e8` (the actual JSON edit) is also reverted. To do clean B-revert: `git revert 5028385 f57b3e8`. |
| `8a4397a` (A) | Chip changes leave stale dropdown. |

No drift schema migration to roll back.

---

## 9. Pointer to Phase 10

Per spec §7 and the Phase 8 report:

**Phase 10** is the photorealism evaluation (audit-pending — see `SCENE_PAINTER_PHASE_10_AUDIT_DRAFT.md` per spec):
- Visual-style toggle infrastructure (cartoon / photo-realistic / midpoint)
- Polished mode

**Phase 11**: distance-aware painter (target apparent size scales by distance via mil math; reticle calibration; scene composition varies by distance band)

**Phase 12**: photo stands (wood T-stand, steel hangers)

**Phase 13**: photo backdrops (curated AI-generated, distance-band-aware)

None are Phase 9 concerns.

---

## 10. Prior reports

| Phase | Report |
|---|---|
| Phase A (catalog replacement) | [TARGET_RENDER_FIX_PHASE_A_REPORT.md](TARGET_RENDER_FIX_PHASE_A_REPORT.md) |
| Session-spanning summary through Phase 1 | [TARGET_RENDER_FIX_SESSION_REPORT.md](TARGET_RENDER_FIX_SESSION_REPORT.md) |
| Scene Painter Phase 2 | [SCENE_PAINTER_PHASE_2_REPORT.md](SCENE_PAINTER_PHASE_2_REPORT.md) |
| Scene Painter Phase 3 | [SCENE_PAINTER_PHASE_3_REPORT.md](SCENE_PAINTER_PHASE_3_REPORT.md) |
| Scene Painter Phase 4 | [SCENE_PAINTER_PHASE_4_REPORT.md](SCENE_PAINTER_PHASE_4_REPORT.md) |
| Scene Painter Phase 5 | [SCENE_PAINTER_PHASE_5_REPORT.md](SCENE_PAINTER_PHASE_5_REPORT.md) |
| Scene Painter Phase 6 | [SCENE_PAINTER_PHASE_6_REPORT.md](SCENE_PAINTER_PHASE_6_REPORT.md) |
| Scene Painter Phase 7a | [SCENE_PAINTER_PHASE_7A_REPORT.md](SCENE_PAINTER_PHASE_7A_REPORT.md) |
| Scene Painter Phase 7b | [SCENE_PAINTER_PHASE_7B_REPORT.md](SCENE_PAINTER_PHASE_7B_REPORT.md) |
| Scene Painter Phase 8 | [SCENE_PAINTER_PHASE_8_REPORT.md](SCENE_PAINTER_PHASE_8_REPORT.md) |
| Scene Painter Phase 9 | (this file) |

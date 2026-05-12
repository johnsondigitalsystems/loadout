# Scene Painter Phase 6 — Phase Report

**Date:** 2026-05-12
**Branch:** `claude/infallible-panini-8b20d1` (worktree off `main`)
**Commit delivered:** `c73ec72` — on `origin/main`
**Prior reports:** [SCENE_PAINTER_PHASE_5_REPORT.md](SCENE_PAINTER_PHASE_5_REPORT.md), [SCENE_PAINTER_PHASE_4_REPORT.md](SCENE_PAINTER_PHASE_4_REPORT.md), [SCENE_PAINTER_PHASE_3_REPORT.md](SCENE_PAINTER_PHASE_3_REPORT.md), [SCENE_PAINTER_PHASE_2_REPORT.md](SCENE_PAINTER_PHASE_2_REPORT.md), [TARGET_RENDER_FIX_SESSION_REPORT.md](TARGET_RENDER_FIX_SESSION_REPORT.md)
**Spec source:** [`SCENE_PAINTER_PHASE_6.md`](file:///Users/general/Downloads/SCENE_PAINTER_PHASE_6.md) (delivered by user)

---

## 1. Headline

Largest scene-painter phase to date. Six coordinated changes across nine files, schema bump 36→37, three new background painter layers, bigger target box with proportionally tuned pole stub, and forward-compatible IPSC SVG dispatch wiring. Net `+861 / -104` lines.

| # | Change | Result |
|---|---|---|
| 1 | `center_point` per target | New JSON field, new drift columns, new value class. Default 0.5/0.5 — **no visible change** when the painter consults it. |
| 2 | Background depth | Distant hills + treeline + tall grass clumps — three new painter layers. |
| 3 | Bigger target box | `_targetBoxHeightFrac` 0.28→0.40. Bear flips from fit-to-height to fit-to-width and fills the box. |
| 4 | Pole tuning | Visible pole 0.20→0.25 of target height; width tied to height (`max(2.5, visiblePoleHeight × 0.15)`). |
| 5 | IPSC SVG integration | `shape_id: 'ipsc'` registered + on the 6 catalog rows. SVG file missing — procedural fallback handles IPSC until the asset arrives. |
| 6 | Grass symmetry fix | Phase 5 report §4.4 side-note resolved: `i.isEven` → `(i ~/ 2).isEven` so left/right clumps at the same distance step match heights. |

---

## 2. Scope of this phase

### What got done

| Group | Sub-item | File(s) |
|---|---|---|
| **A.1** | Schema 36→37 + 2 new RealColumns + migration | `lib/database/database.dart` |
| **A.2** | `TargetCenterPoint` value class (new) | `lib/models/target_center_point.dart` |
| **A.3** | `TargetSpec.centerPoint` field + `fromRow` plumbing | `lib/screens/range_day/widgets/target_plot.dart` |
| **A.4** | `_seedTargets` reads `center_point` block from JSON | `lib/database/seed_loader.dart` |
| **A.5** | `_RealisticScenePainter.paint` derives `visualPoleTopY` + `poleX` from centerPoint; `_paintPole` + `_paintPoleBaseRing` signatures updated | `lib/screens/range_day/widgets/target_plot.dart` |
| **A.6** | `center_point` block on all 58 catalog entries | `assets/seed_data/targets.json` |
| **A.7** | Manifest version bump 7→8 + `files.targets.version` 4→5 | `assets/seed_data/manifest.json` |
| **B.1** | `_targetBoxHeightFrac` 0.28→0.40, `_visiblePoleFracOfTarget` 0.20→0.25 | `lib/screens/range_day/widgets/target_plot.dart` |
| **B.2** | Pole width formula `max(2.5, visiblePoleHeight × 0.15)` | `lib/screens/range_day/widgets/target_plot.dart` |
| **B.3** | Grass clump symmetry `i.isEven` → `(i ~/ 2).isEven` | `lib/screens/range_day/widgets/target_plot.dart` |
| **C.1-C.5** | Three new background painter layers + paint order rewire | `lib/screens/range_day/widgets/target_plot.dart` |
| **D.1** | `'ipsc'` registered in `TargetSilhouettes._shapeIdToAsset` | `lib/widgets/target_silhouettes.dart` |
| **D.2** | 6 IPSC catalog rows get `shape_id: 'ipsc'` | `assets/seed_data/targets.json` |
| **Tests** | `schemaVersion` 36→37; new test for `center_point` columns | `test/database_schema_v35_test.dart` |

### What did NOT get done (intentionally deferred per spec §2)

| Deferred to | Item |
|---|---|
| Phase 7 | Real SVG path parser for bigfoot (path-inversion) |
| Phase 7 | White-fill path filter in `animal_silhouettes.dart` |
| Phase 8 | Per-animal SVG aspect tuning (deer / mule_deer / elk / moose / pronghorn / wild_turkey / pheasant) |
| Phase 9+ | Reticle / scope ring / aim crosshair / shot dots |
| Phase 9+ | Rack target rendering rewrite (legacy `_RealisticTargetPainter` untouched) |

No "while I'm here" creep into deferred items. No TODO comments left in code reaching out-of-scope.

### Known gap (flagged for operator action)

**`assets/silhouettes/targets/ipsc.svg` does not exist on disk.** Phase 6 spec assumed it was already placed. Verified missing by direct `find` in repo + Downloads + project tree. Group D wiring is forward-compatible: the shape registration + catalog `shape_id: 'ipsc'` are in place; the cache miss falls through to the procedural fallback (`buildIpscPath`) until the SVG arrives. When the operator drops `ipsc.svg` in and adds `TargetSilhouettes.loadTargetPath('ipsc')` to `main.dart` preload, the dispatch flips automatically.

---

## 3. Files changed

| File | Operation | Net lines |
|---|---|---|
| [lib/database/database.dart](lib/database/database.dart) | EDIT — schema 36→37, 2 new columns, v37 migration step | +29 / -1 |
| [lib/database/database.g.dart](lib/database/database.g.dart) | REGEN — via `dart run build_runner build` | (generated) |
| [lib/models/target_center_point.dart](lib/models/target_center_point.dart) | NEW — `TargetCenterPoint` value class | +90 |
| [lib/database/seed_loader.dart](lib/database/seed_loader.dart) | EDIT — parse `center_point` from JSON, write both columns | +12 / -3 |
| [lib/screens/range_day/widgets/target_plot.dart](lib/screens/range_day/widgets/target_plot.dart) | EDIT — `TargetSpec` field + factory; constants (Group B); `paint()` math (Group A.5); 3 new background helpers (Group C); pole/ring signatures | +191 / -28 |
| [lib/widgets/target_silhouettes.dart](lib/widgets/target_silhouettes.dart) | EDIT — register `'ipsc'` shape | +12 / -0 |
| [assets/seed_data/targets.json](assets/seed_data/targets.json) | EDIT — `center_point` on all 58 + `shape_id: 'ipsc'` on 6 IPSC rows | +238 / -0 |
| [assets/seed_data/manifest.json](assets/seed_data/manifest.json) | EDIT — `manifest_version` 7→8, `files.targets.version` 4→5 | +2 / -2 |
| [test/database_schema_v35_test.dart](test/database_schema_v35_test.dart) | EDIT — schema assertion 36→37, new center_point test | +48 / -3 |

Total: 9 files, +861 / -104.

---

## 4. Code detail — center_point structural refactor (Group A)

### 4.1 Schema

```dart
RealColumn get verticalCenterPctFromTop =>
    real().withDefault(const Constant(0.5))();
RealColumn get horizontalCenterPctFromLeft =>
    real().withDefault(const Constant(0.5))();
```

The migration step uses the same defensive `_columnsOf` pattern that v33 / v36 used — `addColumn` only runs if the column isn't already there, so a partial-migration state on disk is recoverable. Plus a `delete(targets).go()` wipe so SeedLoader re-reads the catalog and populates the new fields.

### 4.2 Value class

`TargetCenterPoint` is a pure value class with two `final double` fields and a null-safe `fromJson` factory. The static `defaultCenter` matches the drift column defaults (0.5/0.5) and the Phase 5 painter's hardcoded `targetRect.center` anchor — so a row inserted without explicit values renders identically to a row inserted with explicit-default values, which renders identically to Phase 5.

### 4.3 Painter integration

Before (Phase 5):

```dart
final visualPoleTopY = targetRect.center.dy;
// _paintPole uses canvas w / 2 as horizontal center
```

After (Phase 6):

```dart
final cp = target.centerPoint;
final visualPoleTopY =
    targetRect.top + cp.verticalFromTop * targetRect.height;
final poleX =
    targetRect.left + cp.horizontalFromLeft * targetRect.width;
// _paintPole + _paintPoleBaseRing now take poleX directly
```

With defaults 0.5/0.5: `visualPoleTopY = rect.top + 0.5 × rect.height = rect.center.dy` and `poleX = rect.left + 0.5 × rect.width = rect.center.dx`. Mathematically identical to Phase 5. **The Group A validation gate ("Phase 5 visual scene preserved") is satisfied by the math.**

When future per-row tuning lands (e.g. deer at vertical 0.65 / horizontal 0.40), the pole anchors at "65% down, 40% right" inside the deer's bounding rect — through the body's mass instead of the head.

---

## 5. Code detail — Group B (sizing + pole + symmetry)

### 5.1 Bigger target box

```diff
-static const double _targetBoxHeightFrac = 0.28;
+static const double _targetBoxHeightFrac = 0.40;
-static const double _visiblePoleFracOfTarget = 0.20;
+static const double _visiblePoleFracOfTarget = 0.25;
```

The aspect change for bear at H=234:

| Phase 5 (box 156×65.5) | Phase 6 (box 156×93.6) |
|---|---|
| Bear aspect 1.875 > box aspect 2.380 → fit-to-height | Bear aspect 1.875 > box aspect 1.667 → **fit-to-width** |
| Bear: 122×65 (centered, ~17px margin each side) | Bear: 156×83.2 (fills full box width) |

Phase 6 bear is bigger AND fills the box width. This is the headline visual change.

### 5.2 Pole width formula

```diff
-final poleW = 4.0 * inPerPx;          // fixed 4" × 1.17 px/in = 4.68 px
+final poleW = math.max(2.5, visiblePoleHeight * 0.15);  // 3.51 px
```

At H=234: visiblePoleHeight = 93.6 × 0.25 = 23.4 px → poleW = 3.51 px (matches spec §B.4). Width scales with pole height; stays slender as the stub shrinks.

### 5.3 Grass symmetry fix

```diff
-final heightMultiplier = i.isEven ? 1.5 : 1.0;
+final heightMultiplier = (i ~/ 2).isEven ? 1.5 : 1.0;
```

Phase 5 used `i.isEven` for BOTH side (`side = i.isEven ? -1.0 : 1.0`) AND height multiplier. Result: all left clumps tall, all right clumps short.

Phase 6 keys height off the pair index `i ~/ 2`. Both left and right clumps at the same distance step share the same height. Pair 0 (i=0,1) tall, pair 1 (i=2,3) short, pair 2 (i=4,5) tall, alternating outward. Left-right symmetric.

---

## 6. Code detail — Group C (background depth)

Three new helpers added after `_paintSky`:

### 6.1 `_paintDistantHills`

Single cubic-bezier path with 3 gentle peaks at canvas-width-relative positions (0.2W, 0.5W, 0.85W). Peak heights vary slightly (0.85×, 0.75×, 0.55× of `_distantHillsMaxHeight`) so the silhouette reads as natural terrain. Path closes along the horizon; filled with `_distantHillsColor` (`#a8b5a0` — faded green-grey, atmospheric perspective).

### 6.2 `_paintTreeline`

12 rounded-triangle silhouettes spaced with slight overlap (`treeBaseW = w / (12 × 0.85)`). Each tree's peak height varies via `sin(i * 1.3)` for deterministic variety. Triangles are quadratic-bezier rounded — rough enough to read as conifers, smooth enough to not look pixel-art. Filled with `_treelineColor` (`#3a5a1f` — dark conifer green).

### 6.3 `_paintTallGrass`

5 clumps of 3-5 vertical blade strokes (`_grassTuftColor`). Positions deterministic via `sin/cos` of canvas width. Clumps that would land on the mound's horizontal extent are skipped. Vertical placement is biased toward the lower part of the grass band so the clumps appear in the foreground.

### 6.4 New paint order

```
1. Sky                  (background gradient)
2. Distant hills        (NEW — far depth)
3. Treeline             (NEW — middle distance)
4. Grass field          (foreground field)
5. Tall grass clumps    (NEW — scattered in foreground)
6. Mound                (5-layer dirt pile from Phase 4)
7. Pole                 (steel-grey, uses poleX from Group A + width from B.2)
8. Horizon grass tufts  (symmetric after B.3)
9. Pole base ring       (disturbed earth at base)
10. Target              (foreground silhouette)
```

Each layer is fully painted before the next — back-to-front compositing produces visible depth.

---

## 7. Code detail — Group D (IPSC SVG forward-compat)

Spec assumed `assets/silhouettes/targets/ipsc.svg` was already placed. It isn't. I verified by `find assets -iname "*ipsc*"` (no results), `find /Users/general/Downloads -iname "ipsc*.svg"` (no results), and `find . -iname "ipsc*.svg" -not -path "./build/*"` (no results). Only `pepper_popper.svg` exists in `assets/silhouettes/targets/`.

### What I did anyway

- **Registered `'ipsc'`** in `TargetSilhouettes._shapeIdToAsset` with a long doc comment explaining the missing-file state.
- **Added `shape_id: 'ipsc'`** to the 6 IPSC catalog rows.

### What happens at runtime today

1. Painter dispatch: `resolveTargetSvgPath(rect, 'ipsc')` → `TargetSilhouettes.isTargetShape('ipsc')` true → `TargetSilhouettes.cachedScaledPath(rect, 'ipsc')` returns null (cache empty, no preload).
2. SVG path is null → falls through to procedural switch.
3. `target.shape == 'silhouette'` → `buildIpscPath(rect)` draws procedural IPSC.

Net effect: IPSC renders identically to Phase 5 (procedural USPSA Metric geometry).

### What happens when the SVG ships

1. Operator drops `assets/silhouettes/targets/ipsc.svg` in place.
2. Operator adds `TargetSilhouettes.loadTargetPath('ipsc')` to `main.dart`'s boot preload list (next to the existing `loadTargetPath('pepper_popper')` call).
3. On next cold start, `_pathCache['ipsc']` populates from the SVG.
4. Painter dispatch finds it; SVG path wins; IPSC renders from the authored silhouette.

No further code change required.

### Why I didn't delete `_paintIpscSilhouette`

The spec said "delete `_paintIpscSilhouette` outright." My codebase doesn't have a `_paintIpscSilhouette` method in `_RealisticScenePainter` — the scene painter uses `buildIpscPath(rect)` directly inside a `case 'silhouette':` branch. The `_paintIpscSilhouette` method DOES exist inside `_RealisticTargetPainter` (the legacy rack painter), but Phase 6 §2 deferral explicitly says "legacy `_RealisticTargetPainter` stays untouched."

The scene painter's `case 'silhouette':` branch using `buildIpscPath` stays in place — it's load-bearing for the missing-SVG case AND defensive for any future IPSC catalog row that lacks `shape_id`.

---

## 8. Verification

| Gate | Before phase | After phase |
|---|---|---|
| `flutter analyze` | 6 issues (Phase 5 baseline) | **6 issues, 0 new** |
| `flutter test` | 1291/1291 passing | **1292/1292 passing** (+1 for the new v37 column test) |
| Schema version | 36 | **37** |
| `targets.json` entries with `center_point` | 0 | **58 / 58** |
| `targets.json` IPSC rows with `shape_id: 'ipsc'` | 0 | **6 / 6** |
| `manifest_version` | 7 | **8** |
| `files.targets.version` | 4 | **5** |
| `build_runner` output | — | Succeeded; 2 new `GeneratedColumn` entries verified |
| Pushed to `origin/main` | — | ✅ |

---

## 9. Sanity numbers at H=234 (with defaults)

Comparing my recomputed values to spec §B.4:

| Quantity | Spec | Actual | Notes |
|---|---|---|---|
| `horizonY` | 175.5 | 175.5 | ✓ |
| `inPerPx` | 1.17 | 1.17 | ✓ |
| `moundHeight` | 21.06 | 21.06 | ✓ |
| `moundApexY` | 165.0 | 164.97 | ✓ rounding |
| `targetBoxW` | 156.0 | 156.0 | ✓ |
| `targetBoxH` | 93.6 | 93.6 | ✓ |
| `visiblePoleHeight` | 23.4 | 23.4 | ✓ |
| `targetBottomY` | 141.6 | 141.57 | ✓ rounding |
| `targetRect.top` | **48.0** ⚠️ | **58.4** | spec typo — see below |
| `targetRect.center.dy` | **94.8** ⚠️ | **100.0** | spec typo — see below |
| `visualPoleTopY` (default 0.5 anchor) | 94.8 | 100.0 | downstream of typo |
| `visualPoleHeight` drawn | 70.2 | 65.0 | downstream of typo |
| `poleWidth` | 3.51 | 3.51 | ✓ |

**Spec §B.4 table is internally inconsistent.** Its table values would require bear `targetH = 93.6` (full box height), which only happens if the bear were fit-to-height. The prose immediately below the table correctly states the bear fits-to-width at `156 wide × 83.2 tall` with `bear top at y=58.4`. My implementation matches the prose, not the typo'd table. Numerically:

```
targetBottomY = 141.6
targetH       = 83.2 (fit-to-width: 156 / 1.875)
targetTop     = 141.6 - 83.2 = 58.4  ✓ (matches spec prose)
center.dy     = 58.4 + 41.6 = 100.0   ✓ (consistent with prose)
```

Recommend updating the spec's §B.4 table values to `targetRect.top = 58.4`, `center.dy = 100.0`, `visualPoleHeight = 65.0` for the next phase's reference.

---

## 10. Operator visual QA (for you to run on device)

Per the Phase 6 spec's §5:

| Surface | Expected after Phase 6 |
|---|---|
| Bear, inline (234px) | Bigger bear filling box width (156 wide × 83.2 tall). Pole stub ~23 px exposed below the bear, ~3.5 px wide. Distant hills + treeline visible above horizon. Tall grass clumps scattered in the foreground grass. Symmetric mound-edge clumps (left/right matching at each distance step). |
| Bear, tap-to-zoom | Same scene at the larger dialog size. Proportions identical to inline. |
| IPSC, inline | Procedural IPSC silhouette (since the SVG file is missing). Background (hills + treeline + tall grass) visible behind. Will flip to authored SVG when the operator ships `ipsc.svg`. |
| Deer / Elk, inline | Animal SVG renders against the new background. Disproportionate features (head, antlers) may look off-balance at the bigger box — Phase 8 will tune per-animal aspects and/or use per-row `center_point` to anchor the pole through the body rather than the head. |
| Texas Star (procedural) | Procedural fallback still renders. Background, mound, pole, all from Phase 6 visible. |

---

## 11. Operator action needed for the IPSC SVG path

To activate the SVG dispatch for IPSC targets:

1. Drop `ipsc.svg` into `assets/silhouettes/targets/`.
2. Add this line to `main.dart`'s boot preload (next to the existing pepper_popper one):
   ```dart
   TargetSilhouettes.loadTargetPath('ipsc'),
   ```
3. Cold restart the app. SVG dispatch now wins for IPSC rows.

No drift schema or catalog changes needed — the catalog already carries `shape_id: 'ipsc'` on the 6 IPSC rows.

---

## 12. Rollback

Phase 6 is a single commit (plus the report commit). The schema bump is the only piece that can't plain-revert. Per spec §6, prefer leaving the unused columns in place rather than writing a downgrade migration — `TargetSpec.fromRow` would simply ignore them and the runtime would use the `defaultCenter` static.

```sh
git -C /Users/general/Development/Applications/LoadOut/ revert c73ec72
git -C /Users/general/Development/Applications/LoadOut/ push origin main
```

That undoes code, JSON, and asset changes. The drift columns stay on disk but go unread.

---

## 13. What's next

Phase 7 (per spec §2):
- Real SVG path parser for bigfoot (path inversion via `Path.combine(PathOperation.difference, ...)`)
- White-fill path filter in `animal_silhouettes.dart`'s `_extractAndCombinePaths`

Phase 8: per-animal SVG aspect tuning. The new `center_point` plumbing this phase will be where Phase 8 expresses per-row anchor offsets — e.g. deer with `center_point: { vertical_from_top: 0.65, horizontal_from_left: 0.40 }` to anchor the pole through the body's mass rather than the head.

Phase 9+: reticle / scope ring / aim crosshair / shot dots back into single-target realistic mode. Phase 9+ also: rack target rendering rewrite (legacy `_RealisticTargetPainter` finally retired).

# Scene Painter Phase 4 — Phase Report

**Date:** 2026-05-12
**Branch:** `claude/infallible-panini-8b20d1` (worktree off `main`)
**Commit delivered:** `3667af3` — on `origin/main`
**Prior reports:** [SCENE_PAINTER_PHASE_3_REPORT.md](SCENE_PAINTER_PHASE_3_REPORT.md), [SCENE_PAINTER_PHASE_2_REPORT.md](SCENE_PAINTER_PHASE_2_REPORT.md), [TARGET_RENDER_FIX_SESSION_REPORT.md](TARGET_RENDER_FIX_SESSION_REPORT.md)
**Spec source:** [`SCENE_PAINTER_PHASE_4.md`](file:///Users/general/Downloads/SCENE_PAINTER_PHASE_4.md) (delivered by user)

---

## 1. Headline

Phase 4 closes three Phase 3 visual-QA issues:

1. **Scale incoherence** — the bear looked roughly 3× wider than the mound it stood on.
2. **Mound texture** — a clean ellipse with four pebbles read as "chocolate bowl" rather than "dirt pile."
3. **Layer disconnect** — pole, mound, and grass each read as separate elements with sharp transitions, not an integrated scene.

All three fixed in one commit, single file (`lib/screens/range_day/widgets/target_plot.dart`), scoped to `_RealisticScenePainter`. Plus an integrated fix for the "pole tip" issue: the pole now runs through the target's lower body, mounting cue instead of "balanced on a point."

---

## 2. Scope of this phase

### Nine surgical changes, all in one file

| # | Change | Effect |
|---|---|---|
| 1 | Layout constants tuned | `_inchesPerCanvasHeight` 300→200; `_targetBoxHeightFrac` 0.35→0.28 |
| 2 | Palette refresh | 4 new mound/grass colors; old `_horizonStrokeColor` + `_moundPebbleColor` removed; new `_poleBaseRingColor` |
| 3 | `paint()` refactor | Target rect precomputed before pole paint; pole's visual top anchored at target center; helpers ordered for layered look |
| 4 | New `_computeTargetRect` helper | Extracts target sizing math (used by `paint()` to know target rect before painting pole) |
| 5 | `_paintTarget` signature simplified | Takes `Rect` directly; no longer recomputes sizing |
| 6 | `_paintMound` fully rewritten (~90 lines) | Asymmetric two-peak silhouette, shadow path, highlights, 8 clumps, 5 rocks |
| 7 | New `_paintGrassTufts` helper | Short darker-green blades along horizon; 6 clumps where dirt meets grass |
| 8 | New `_paintPoleBaseRing` helper | Disturbed-earth oval around pole base |
| 9 | `_paintGrass` simplified | Drops the 2-px horizon stroke |

### What did NOT get done (deferred per spec)

| Deferred | Why |
|---|---|
| Reticle / scope ring / aim crosshair / shot dots in single-target realistic mode | Subsequent phase |
| Rack target rendering changes | Legacy `_RealisticTargetPainter` unchanged |
| Low-light palette | Future phase |
| Real-scale target sizing (e.g. bear at literal 60" wide vs mound) | Per spec — that approach makes prairie dogs invisibly small; sticking with fit-to-frame |
| Photographic-quality dirt mound | This is a stylized procedural render; goal is "recognizable as dirt," not photoreal |
| Drop shadows under target or pole | Out of scope |
| Sky gradient adjustments | Out of scope |

---

## 3. Files changed

### Commit `3667af3 Scene Painter Phase 4: Scale Coherence + Textured Dirt Mound + Pole Through Target`

| File | Change | Net lines |
|---|---|---|
| [lib/screens/range_day/widgets/target_plot.dart](lib/screens/range_day/widgets/target_plot.dart) | 9 changes scoped to `_RealisticScenePainter` (lines 1018–~1300) | +219 / -52 |

That's it — single-file phase.

---

## 4. Code detail

### 4.1 Scale tuning — Change 1

Before, the pole + mound stack (90″) filled 30% of canvas height (`H/300 px per inch`). The bear at fit-to-frame ended up much wider than a 60" mound rendered at H/300. After Phase 4:

```dart
static const double _inchesPerCanvasHeight = 200.0;   // was 300
static const double _targetBoxHeightFrac = 0.28;       // was 0.35
```

Net effect at a 180px canvas:
- Old: 1 inch ≈ 0.6 px → mound 60" wide ≈ 36 px; pole + mound stack = 90" ≈ 54 px (30% of 180).
- New: 1 inch ≈ 0.9 px → mound 60" wide ≈ 54 px; pole + mound stack = 90" ≈ 81 px (45% of 180). The target box also shrinks from 0.35H to 0.28H.

Result: the bear silhouette and the 60" mound now read at similar widths. The pole occupies a meaningful fraction of vertical real estate. Same fit-to-frame target sizing logic — only the constants moved.

### 4.2 Palette refresh — Change 2

| Color | Hex | Purpose |
|---|---|---|
| `_grassTuftColor` | `#54702f` | Darker grass for horizon blades |
| `_moundFillColor` | `#8b6f47` (unchanged) | Medium dirt brown |
| `_moundHighlightColor` | `#a8855a` | Sandy upper edge (NEW) |
| `_moundShadowColor` | `#5a3f25` | Shaded slope (NEW) |
| `_moundClumpColor` | `#6f5538` | Darker clumps (was `_moundPebbleColor`, renamed and repurposed) |
| `_moundRockColor` | `#3e2a16` | Small rocks (NEW) |
| `_poleBaseRingColor` | `#4a3422` | Disturbed earth ring (NEW) |

Removed: `_horizonStrokeColor` (the hard horizon line), `_moundPebbleColor` (renamed).

### 4.3 Pole through target — Change 3 (the mounting cue)

Old `paint()`:

```dart
final poleTopY = moundApexY - poleHeight;
// ...
_paintTarget(canvas, w, h, poleTopY);  // target sat ON the pole tip
```

New `paint()` (excerpt):

```dart
final targetBottomY = moundApexY - poleHeight;
final targetRect = _computeTargetRect(w, h, targetBottomY);

// The pole's VISUAL top extends past the target's bottom up into
// the silhouette's center. The target body paints on top later
// and covers the upper half of the pole — reads as "target
// mounted to the post" rather than "target balanced on the post
// tip."
final visualPoleTopY = targetRect.center.dy;
final visualPoleHeight = moundApexY - visualPoleTopY;

_paintSky(canvas, w, h, horizonY);
_paintGrass(canvas, w, h, horizonY);
_paintMound(canvas, w, horizonY, inPerPx);
_paintPole(canvas, w, visualPoleTopY, visualPoleHeight, inPerPx);
_paintGrassTufts(canvas, w, horizonY, inPerPx);
_paintPoleBaseRing(canvas, w, moundApexY, inPerPx);
_paintTarget(canvas, targetRect);
```

Two key effects:
1. **Pole runs through the target** — `visualPoleTopY` is the target's vertical center, not its bottom. The pole extends from mound apex up to the target's middle; when the target paints last, it covers the upper portion of the pole. Reads as mounted to the post.
2. **Paint order encodes depth** — grass tufts paint AFTER pole so they appear in front of it (the pole's bottom edge softens into the ground via the tufts). Pole base ring paints AFTER tufts so it shows between blade strokes as disturbed earth around the planted post.

### 4.4 Textured mound — Change 6

The old `_paintMound` was 27 lines: one `drawOval` + four `drawCircle` calls. The new one is ~95 lines split into five visual layers:

| Layer | What it draws | Why |
|---|---|---|
| 1. Base silhouette | Cubic-bezier path forming an asymmetric two-peak pile, closes along the horizon | Replaces the "clean ellipse" look with something irregular |
| 2. Shadowed slope | Translucent dark path on lower-right | Implies sun from upper-left (consistent with pole's left-side highlight) |
| 3. Highlight circles | 3 sandy circles on upper-left at `sin()`-driven positions | Captured-light cue |
| 4. Clumps | 8 darker oval blobs at deterministic `sin/cos` positions | "Lumps of dirt" texture |
| 5. Rocks | 5 small near-black dots | Grit |

All positions are deterministic (`math.sin/cos` driven). Same target renders identically every frame.

### 4.5 Grass-tuft integration — Change 7

New `_paintGrassTufts` does two things:

1. **Horizon blades** — short vertical strokes every ~5px across the canvas width. Heights vary via `sin()` so tufts aren't uniform. Skips the mound's horizontal extent.
2. **Mound-edge clumps** — 6 taller tufts where the mound silhouette meets the grass field. Three on each side, at decreasing distances from the mound center. Gives the mound a "growing out of the ground" cue.

### 4.6 Pole base ring — Change 8

A thin darker-brown oval centered on the pole's base at the mound apex. Width is ~3× the pole's width; height ~0.9× the pole width. 70% alpha so it tints the mound underneath rather than masking it.

### 4.7 Horizon stroke removal — Change 9

`_paintGrass` drops the 2-px crisp stroke at `y = horizonY`. The mound silhouette + grass tufts now provide the visual boundary between sky and grass — and that boundary is no longer geometrically sharp, which was the main "three disconnected layers" cue.

---

## 5. Verification

| Gate | Before phase | After phase |
|---|---|---|
| `flutter analyze` | 6 issues (Phase 3 baseline) | **6 issues, 0 new** |
| `flutter test` | 1291/1291 passing | **1291/1291 passing** |
| Lines in `_RealisticScenePainter` | ~234 | ~401 (+167 net for the textured mound + 3 new helpers + paint refactor) |
| Net file change | — | +219 / -52 |

The 6 baseline infos are unchanged from prior phases:
- 2× `<path>` HTML-in-doc-comment infos in `animal_silhouettes.dart`
- 4× deprecated `Matrix4.translate` / `Matrix4.scale` infos in `animal_silhouettes.dart` and `target_silhouettes.dart`

---

## 6. Paint-order summary

```
1. Sky gradient                    (background)
2. Grass field                     (solid green, bottom 30%)
3. Mound (5 layers)
   3a. Base silhouette
   3b. Shadow path
   3c. Highlights
   3d. Clumps
   3e. Rocks
4. Pole + cylinder strips          (visual top at target center)
5. Grass tufts                     (in FRONT of pole — softens bottom)
6. Pole base ring                  (between tufts — disturbed earth)
7. Target silhouette               (covers upper portion of pole)
```

---

## 7. What's deferred

| Item | Where |
|---|---|
| Reticle / scope ring / aim crosshair / shot dots in `_RealisticScenePainter` | Scene Painter Phase 5+ |
| Rack target rendering rewrite | Future phase |
| Low-light palette for `_RealisticScenePainter` | Future phase |
| Drop shadows under target / pole | Future phase if needed |
| Sky gradient adjustments | Out of scope |
| Photoreal dirt mound | Explicitly NOT in scope — this is a stylized render |
| Cleanup of stale doc-comment references to deleted classes (`_TargetThumbnailPainter` in `scope_daytime_backdrop.dart`) | Opportunistic |

---

## 8. Operator visual QA (for you to run on device)

Per the Phase 4 spec's report-back section:

| Surface | Expected after Phase 4 |
|---|---|
| Picker preview with Bear selected | Bear sits **mounted to** the pole (lower body wraps the post, post visible above the mound but not through the upper bear body). Mound has visible dirt texture: two sub-peaks, clumps, rocks. Grass tufts at the horizon on both sides of the mound. Scene feels integrated. |
| Tap-to-zoom dialog of same Bear | Same scene at larger size; proportions scale up cleanly. The pole-through-target effect remains visible. |
| Small target preview (Prairie dog or Rabbit) | Smaller animals still render visibly inside the new tighter 0.28H box. |
| Tall portrait target (36×60 rectangle) | Outer frame is 4:3 landscape (unchanged from Phase 1); rectangle target sits properly on the pole. |
| Texas Star / IPSC / Circle / Plate | Procedural fallbacks still render correctly; new mound/grass scenery surrounds them. |

### If proportions still feel off

The two knobs are easy to tune further:
- `_inchesPerCanvasHeight` (currently 200) — lower = bigger scenery elements.
- `_targetBoxHeightFrac` (currently 0.28) — lower = smaller target.

### If the dirt texture looks wrong

The procedural mound's clump count (8), rock count (5), highlight count (3), and color values are all easy to adjust in `_paintMound`. The bezier silhouette is the most visually distinctive part — its two-peak shape is intentional, but if "asymmetric two-peak" reads as wrong rather than as natural-dirt, the cubic-bezier control points can be flattened or rebalanced.

---

## 9. Rollback notes

| Commit | Revert effect |
|---|---|
| `3667af3 Scene Painter Phase 4` | All nine changes reverted as a unit. Mound returns to clean ellipse + 4 pebbles. Pole returns to "target balanced on the tip" cue. Horizon stroke returns. Scenery scale returns to 1/300 in-per-px. **No schema or data changes — pure painter code, fully reversible.** |

Single `git revert 3667af3` reverts the entire phase cleanly.

---

## 10. What's next

Phase 5 (presumably) adds the reticle / scope ring / aim crosshair / shot dots overlay back into the single-target realistic mode. Those layers were deliberately deferred since Phase 1 so each phase could land independently. The painter is now mature enough (scale tuned, scene integrated, mounting cue working) to be a good base for the overlay work.

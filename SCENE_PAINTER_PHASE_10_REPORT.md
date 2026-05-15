# Scene Painter Phase 10 — Final Report

Date: 2026-05-15
Branch: `claude/infallible-panini-8b20d1` → fast-forwarded onto `main`
Spec: `/Users/general/Downloads/SCENE_PAINTER_PHASE_10_SPEC.md`

Commits on `main` (chronological):

| Commit | Group | Title |
|---|---|---|
| `537e1c1` | A   | Scene Painter Phase 10 Group A: VisualStyle foundation |
| `021f680` | B   | Scene Painter Phase 10 Group B: VisualStyle toggle surfaces |
| `3036bdc` | C   | Scene Painter Phase 10 Group C: polished rendering scaffold |
| `b621cfd` | hotfix | Phase 10 hotfix: AppBar overflow on Range Day (10 px right) |
| `1b51498` | D   | Scene Painter Phase 10 Group D: DOF blur + ground haze |
| `5680a53` | E   | Scene Painter Phase 10 Group E: soft drop shadow under target / slots |
| `7da1afc` | F   | Scene Painter Phase 10 Group F: color grade + vignette + film grain + noise asset |

## TL;DR

Phase 10 ships polished mode + visual-style toggle. Six halt-and-validate
groups (A–F) plus one mid-phase hotfix. Every group committed atomically,
verified through `flutter analyze` + `flutter test`, and operator-confirmed
before the next started.

The cartoon paint pass is byte-identical to pre-Phase-10. Polished mode
layers six atmospheric effects on top: DOF blur on distant elements,
ground haze over the horizon, soft drop shadow under target / each rack
slot, warm color grade on the full scene, radial vignette, subtle film
grain. Photo mode aliases to polished at one dispatch site (the painter's
`_effectiveStyle` getter); the enum keeps all three values so Phases 12 /
13 can light up photo's own rendering without forcing a re-pick.

flutter analyze: **0 errors, 6 baseline infos** (Vector matrix
deprecations in animal_silhouettes / target_silhouettes, pre-existing).
flutter test: **1399 passing** (+48 from 1351 at start of Phase 10 — +7
from Group A's enum-contract tests, +2 from Group F.1's new
asset-bundle integrity tests for `assets/noise/`, +39 unrelated from
parallel Phase One Recipes work that landed on main while Phase 10 was
in flight).

## Group A — `VisualStyle` foundation (`537e1c1`)

Smallest group. Enum + persistence + provider. No UI yet, no rendering
change.

- New `lib/models/visual_style.dart` — `enum VisualStyle { cartoon,
  polished, photo }` with `persistKey` getter and `fromPersistKey(String?)`
  static parser that falls back to `cartoon` on null / empty / unknown.
- New `lib/services/visual_style_notifier.dart` —
  `VisualStyleNotifier extends ChangeNotifier`, mirrors `LocaleService`
  pattern: hydrates from SharedPreferences on construction, persists +
  notifies on `setStyle`. No-op-on-redundant-set guard prevents
  spurious notify loops.
- `lib/app.dart` — `ChangeNotifierProvider<VisualStyleNotifier>` added
  to the root `MultiProvider`.
- `lib/screens/range_day/widgets/target_plot.dart` — added
  `visualStyle` parameter on `_RealisticScenePainter` (default
  `VisualStyle.cartoon`), updated `shouldRepaint` to include the
  field. `TargetPlot.build` hardcodes `VisualStyle.cartoon` here
  pending Group B wire-up.
- New `test/visual_style_test.dart` — 7 round-trip + fallback contract
  tests.

Cartoon path byte-identical (paint pass ignores the new field).

## Group B — UI surfaces (Settings + Range Day toggle) (`021f680`)

Wires the notifier to two synced surfaces and threads the user's
chosen style through to every `TargetPlot` call site so the painter
reads it on each rebuild.

- `lib/screens/settings/app_preferences_screen.dart` — new
  "Visual Style" section between Auto-save and Language, hosting
  `_VisualStyleTile`. Three-option `SegmentedButton<VisualStyle>`
  with brush / sparkle / image icons + helper paragraph per option.
- `lib/screens/range_day/range_day_detail_screen.dart` — compact
  icon-only `SegmentedButton<VisualStyle>` inserted into the AppBar
  actions row immediately after Quick/Full, before Low Light. All
  five Range Day `TargetPlot(...)` call sites
  (`_targetVisualBox`, `_showTargetPreviewDialog` zoom dialog via
  `ctx.watch`, and the three workspace TargetPlots: StreamBuilder
  error / StreamBuilder happy / no-stream else) now pass
  `visualStyle: context.watch<VisualStyleNotifier>().style`.
- `lib/screens/range_day/widgets/target_plot.dart` — `TargetPlot`
  exposes `visualStyle` as a constructor parameter (defaulting to
  cartoon for non-Range-Day callers); painter construction uses
  the widget field instead of the Group A hardcoded literal.
- `test/_range_day_test_harness.dart` — registers
  `VisualStyleNotifier` in the `MultiProvider` tree. Without it
  every Range Day widget test threw `ProviderNotFoundError` and
  `RangeDayErrorBoundary` swallowed the screen.

Section header "Visual Style" — Title Case per CLAUDE.md § 0a (had
initially shipped as "Visual style"; corrected before commit).

## Group C — Polished rendering scaffold (`3036bdc`)

Photo aliasing locked at the dispatch site; saveLayer scaffold around
the existing paint pass. Visually inert at this group — all three
modes render byte-identically to cartoon.

- C.1 — `effectiveStyle` switch (`photo => polished`) computed at the
  top of `paint()`. Every downstream conditional reads it.
- C.2 — `canvas.saveLayer(rect, Paint())` wraps the existing dispatch
  when `effectiveStyle != cartoon`. Default Paint() is a passthrough
  on restore.

Rationale for visibly inert scaffold: isolating the saveLayer wrap
from the effects validated that wrapping the entire paint pass in an
extra layer didn't introduce a regression on its own. If wrapping
broke gestures / clip math / hit-testing / etc., Groups D-F would
have landed on top of an already-broken foundation. Cheap-to-revert
checkpoint per the halt-and-validate workflow.

## Hotfix — AppBar overflow (`b621cfd`)

Operator's cold-restart QA on Group C surfaced a 10-px RenderFlex
overflow on the Range Day AppBar at 430-px-wide phone widths. Root
cause: Group B's 3-segment `SegmentedButton<VisualStyle>` adjacent
to the existing 2-segment Quick/Full `SegmentedButton<RangeDayMode>`
+ three trailing IconButtons (Low Light / History / Recalculate)
totalled ~440 px on a 430 px constraint.

Fix at root cause, not bandaid (CLAUDE.md § 0b). The spec at
§UI-placements explicitly allows either pattern for this surface:
*"Tapping cycles through (or shows a quick popup of) the three
modes."* I converted the trigger to a `PopupMenuButton<VisualStyle>`
(single-icon trigger, opens a labeled popup of all three modes).
Saves ~80 px; the 10-px overflow becomes ~70 px of breathing room.
Settings UI keeps its 3-segment SegmentedButton (full-screen list,
plenty of room).

New tiny helper `_visualStyleIcon(VisualStyle)` flips the trigger
icon to the currently-selected mode's icon so the user reads the
current style at a glance.

## Group D — DOF blur + ground haze (`1b51498`)

First visible effect in polished mode. Distant elements pick up
atmospheric depth via Gaussian blur; the horizon gets a soft white
wash.

- `_paintBackdrop(canvas, size, horizonY, inPerPx)` helper extracted
  to centralise the sky → distant pair → foreground sequence used
  by both `_paintSingle` and `_paintRack`. In cartoon mode the
  helper makes the same six painter calls inline; in polished /
  photo it adds the DOF blur saveLayer + ground haze.
- `_effectiveStyle` getter on the painter — promotes Group C's
  inline switch to a property so all downstream effect dispatches
  read from one source of truth.
- D.1 — DOF blur: `canvas.saveLayer(rect, Paint()..imageFilter =
  ImageFilter.blur(sigmaX: 1.5, sigmaY: 1.5))` wraps
  `_paintDistantHills` + `_paintTreeline`. Sky stays outside (crisp
  horizon line); foreground helpers stay outside (crisp grass / tree).
- D.2 — Ground haze: white vertical gradient band, top edge
  `horizon_y − canvas_h × 0.06`, bottom edge
  `horizon_y + canvas_h × 0.01`, alpha 0.0 → 0.18, painted between
  foreground backdrop and mid-scene content.

Spec parameters used verbatim. Haze alpha 0.18 is tunable in 0.15–
0.25 per spec — flag for follow-up if cold-restart QA finds it too
strong / weak.

## Group E — Soft drop shadow on target / slots (`5680a53`)

Single effect — targets now read as grounded.

- New `_paintTargetShadow(canvas, rect, category)` helper. Early
  returns in cartoon. Otherwise emits a shape-aware drop shadow.
- Called at the top of `_drawCategoryShape(...)` — the shared
  dispatch used by single-target (`_paintTarget` → category
  dispatch) AND rack slot loop (`_paintRack`'s slot loop → category
  dispatch). One change covers both paths; they can't drift.
- Shape geometry: `circle` → `drawCircle` (path-shaped); `square`
  / `rectangle` → `drawRect` (path-shaped); `ipsc` / `animal` /
  `special` → `drawRect` of shifted bounds (bounds-rect
  approximation per spec — blurring complex paths reads as fuzzy
  blob; rect reads as "soft shadow under this thing").

Render order in rack mode: rig first (drawn before slot loop opens),
then per slot: shadow → fill + outline. Each slot's shadow lands on
top of any rig geometry it overlaps (silhouette_stand stakes,
hanging_rail chains, popper bases). Per spec default; can move to
under-the-rig if cold-restart QA finds it wrong for a specific
mount type.

## Group F — Color grade + vignette + film grain + noise asset (`7da1afc`)

Final group. Three composite effects + one new asset.

- F.1 — `assets/noise/film_grain_256.png` (65.9 KB). 256×256, 8-bit
  grayscale, uniform random noise via `np.random.default_rng(seed=20260515)`
  (today's date as seed for reproducibility). Tileable: pure random
  noise has matching adjacent-pixel distribution at boundaries vs
  interior — the eye can't detect a seam. Asset added to
  `pubspec.yaml` (`- assets/noise/`) AND
  `test/assets_present_test.dart` `assetDirs` list (locks the
  pubspec contract).
- F.2 — Color grade: `ColorFilter.matrix(_colorGradeMatrix)`
  attached to the polished-mode saveLayer's Paint. Matrix is spec
  values verbatim: R × 1.05, G × 1.00, B × 0.95, A × 1.00 (subtle
  warm cast — daylight feel vs cooler fluorescent). Applied on
  saveLayer restore.
- F.3 — Vignette: `RadialGradient` shader, center canvas center,
  inner radius 0.35× canvas width (transparent), outer radius
  0.75× canvas width (25 % black). `stops: [0.35 / 0.75, 1.0]`.
  Drawn AFTER the color-grade restore so vignette pixels stay
  neutral black.
- F.4 — Film grain: `ui.ImageShader(noiseImage, TileMode.repeated,
  TileMode.repeated, ...)` + `ColorFilter.mode(Color(0x14FFFFFF),
  BlendMode.modulate)` + `BlendMode.overlay`. One `drawRect` over
  the full canvas. Drawn AFTER vignette so the grain texture
  composes on top of everything else.
- Async asset cache — process-global `_NoiseAssetLoader` singleton
  with `ValueNotifier<ui.Image?>`. `kickoff()` is idempotent; fires
  the load on the first polished-mode build. `TargetPlot.build`
  wraps the realistic-mode `CustomPaint` in
  `ValueListenableBuilder<ui.Image?>` so the painter is
  reconstructed when the asset arrives. First polished paint may
  render without grain; `shouldRepaint` catches the `null →
  ui.Image` transition and the next frame fires the grain pass.

Cartoon-only users never trigger the async load — `kickoff()` is
guarded by `visualStyle != VisualStyle.cartoon`.

Async pattern choice: process-global ValueNotifier rather than
StatefulWidget conversion or per-widget `FutureBuilder`. Single
decode per process, lazy load on first polished use, no
const-constructor break on `TargetPlot`, no "why is the asset
loading 5 times when there are 5 TargetPlots on screen" weirdness.

## Render order — single source of truth

For polished + photo modes, `_RealisticScenePainter.paint()` runs:

1. Open outer saveLayer with `ColorFilter.matrix(_colorGradeMatrix)`.
2. Sky (cartoon helper).
3. Open inner saveLayer with `ImageFilter.blur(σ=1.5)`.
4. Distant hills + treeline (Group D blur target).
5. Close inner saveLayer.
6. Foreground backdrop (grass, tall grass, foreground tree).
7. Ground haze gradient (Group D.2).
8. Mid-scene rig (mound + pole + grass tufts + base ring, OR
   rack mount-structure rig).
9. Drop shadow under target / each slot (Group E).
10. Target fill + outline (or per-slot fill + stroke in rack mode).
11. Close outer saveLayer — color grade applies on restore.
12. Vignette overlay (Group F.3).
13. Film grain overlay (Group F.4, no-op if asset not yet loaded).

For cartoon mode, steps 1, 3, 5, 7, 9, 11, 12, 13 are skipped.
Paint pass is byte-identical to pre-Phase-10.

## Acceptance criteria — final pass

| Criterion | Status |
|---|---|
| Schema is at v40 (no change from 9.8) | ✅ |
| `flutter analyze` — 0 errors, 6 baseline infos | ✅ |
| `flutter test` — all passing (1399) | ✅ |
| A: enum + persistence + provider compile | ✅ |
| B: Settings + Range Day toggle present and synced | ✅ |
| C: All three modes render identically to cartoon (scaffold no-op) | ✅ |
| D: DOF blur on distant backdrop only; ground haze above horizon | ✅ — pending cold-restart visual QA |
| E: Drop shadow visible under target / each slot | ✅ — pending cold-restart visual QA |
| F: Color grade + vignette + film grain visible | ✅ — pending cold-restart visual QA |
| Cartoon mode pixel parity with `main` pre-Phase-10 (`56a08d4` or later) | ✅ |
| Photo mode renders identically to polished mode | ✅ |
| Noise asset committed to repo, declared in `pubspec.yaml`, asset-bundle test passes | ✅ |
| Phase 10 report posted | ✅ (this file) |

## Tunable parameters (spec-sanctioned)

| Effect | Parameter | Current | Spec-sanctioned range |
|---|---|---|---|
| Ground haze | bottom-edge alpha | 0.18 | 0.15 – 0.25 |
| DOF blur | sigma | 1.5 | not in spec's listed tunable set |
| Drop shadow | mount-rig ordering | rig → shadow → slot | can move shadow under rig for `silhouette_stand` if cold-restart QA flags |

If cold-restart QA finds any visual feels wrong, surface and I'll
dial without touching anything else.

## Mount-structure shadow interaction — spec-flagged

Per Phase 10 spec §Group E: each slot's shadow draws AFTER the
mount-structure rig (which paints once before the slot loop opens)
and BEFORE the slot fill. The shadow sits ON TOP of any rig
geometry that overlaps it (`silhouette_stand` stake will have a
soft shadow band across it; `hanging_rail` chain will have a band
crossing it just below the rail).

This is the spec's default behavior. Cold-restart QA on each rack
type would catch any case where this reads wrong. Two
remediation paths if needed:

1. Move the shadow draw into the rig painter so the rig appears in
   front of the shadow (different visual: shadow lands BEHIND the
   rig).
2. Skip the shadow for specific mount styles where the rig already
   provides anchoring (e.g. `hanging_rail` chains already give the
   slot visual grounding; the shadow may be redundant there).

## Out of scope (deferred per spec)

- **Phase 10.5a — SVG live-update infrastructure.** Firebase-Storage
  SeedUpdater parallel for SVGs. Scheduled for launch-prep.
- **Phase 10.5b — Popper SVG improvement.** Bundled asset change.
- **Phase 11 — Distance-aware painter.** Reticle-anchored true-size
  rendering. Needs its own audit cycle and spec.
- **Phase 12 — Photo stands.** Lights up the photo mode that
  currently aliases to polished.
- **Phase 13 — Photo backdrops.** Curated backdrop library per
  distance band.
- **Chromatic aberration.** Was on the polished-mode candidate
  list; deferred from Phase 10 (shader complexity disproportionate
  to visual contribution).
- **Per-mode opacity / intensity slider.** Not shipped — three
  discrete modes are the v1 API. Tuning per-effect parameters is
  the v1.x adjustment path.

## What you should see on cold restart

Open Range Day Realistic mode. Flip the AppBar visual-style popup
through all three options.

**Cartoon**: identical to pre-Phase-10. Crisp distant hills,
treeline. No haze. No target shadow. No warm cast. No vignette.
No grain.

**Polished**: distant hills + treeline subtly blurred (DOF). Soft
white wash on the horizon (haze). Soft dark band under target /
each rack slot (drop shadow). Whole scene picks up a warm daylight
cast (color grade). Corners and edges of the scene subtly darker
than center (vignette). Surface has a very subtle film-texture
(grain — barely perceptible at 8 % overlay opacity but adds depth).

**Photo**: identical to polished (alias). When Phases 12 / 13 land
this becomes the gateway to photo stands + photo backdrops.

The painter's `shouldRepaint` correctly captures every effect
trigger so flipping the popup repaints immediately. The Settings
segmented button and the Range Day popup are synced via the
notifier — flip one, the other updates on the next build.

Phase 10 closes. Follow-up phases (Phase 10.5a, 10.5b) unblock.

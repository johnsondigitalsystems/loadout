# Scene Painter Phase 2 — Phase Report

**Date:** 2026-05-12
**Branch:** `claude/infallible-panini-8b20d1` (worktree off `main`)
**Commits delivered:** `418344f` + `9ca914f` — both on `origin/main`
**Prior report:** [TARGET_RENDER_FIX_SESSION_REPORT.md](TARGET_RENDER_FIX_SESSION_REPORT.md) (session summary through Phase 1)
**Spec source:** [`SCENE_PAINTER_PHASE_2.md`](file:///Users/general/Downloads/SCENE_PAINTER_PHASE_2.md) (delivered by user, supersedes Phase 1)

---

## 1. Headline

Scene Painter Phase 2 closes the **cartoon-animal rendering bug on the target picker thumbnails** and consolidates SVG dispatch behind a single shared helper. Phase 1 had only fixed the realistic-scene preview surface; the picker card thumbnails were still drawing procedural cartoons. Phase 2 fixes that AND refactors Phase 1's inline dispatch to use the same helper, so there's now one source of truth for "given a `TargetSpec`, give me the SVG path or null."

Two associated workflow rule revisions also landed in this phase:
- **Rule 6** (briefly active): "wait for approval before commit/push"
- **Rule v3** (current): "auto-commit + auto-merge to main, no approval gates"

---

## 2. Scope of this phase

### What got done

| Area | Change |
|---|---|
| Shared SVG dispatch | New top-level `resolveTargetSvgPath(Rect, String?)` helper in `target_plot.dart` |
| Realistic scene painter | `_RealisticScenePainter._paintTarget` refactored to call the helper |
| Picker thumbnail painter | `_TargetThumbnailPainter.paint` switch rewritten with `shape_id` check first; cartoon animal cases + popper case deleted |
| Dead-code deletion | `_paintAnimal` (177 lines) + `_paintPopper` (109 lines) removed from `_TargetThumbnailPainter` |
| Workflow rule | Rule 6 added, then immediately superseded by Rule v3 |
| Session report | Comprehensive session-spanning report committed under `docs/` |

### What did NOT get done (deferred per the spec)

| Deferred | Why |
|---|---|
| Reticle / scope ring / aim crosshair / shot dots in single-target realistic mode | Subsequent phase |
| Rack target rendering changes | Legacy `_RealisticTargetPainter` still backs the rack path |
| Low-light palette for `_RealisticScenePainter` | `lowLightMode` accepted but ignored — daytime only |
| Removing `_paintAnimal` / `_paintPopper` from `scope_daytime_backdrop.dart` | Different file, different class (`ScopeDaytimeBackdropPainter`), still used by the rack path. Spec explicitly kept it. |
| Deleting `_paintIpscSilhouette` and `_paintTexasStar` from `_TargetThumbnailPainter` | Still called by the procedural fallback switch |

---

## 3. Files changed

### Commit `418344f Scene Painter Phase 2 + Workflow Rule 6 + Session Report`

| File | Change | Net lines |
|---|---|---|
| [lib/screens/range_day/widgets/target_plot.dart](lib/screens/range_day/widgets/target_plot.dart) | Added top-level `resolveTargetSvgPath` helper at lines 140-170 (after imports, before first enum). Refactored `_RealisticScenePainter._paintTarget` to call the helper instead of inline dispatch. | +49 / -9 |
| [lib/screens/range_day/range_day_detail_screen.dart](lib/screens/range_day/range_day_detail_screen.dart) | `_TargetThumbnailPainter.paint` switch rewritten — `shape_id` check via `resolveTargetSvgPath` first, then procedural fallback for `circle / star / silhouette / rectangle / square`. Cases for `popper` and the six animal shape-strings (`bear / boar / deer / elk / coyote / hog`) deleted. `_paintAnimal` method (177 lines) deleted. `_paintPopper` method (109 lines) deleted. `_paintTexasStar` and `_paintIpscSilhouette` kept. | +28 / -296 |
| [CLAUDE.md](CLAUDE.md) | New Section 0b rule 6 — "Show diff, wait for approval before commit/push" | +29 |
| [docs/TARGET_RENDER_FIX_SESSION_REPORT.md](docs/TARGET_RENDER_FIX_SESSION_REPORT.md) | Session-spanning 16-section report (new file) | +368 |

### Commit `9ca914f Workflow Rule v3: Auto-Commit + Auto-Merge to Main`

| File | Change | Net lines |
|---|---|---|
| [CLAUDE.md](CLAUDE.md) | Section 0b rule 6 rewritten — "Auto-commit and auto-merge to main, no approval gates" (replaces Rule 6 v1) | +39 / -21 |
| `~/.claude/CLAUDE.md` (global, not in repo) | Section 2b rewritten with the same content | (not tracked) |

---

## 4. Scene Painter Phase 2 — code detail

### 4.1 New helper: `resolveTargetSvgPath`

Lives in [target_plot.dart](lib/screens/range_day/widgets/target_plot.dart) at the top of the file, after imports and before the first enum.

```dart
Path? resolveTargetSvgPath(Rect bounds, String? shapeId) {
  if (shapeId == null) return null;
  if (AnimalSilhouettes.isAnimalShape(shapeId)) {
    return AnimalSilhouettes.cachedScaledPath(bounds, shapeId);
  }
  if (TargetSilhouettes.isTargetShape(shapeId)) {
    return TargetSilhouettes.cachedScaledPath(bounds, shapeId);
  }
  return null;
}
```

Three null-return cases:
- `shapeId == null` — the row is a procedural shape (circle, IPSC silhouette, rectangle, etc.)
- `shapeId` doesn't match any known asset map — defensive (won't happen with current catalog, but keeps the helper robust to future drift)
- `shapeId` is known but the path cache is cold (`main.dart`'s boot-time preload hasn't fired yet) — caller falls back to procedural this frame, next repaint picks up the SVG

Two call sites:
- `_RealisticScenePainter._paintTarget` ([target_plot.dart:~1208](lib/screens/range_day/widgets/target_plot.dart))
- `_TargetThumbnailPainter.paint` ([range_day_detail_screen.dart:~9670](lib/screens/range_day/range_day_detail_screen.dart))

### 4.2 `_RealisticScenePainter._paintTarget` refactor

Phase 1 had inline dispatch:

```dart
final shapeId = target.shapeId;
Path? svgPath;
if (shapeId != null) {
  if (AnimalSilhouettes.isAnimalShape(shapeId)) {
    svgPath = AnimalSilhouettes.cachedScaledPath(rect, shapeId);
  } else if (TargetSilhouettes.isTargetShape(shapeId)) {
    svgPath = TargetSilhouettes.cachedScaledPath(rect, shapeId);
  }
}

if (svgPath != null) { ... }
```

After Phase 2:

```dart
// Shared dispatch: SVG path if shapeId resolves, otherwise null.
// See top-level [resolveTargetSvgPath]; the same helper backs the
// picker thumbnail painter in range_day_detail_screen.dart.
final svgPath = resolveTargetSvgPath(rect, target.shapeId);
if (svgPath != null) { ... }
```

Net: -9 inline-dispatch lines, +3 helper call. The procedural fallback switch below it stays unchanged.

### 4.3 `_TargetThumbnailPainter.paint` rewrite

Before Phase 2 — switch dispatched `shape.toLowerCase()` directly, with hardcoded cases for each animal species routing to `_paintAnimal` (the cartoon):

```dart
switch (shape) {
  case 'circle':         // ...
  case 'star':           _paintTexasStar(...);
  case 'silhouette':     // (and ipsc/idpa/human) _paintIpscSilhouette(...);
  case 'popper':         _paintPopper(...);
  case 'bear':           // (and boar/deer/elk/coyote/hog) _paintAnimal(...);
  case 'rectangle':      // (and square/default) draw rect
}
```

After Phase 2 — SVG dispatch first, procedural fallback only for non-SVG shapes:

```dart
final shapeId = spec.shapeId;
if (shapeId != null) {
  final svgRect = Rect.fromCenter(
    center: Offset(centerX, centerY),
    width: maxBox,
    height: maxBox,
  );
  final svgPath = resolveTargetSvgPath(svgRect, shapeId);
  if (svgPath != null) {
    canvas.drawPath(svgPath, fill);
    canvas.drawPath(svgPath, outline);
    return;
  }
  // shapeId set but cache cold — fall through to procedural
}

final shape = spec.shape.toLowerCase();
switch (shape) {
  case 'circle':         // ...
  case 'star':           _paintTexasStar(...);
  case 'silhouette':     // (and ipsc/idpa/human) _paintIpscSilhouette(...);
  case 'rectangle':      // (and square/default) draw rect
}
```

The `popper` case and the six animal shape-string cases are gone. They're not needed: poppers have `shape_id: 'pepper_popper'` (routes through SVG dispatch) and animals have `shape_id: <name>` (routes through SVG dispatch). If a legacy row somehow has `shape: 'bear'` without `shape_id`, it falls through to the rectangle default — visually degraded but doesn't crash. The Phase A catalog rewrite eliminated all such legacy rows from the seeded data.

### 4.4 Deleted helpers

| Helper | Lines | Why deleted |
|---|---|---|
| `_paintAnimal(canvas, cx, cy, maxBox, fill, outline, kind)` | 177 (lines 9910-10078, pre-edit) | Replaced by SVG dispatch via `resolveTargetSvgPath`. All animal shape-string callers were the cases I deleted from the switch above. Zero remaining callers. |
| `_paintPopper(canvas, cx, cy, maxBox, fill, outline)` | 109 (lines 9799-9900, pre-edit) | Replaced by SVG dispatch. The popper case in the switch was its only caller. Zero remaining callers. |

Verified via `grep -n "_paintAnimal\b\|_paintPopper\b" lib/screens/range_day/range_day_detail_screen.dart` → 0 hits after the deletions.

### 4.5 Helpers kept (still called)

| Helper | Reason |
|---|---|
| `_paintTexasStar` | Still called by the `case 'star':` arm of the procedural fallback switch |
| `_paintIpscSilhouette` | Still called by the `case 'silhouette' / ipsc / idpa / human:` arm |

### 4.6 What `scope_daytime_backdrop.dart` looks like

A grep for `_paintAnimal` and `_paintPopper` after the Phase 2 deletions shows matches in `lib/widgets/scope_daytime_backdrop.dart` — these are **different methods in a different class** (`ScopeDaytimeBackdropPainter`):

| Match | Context |
|---|---|
| `scope_daytime_backdrop.dart:745` | Internal call site for the file's OWN `_paintAnimal` method |
| `scope_daytime_backdrop.dart:756` | Internal call site for its OWN `_paintPopper` method |
| `scope_daytime_backdrop.dart:767` | Declaration of `_paintPopper` (different class, different bowling-pin geometry) |
| `scope_daytime_backdrop.dart:858` | Declaration of `_paintAnimal` (different class, different cartoon geometry) |

The Phase 2 spec explicitly kept these in place — they back the legacy `_RealisticTargetPainter` for the rack-rendering path. Phase 2's scope was the picker thumbnail painter only.

---

## 5. Workflow rule evolution during this phase

Two rule revisions landed in this phase. Both are documented for the historical record:

### 5.1 Rule 6 — "Show diff, wait for approval before commit/push" (briefly active)

Landed in commit `418344f`. The rule:
- Never auto-commit or auto-push.
- After editing, show the diff + analyze / test results.
- Wait for the user to approve before running `git commit`.
- Push is a separate explicit ask.

Lifespan: one turn. The user wanted to review code BEFORE it landed on `main`.

### 5.2 Rule v3 — "Auto-commit and auto-merge to main, no approval gates" (current)

Landed in commit `9ca914f`. Replaces Rule 6 wholesale. The rule:
- When analyze + tests are clean, commit immediately.
- If on a non-`main` branch, automatically fast-forward `main` AND push to `origin/main`.
- All five steps (edit → analyze → test → commit → fast-forward → push) happen in one turn.
- The user reviews changes on `main` directly (locally + on GitHub), not pre-commit.

Blocking conditions remain:
- Test failures / analyze regressions → don't commit, surface the failure.
- Auth blockers on push → surface and ask.
- Genuinely destructive operations (`git push --force`, branch deletion, history rewrites, schema-incompatible migrations) → still need explicit authorization.
- User-typed slash commands (`/create-pr-command`) → still treated as questions.

Why the flip: the approval-at-every-step pattern added friction without adding signal. The user's actual review surface is `main`, not pre-commit diffs.

---

## 6. Verification

| Gate | Before phase | After phase |
|---|---|---|
| `flutter analyze` | 6 issues (pre-existing baseline) | 6 issues, **0 new** |
| `flutter test` | 1291/1291 passing | 1291/1291 passing |
| Stale references to `_paintAnimal` / `_paintPopper` in `range_day_detail_screen.dart` | 9 hits (declarations + call sites) | **0 hits** (clean delete) |
| `resolveTargetSvgPath` call sites | 0 (didn't exist) | 2 (both painters) |
| Branch state | `1bf2b8a` ahead of `origin/main` by 0 | `9ca914f`, identical to `origin/main` |

---

## 7. Cumulative file changes (this phase)

| File | Operation | Diff |
|---|---|---|
| `lib/screens/range_day/widgets/target_plot.dart` | Modified | New top-level `resolveTargetSvgPath` helper; `_RealisticScenePainter._paintTarget` calls it |
| `lib/screens/range_day/range_day_detail_screen.dart` | Modified | `_TargetThumbnailPainter.paint` switch rewritten; `_paintAnimal` + `_paintPopper` deleted |
| `CLAUDE.md` (project) | Modified | Rule 6 added, then rewritten as Rule v3 |
| `~/.claude/CLAUDE.md` (global) | Modified | Section 2b added, then rewritten with Rule v3 content |
| `docs/TARGET_RENDER_FIX_SESSION_REPORT.md` | Created | Session-spanning 16-section report |
| `docs/SCENE_PAINTER_PHASE_2_REPORT.md` | Created | This file |

### Files NOT touched (per the spec's "Don't touch" list)

- `_RealisticTargetPainter` (legacy painter — still backs the rack path)
- `RealisticLayout`
- `_TargetPainter` (target-focused mode)
- `_paintIpscSilhouette` and `_paintTexasStar` on `_TargetThumbnailPainter` (still in use)
- Sensitive files: `revenue_cat_config`, `onedrive_config`, `auth_service`, `backup_crypto`, `purchases_service`, `biometric_service`, `cloud_backup_service`, `Info.plist`
- Math-audit-boundary files: `solver.dart`, `hit_probability_service.dart`, `hit_probability_map_service.dart`

---

## 8. Operator visual QA (for you to run on device)

Per the Phase 2 spec's report-back section:

### Picker thumbnail surface (the bug Phase 2 closes)

| Thumbnail | Expected |
|---|---|
| Bear / Boar / Deer / Elk / Coyote / Mountain lion | Authored SVG silhouette (NOT a cartoon) |
| Prairie dog / Rabbit / Pheasant / Wild turkey / Fox / Bigfoot | Authored SVG silhouette |
| Moose / Mule deer / Pronghorn / Groundhog | Authored SVG silhouette |
| Pepper Popper (Full + Mini) | Authored `pepper_popper.svg` (NOT the procedural bowling-pin path) |
| IPSC silhouette | Procedural IPSC outline (unchanged from before) |
| 24″ steel plate | Procedural circle (unchanged) |
| 36×60 rectangle | Procedural rectangle, taller-than-wide (unchanged) |
| Texas Star | Procedural hub + 5 plates (unchanged) |

### Realistic scene preview surface (unchanged from Phase 1)

| Target | Expected scene |
|---|---|
| Default IPSC silhouette | Sky 70% + grass 30% + brown mound + steel-grey pole + IPSC silhouette |
| 24″ steel plate | Same scene, circular target |
| Bear | Same scene, authored Bear SVG |
| Prairie dog | Same scene, prairie dog SVG |
| Any rack (KYL plate rack) | Legacy painter: cross-bar + chains + plates as before |
| All single targets | NO reticle, NO scope ring, NO aim crosshair, NO shot dots — intentionally deferred |
| Tall portrait target (36×60 rectangle) | Outer frame is 4:3 landscape (NOT square) |

### Cold-cache fallback (per the spec)

If any SVG target shows a procedural fallback (rectangle / circle) instead of the authored silhouette on first paint, that's the cold-cache case — `main.dart`'s boot preload hasn't completed yet. Resolves on the next repaint. Not a bug.

---

## 9. What's next

| Item | Where |
|---|---|
| Reticle / scope ring / aim crosshair / shot dots in `_RealisticScenePainter` | Scene Painter Phase 3+ |
| Rack target rendering rewrite | Future phase — legacy painter stays for now |
| Low-light palette for `_RealisticScenePainter` | Future phase |
| Deleting the duplicate `_paintAnimal` / `_paintPopper` in `scope_daytime_backdrop.dart` | Whenever the rack path's legacy painter is rewritten |
| Visual QA pass on device | Operator step |

---

## 10. Rollback notes

| Commit | Revert effect |
|---|---|
| `9ca914f Workflow Rule v3` | Rule reverts to v1 wording (no auto-commit). No code effect. |
| `418344f Scene Painter Phase 2 + Workflow Rule 6 + Session Report` | Picker thumbnails revert to cartoon animals + procedural popper. `_RealisticScenePainter` inline dispatch returns (Phase 1 behavior). `resolveTargetSvgPath` deleted. Workflow Rule 6 (wait-for-approval) returns. Session report file vanishes. |

Cleanest "undo phase 2" path: `git revert 9ca914f 418344f` from `main`, push. No schema migrations involved, no irreversible state changes.

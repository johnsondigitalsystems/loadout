# Visual Fidelity Program Plan v3 — Audit (Claude Code / reviewer 2)

> **Reviewer:** Claude Code. Per the plan's own §Audience and
> DEVELOPMENT.md § 1.3 my lens is **implementation feasibility,
> codebase compatibility, and halt-and-validate group sizing** — not
> product/aesthetic judgement (operator) or pure architecture
> (engineering Claude). My differentiator is that I have the running
> code; every claim below is checked against it.
>
> **Codebase state at audit time:** Phase 11 Group A v2 shipped
> (`ee02a88`); Phase 11 Group B and C.1–C.4 NOT shipped; `main` test
> count 1435 passing, `flutter analyze` 0 errors / 6 baseline infos.
>
> **Notation:** `[code: path:line]` = fact verified in the current
> tree this session. Severity: 🔴 critical (blocks approval) / 🟠 major
> (resolve or accept in writing) / 🟡 minor (resolve in execution) /
> 🟢 sound.

---

## 1. Verdict

**Do not approve as written.**

The architectural spine is good: the three-tier hierarchy, the
per-asset fallback chain, and the reuse of the Phase 11 Group A v2
cache-generation `ValueNotifier` are the right structural choices, and
the halt-and-validate decomposition is mostly correctly sized. But the
plan has **five critical defects**, two of which invalidate its core
resource model and its asset strategy, plus a cluster of major errors
that show the document was written against an assumed end-state rather
than the code that exists today.

The single most important finding: the plan proposes to replace flat
white vector shapes with 16+ enormous photographic raster sprites —
**the exact class of mistake the operator just caught and reverted for
the pepper popper this same session, repeated at 16× scale.** Settle
that first; it collapses the asset inventory, the memory model, and
roughly an entire authoring workstream.

| Severity | Count |
|---|---|
| 🔴 Critical — must resolve before approval | 5 |
| 🟠 Major — resolve or accept risk in writing | 7 |
| 🟡 Minor / clarify — resolve during execution | 6 |
| 🟢 Sound — credited explicitly | 5 |

---

## 2. 🔴 Critical findings

### C1 — Memory budget is computed from file size, not decoded size. Wrong by ~400×; the ceiling is blown by the plan's own cache spec.

A decoded image costs **width × height × 4 bytes** of RAM regardless
of how small the compressed file is. Section 4 and Section 8 reason in
file-size terms throughout.

Decoded cost of the plan's own resolution spec (§3, §4):

| Asset | Plan's stated "size" | **Decoded RAM** |
|---|---|---|
| Backdrop 2560×1440 | 200–400 KB | **14.7 MB** |
| Paper target 4096×4096 | 80–120 KB | **67 MB** |
| Animal sprite 4096×3072 | 100–180 KB | **50 MB** |
| A-frame mount 4096×1536 | 200–300 KB | **25 MB** |
| Wooden post 1024×3072 | 80–120 KB | **12.6 MB** |

One Realistic rack frame (1 backdrop + 1 A-frame + 1 reused slot
sprite) ≈ **90 MB of decoded texture for three images**, before the
LRU holds anything and before the GPU-side texture mirror. Section 8's
own `LRU maxEntries = 5` + `maxCachedBackdrops = 3` at these
resolutions = **~294 MB of image cache alone** (optimistic — uses 50 MB
animals, not the 67 MB paper target). The "300 MB ceiling" is exceeded
by the cache structure the plan itself specifies; the "iPhone 11 /
Pixel 6 baseline" target is unreachable (a single 4096² sprite + its
GPU texture is most of an iPhone 11's app-memory allowance before
jetsam).

The standard remedy — **decode-time downsampling**
(`instantiateImageCodec(targetWidth:, targetHeight:)`,
`ResizeImage`, `ImageDescriptor` target dims) — is **not mentioned
anywhere in the plan.** Without it the resolution spec and the memory
budget cannot both hold.

**Before approval:** rewrite Section 8 in decoded-RAM terms; make
decode-time downsampling a first-class, specified Phase 13 deliverable
with decode dimensions derived from `canvas × devicePixelRatio × max
sharp zoom` (not the authoring resolution); re-derive every budget.

### C2 — Flat matte-white targets / silhouettes / animals do not need photographic sprites. This is the popper mistake at 16× scale.

This session opened with the operator correctly rejecting a procedural
popper drawer; the real cause was an SVG cache-warmup race, fixed in
Phase 11 Group A v2. The lesson: don't swap a working vector
representation for a heavier one without the real reason.

The plan does the inverse of that lesson, larger. Per §4 and
Appendix C the animal sprites are explicitly:

> "White silhouette style (paper/steel target in animal shape, painted
> matte white) … `silhouette_only: true # no fur detail; flat
> painted-steel look`"

A flat matte-white animal-shaped steel plate is **a filled path plus a
material-shading pass.** That is exactly what the existing
`AnimalSilhouettes` vector system already produces
`[code: lib/widgets/animal_silhouettes.dart]`, shaded by the Phase 10
effects stack (sun highlight, edge shadow, drop shadow, color grade).
Reference Image 3 (IPSC) and Images 1–2 (square/circle plates) are
likewise flat painted steel — not photographic objects.

Spending **16 × ~50 MB decoded** + the 67 MB paper target + mount
sprites to render shapes that are mathematically flat fills is the
popper error × 16. It also re-imports every problem the popper debate
surfaced: cache-warmup races (now 30+ assets, not 2), CDN dependency,
alpha-cutout halos (the plan's own Concern C1), and AI-asset style
drift across 16 files (the plan's own Risk A1/A2).

The genuinely photographic objects in the reference images are the
**backdrop, dirt mound, wood-grain post, metal A-frame, chains** —
real texture procedural rendering does poorly; sprites are right
there. The **targets themselves** are flat painted surfaces the
existing vector + material-shading path already handles cheaply.

**Recommended reframing (settle before anything else):**
- Photo sprites: backdrop, mound, post, A-frame, standing stake,
  silhouette stand, chains.
- Vector/procedural + a "painted-steel" material pass (sun-direction
  highlight + edge shadow + existing drop shadow): every plate, every
  silhouette, all 16 animals.
- Net: deletes ~16 CDN assets, the worst of C1, Risk A1/A2, and a
  whole authoring workstream — and matches the "flat painted steel"
  spec *better* than an AI photo of a flat white shape would.

If the operator wants raster animals for a reason not in the document,
that reason should be stated and the C1 memory cost accepted in
writing. Sliding into 16 huge sprites for flat shapes by default is
the unforced error already reverted once this session.

### C3 — `compute()` cannot decode and return a `ui.Image`. Phase 13 Group A is impossible as written.

Phase 13 Group A: *"Async decode with `compute()` for off-thread."*

`ui.Image` wraps a native/GPU handle and is **not sendable across an
isolate boundary.** `compute()` runs in a separate isolate; a
`ui.Image` cannot be constructed there and returned — it throws at the
send port. Only raw file *bytes* can cross; the *decode* cannot.

The correct off-platform-thread primitive is
`ui.instantiateImageCodec(bytes, targetWidth:, targetHeight:)` /
`ImageDescriptor.instantiateCodec()` — these decode off the platform
thread internally and yield a `ui.Image` on the main isolate. This is
exactly what the codebase's Phase 10 noise loader and Phase 11 Group A
v2 SVG loader already do correctly `[code:
lib/screens/range_day/widgets/target_plot.dart — `_NoiseAssetLoader`
uses `instantiateImageCodec`]`. Phase 13 must specify that primitive
and delete the `compute()` language, or Claude Code is sent down an
impossible path.

### C4 — Horizon mismatch: code anchors the scene at 0.75 H; the plan authors backdrops at 0.62 H. Sprites will float off the photo's ground line.

`[code: lib/screens/range_day/widgets/target_plot.dart:1550]`
`static const double _horizonFrac = 0.75;` — the sky/grass boundary
and the Y every mid-ground element (mound, pole, rack rig, target
anchor) is positioned against.

The plan's backdrop metadata schema (§3, Appendix C) and Appendix B
both state `horizon_y_normalized: 0.62` and literally call it
"(procedural)". **Appendix B's "0.62 (procedural)" is factually wrong
about the current code — it is 0.75** — and the authoring spec
inherits the wrong number.

Consequence: in Scenic/Realistic the rig anchors at 0.75 H, but a
backdrop authored with its horizon at 0.62 H places the photo's ground
line 13% of canvas height above the rig's feet — every sprite floats,
or the mound clips into the photo grass. This makes the plan's own
"Concern C2 — ground/lighting consistency" unavoidable via a constant
the plan misread.

**Before approval:** reconcile to one number. Either author backdrops
at 0.75 horizon, or drive the painter's anchor Y from the backdrop
metadata `horizon_y_normalized` in Scenic/Realistic and state that the
0.75 constant applies only in Stylized. Either way, stop asserting
0.62 is the existing value.

### C5 — Web and macOS are unaddressed; the program as specified crashes the web build.

LoadOut ships iOS, Android, **macOS, and web** (CLAUDE.md § 1, § 17).
The plan never says "web" or "macOS."

- `Platform.totalPhysicalMemory` (Section 8 device detection) is
  `dart:io` and **throws on web**. The first thing the
  adaptive-degradation code runs crashes the web target.
- `getApplicationSupportDirectory()` (Sections 7/13/14 photo cache)
  has no web implementation — the cache + SeedUpdater download path is
  mobile-only.
- The codebase's established convention is `kIsWeb` / explicit
  platform gates with a UI fallback (CLAUDE.md § 17 documents this for
  drift/BLE/Crashlytics/etc.). The plan has no equivalent decision.

**Before approval:** an explicit written decision — simplest and
consistent with § 17 precedent: *"Realistic + Scenic are mobile-only;
web and macOS fall back to Stylized."* As written, Phase 13 ships code
that throws on web.

---

## 3. 🟠 Major findings

### M1 — Phase 11 is not closed; the plan asserts an unshipped end-state as fact.

Phase 12's prerequisite is "Phase 11 closed." It isn't — Group B
(dark-mode) and C.1–C.4 (SVG live-update) are unshipped and Group A
required a revert + redo this session.

- Appendix B lists `final bool isDarkMode; // Phase 11` as an existing
  painter field. It does **not** exist — `isDarkMode` occurs 0 times
  in `target_plot.dart` `[code: grep -c isDarkMode → 0]`. It is Phase
  11 Group B, unshipped.
- §1 / Section 14 / many phases treat "Phase 11 dark-mode
  desaturation applied" as a stable substrate. It is pending design
  this plan now hard-depends on.
- Phase 13 says it mirrors the Phase 11 `svg_cache` pattern. Phase 11
  C's `svg_cache` is unshipped — Phase 13 would be *defining* it, not
  reusing it. (The cache-*generation* `ValueNotifier` IS shipped —
  Phase 11 Group A v2, `ee02a88` — and is correctly reused; see 🟢.)

Relabel Appendix B "target architecture after Phases 11–13," declare
Phase 11 B+C as real prerequisites with their own gates, and stop
citing Phase-11-end-state as already true.

### M2 — The Scope View / reticle-picker-preview surface is invisible to the plan.

CLAUDE.md § 31 documents that three painters cooperate and that
`ScopeDaytimeBackdropPainter` `[code:
lib/widgets/scope_daytime_backdrop.dart, referenced from
target_plot.dart]` renders the backdrop for the reticle-picker preview
AND Scope View AND Range Day Realistic. The plan only ever touches
`_RealisticScenePainter`.

If Phase 14 swaps the backdrop only inside `_RealisticScenePainter`,
the Scope View and reticle-picker preview still render the procedural
daytime backdrop — the user sees a photographic range in Range Day and
an illustrated one in Scope View for the same target. The plan's own
quality bar ("every target type, every rack type, every distance, on
every supported device") implicitly includes Scope View, but no phase,
group, or sentence addresses it.

Decide: bring `ScopeDaytimeBackdropPainter` into the tier system (its
own group), or scope Realistic to Range-Day-only and reconcile that
with the quality-bar language.

### M3 — `rangeYards` is not plumbed to the painter; distance-aware selection (Phases 19/21) needs unacknowledged plumbing.

The plan repeatedly assumes "the painter queries target context for
range" (Section 5; Phase 19A; Phase 21A).

Reality: `rangeYards` is a `TargetPlot` widget field
`[code: target_plot.dart:498, 621]` consumed by
`computeRealisticLayout(...)` for **reticle-subtension math only**
`[code: target_plot.dart:691 → layout helper; 1069–1085 mil/MOA
sizing]`. It is **not** passed to the `_RealisticScenePainter`
constructor — the painter has no knowledge of distance today.

Phases 19/21 therefore need a new painter constructor parameter +
`shouldRepaint` participation + threading from `TargetPlot.build`, plus
a decision for the null case (`rangeYards` is `double?`, frequently
null before the user sets a distance — "no distance → which band?" is
unaddressed). Real additive work the plan treats as "just query
context." Call it out and size it.

### M4 — Backdrops under-specced for zoom; sprites over-specced. Internally contradictory.

§3 "Resolution rationale" justifies **4096 px sprites** for "scope
zoom up to 24× without pixelation." Section 5 zoom math
"procedurally crops + scales the backdrop," but backdrops are authored
at only **2560×1440**. At 9× the visible backdrop crop (~284 px wide)
is upsampled to a ≥1080 px canvas — heavy blur behind a razor-sharp
sprite. The zoom budget is spent on the flat shape (which doesn't need
it — C2) and starved on the photo backdrop (which does). One feature
(scope zoom) drives opposite resolution conclusions for the two
layers and the plan applied it to only one. Resolve jointly with
C1/C2 from a single "max sharp zoom" decision.

### M5 — Golden-test infra doesn't exist; the <0.5% cross-platform threshold is infeasible with blur/blend; Impeller is never mentioned.

Section 10 specifies `golden_toolkit`, `test/goldens/scene_painter/`,
"<0.5% pixel diff." There is **no `golden_toolkit` dependency and no
`test/goldens/` directory** `[code: pubspec.yaml — no golden_toolkit;
test/goldens absent]`; standing the infra up is unscoped.

The painter's Phase-10 effect stack is `ImageFilter.blur`,
`MaskFilter.blur`, `RadialGradient`, `BlendMode.overlay`,
`saveLayer + ColorFilter.matrix` — the most backend-divergent
operations in Flutter. **Skia vs Impeller** (Impeller is default on
iOS for the pinned SDK), CI vs device, and minor Skia bumps all shift
these. A <0.5% diff across the plan's 7-device matrix is not
achievable; goldens must be single-platform-pinned with a materially
looser threshold or the gate is permanently red and ignored. The plan
never mentions **Impeller** anywhere — a notable omission for an
iOS-shipping app doing this much blur/blend.

### M6 — Device tiering keys off the wrong number for iOS.

Section 8 tiers by total device RAM (`≥6 GB capable`). On iOS the
binding limit is the per-app **jetsam** threshold, not total RAM — an
iPhone 11 has 4 GB but is killed well under ~1.4 GB. Tiering iPhone 11
as "mid-range / 200 MB / half-res" still implies a 5-deep LRU of
2048-px (≈16 MB) sprites + backdrops — combined with C1 still
over-commits. Pair tiering with real decoded-budget accounting (C1)
and `didReceiveMemoryWarning` eviction (the plan mentions warning
eviction in Phase 27C but the budget that triggers it is
mis-derived).

### M7 — Phase 12 "no visual change" contradicts Appendix B's `effectiveStyle` sketch.

Phase 12 (rename only) acceptance: "No visual change." The alias
today lives in the painter's `_effectiveStyle` getter as
`photo → polished` `[code: target_plot.dart, Phase 10 Group C.1]`.
Post-rename there is no `photo`/`polished`; `realistic` must STILL
render exactly as procedural until Phase 14+ ships backdrops.

Appendix B's sketch —
`effectiveStyle = (visualStyle == realistic) ? realistic : visualStyle`
— returns `realistic` as effective, but no render path for `realistic`
exists until Phase 14. Followed literally in Phase 12, this fails
Phase 12's own "no visual change" gate. Phase 12 must explicitly
preserve `realistic → scenic-equivalent → stylized-render` aliasing
until Phase 14; Appendix B must not be the executable reference for
Phase 12.

---

## 4. 🟡 Minor / clarifications

- **"Graceful" fallback is a hard style jump.** §1.3: missing mount
  sprite → "procedural mount (Scenic-style)." The procedural
  hanging-rig is a brown cross-bar `[code: target_plot.dart
  `_paintHangingRailRig`]`, not a silver A-frame. A Realistic A-frame
  degrading to a brown rail is functional but not visually graceful;
  set the expectation so operator QA doesn't log it as a bug.

- **Phase 24 hard-depends on Phase 22's Ticker.** A `CustomPainter`
  has no animation lifecycle; the ~6-frame impact loop needs the Phase
  22 animation foundation feeding repaints. Sequence (22 → 24) is
  right; make the dependency explicit so 24 isn't attempted alone.

- **Shot-impact vs persisted shot-dots.** Phase 24A "wire painter to
  receive shot result." Range Day already persists `ShotImpacts` and
  renders dots. Phase 24D addresses hit-probability overlap but not
  the shot-dot layer. Clarify transient FX vs persisted dots so they
  don't fight the same draw pass.

- **Color-picker × tint matrix order (Section 6).** `colorMultiply4x5`
  order matters; Section 6 shows it one way and implies the reverse
  elsewhere. Cite the Phase 11 Group B `multiplyColorMatrices4x5`
  apply-order contract (once it ships) rather than restating
  ambiguously.

- **Migration idempotency is a data-loss bug (Section 14).** The
  snippet reads `visual_style`, switches old→new, `_ => 'stylized'`.
  After Phase 12 the stored value is already
  `stylized|scenic|realistic`; a second run maps the already-migrated
  value through the `_` default and **silently resets scenic/realistic
  users to stylized.** The switch must pass already-migrated values
  through (`'stylized' => 'stylized'`, etc.). Fix before Phase 12.

- **Standing-stake / silhouette-stand anchoring.** §5 says "identical
  to existing rack math." Cite `computeRackSlotRects(...)`
  `[code: target_plot.dart, Phase 9.8]` as the explicit anchor source
  so sprite placement can't drift from the hit-test rects (the Phase
  9.8 bug class).

---

## 5. 🟢 What is sound (credited)

- **Cache-generation `ValueNotifier` reuse is correct and proven.**
  §1.3 / Section 7 / Risk E7 lean on the "Phase 11 Group A v2
  pattern." That shipped this session (`ee02a88`, 1435 tests green)
  and is the right tool for staged async asset arrival. Best
  architectural decision in the document.

- **Phase 8 `inPerPx` claim is accurate.** Section 5 states
  `inPerPx = canvas_h / 150`. Verified: `_inchesPerCanvasHeight =
  150.0`; `inPerPx = h / _inchesPerCanvasHeight`
  `[code: target_plot.dart:1557]`. The math-preservation invariant
  (substitute `drawImageRect` into the same `target_rect`) is the
  correct thing to hold.

- **Backdrop helper names are accurate.** Phase 14B names `_paintSky`
  / `_paintDistantHills` / `_paintTreeline` — all exist with those
  exact names `[code: target_plot.dart:2037, 2057, 2092]`, alongside
  `_paintBackdrop` (1951), `_paintForegroundTree`, `_paintGrass`,
  `_paintMound`. Phase 14's integration point is real.

- **Tier hierarchy + per-asset fallback chain is conceptually
  sound** and matches how the codebase already treats optional
  capability (CLAUDE.md § 17). Stylized-as-floor is the right
  resilience model.

- **Halt-and-validate sizing is mostly right** — most phases are 3–5
  groups of one coherent change, consistent with DEVELOPMENT.md
  § 2.2. Watch Phase 16 (5 groups + a UI surface + shadow projection
  — heavy; likely a mid-phase split) and Phase 12 Group A (enum +
  migration + tests is acceptable only after the Section 14 migration
  bug is fixed).

---

## 6. Recommended actions before approval (ordered)

1. **C2 first.** Decide targets/silhouettes/animals = vector +
   material-shading, not raster sprites. This collapses the asset
   inventory, the worst of C1, Risk A1/A2, and an authoring
   workstream. Everything downstream depends on this answer.
2. **C1.** Rewrite Section 8 in decoded-RAM terms; make decode-time
   downsampling a specified Phase 13 deliverable; re-derive budgets.
3. **C4.** Reconcile horizon (code 0.75 vs plan 0.62); decide whether
   backdrop metadata drives the anchor in Scenic/Realistic.
4. **C5.** Write the explicit web/macOS decision (mobile-only →
   Stylized fallback).
5. **C3.** Replace `compute()` decode language with
   `instantiateImageCodec(targetWidth:, targetHeight:)`.
6. **M1 / M7 / Section-14 bug.** Re-baseline against the true
   Phase-11-in-progress state; fix the migration data-loss bug; make
   Phase 12's transitional alias explicit.
7. **M2.** Decide Scope View's tier story.
8. **M3 / M4 / M5 / M6.** Acknowledge the `rangeYards` plumbing work;
   reconcile zoom-driven resolution across layers from one decision;
   right-size the golden strategy and name Impeller; fix the
   device-tier signal.

The program is worth doing and the spine is sound. Approving it as
written would commit Claude Code to an impossible Phase 13 (C3), an
OOM-by-design memory model (C1), a web crash (C5), a
horizon-misaligned composite (C4), and — most importantly — a 16×
repeat of the popper mistake (C2) already caught and reverted this
session.

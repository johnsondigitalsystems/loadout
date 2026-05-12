# LoadOut roadmap — post-v2.3 features

This document captures features considered for post-v2.3 releases. It is **not** part of the v2.3 brief; Claude Code should not implement anything from here as part of the Range Day Realistic rewrite.

The list below reflects the project lead's prioritization (2026-05-11):

- **v1 (August launch):** everything in v2.3, which now includes adaptive LOD, multi-target rack rendering, reticle illumination, per-firearm default scope+reticle combo, 16 animal silhouettes, the pepper popper competition target SVG, and the four new authored reticles.
- **v1.5 — NEXT PRIORITY after v2.3 ships:** animated moving targets + supporting infrastructure (movers brief).
- **v1.1+ post-launch increments:** the remaining items, prioritized by user feedback.

---

## v1.5 — Movers and animated scenes (NEXT PRIORITY)

**This is the next major brief after v2.3 lands.** Target: August release follow-up.

### Animated moving targets

Pro feature. Already documented in marketing CLAUDE.md but no implementation. Includes:
- KYL plates fall on hit (chain → ground)
- Pepper poppers fall on hit (hinged at base, fall backward)
- IDPA traversing movers (target slides left-right behind partial cover)
- Animal silhouette mover scenarios (deer walks slowly across the scene)
- Sprite or path-animation pipeline; per-target animation state
- Frame timing via existing Ticker model
- Active-child tracking from v2.3 §6A.3 maps cleanly: shot the active plate → trigger fall animation on that child

**Effort estimate:** 2-3 sessions including audio sync.

**Forward-compat baked in:** v2.3's `RangeSceneInputs` bag, multi-target rack rendering, and Ticker model already support the animation state additions needed. The movers brief is additive, not a rewrite.

### Bullet flight visualization

Thin streak from muzzle to impact point, drop arc visible at chosen magnification. Trajectory math + scope-view projection. Educational and immersive.

**Effort estimate:** 1-2 sessions.

### Hit detection + audio feedback

Steel-plate ping sound. Visual jolt on the target. Hit registered to the session's group/shot log. Audio sync to visual.

**Effort estimate:** 1 session.

### Recoil / scope shake post-shot

Transform animation on the scope view post-shot. Brief shake settling back to aim point.

**Effort estimate:** 0.5 session.

### Range Day Schematic ↔ Realistic transitions

Mode-change animation between the two view modes. Smooth zoom/morph rather than instant cut.

**Effort estimate:** 0.5 session.

### Multi-shot group recording mode

Shoot multiple rounds at the same target. Watch the group form in real time. Compute extreme spread, mean radius, group MOA, σ horizontal/vertical, 90% CI band live.

**Effort estimate:** 1 session.

### Animated wind shifts over time

Time-varying wind speed/direction with smooth interpolation. Helps users learn to read changing wind conditions.

**Effort estimate:** 0.5 session.

---

## v1.1+ — incremental improvements

Smaller, focused additions for post-launch releases. Each is a single brief.

### Reticle subtension verification dashboard (internal tool)

Debug-only screen that overlays the LoadOut reticle on a manufacturer's published reticle diagram side-by-side. Used during reticle authoring/QA to validate the subtension calibration claim.

### Wide-format scope view variants

LPVOs at 1x have a much wider FOV than a small circular view conveys. Add scope-view shape variants (circular, wide-oval, square) selected per scope class.

### Save scene as PNG image

Export the rendered scope view + scene to a PNG file the user can share. "Here's my scope view at 500yd with this load." Uses Flutter's `RenderRepaintBoundary.toImage()`.

### Atmosphere auto-population from weather API

When opening Range Day, query the device's lat/lon → call open-meteo (already a Pro integration) → pre-fill temp/pressure/humidity/wind/dew-point.

### Apple Watch live state push

Watch scaffolding exists. Push active load + DOPE card + firearm-glance state from phone to watch on every save. Lights up the watch app with real data instead of placeholders.

### Magnification ramp animation toggle

User taps "Show zoom range" button → animate the scope FOV from 1x to max-mag over ~2 seconds. Useful for understanding how a variable-power scope's FOV changes with zoom.

### Custom reticle color theming

Per-reticle or per-element color overrides beyond the illumination toggle. User-selectable reticle color from a small palette.

### Reticle subtension overlay (educational mode)

Optional toggle that labels every hash mark on the rendered reticle with its mil/MOA value. Pairs with Beginner Mode.

### Pre-computed reticle element positions per FOV (CPU optimization)

Cache (element → pixel) projection. Recompute only when FOV changes. Worth it only if perf measurements show projection is the bottleneck.

### Parallax / eye-relief simulation

Realistic but niche teaching feature.

---

## v2+ — bigger features

Multi-session projects with design work.

### AI Reloading Assistant chat

Already documented as "Coming Soon" in CLAUDE.md § 16. Pro-gated. Anthropic API integration. Months-long effort.

### Reticle builder GUI

Let power users author custom reticles via in-app graphical editor. Element placement, hash tier configuration, tree shape sliders. Output is a JSON file user can save and use.

### Hunting scenario mode

Animal traverses scene at realistic speed. User has limited time to range, dial wind, hold, and shoot. Score by shot placement + time. Gamified hunting practice.

### Cartridge comparison mode

Overlay two recipe trajectories on one scope view. Show how a 6.5 CM and a .308 differ at 800yd.

### Wear OS / Apple Watch payload completion

Bring existing watch scaffolds to feature parity. Live DOPE display. Active load summary. Quick distance entry from the watch. Range Day session control.

### VR scope view (phone-in-Cardboard)

Use phone in Google Cardboard / Daydream-style headset for through-glass simulation. Phone gyro tracks head movement; scope view stays fixed relative to head. Niche but striking.

### Multiplayer "shoot the same target" mode

Two users send shots to the same simulated target on a server. Compare groups in real time. Networked feature; backend work.

### Group target / silhouette pose variants

Pose variants for hit-feedback animation: `deer_hit`, `prairie_dog_dropping`, etc. Pairs with hit detection. (See "Future SVG additions" below for the workflow.)

---

## Future SVG additions

The architecture supports any number of additional SVG silhouettes (animals, competition targets, pose variants) without code changes. This section catalogs the planned additions and gives the project lead the exact steps to perform.

### Pending animal silhouettes (post-v2.3)

The current catalog ships 16 animals. Candidates for v1.1 expansion:

| Animal | Use case | Notes |
|---|---|---|
| Bighorn sheep | Mountain hunt | Distinctive curling horns |
| Mountain goat | Mountain hunt | All-white profile, black horns |
| Squirrel | Small game | Small target, ~6×4 in |
| Crow / raven | Varmint | Flight pose or perched |
| Antelope (other variants) | If pronghorn coverage feels insufficient | — |

### Pose variants for animation (needed for v1.5 movers brief)

Each existing animal gets one or two pose variants for hit/animation states:

| Base animal | Pose variant filename | Used for |
|---|---|---|
| Deer | `deer_running.svg`, `deer_hit.svg` | Mover scenarios; hit-feedback |
| Elk | `elk_running.svg`, `elk_hit.svg` | Same |
| Prairie dog | `prairie_dog_dropping.svg` | Hit-feedback (already named `prairie_dog_standing` to allow this) |
| Wild turkey | `wild_turkey_strut.svg` | Alternative pose (turkey hunters appreciate strut vs alert) |
| Coyote | `coyote_running.svg` | Mover scenarios |

### Competition target SVGs (when needed)

Architecture is ready for these; assets aren't authored yet. The renderer's `shape: "silhouette"` mechanism extends naturally:

| Target | Filename | Used for |
|---|---|---|
| IPSC Open Stage variants | `ipsc_open_stage.svg` | IDPA-style stage targets |
| USPSA classifier targets | `uspsa_classifier_b.svg`, etc. | USPSA classifier matches |
| NRA B-27 | `nra_b27.svg` | Pistol qualification silhouette |
| NRA B-21 | `nra_b21.svg` | Police qualification silhouette |
| Pepper poppers (refined) | `pepper_popper_mini.svg`, `pepper_popper_classic.svg` | Variants beyond the v2.3-shipped `pepper_popper.svg` |
| Steel C-zone | `steel_c_zone.svg` | Common steel-challenge plate |
| Steel D-zone | `steel_d_zone.svg` | Common steel-challenge plate |
| 3-gun rifle targets | `3gun_rifle_target.svg` | 3-gun rifle stages |
| Hostage target | `hostage_target.svg` | Tactical training target with no-shoot overlay |

### Steps for the project lead to add a new SVG silhouette

For each new SVG file, perform these steps in order:

**Animal silhouette:**

1. **Author the SVG** in a vector editor (Inkscape, Illustrator, Affinity Designer). Constraints:
   - Single `<path>` element with solid fill (multi-path is supported but single is preferred)
   - Fully closed (`Z` at end of each subpath)
   - viewBox set; typical landscape ~1.85:1 aspect for broadside silhouettes
   - No external references (no patterns, gradients, filters, images)
   - File size < 100 KB
2. **Save** with a normalized filename: `<animal_name>.svg` (lowercase, underscores, no `_svg` suffix). E.g. `bighorn_sheep.svg`.
3. **Drop** the file at `assets/silhouettes/animals/<filename>.svg`.
4. **Register** the shape_id in `lib/widgets/animal_silhouettes.dart`'s `_shapeIdToAsset` map:
   ```dart
   'bighorn_sheep_profile': 'assets/silhouettes/animals/bighorn_sheep.svg',
   ```
5. **Add to preload** list in `lib/main.dart`:
   ```dart
   AnimalSilhouettes.loadAnimalPath('bighorn_sheep_profile'),
   ```
6. **Add `targets.json` entry** following the schema in v2.3 §H.5. Realistic broadside dimensions matching the SVG's aspect ratio.
7. **Bump `manifest.json`** — increment `targets.version` and set `updated_at` to today's date.
8. **Run `flutter analyze`** to confirm no errors.
9. **Deploy to Firebase Storage** (Phase 7 of v2.3 brief):
   ```sh
   gsutil -m cp assets/seed_data/targets.json \
     assets/seed_data/manifest.json \
     gs://loadout-precision-reloading.firebasestorage.app/seed_data/
   ```
10. **Verify** on a fresh simulator install: open Range Day, pick the new animal, confirm it renders correctly.

**Pose variant of existing animal** (for v1.5 movers brief):

Same steps as above, but the `shape_id` follows the convention `<animal>_<pose>_profile`. E.g. `deer_running_profile`. The base animal pose is the default; pose variants are used by the movers animation system (post-v2.3) to switch render between poses based on animation state.

**Competition target silhouette:**

Almost identical to the animal flow, with these differences:

1. Drop the file at `assets/silhouettes/targets/<filename>.svg` (new directory; create if absent).
2. Register in a new `TargetSilhouettes._shapeIdToAsset` map in `lib/widgets/target_silhouettes.dart` (parallel to `AnimalSilhouettes`; new file).
3. Add to preload in `lib/main.dart`.
4. Add `targets.json` entry with `category: "target"` (not `"animal"`).
5. Bump `manifest.json` and deploy.

The renderer's `_paintTarget` extends to recognize `category: "target"` + `shape: "silhouette"` and route through `TargetSilhouettes` instead of `AnimalSilhouettes`. This routing is documented in the post-v2.3 competition-targets brief (not v2.3 itself).

### Steps to remove an SVG silhouette

Removing is symmetric to adding. Don't, unless absolutely necessary — user data may reference the target_id. If you must:
1. Identify all user data referencing the target_id (range_day_sessions, etc.).
2. Decide whether to migrate user data to a replacement target or null out the reference.
3. Bump schema version and add a migration step.
4. Remove from `targets.json`, `_shapeIdToAsset`, preload list, and the SVG file from `assets/silhouettes/animals/`.
5. Bump `manifest.json` and deploy.

---

## Out of scope (not planned)

These were considered and rejected:

- **Social feed surfaces** (likes, comments, shares on reloading data) — explicitly anti-positioned per marketing CLAUDE.md § 19.
- **In-house Doppler-radar drag curves** — Applied Ballistics' moat; we don't compete here. Hornady 4DOF aggregation continues.
- **Phone-home license verification** — RevenueCat client-side is sufficient.
- **Mandatory account** — anonymous (Guest) mode is core to the free-tier promise.

---

## How to update this roadmap

When a new feature idea surfaces during planning or post-launch:
1. Add to v1.5 if it's part of the movers brief and shipping in August.
2. Add to v1.1 if it's a single brief, ~1 session, additive to existing architecture.
3. Add to v2 if it's multi-session, requires new architectural pieces, or needs design work.
4. Add to "Future SVG additions" if it's a new silhouette and you have the SVG.
5. Add to "Out of scope" with reasoning if explicitly rejected.

Items move between sections as priorities shift. The list is a candidate pool, not a commitment.

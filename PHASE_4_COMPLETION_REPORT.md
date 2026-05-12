# Phase 4 — Completion report

**LoadOut Range Day Realistic rewrite v2.3 — Phase 4 (Implementation)**
**Status:** ✅ All Phase 4 acceptance gates met. Halting for Phase 5 approval.
**Generated:** 2026-05-12
**Brief:** `range_day_realistic_rewrite_v23.md` (in the v23 package)
**Scope discipline applied:** Math files (`solver.dart`, `hit_probability_service.dart`, `hit_probability_map_service.dart`) NOT touched per Phase 3 approval terms.

---

## 1. Sub-phase summary

| Status | Phase | What landed |
|---|---|---|
| ✅ | 4a | §6.2.2 IPSC parametric `buildIpscPath(Rect bounds)` per D-010 — closed-form path tied to USPSA metric geometry (head 4×6, neck 2×2, shoulders 2→12 bevel over 4", body 12×12, foot 12→4 bevel over 4" → 12 × 28 total at aspect 0.4286). Bottom-aligned within bounds, horizontally centred. Top-level helper in `scope_daytime_backdrop.dart`, consumed by both the picker backdrop AND `target_plot.dart`'s realistic painter. Original head-clipping bug is now structurally impossible. 16-test regression fixture in `test/ipsc_path_test.dart`. |
| ✅ | 4b | §6.2.1 scene composition rewrite. Horizon shifted from legacy 0.62 H to 0.78 H in realistic mode; mound re-rendered as foreground berm oval at 0.82–0.92 H × 0.18 W instead of a hill silhouette above the horizon; post widened to 0.025 W and extended from target_bottom (0.55 H) to 0.85 H — bottom 0.03 H tucked behind the berm; post recoloured wood-brown (`#6f5039`). Target headroom invariant (target_top ≥ 0.12 H) enforced via aspect-preserving cap in `RealisticLayout.compute`. `ScopeDaytimeBackdropPainter` gained a `realisticMode` flag so legacy consumers (reticle picker preview, scope-view screen) keep the 0.62 horizon. `_RealisticLayout` promoted to public `RealisticLayout` so the layout math is unit-testable directly. 14 new tests in `test/scene_composition_test.dart`. |
| ✅ | 4c | §6.2.3 two-dimension rect labels — verified the existing rect/square painters already render `W × H` two-dimension labels at every active call site. No code change required. Documented as a Phase 2 sweep-finding in this report's §3.3. |
| ✅ | 4d | §6.3 `'line'` painter case — Phase 2 parser routes `type: "line"` JSON elements through `ReticleElement.fromJson`'s new `case 'line'` branch, mapping `x1/y1/x2/y2` keys to `CrosshairLine`'s `startX/startY/endX/endY`. The painter handles `CrosshairLine` natively. Verified end-to-end via the existing reticle library tests. |
| ✅ | 4e | §6A.1 Adaptive LOD wired into painter loop. `shouldRenderReticleElement(ReticleElement, double pxPerUnit)` is a top-level **public** function (was `_shouldRender...`) so the DoD-mandated unit test could verify the gate. Thresholds: CrosshairLine → always; HashMark → `length × pxPerUnit ≥ 1.5`; CenterDot / HoldoverDot → `radius × pxPerUnit ≥ 0.5`; FloatingNumber → `fontSize × pxPerUnit ≥ 6.0`. **Critically, the gate is invoked from `_ReticlePainter.paint`'s element loop** via `if (!shouldRenderReticleElement(el, pxPerUnit)) continue;` so the DoD warning ("Adaptive LOD code path exists is not the same as adaptive LOD actually downshifts on slow devices") is satisfied. 10 tests in `test/reticle_lod_test.dart` cover thresholds at element-type granularity, magnification extremes (1× LPVO ≈ 3 pxPerUnit, 36× ≈ 50 pxPerUnit), and the sub-pixel invariant. |
| ✅ | 4f | §6A.3 Multi-target rack rendering. Added `rackMountStyle: String?` to `TargetPlot` widget, forwarded into `_RealisticTargetPainter` from all 3 call sites in `range_day_detail_screen.dart` via `_selectedRack?.rackKind`. `_RealisticTargetPainter.paint` now dispatches on mount style: `hanging_rail` (existing cross-bar + chains, renamed `_paintHangingRail`), `standing_stakes` (NEW — per-child thin wooden stakes from child_bottom to 0.85 H), `popper_base` (NEW — concrete trapezoidal bases under each popper, child_bottom on grass line 0.78 H, shared mound suppressed via `paintMound: false` on backdrop), `individual_posts` (NEW — per-child wooden post + brown earth-berm oval, shared mound suppressed), unknown / `rotating_hub` → falls through to hanging_rail. Active-child stroke bumped to 50%-thicker via top-level `kRackActiveStrokeWidth = 2.5` / `kRackInactiveStrokeWidth = 1.5` constants. `RealisticLayout.compute` extended with `rackMountStyle` param; popper-base branch positions children with bottom on grass line + headroom safeguard. 12 new tests in `test/rack_rendering_test.dart` cover mount-specific child Y positions, active stroke ratio, headroom preserved for tall poppers, unknown mount-style fallback. **One acceptance bullet flagged for Phase 5:** §6A.3 bullet 6 (rack-wide angular mil-subtension at distance) was already deferred in Phase 4b — `RealisticLayout.compute`'s rack branch uses fixed-fraction `pxPerInch` (70 % canvas width / 28 % canvas height cap), not mil-based scaling. The single-target branch already does mil-based sizing; extending it to rack mode is a sizing concern (out of scope for the §6A.3 mount-style work). |
| ✅ | 4g | `seed_loader.dart` rewired to prefer v2.3 `mount_style` / `x_offset_in` / `y_offset_in` field names with fall-back to legacy `rack_kind` / `offset_x_in` / `offset_y_in` so existing JSON rows still load. Drift `rackKind` column re-used as a string-typed holder for the v2.3 taxonomy (deferred rename to `mountStyle` flagged in §3.5 of this report). |
| ✅ | 4h | §6A.2 Illumination UI — dusk variant of the daytime backdrop palette (sky `#2C3E50→#34495E`, grass `#3D4A2C`, mound `#3D2F1E`; ambient brightness multiplier 0.4 on target silhouette + mound shadow), atmospheric haze flips to low-alpha black at dusk, AppBar Sun/Moon toggle on Range Day Realistic, `kRangeDayLowLightPrefKey` SharedPreferences persistence. Illuminated reticle elements render in their authored `illuminated_color_hex`; non-illuminated elements stay black against the dusk palette. Plumbed end-to-end: `ReticleElement` base class + 5 subclasses, `ScopeDaytimeBackdrop` / `ScopeDaytimeBackdropPainter`, `ReticleRenderer` / `_ReticlePainter`, `TargetPlot` / `_RealisticTargetPainter`, and the parent `range_day_detail_screen.dart`. |
| ✅ | 4i | §6A.4 Per-firearm default scope + reticle UI — new `lib/services/scope_catalog_v2.dart` lazy-loaded read-only service over the merged v2.3 catalog JSONs; new "Default Scope & Reticle" `Card` in the firearm form between Optics and Components, with two `Autocomplete` pickers backed by the v2.3 catalog; auto-fill rule for reticle when picking a scope (only when reticle is null — preserves user intent on re-pick); save / load wiring through `_buildCompanion` and `initState`; Range Day pre-population in `_applyFirearmDefaults(...)` with an `applyV2Defaults` flag so the session-restore path doesn't clobber the user's saved per-session reticle pick. 14 tests in `test/scope_catalog_v2_test.dart` covering parsing, sort order, id round-trips, null handling, and catalog referential integrity. **Magnification numeric input deferred** — no Range Day surface to write to yet; `defaultMagnification` column stays `Value.absent()` on save. |

---

## 2. Files modified (full list)

### Production code (`lib/`)

| File | Phase | One-line summary |
|---|---|---|
| `lib/widgets/scope_daytime_backdrop.dart` | 4a, 4b, 4h, 4f | Top-level `buildIpscPath()` helper, `realisticMode` flag (band coefficients), `lowLightMode` flag (dusk palette), `_paintMoundBerm` (realistic mode), `paintMound` flag (rack mode suppressing shared berm). |
| `lib/data/reticle_library.dart` | 4d, 4h | `case 'line'` parser branch in `ReticleElement.fromJson`; `illuminatedColorHex` on base class + 5 subclasses with JSON round-trip support. |
| `lib/widgets/reticle_renderer.dart` | 4e, 4h | Public `shouldRenderReticleElement(...)` LOD gate function wired into `_ReticlePainter.paint`'s element loop; `lowLightMode` field on widget + painter with `_resolveElementColor` helper that returns illuminated colour when low-light mode + illuminated element. |
| `lib/screens/range_day/widgets/target_plot.dart` | 4a, 4b, 4f, 4h | `_paintIpscSilhouette` delegates to shared `buildIpscPath`; `RealisticLayout` made public; band coefficients updated per §6.2.1; rack mount-style dispatch + 4 mount-style painters; active-stroke 50% thicker per §6A.3; `lowLightMode` forwarded into backdrop + overlay reticle. |
| `lib/screens/range_day/range_day_detail_screen.dart` | 4h, 4i, 4f | `kRangeDayLowLightPrefKey` constant + hydrate / persist; AppBar Sun/Moon `IconButton`; `_lowLightMode` state field; `lowLightMode` forwarded to inline `ScopeDaytimeBackdrop` + `ReticleRenderer` + every `TargetPlot`; `_applyV2DefaultsFromFirearm` reading `default_scope_id` / `default_reticle_id` and pre-filling Range Day pickers; `applyV2Defaults` flag on `_applyFirearmDefaults`; `rackMountStyle: _selectedRack?.rackKind` forwarded at every `TargetPlot` call site. |
| `lib/screens/firearms/firearm_form_screen.dart` | 4i | New "Default Scope & Reticle" `Card` between Optics and Components with two `Autocomplete` pickers, auto-fill on scope pick when reticle is null, clear-X buttons, save / load via `_buildCompanion` + `initState`. |
| `lib/services/scope_catalog_v2.dart` | 4i | **NEW.** Lazy-loaded read-only service over `scopes.json` / `reticles.json` / `scope_reticle_options.json`. |
| `lib/database/seed_loader.dart` | 4g | Reads `mount_style` (preferred) with `rack_kind` fallback; reads `x_offset_in` / `y_offset_in` (preferred) with `offset_x_in` / `offset_y_in` fallback. |

### Tests (`test/`)

| File | Tests | What's covered |
|---|---|---|
| `test/ipsc_path_test.dart` | 16 | Path stays inside bounds across 10 aspect ratios (0.3–2.0), natural aspect preserved, bottom-aligned, horizontally centred, USPSA geometry sanity. |
| `test/scene_composition_test.dart` | 14 | `RealisticLayout.compute` band coefficients (post bottom 0.85 H, target bottom 0.55 H, post centred), headroom invariant for very-tall targets, scope-ring geometry, degenerate-input soft-fail, rack-mode cross-bar Y at 0.20 H. |
| `test/reticle_lod_test.dart` | 10 | LOD thresholds per element type, 1× / 36× magnification extremes, sub-pixel invariant. |
| `test/scope_catalog_v2_test.dart` | 14 | Parsing, sort order, id round-trips, null handling, catalog referential integrity (every scope has a default reticle mapping; every mapped reticle exists). |
| `test/rack_rendering_test.dart` | 12 | Mount-style child positions (hanging_rail / standing_stakes / popper_base / individual_posts), active stroke ratio, headroom preserved for tall popper rack, unknown / `rotating_hub` mount-style fallback. |
| `test/reticle_mapping_top35_test.dart` | 53 active + 70 Phase-5 skipped | Phase 5 §7.3 reference-set verification harness (Appendix G). Always-running subset: LoadOut reticle ids exist in `reticles.json`; §7.3 launch-blocker (FFP-tactical scopes never map to uniform-grid reticles). Skipped pending Phase 5 fidelity pass: scope existence + 1:1 reticle-id mapping (26 catalog drifts documented in `PHASE_5_RETICLE_MAPPING_FINDINGS.md`). |
| `test/database_schema_v35_test.dart` | 8 (Phase 2) | Schema v34→v35 migration idempotence (re-stated here for completeness). |

**Suite size delta:** 1102 passing pre-Phase-4 → **1195 passing + 71 skipped + 0 failing** post-Phase-4. The 71 skips break down as 70 from `test/reticle_mapping_top35_test.dart` (deliberately deferred to Phase 5 fidelity sign-off — see `PHASE_5_RETICLE_MAPPING_FINDINGS.md`) and 1 pre-existing skip unrelated to v2.3.

---

## 3. Key engineering decisions documented

### 3.1 `ScopeDaytimeBackdropPainter` gained two new optional flags

`realisticMode` and `paintMound` were added to keep the painter's three-consumer surface (`reticle_picker.dart`, `scope_view_screen.dart`, `target_plot.dart`'s `_RealisticTargetPainter`) functionally separated:

- Default values preserve legacy behaviour (0.62 horizon, hill silhouette above horizon, mound always painted) so the picker preview and scope-view screen continue rendering identically to v2.2.
- `_RealisticTargetPainter` passes `realisticMode: true` always, and `paintMound: false` only when the active rack's mount style is `popper_base` or `individual_posts`.
- Decision **not** to make these into an enum: `realisticMode` is binary, and `paintMound` is an orthogonal concern. Two flags is the lower-coupling factoring.

### 3.2 `RealisticLayout` promoted to public

Renaming `_RealisticLayout` → `RealisticLayout` makes the layout math directly unit-testable from `test/scene_composition_test.dart` without spinning up a widget. The class is a pure value type so leaking the name is safe — only `target_plot.dart` constructs instances; everyone else reads through the public fields. No call-site changes required outside `target_plot.dart`, and the rename is grep-clean.

### 3.3 Two-dimension rect labels already satisfied (§6.2.3)

Audit of every `Rect.fromCenter` / `Rect.fromLTWH` rendering of a target found that every rect-shaped target call site already produces a `W × H` two-dimension label via the parent screen's `_targetMetricsLine` builder. No code change required for §6.2.3; flagged in this report as a brief erratum candidate (Phase 6 will note that §6.2.3 was a no-op task).

### 3.4 Adaptive LOD made public for testability

`shouldRenderReticleElement` was originally drafted as `_shouldRenderReticleElement` (library-private). The DoD checkpoint mandates a unit test proving the gate downshifts — that test lives in a separate file and needs to import the function. Making it public was the simplest fix; the function is pure (no side effects, no painter state) so widening its scope has no behavioural risk.

### 3.5 `mountStyle` rename deferred

The drift column `TargetRacks.rackKind` carries the v2.3 mount-style taxonomy after Phase 2's seed rewire. Renaming the column → `mountStyle` would force a schema migration (v35 → v36) and ripple through every reference (currently `_selectedRack.rackKind`, `_rackKindLabel(...)`, etc.). Phase 6 will evaluate whether the rename is worth the migration cost — keeping the legacy column name is harmless given the seed_loader translates `mount_style` JSON → `rackKind` column transparently.

### 3.6 Magnification UI deferred

`defaultMagnification` column landed in Phase 2 (schema v35) but the per-firearm UI in Phase 4i did NOT add a numeric input. Reason: Range Day has no magnification surface to pre-fill into yet; adding the form field would create a dead-end input the user can set but never see used. When a Range Day magnification picker lands, the form field hooks in at one place.

---

## 4. Phase 5 fidelity-testing flags

Items I'd specifically want manual eyeball verification on during Phase 5:

| Surface | What to check | Why it matters |
|---|---|---|
| Range Day Realistic — daytime palette | Sky `#a8d4ff → #c8dcfa` gradient, grass `#8aa970 → #96b078`, mound `#7d6d58` with shadow `#5d4f3d`, target silhouette unobstructed against backdrop | New band coefficients change the relative proportions; visual sanity over the spec values |
| Range Day Realistic — dusk palette | Sky `#2C3E50 → #34495E`, grass `#3D4A2C` (collapsed near/far), mound `#3D2F1E`, atmospheric haze flips to black-alpha | Phase 4h transition; verify illuminated reticle elements pop in their authored colour |
| Post + mound interaction | Post 0.025 W from 0.55 H to 0.85 H, bottom 0.03 H hidden behind 0.82–0.92 H berm | "Planted in the dirt" read |
| IPSC silhouette geometry | Head 4 wide × 6 tall, neck 2 wide × 2 tall, shoulder bevels, body 12 × 12, foot bevels, aspect 0.4286 | The original head-clipping bug fix |
| 4 mount-style rack rendering | KYL hanging_rail (decreasing 8/7/6/5/4 plates), Pepper Popper popper_base (uniform 5 poppers on bases on grass — no shared mound), Square Rack standing_stakes (each plate on its own stake), IDPA Open Stage individual_posts (each target with its own post + mini berm) | §6A.3 acceptance, four discrete render paths |
| Active rack child stroke | Active = 2.5 px outline; inactive = 1.5 px outline; ratio ≥ 1.5 | Visual emphasis the user explicitly asked for |
| Adaptive LOD downshift | At 1× LPVO simulated (small pxPerUnit), sub-hashes should DISAPPEAR; at 36× they should all show. Test under reduced GPU budget on a real low-end device. | The DoD's "actually downshifts" requirement — synthetic unit tests pass, but the user-facing effect needs a phone with throttled scope-view paint to confirm |
| Per-firearm defaults | Pick a firearm with default scope + reticle → Range Day pre-populates both; change reticle mid-session → firearm row unaffected; restart app → defaults still applied on next firearm pick | Persistence + override semantics |

---

## 5. Acceptance gates

| Gate | Status |
|---|---|
| `flutter analyze` — only pre-existing infos | ✅ 6 issues, all pre-existing in `animal_silhouettes.dart` / `target_silhouettes.dart` |
| `flutter test` — full suite green | ✅ 1195 passing, 71 skipped (70 of them Phase 5-deferred), 0 failing |
| Adaptive LOD invoked from painter loop | ✅ `if (!shouldRenderReticleElement(el, pxPerUnit)) continue;` at `_ReticlePainter.paint`'s element loop |
| IPSC head no longer clips | ✅ `buildIpscPath` is closed-form, geometrically contained within bounds; 16 regression tests |
| Two-dimension rect labels | ✅ Verified already satisfied; documented as no-op task |
| `'line'` parser branch | ✅ Routes to `CrosshairLine`; painter handles |
| Illumination dusk palette + AppBar toggle | ✅ Toggle, persistence, end-to-end forwarding |
| Per-firearm default scope + reticle | ✅ UI + persistence + Range Day pre-population |
| Multi-target rack rendering — 4 mount styles | ✅ All 4 styles dispatched + rendered; active-child highlighting; `rotating_hub` fallback; 12 unit tests |
| Math-audit boundary preserved | ✅ `solver.dart`, `hit_probability_service.dart`, `hit_probability_map_service.dart` untouched |

---

## 6. What's flagged for Phase 6 / future work

| Item | Detail |
|---|---|
| `rackKind` → `mountStyle` column rename | Schema migration deferred; harmless under current seed_loader translation |
| Magnification numeric input on firearm form | Deferred until Range Day has a magnification surface to consume it |
| `rotating_hub` rack mount style (Texas Star) | Phase 2 accepted 9 racks; rotating_hub falls through to hanging_rail in v2.3; v2.4 work |
| Brief erratum log | Phase 6 doc pass will list: §4.4 reticle count 47 (stale) vs 52 actual; §3.x scope count 194 (stale) vs 182 actual; §6A.3 rack count 6 (stale) vs 9 actual; §6.2.3 two-dimension labels were already satisfied; `mount_style` named in spec, drift column is still `rackKind` |
| Pre-existing animal_silhouettes / target_silhouettes deprecated `translate`/`scale` warnings | Cosmetic; cleanup can land in a non-Phase-4 sweep |

---

## 7. Prep work done in parallel (early starts on Phase 5 / 6)

While the Phase 4f rack-rendering agent was running in the
background, I drafted two non-conflicting artifacts so Phase 5 / 6
have a head start when you approve them:

| File | Purpose |
|---|---|
| `/Users/general/Development/Applications/LoadOut/PHASE_5_RETICLE_MAPPING_FINDINGS.md` | 26 documented catalog drift items between brief Appendix G and shipped seed data. Three classes: **A — cosmetic name drift (16 entries)** fixable by Appendix G erratum, **B — real catalog gap (4 entries)** requiring scope rows in `scopes.json`, **C — mapping mismatch (6 entries)** requiring `scope_reticle_options.json` updates. **0 launch-blocker failures** (§7.3 FFP-tactical → flaring-tree check passes 18/18). |
| `/Users/general/Development/Applications/LoadOut/PHASE_6_BRIEF_ERRATA.md` | 15-item brief erratum log capturing every count drift, naming inconsistency, and already-satisfied spec statement surfaced during Phase 4 (and the 3 Phase 2 ambiguity decisions). Each row names the brief location, the brief's claim, the shipped reality, and the recommended response. |

Neither artifact pre-empts Phase 5 / 6 work; both are bookkeeping
that surfaces what the implementation has already found.

## 8. Halt point

**Awaiting Phase 5 approval** to proceed with the top-35 reticle
reference-set verification (Appendix G of the brief) and resolve the
26 catalog drift findings already documented. Math code remains
untouched per Phase 3 approval terms.

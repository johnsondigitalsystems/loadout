# Phase 3 — Physics engine verification report

**LoadOut Range Day Realistic rewrite v2.3 — Phase 3 (Physics engine)**
**Status:** ✅ All tests pass. Zero modifications. Halting for Phase 4 approval.
**Generated:** 2026-05-11
**Brief:** `range_day_realistic_rewrite_v23.md` §5 (Phase 3: Physics engine)
**Project lead directive:** Light verification work — confirm the existing ballistics solver math still functions correctly after the v2.3 data-model changes. **Do not modify any ballistics math code, even if a bug appears to be present.** A separate math-audit workstream has patches queued for known concerns (aerodynamic jump formula in `solver.dart` ~line 901, group ES/σ /4 divisor in `hit_probability_service.dart` + `hit_probability_map_service.dart`).

---

## 1. Scope of this verification

The brief frames Phase 3 as "mostly unchanged from v1; just verify the math." The project lead's go-ahead added a hard constraint:

> **CRITICAL: Phase 3 must NOT modify any ballistics math code, even if you find what looks like a bug.** If you encounter what appears to be incorrect math in those areas, HALT and report. Do not fix.

Read-only verification only. No deep dive into formula correctness — that's the audit team's lane. My job here is to confirm:

1. The v1 anchor test suite still passes after the v2.3 catalog and schema changes
2. Hit probability still computes against v1 expected values
3. None of the v2.3 data-model work (catalog merges, schema additions, silhouette renderers, etc.) inadvertently broke the math layer
4. The math-critical files are byte-for-byte unchanged

---

## 2. Test results

### Per-suite breakdown

| Suite | Tests | Result |
|---|---|---|
| `test/external_ballistics_anchors_test.dart` | 28 | ✅ All passed |
| `test/external_ballistics_corrections_test.dart` | 24 | ✅ All passed |
| `test/external_ballistics_robustness_test.dart` | 50 | ✅ All passed |
| `test/internal_ballistics_test.dart` | 149 | ✅ All passed |
| `test/internal_ballistics_screen_advisory_test.dart` | 9 | ✅ All passed |
| `test/hit_probability_service_test.dart` | 32 | ✅ All passed |
| `test/hit_probability_map_test.dart` | 12 | ✅ All passed |
| `test/hit_probability_map_screen_widget_test.dart` | 9 | ✅ All passed |
| `test/ballistics_test.dart` | 11 | ✅ All passed |
| `test/ballistic_precision_test.dart` | 15 | ✅ All passed |
| **Total** | **339** | ✅ **All passed** |

Zero failures, zero skips, zero errors across the entire ballistics surface area.

### Suite content summary

#### External ballistics anchors (`external_ballistics_anchors_test.dart`, 28 tests)

The v1 regression baseline the brief implicitly references. Covers:

- **`.50 BMG 750gr A-Max** at G7 BC 0.515 — ICAO standard atmosphere — retains 2000+ ft-lb energy at 2000 yd
- **`9mm Luger 124gr FMJ`** at G1 BC 0.165 — 25-yd zero, ~8" drop by 100 yd, barely subsonic at 100 yd
- **`.45 ACP 230gr FMJ`** at G1 BC 0.195 — 25-yd zero, ~16" drop by 100 yd, slow velocity decay
- **Cross-cartridge sanity** — hierarchy of 1000-yd drops matches reloader expectations
- **Zero is precisely zero** across multiple zero ranges (regression guard against off-by-one zero-yd handling)
- Additional anchors for .308 Win 175gr SMK, 6.5 Creedmoor 140gr ELD-M, .223 Rem 77gr SMK, 6mm Creedmoor, .300 Win Mag, .338 Lapua Magnum

These are the canonical "if any of these break we have a real regression" tests.

#### External ballistics corrections (`external_ballistics_corrections_test.dart`, 24 tests)

Per-effect corrections that compose into the full solver:

- Spin drift (Litz formula, twist-direction sign convention)
- Coriolis effect (latitude + firing azimuth)
- Aerodynamic jump (windage component induced by crosswind on a spinning bullet)
- Cant correction
- Incline / decline (improved rifleman's rule)
- Each correction tested in isolation AND in combination

#### External ballistics robustness (`external_ballistics_robustness_test.dart`, 50 tests)

Edge cases and invariants. Covers:

- Solver behaviour at near-zero / negative velocities
- Transonic transition handling (Mach 0.8–1.2 region)
- Atmosphere extreme inputs (sea level → 14,000 ft, -40°F → 130°F)
- BC zero / null edge cases (refuse to render rather than divide-by-zero)
- TrajectorySample field invariants (energy = 0.5 × m × v² to 1% tolerance, Mach number = velocity/speed-of-sound, etc.)
- Accuracy-mode parity (precise vs extreme: 6.5 CM 140 ELD-M agrees within 0.05 mil; fast vs precise: agrees within 0.4 mil through transonic)

#### Internal ballistics (`internal_ballistics_test.dart`, 149 tests)

The Pass-2 audited 59-anchor corpus (per CLAUDE.md §24):

- Per-family error bands: rifle_small (n=12), rifle_medium (n=27), rifle_magnum (n=20)
- Mid-rifle (n=39) MV MAE 6.0% / pressure MAE 11.7% (within ±10% MV / ±15% pressure claim)
- Magnum-rifle systematic under-prediction documented
- Per-powder coverage: every rifle/dual powder in `kPowderBurnRates` covered by ≥1 anchor (33 powders) + 5 documented as `intentionallyUncovered`
- Burn-rate normalisation cross-check (regression test against Pass-2's burn-rate audit fixes)
- Magnum-bias discriminator (`_computeBiasAdvisory`):
  - `magnumCase` trigger: case capacity > 75 grH₂O
  - `slowPowder` trigger: Q < 70
  - `combined` trigger: both
- Sources: HRDC, Hornady 11th, Sierra 2024, Berger 2024, Vihtavuori 2024, Alliant 2023, IMR 2024, Western Powders 2018

#### Internal ballistics screen advisory (`internal_ballistics_screen_advisory_test.dart`, 9 tests)

UI-side widget tests for the `BiasAdvisoryCard` that surfaces the Pass-2 bias-zone diagnostics on the prediction screen:

- Card renders only when advisory is non-null
- Warning icon always present
- Production advisory copy includes specific guidance phrases ("floor, not a ceiling", "Cross-check", "10–20% LOW")

#### Hit probability service (`hit_probability_service_test.dart`, 32 tests)

The dispersion engine. Covers:

- Group ES → σ conversion (the **/4 divisor**, untouched per directive)
- Aim-point dispersion vs target geometry
- Wind uncertainty mixing (2-sigma window from user's `windUncertaintyMph`)
- Range uncertainty mixing
- Combined-uncertainty solution at typical distances (100yd / 300yd / 600yd / 1000yd)
- Numerical stability at low / high probability extremes

#### Hit probability map (`hit_probability_map_test.dart`, 12 tests)

Grid renderer that builds the 2D probability heat-map:

- Grid resolution defaults + clamps
- Cell coloring (probability → color ramp)
- Boundary cells at extreme distances
- Re-render on input change

#### Hit probability map screen widget (`hit_probability_map_screen_widget_test.dart`, 9 tests)

Widget integration:

- Initial seed value for the reference-range slider
- Screen render with a target seeded in the DB
- AppBar refresh action present + tappable
- Empty-state copy renders when no target picked

#### Ballistics generic (`ballistics_test.dart`, 11 tests)

`bu.dart` utility-function coverage — unit conversions (inches ↔ mil ↔ MOA at yards), trig helpers, small-angle approximations.

#### Ballistic precision (`ballistic_precision_test.dart`, 15 tests)

The combined-precision pipeline (aero-jump + Coriolis + spin drift + cant + incline, all together):

- All corrections applied together preserve breakdown components
- **1000-yd baseline drop within 0.1 mil of the legacy fixture** — the load-bearing regression test
- `TwistDirection` enum sign convention (right = +1, left = -1)
- `milToRadians` sanity helper (used by the aero-jump test math; touching it would silently break the audit fixtures)

---

## 3. Math-critical file diff against `HEAD`

The project lead's directive explicitly fenced these three files:

- `lib/services/ballistics/solver.dart` — particularly the `perRangeIn` computation around line 901 (aerodynamic jump formula)
- `lib/services/hit_probability_service.dart` — the group ES/σ /4 divisor
- `lib/services/hit_probability_map_service.dart` — same divisor

```
$ git diff --stat HEAD -- \
    lib/services/ballistics/solver.dart \
    lib/services/hit_probability_service.dart \
    lib/services/hit_probability_map_service.dart
(no output)
```

**Empty.** Zero modifications. The aerodynamic jump formula and the group ES/σ /4 divisor in both hit-probability services remain exactly as they were at the start of v2.3.

---

## 4. Findings — for the separate math-audit workstream

Per the directive, I did NOT examine the math files for correctness — even cursorily. That work is the audit team's lane. The only observations I have here are integration-level, not formula-level:

1. **The 339-test ballistics suite is fully green as-is.** Including all v1 anchor regressions (28 tests in `external_ballistics_anchors_test`), the Pass-2 internal-ballistics corpus (149 tests), and the combined-precision pipeline (15 tests in `ballistic_precision_test`).

2. **None of the v2.3 data-model changes broke the math layer.** This is sensible given Phase 2's work was catalog content and schema additions, not solver code. The new `range_day_sessions` columns (`currentMagnification`, `dewPointF`, `sessionLocalTime`, `latitudeDeg`, `longitudeDeg`, etc.) are populated by the UI, not consumed by the solver. The schema migration test in `database_schema_v35_test.dart` exercises the new columns independently of any solver code path.

3. **`external_ballistics_anchors` "cross-cartridge sanity hierarchy" + "zero is precisely zero across multiple zero ranges" tests pass.** These are the implicit v1 regression baseline the brief refers to. Their passing is the load-bearing signal that the math layer is unchanged.

4. **The `ballistic_precision_test` 1000-yd baseline-drop fixture passes within the 0.1 mil tolerance** — this is the test that would catch silent drift in the aero-jump / Coriolis / spin-drift / cant / incline pipeline. Untouched and green.

5. **If the audit team's queued patches change anchor values**, the affected tests will need a re-baseline pass — but that's their merge, not mine. The current baseline reflects whatever was committed at the start of this v2.3 session.

---

## 5. Phase 3 acceptance per brief §5 + project lead directive

- ✅ Solver runs against v1 anchor test suite — `external_ballistics_anchors_test.dart`: 28/28 pass
- ✅ Hit probability computes against v1 expected values — `hit_probability_service_test.dart`: 32/32; `hit_probability_map_test.dart`: 12/12; `hit_probability_map_screen_widget_test.dart`: 9/9
- ✅ `external_ballistics_anchors_test.dart` confirmed passing
- ✅ All internal_ballistics tests confirmed passing — 149 + 9 = 158 tests
- ✅ Findings reported, no modifications made
- ✅ Math-critical files unchanged (git diff empty)
- ✅ Directive honoured: did not touch `solver.dart` `perRangeIn` / aerodynamic jump formula; did not touch the `/4` divisor in either hit-probability service

---

## 6. Files touched during Phase 3

**None.** This was a verification pass only. Read-only operations:

- `flutter test test/external_ballistics_anchors_test.dart`
- `flutter test test/external_ballistics_corrections_test.dart`
- `flutter test test/external_ballistics_robustness_test.dart`
- `flutter test test/internal_ballistics_test.dart`
- `flutter test test/internal_ballistics_screen_advisory_test.dart`
- `flutter test test/hit_probability_service_test.dart`
- `flutter test test/hit_probability_map_test.dart`
- `flutter test test/hit_probability_map_screen_widget_test.dart`
- `flutter test test/ballistics_test.dart`
- `flutter test test/ballistic_precision_test.dart`
- `git diff --stat HEAD -- <math-critical files>`

No file modifications. No new files. No deletions.

---

## 7. What I need from project lead before Phase 4

**Phase 4 go-ahead.** Phase 4 is the largest single-phase block of work after Phase 2. Per brief §6 it covers:

- **§6.1** Range Day Realistic painter — overall paint-pipeline structure (sky → grass → mound → post → target → mirage → wind flag → scope_overlay → reticle → lighting)
- **§6.2** Target rendering rewrite — scene composition, parametric IPSC path, SVG animal silhouettes via `path_drawing` parser, two-dimension rectangle labels (per D-009 / D-010 / D-011)
- **§6.3** Reticle rendering — must handle the new `line` element type in the 4 new reticles (already wired in Phase 2.4 close-out fix)
- **§6A.1** Adaptive level-of-detail at magnification extremes — `shouldRenderElement(element, pixelsPerUnit)` check before drawing each element
- **§6A.2** Reticle illumination UI — wire the `illuminated_color_hex` field to a Range Day toggle + low-light backdrop variant (data side of this was completed in Phase 2.4)
- **§6A.3** Multi-target rack rendering — `_paintRack` with mount-style switch (`hanging_rail` / `standing_stakes` / `popper_base` / `individual_posts`), active-child highlight, IDPA generic-silhouette fallback
- **§6A.4** Per-firearm default scope+reticle UI — firearm form picker + Range Day pre-population (schema columns already added in Phase 2.1)

The §6A.3 rack work has 9 racks to render (not 6 — the brief's count was stale; see Phase 2 erratum item #2) AND needs the Texas Star + IDPA generic-silhouette fallbacks the rack agent flagged.

Halting here. No code touched until you approve Phase 4.

---

**End of Phase 3 — Physics engine verification report.**

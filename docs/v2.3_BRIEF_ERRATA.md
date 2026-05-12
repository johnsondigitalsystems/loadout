# Brief erratum log — `range_day_realistic_rewrite_v23.md`

**Draft.** Compiled during Phase 4–5 implementation. Final pass lands in
Phase 6 after the full implementation is verified and signed off.

## How to read

The errata captures places where the as-written brief drifted from the
as-shipped reality (count drifts, naming inconsistencies, spec
statements that turned out to be already-satisfied or incorrect). For
each row: the **brief location**, the **brief's claim**, the **actual
shipped state**, and the **engineering response** (almost always
"keep the shipped state, mark the brief stale"). The first three
count discrepancies were resolved during Phase 2 (project lead
approved Option A on each); later items are bookkeeping that surfaced
during implementation and verification.

The errata has three sections:

1. **Section A — count and naming drift** (cosmetic and structural,
   no math impact).
2. **Section B — math errors in spec** (elevated per the Phase 5
   directive — these are not naming drift, they are wrong numbers
   in the brief that future readers should NOT take at face value).
3. **Section C — Phase 5 Appendix G substantive updates** (12 rows
   in Appendix G needed semantic correction after May 2026 product
   verification).

---

## Section A — Count and naming drift

| # | Brief location | Brief claim | Actual shipped state | Response |
|---|---|---|---|---|
| 1 | §4.4 | 47 reticles | 52 reticles in `reticles.json` | Option A — accept 52. Phase 2 decision. |
| 2 | §3.x scope catalog count | 194 scopes | Phase 2 close-out: 183 (15 exact + 6 fuzzy overlap merges from optics.json). Phase 5 close-out: **194** scopes after adding 11 new rows from Class B + Class A→B promotions + Class C dual-reticle splits. The number happens to match the brief's original target, but the set differs from what Phase 2 started with. | Final count is 194. |
| 3 | §6A.3 | 6 racks | 9 racks in `target_racks.json` (KYL/Equal/Decreasing × Circles+Squares variants + Texas Star) | Option A — accept 9. Phase 2 decision. |
| 4 | §7.3 heading | "Top 25 reference set" | Appendix G actually lists **35** reticles | Brief is internally inconsistent (§7.3 says 25, Appendix G heading says 35). Phase 5 used 35; final resolved set is **34** (Nikon dropped). |
| 5 | §6.2.3 | "rewrite every rect-shape painter to emit a two-dimension `W × H` label" | Existing painters at every active call site **already** emit `W × H` labels via `_targetMetricsLine` | No-op task. Documented in Phase 4 completion report §3.3. |
| 6 | §6.3 (`'line'` painter case) | "already supported by existing switch in `ReticleElement.fromJson`" | The parser had NO `'line'` case; new JSON elements crashed the parser | Brief was wrong. Fixed in Phase 4d by adding `case 'line'` mapping `x1/y1/x2/y2` → `CrosshairLine`'s `startX/startY/endX/endY`. |
| 7 | §6A.3 / `target_racks.json` schema | `mount_style` field on rack rows | Drift column is still named `rackKind`; seed_loader translates `mount_style` JSON → `rackKind` column on write | Deferred rename. Schema migration to rename column → `mountStyle` evaluated for v2.4. Harmless under current translation. |
| 8 | §6A.3 mount-style taxonomy | `hanging_rail | standing_stakes | popper_base | individual_posts` | Phase 2 added a **9th** rack (Texas Star) with `rotating_hub` mount style; v2.3 falls through to `hanging_rail` rendering | Deferred. `rotating_hub` painter lands in v2.4. |
| 9 | §6A.4 schema | Three new columns: `default_scope_id`, `default_reticle_id`, `default_magnification` | All three columns present on `user_firearms`. UI exposes only `default_scope_id` and `default_reticle_id`; `default_magnification` is `Value.absent()` on save | Deferred numeric input. No Range Day surface consumes `default_magnification` yet — UI input would be a dead-end field. |
| 10 | §3.x scope `id` slug generation rule example | `vortex_razor_hd_gen_iii_6_36x56_ffp` | Actual slug is `vortex_optics_razor_hd_gen_iii_6_36x56_ffp` because the catalog manufacturer field is "Vortex Optics", not "Vortex" | Slug-generation rule applied correctly; brief's example was hand-written without including `_optics`. |
| 11 | §6A.1 LOD hooks | "Adaptive LOD code path exists is not the same as adaptive LOD actually downshifts on slow devices" (DoD warning) | `shouldRenderReticleElement` is now public AND invoked from `_ReticlePainter.paint`'s element loop. Originally drafted as `_shouldRenderReticleElement` (private) | DoD warning satisfied. Function had to be made public for the unit test to import it — pure function, no behavioural risk in widening scope. |
| 12 | §0 ("the brief") version header | "v2.1" appears in some H1 occurrences | The actual rewrite ships as v2.3 | Cosmetic. Phase 6 will sweep header for v2.1 → v2.3 references. |
| 15 | Appendix L (`gsutil` commands) | Apparent assumption that `gsutil rsync` will not preserve `archive/` snapshots | Phase 2.8 verification confirmed `gsutil rsync` DOES preserve `archive/` snapshots when `-d` is omitted (and the operator script `scripts/upload_seed_data.sh` explicitly omits `-d` for this reason) | No action required — existing tooling handles this. Brief's caution is over-conservative. |

---

## Section B — Math errors in spec ⚠️

These are NOT naming drift. They are **substantive numeric errors**
in the brief that a future engineer reading the spec at face value
would carry forward into incorrect implementations. Each is elevated
per the Phase 5 directive so that this section becomes the first place
anyone touches when re-implementing or extending the spec.

### B-1 — §6A.3 rack subtension example math is off by ~28×

| | |
|---|---|
| **Brief location** | §6A.3 acceptance bullet 6 (line 1269) |
| **Brief claim** | "Rack-wide angular subtension at distance feels visually correct (a 60" wide KYL rack at 100yd subtends about 0.6 mil — matches reality)." |
| **Reality** | Using the standard small-angle approximation `mil = inches / (yards × 36) × 1000`: 60 / (100 × 36) × 1000 = **16.67 mil**. 0.6 mil would require ~2,778 yards. The author likely meant 1000 yards (60 / (1000 × 36) × 1000 = 1.67 mil — still not 0.6 mil) OR transposed digits / units somewhere. |
| **Engineering response** | Phase 4f's rack-rendering implementation uses the correct `mil = in / (yd × 36) × 1000` formula. The brief's example math has NO impact on shipped behaviour — it only matters if a future implementer takes the example at face value to derive a different formula. Phase 6 will rewrite the example with correct numbers. |
| **Severity** | High for future readers; zero for v2.3 shipped. |

### B-2 — §6A.3 active-stroke "50% thicker" is actually 67% thicker

| | |
|---|---|
| **Brief location** | §6A.3 line 1244 |
| **Brief claim** | "the active plate renders with a 50% thicker stroke (e.g., 2.5px instead of 1.5px)" |
| **Reality** | 2.5 / 1.5 = 1.667 = **67% thicker**, not 50%. The "50%" framing and the "2.5/1.5" pixel example are internally inconsistent. |
| **Engineering response** | Phase 4f shipped the explicit pixel values (`kRackActiveStrokeWidth = 2.5` / `kRackInactiveStrokeWidth = 1.5`) as the source of truth. Per the Phase 5 directive: **drop the "50%" framing entirely** from the brief; keep the explicit numbers. |
| **Severity** | Low (the explicit numbers were the author's primary intent — the "50%" was an approximation phrase that became misleading once it landed next to the exact pixel values). |

---

## Section C — Appendix G substantive updates (Phase 5 resolutions)

Each Phase 5 finding resulted in either a catalog change (documented in
`PHASE_5_RETICLE_MAPPING_FINDINGS.md`) or a brief erratum row below.
These are the brief-side fixes.

| Appendix G # | Brief said | Phase 6 erratum |
|---|---|---|
| 3 | "Viper PST Gen II 5-25x50 FFP → loadout_mil_tree_flare (FFP-mil)" | "Viper PST Gen II 5-25x50 → loadout_mil_tree_flare (FFP-mil)" — drop " FFP" suffix; FFP is implicit per the category. |
| 8 | "Hensoldt ZF 5-25x56 → loadout_mil_tree_flare (FFP-mil)" | "Hensoldt ZF 3.5-26x56 → loadout_mil_tree_flare (FFP-mil)" — the brief's mag range does not exist as a Hensoldt SKU per May 2026 verification; substituted with the actual flagship FFP. |
| 9 | "Tangent Theta TT525P → loadout_mil_tree_flare (FFP-mil)" | "Tangent Theta TT525P 5-25x56 → loadout_mil_tree_flare (FFP-mil)" — add mag/objective suffix to match the canonical catalog name. |
| 11 | "Razor HD Gen III 6-36x56 FFP MOA → loadout_moa_tree_flare (FFP-MOA)" | "Razor HD Gen III 6-36x56 FFP → loadout_mil_tree_flare (FFP-mil)" — Phase 2 collapsed the MIL and MOA variants into a single scope row (the same physical hardware); the MIL flaring tree is the catalog default. (See B-2 / Phase 4f for the MOAR-T dual-reticle Option A split that exposes the MOA variant separately.) |
| 12 | "Nightforce ATACR 5-25x56 F1 → loadout_moa_tree_flare (FFP-MOA)" | "Nightforce Optics ATACR 5-25x56 F1 MOAR-T → loadout_moa_tree_flare (FFP-MOA)" — Phase 5 Option A dual-reticle split. The base scope (Mil-XT variant) stays mapped to `loadout_mil_tree_flare`. |
| 13 | "Razor HD Gen II 4.5-27x56 FFP MOA → loadout_moa_tree_flare (FFP-MOA)" | "Razor HD Gen II 4.5-27x56 FFP → loadout_mil_tree_flare (FFP-mil)" — same collapse rationale as #11. |
| 14 | "Leupold Mark 5HD 7-35x56 → loadout_moa_tree_flare (FFP-MOA)" | "Leupold Mark 5HD 7-35x56 TMOA → loadout_moa_tree_flare (FFP-MOA)" — Phase 5 Option A dual-reticle split. Base scope (Tremor3) stays mapped to mil. |
| 16 | "Athlon APMR2 MOA → Argos BTR Gen2 6-24x50" | (manufacturer field) "Athlon Optics" (catalog's canonical) instead of "Athlon". |
| 18 | "Nikon Black FX1000 6-24x50" | **DROPPED.** Nikon discontinued their entire riflescope line in 2020 (verified via Phase 5 product research, May 2026). |
| 19 | "Sig Sauer Tango6T 5-30x56 → loadout_sfp_moa_drop (SFP-tactical)" | "Sig Sauer Tango6T DEV-L 5-30x56 → loadout_mil_tree_flare (FFP-mil)" — the brief was thinking of the SFP BDX-R1 Digital variant which is the Tango DMR family, not Tango6T. The Tango6T 5-30x56 is FFP with the DEV-L tactical mil tree. Catalog mapping also updated from `loadout_mil_tree_dense` to `loadout_mil_tree_flare` (§7.3 launch-blocker remap). |
| 20 | "Vortex Diamondback Tactical 6-24x50 → loadout_hunting_bdc (SFP-tactical)" | "Vortex Optics Diamondback Tactical 6-24x50 FFP → loadout_mil_tree_christmas (FFP-mil)" — the brief was thinking of the SFP variant (Dead-Hold BDC); the catalog has the FFP variant (EBR-2C MRAD → mil Christmas tree). Both variants exist as SKUs; catalog represents the FFP one. |
| 21 | "Bushnell DMR II Pro 3.5-21x50 → loadout_dmr_bdc (SFP-tactical)" | "Bushnell Elite Tactical DMR3 3.5-21x50 → loadout_mil_tree_flare (FFP-mil)" — DMR II Pro was discontinued and superseded by the DMR3 (verified May 2026). The DMR3 ships with G3 MIL / EQL flaring-tree reticles. |
| 27 | "Vortex Crossfire II 6-24x50 → loadout_hunting_bdc (SFP-hunting)" | "Vortex Optics Crossfire II 4-12x44 → loadout_hunting_bdc (SFP-hunting)" — catalog's Crossfire II variant in the relevant mag range is 4-12x44. |
| 30 | "Trijicon ACOG TA31 → loadout_sfp_lpvo_chevron (LPVO)" | "Trijicon ACOG TA31 4x32 → loadout_sfp_lpvo_chevron (LPVO)" — add "4x32" to match catalog's canonical name. Catalog mapping also corrected from `loadout_combat` to `loadout_sfp_lpvo_chevron` (the BAC IS the chevron variant). |
| 34 | "EOTech XPS2-0" | "EOTech XPS2-0 Holographic" — append "Holographic" to match catalog. |
| 35 | "Holosun 510C" | "Holosun HS510C" — catalog's canonical name. Catalog mapping also corrected from `loadout_red_dot_2moa` to `loadout_holographic_ring` (the HS510C IS a circle-dot reflex). |
| 23 | "EOTech Vudu 1-8x24 → loadout_combat" | "EOTech Vudu 1-8x24 SFP → loadout_combat" — the 1-8x24 is SFP, not FFP. New scope row added for SFP variant. |
| 25 | "Leupold VX-Freedom 3-9x40 → loadout_hunting_bdc (SFP-hunting)" | "Leupold VX-Freedom 3-9x40 Boone & Crockett → loadout_hunting_bdc (SFP-hunting)" — Phase 5 Option A dual-reticle split. Base scope (Duplex variant) stays mapped to `pd_plex`. |

## Out of scope for this errata log

- Style edits / typos in the brief — these get a Phase 6 sweep, not individual line items.
- Decisions that were made BY this brief (the brief is the authoritative spec; the errata log captures only DRIFT between spec and reality, not the spec itself).

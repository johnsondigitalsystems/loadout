# Competitive audit v2: LoadOut vs Strelok / Ballistic Calculator 2026, Applied Ballistics Quantum, Ballistic AE

**Last updated:** 2026-05-08
**Author:** internal — engineering / marketing reference, not for
public distribution as-is.
**Predecessor:** `marketing/competitive_audit.md` (Strelok-only audit;
the v2 retains the Strelok column, expands the field to include
Applied Ballistics Quantum and Ballistic AE, and folds in the
modern long-range exterior-ballistics research summary).

**Sources used (citations linked inline below):**

- Existing repo:
  - [`/CLAUDE.md`](../CLAUDE.md) — engineering reference.
  - [`marketing/CLAUDE.md`](./CLAUDE.md) — pitch reference.
  - [`marketing/competitive_audit.md`](./competitive_audit.md) — v1 audit.
  - [`lib/services/ballistics/solver.dart`](../lib/services/ballistics/solver.dart) — solver internals (1828 lines).
  - [`lib/services/ballistics/projectile.dart`](../lib/services/ballistics/projectile.dart) — Miller stability, form factor.
  - [`lib/services/ballistics/group_stats.dart`](../lib/services/ballistics/group_stats.dart) — extreme spread, mean radius, σ_x, σ_y.
  - [`lib/services/hit_probability_service.dart`](../lib/services/hit_probability_service.dart) — single-aim-point Monte Carlo dispersion.
  - [`lib/database/database.dart`](../lib/database/database.dart) — `BallisticProfiles` table (schema v8, single-atmosphere).
  - [`assets/seed_data/`](../assets/seed_data/) — catalog counts.
- Applied Ballistics:
  - [AB Quantum product page](https://appliedballisticsllc.com/ab-quantum/) — feature list, Doppler-derived CDM library, AB Quantum Connect / Sync.
  - [AB Quantum on Apple App Store](https://apps.apple.com/us/app/ab-quantum/id785619104) — pricing ($2.99/mo or $19.99/yr Elite; $3.99/mo or $29.99/yr Pro), platform list, in-app feature listing.
  - [WEZ overview](https://appliedballisticsllc.com/weapon-employment-zone-wez/) — Monte Carlo hit-probability with sensitivity analysis.
  - [The Science of Accuracy — Device License Levels](https://thescienceofaccuracy.com/understanding-device-license-levels-and-their-benefits-in-ab-quantum/) — Pro vs Elite tier breakdown, hardware unlocks (Kestrel 5700X-WEZ unlocks Pro, Kestrel 5700x Elite unlocks Elite, etc.).
  - [PrecisionRifleBlog AB Quantum announcement](https://precisionrifleblog.com/2024/12/03/new-release-applied-ballistics-quantum-app/) — context for AB Mobile → AB Quantum rebranding.
  - [AB Mobile User Guide v2.2 (2018 PDF)](https://appliedballisticsllc.com/wp-content/uploads/2019/11/ABMobileUserGuide.pdf) — older AB Mobile feature set.
  - [Applied Ballistics LLC, "The Evolution of Ballistic Calibration" (2025 PDF)](https://appliedballisticsllc.com/wp-content/uploads/2025/01/CDF.pdf) — Custom Drag Factor (CDF) methodology paper.
  - [Applied Ballistics LLC, "Shot-to-Shot Variation in MV and BC" (PDF)](https://appliedballisticsllc.com/wp-content/uploads/2020/08/BC_SD_Effects.pdf) — error budget analysis.
- Ballistic AE / Ballistic Advanced Edition (Inert Solutions):
  - [Ballistic Advanced Edition on Apple App Store](https://apps.apple.com/us/app/ballistic-advanced-edition/id303254296) — feature list, Kestrel LiNK $9.99 IAP, JBM engine, 5,000 projectile library, Advanced Wind Kit (8 sources), iCloud Sync.
  - [Pew Pew Tactical 8 Best Ballistic Calculator Apps](https://www.pewpewtactical.com/best-ballistic-calculator-apps/) — community reference for app comparisons.
- Modern long-range exterior-ballistics literature:
  - ["Applied Ballistics for Long Range Shooting" 4th Edition product page](https://thescienceofaccuracy.com/product/applied-ballistics-for-long-range-shooting-4th-edition/) — chapter list (BC, wind deflection, gyroscopic spin drift, Coriolis, sights, stability, extended range).
  - ["Modern Advancements in Long Range Shooting" Vol. I product page](https://store.accuracy1st.com/products/modern-advances-in-long-range-shooting) — twist-rate effects on BC, chronograph testing, rangefinder / wind-meter chapter.
  - ["Modern Advancements in Long Range Shooting" Vol. III product page](https://thescienceofaccuracy.com/product/modern-advancements-long-range-shooting-3/) — TOP Gun precision-class formula, barrel tuner testing, BC variation, ladder testing, powder humidity, barrel break-in, drag-modeling evolution, transonic aero, large-caliber spin, bore-groove diameter, chronograph testing.
  - ["Accuracy and Precision for Long Range Shooting" product page](https://thescienceofaccuracy.com/product/accuracy-and-precision-for-long-range-shooting/) — three-part structure (Precision / Accuracy / WEZ Analysis).
- Strelok / Ballistic Calculator 2026: see citations carried forward in the v1 audit.

---

## Executive summary

LoadOut sits **between** three quite different competitors. **Strelok / Ballistic Calculator 2026** is the legacy mass-market calculator with a deep cartridge / reticle catalog and shallow workflow. **Applied Ballistics Quantum** is the chief-ballistician's product — its in-house team owns the math, ships a Doppler-radar CDM library Berger / AB licenses commercially, integrates with the Kestrel 5700X-WEZ and the Leica Geovid Pro AB+ to unlock Pro tier features, and ships full WEZ analysis. **Ballistic AE** is the Apple-ecosystem premium solver — JBM engine, 5,000 projectile library, iCloud Sync, Kestrel LiNK, $30 one-time + $9.99 IAP for hardware. None of them is a reloading workspace.

LoadOut leads all three on **the bench layer**: recipes with 60+ optional fields, lot-aware brass lifecycle, batch tracking, photo OCR, end-to-end encrypted Cloud Sync to the user's own cloud. We trail **Applied Ballistics Quantum** on three measurable axes — full WEZ analysis (we ship single-aim-point hit probability, not the surface across the engagement window), the AB-licensed Doppler CDM library, and the chief-ballistician brand. We trail **Ballistic AE** on raw projectile count, JBM-engine pedigree, Apple-ecosystem-only depth, and HUD / night-mode polish. We trail **Strelok** on raw cartridge / reticle count and 19-year brand pedigree.

**v1.0 priority** is to close the WEZ-analysis gap (we have all the inputs already — wind uncertainty, MV SD, group MOA, range estimation error are all live in `HitProbabilityService`; we just don't sweep across the engagement window) and to ship BC truing as a first-class workflow (the only published Applied Ballistics calibration we still don't support). Both are software-only; neither needs a partnership.

---

## The competitive set

### Strelok Pro / Ballistic Calculator 2026

- **Publisher:** Igor Borisov (Strelok Pro, removed from US App Store 2023-03 over sanctions); the active Google Play replacement is "Ballistic Calculator 2026" by Educational apps LLC, ~100K installs.
- **Pricing:** Free with IAP. Premium 3 months $11.99–$19.99 (band varies by store / region), Premium 12 months $23.99–$59.99, no lifetime since they dropped it.
- **Audience:** Mass market — Eastern European, Central Asian, and US shooting communities. Was 22% share among PRS pros in 2019 per [PrecisionRifleBlog](https://precisionrifleblog.com/2019/05/22/ballistic-app/).
- **Reputation:** "Field-proven since 2007" per their own marketing; in PRS forum threads called the cheap-and-deep solver. Documentation is sparse and the proprietary engine is undisclosed per [Recoil's review](https://www.recoilweb.com/ballistics-in-the-palm-of-your-hand-109258.html).
- **Strengths:** ≈4,000 cartridge entries, ≈2,300 reticles, deep BLE list including Vectronix Terrapin X.
- **Weaknesses:** No reloading workspace, no Hornady 4DOF, no Cloud Sync (manual file copy), the Google Play replacement title BC2026 has third-party log analytics per their [privacy policy](https://pages.flycricket.io/ballistics-calcula/privacy.html).

### Applied Ballistics Quantum (formerly AB Mobile)

- **Publisher:** Applied Ballistics LLC (Berger Bullets / Ammo Inc subsidiary).
- **Pricing:** Ultralite tier free. Elite $2.99/mo or $19.99/yr; Pro $3.99/mo or $29.99/yr ([App Store](https://apps.apple.com/us/app/ab-quantum/id785619104)). Hardware unlocks: Kestrel 5700X-WEZ unlocks Pro features, Kestrel 5700x Elite unlocks Elite features, Leica Geovid Pro AB+ unlocks Pro features ([The Science of Accuracy](https://thescienceofaccuracy.com/understanding-device-license-levels-and-their-benefits-in-ab-quantum/)).
- **Audience:** Mil/LE, PRS top tier, ELR shooters. The premium tier of the precision-rifle market.
- **Reputation:** **The reference engine for serious long-range work.** Applied Ballistics' published research is the math behind it; the Doppler-radar-derived Custom Drag Models ship with the app. Kestrel and Leica integrate AB Pro / Elite by license. The AB Mobile → AB Quantum rebrand happened December 2024 ([PrecisionRifleBlog](https://precisionrifleblog.com/2024/12/03/new-release-applied-ballistics-quantum-app/)).
- **Strengths:** Doppler-radar CDM library (thousands of bullets), full WEZ analysis with sensitivity, AB Spotter (AI ballistics expert), AB Learn (educational content), Bluetooth chronograph (Garmin Xero C2, Optex SpeedTracker), 50+ Bluetooth devices, AB Quantum Connect/Sync (encrypted cloud sync of rifle profiles).
- **Weaknesses:** Subscription-only above the free tier (no lifetime), no reloading workspace at all (zero recipe / brass / batch concepts), Pro features lock most users out (true Pro requires both subscription AND Pro-licensed hardware OR the $29.99/yr subscription override), 308 MB app size, AB Spotter / AB Learn / E-Dope only on Pro subscription.

### Ballistic AE (Advanced Edition)

- **Publisher:** Inert Solutions (formerly KennedyApps / Mobile Notepad LLC).
- **Pricing:** ~$29.99 one-time as Ballistic Advanced Edition on the App Store; Kestrel LiNK $9.99 add-on IAP per the [App Store listing](https://apps.apple.com/us/app/ballistic-advanced-edition/id303254296). No subscription.
- **Audience:** Apple-ecosystem hunters and target shooters. iOS-first (the Mac and Apple Watch versions ship the same Catalyst codebase).
- **Reputation:** **The premium iOS solver.** Long-running, polished UI, "go-to" for hunters who already live in Apple. Uses the [JBM ballistics engine](https://www.jbmballistics.com/) under the hood — JBM's solver is itself a respected community resource published by James Boatright.
- **Strengths:** ~5,000 projectile library (largest in the apps surveyed) including Applied-Ballistics custom G7 BCs, Advanced Wind Kit (up to 8 wind sources), iCloud Sync of favorites/optics/range log, HUD with Mil-Dot rangefinder, 3D trajectory imaging, atmospheric pressure via iPhone barometer.
- **Weaknesses:** iOS-only (no Android, no Web, native Mac is iPad Catalyst), no full WEZ analysis (single trajectory + Mil-Dot HUD), no reloading workspace, limited custom drag model support (G1/G7 + Stepped BC only — no Hornady 4DOF, no Doppler CDMs), no continuous Cloud Sync — only iCloud "favorites" backup, no native Wear OS.

### LoadOut (us)

- See [`/CLAUDE.md`](../CLAUDE.md) and [`marketing/CLAUDE.md`](./CLAUDE.md). 6 platforms, $14.99/3mo / $39.99/yr / $79.99 lifetime, local-first, end-to-end encrypted Cloud Sync, reloading workspace + ballistics solver.

---

## Modern long-range methodology — research summary and LoadOut implementation status

The published Applied Ballistics methodology is the modern reference
for long-range shooting math. The book series and supporting papers
cover spin drift, aerodynamic jump, atmosphere, Coriolis, custom
drag modelling, BC truing, group statistics, and weapon-employment-
zone analysis.

**Important framing:** LoadOut is **not affiliated with Applied
Ballistics LLC, Berger Bullets, or any author of the underlying
literature.** We use the **published** formulas with citation. Where
Applied Ballistics ships licensed material (the Doppler-radar CDM
library, AB-Pro-tier hardware integrations), we have no equivalent
and don't claim parity. Our positioning is "industry-standard
exterior-ballistics math," meaning we honor the published
methodology — never "Applied-Ballistics-endorsed."

### Published works covered

| Book | Edition / year | Source |
|---|---|---|
| Applied Ballistics for Long-Range Shooting | 4th edition (3rd ed. 2015 ISBN 9780990920618) | [Science of Accuracy](https://thescienceofaccuracy.com/product/applied-ballistics-for-long-range-shooting-4th-edition/) |
| Accuracy and Precision for Long-Range Shooting | 1st (2012, ISBN 9780615672557) | [Science of Accuracy](https://thescienceofaccuracy.com/product/accuracy-and-precision-for-long-range-shooting/) |
| Modern Advancements in Long Range Shooting Vol. I | 2014 (ISBN 9780692208434) | [Accuracy 1st](https://store.accuracy1st.com/products/modern-advances-in-long-range-shooting) |
| Modern Advancements in Long Range Shooting Vol. II | 2017 | [Science of Accuracy](https://thescienceofaccuracy.com/product/modern-advancements-in-long-range-shooting-volume-ii/) |
| Modern Advancements in Long Range Shooting Vol. III | 2022 | [Science of Accuracy](https://thescienceofaccuracy.com/product/modern-advancements-long-range-shooting-3/) |

The literature also cites Harold Vaughn's 1998 "Rifle Accuracy Facts"
(ISBN 9781571570112) extensively — barrel harmonics, bullet
imbalance, etc. That work is upstream of the modern long-range
synthesis; we treat it as foundational rather than something to
"implement against."

### Methodology / formula table

| # | Calculation / methodology | Source (book + chapter) | LoadOut today | Gap | Effort to close |
|---|---|---|---|---|---|
| 1 | **Spin drift formula** `Sd ≈ 1.25 × (Sg + 1.2) × t^1.83` inches | *Applied Ballistics for Long-Range Shooting*, "Gyroscopic (Spin) Drift" chapter | **Implemented** as the default in [solver.dart:138](../lib/services/ballistics/solver.dart) | — | — |
| 2 | **Aerodynamic jump from cant × cross-wind** `aero_jump_in ≈ 0.087 × cross_wind_mph × tof × velocity_fps / 1000` | *Modern Advancements* Vol. III; original derivation in *Applied Ballistics* "Wind Deflection" chapter | **Implemented** as per-sample correction in [solver.dart:898–909](../lib/services/ballistics/solver.dart) plus the cant×crosswind angular term from *Modern Advancements* Vol. III | — | — |
| 3 | **Custom Drag Model (CDM) philosophy** — measure Cd-vs-Mach via Doppler radar, more accurate than BC alone in transonic region | *Modern Advancements* Vol. I (twist effects on BC) and Vol. III chapters 9–10 (Doppler-radar drag-model evolution) | **Partial** — we ship 300 Hornady 4DOF curves with PCHIP interpolation in [`custom_drag.dart`](../lib/services/ballistics/custom_drag.dart) and 6 standard tables in [`drag_functions.dart`](../lib/services/ballistics/drag_functions.dart). We don't ship Berger/AB CDMs (that's licensed material). | We can't ingest the AB Doppler library; we can ingest more public Doppler curves (Hornady) | Small — data work only |
| 4 | **Weapon Employment Zone (WEZ) analysis** — Monte Carlo across the engagement window with target size + range estimation error + wind uncertainty + MV SD + group MOA, surfaces a hit-probability surface and per-input sensitivity | *Accuracy and Precision for Long-Range Shooting* Part 3 (entire third of the book is WEZ); examples throughout *Applied Ballistics* "Extended Range Shooting" | **Service + screen shipped 2026-05-08.** [`wez_analysis_service.dart`](../lib/services/wez_analysis_service.dart) computes the WEZ curve and per-source variance breakdown; [`wez_analysis_screen.dart`](../lib/screens/range_day/wez_analysis_screen.dart) renders the curve. [`hit_probability_service.dart`](../lib/services/hit_probability_service.dart) covers the single-aim-point case. | Polish + wire the screen into Range Day tabs; add 2D heatmap for v1.2 | **Tiny** — math + UI both done |
| 5 | **BC truing** — observed-vs-predicted impact at distance back-solves a BC correction (Custom Drag Factor — CDF) | *Applied Ballistics* "Using Ballistics Programs" chapter; full standalone treatment in [the 2025 CDF paper](https://appliedballisticsllc.com/wp-content/uploads/2025/01/CDF.pdf) | **Service shipped, no UI yet.** [`bc_truing_service.dart`](../lib/services/bc_truing_service.dart) (created 2026-05-08) provides `trueBcFromSingleObservation` and `trueBcFromObservations` (bisection + golden-section). **Missing the screen** that lets a user enter observations and apply the trued BC to a load. | Build a BC-truing screen that takes (distance, observed mil hold) and writes the trued BC back to the load | **Small** — math is done; needs only the UI + a schema column to persist |
| 6 | **Drop Per Click (DPC) / sight-scale calibration** — observed dial-vs-impact ratio calibrates sight scale | *Applied Ballistics* "Getting Control of Sights" chapter; tall-target test methodology | **Static field only.** We have `sightScaleVertical` and `sightScaleHorizontal` in [solver.dart:609,613,652,656](../lib/services/ballistics/solver.dart) but no auto-calibration workflow that takes a tall-target measurement and computes the factor. | A wizard: enter dialed mils + measured impact → solve for scale | **Small** — math is `actual_dial / measured_impact`; needs a UI screen |
| 7 | **Multiple atmosphere profiles** — save zero atmosphere + multiple "shooting atmosphere" presets, switch between them quickly | *Applied Ballistics* "Atmosphere" / "Using Ballistics Programs" chapters; *Accuracy and Precision* Part 2 | **Single profile per ballistic profile.** [`BallisticProfiles`](../lib/database/database.dart) stores ONE atmosphere per row; the calculator screen has one zero-atmosphere field separate from runtime, but no preset library. | Add an `AtmospherePresets` table + picker | **Small** — schema bump + UI |
| 8 | **Wind bracket method** — bracket the wind call between low/high estimates, compute holds for both | *Applied Ballistics* "Wind Deflection" chapter; *Accuracy and Precision* Part 3 worked example | **Not implemented as a UI surface.** Our hit-probability service already accepts `windUncertaintyMph` and re-solves at base ± U, but we don't surface low/high holds as a separate "wind bracket card." | Add a "wind bracket card" UI on the ballistics + range-day screens that surfaces solver runs at (wind-low, wind-call, wind-high) | **Small** — math already exists, needs UI |
| 9 | **Group MOA confidence intervals** — group MOA from N shots has a wide CI; the literature publishes the distribution math | *Accuracy and Precision* Part 1 (precision); also *Modern Advancements* Vol. III ch. 3 ("TOP Gun" precision-class formula) | **Group MOA reported, no CI.** [`group_stats.dart`](../lib/services/ballistics/group_stats.dart) computes ES, MR, σ_x, σ_y, group size MOA — none with confidence intervals or sample-size effects. | Add CI based on χ² distribution for σ-based metrics; use simulation for ES (which has no closed form) | **Medium** — math in *Accuracy and Precision*; reasonable test coverage required |
| 10 | **Twist-rate effects on BC** — same bullet through different twists changes effective BC; the literature quantifies the effect | *Modern Advancements* Vol. I "twist rate effects on muzzle velocity / BC / precision" | **Not modeled.** [`projectile.dart`](../lib/services/ballistics/projectile.dart) computes Miller stability from twist + length + diameter, but doesn't apply the BC-vs-twist-rate correction (i.e. an Sg-low bullet has 3–5% degraded BC). | Apply a BC correction when Sg < 1.5 per *Modern Advancements* Vol. I tables | **Small** — formula is one multiplier |
| 11 | **Pejsa stability formula** alongside Miller — the literature discusses both | *Applied Ballistics* "Bullet Stability" chapter | **Pejsa is shipped as a spin-drift model** ([solver.dart:527,536](../lib/services/ballistics/solver.dart) `SpinDriftModel.pejsa`). The Pejsa **stability** formula (different from Pejsa spin-drift) is not a separate option; we use Miller for stability and the industry-standard / Pejsa formulas for drift. | Optional — most users prefer Miller. Could add as a stability-check option. | **Small** — but low priority |
| 12 | **Form factor (i7) vs G7 BC** as user-facing concept — the literature argues form factor + reference curve over BC | *Applied Ballistics* "The Ballistic Coefficient" chapter; *Modern Advancements* Vol. I drag-modeling chapters; "[A Better Ballistic Coefficient](https://bergerbullets.com/a-better-ballistic-coefficient/)" Berger blog post | **Computed internally** ([projectile.dart:283](../lib/services/ballistics/projectile.dart) `formFactor = SD / BC`), **not surfaced.** Users see G1/G7 BC fields, never `i7`. | Surface form factor on the bullet detail screen as an info-only field; let advanced users enter it directly instead of BC | **Small** — UI work only |
| 13 | **TOP Gun precision-class formula** — estimates rifle precision class from barrel quality, trigger, action | *Modern Advancements* Vol. III ch. 3 | **Not implemented.** | Optional — speculative until Vol. III is fully analyzed | **Medium** — needs the actual coefficients from the book |
| 14 | **Powder humidity sensitivity** — fps shift per % humidity in powder | *Modern Advancements* Vol. III ch. 7 | **Not modeled.** We have `mvTempSensitivityFpsPerC` for powder temperature, no humidity field. | Add `mvHumiditySensitivityFpsPerPctHumid` field on UserLoads | **Small** — schema bump + form field |
| 15 | **Barrel break-in / MV migration over time** | *Modern Advancements* Vol. III ch. 8 | **Not modeled.** We track `shotsFired` per firearm but don't surface per-load MV migration. | Per-load MV regression vs round count would be a load-development win | **Medium** — needs UI + small stats |
| 16 | **Ladder testing repeatability** — research showing ladder powder-charge testing is statistically dubious | *Modern Advancements* Vol. III ch. 6 | We **ship** ladder testing in [`/lib/screens/load_development/`](../lib/screens/load_development/). The honest framing is that ladder works for some shooters but the literature argues OCW + group testing is more repeatable. | Add a "what does this ladder actually tell you" CI panel | **Small** — disclaimer + CI math |
| 17 | **Standard atmosphere correction (ICAO/Tetens humid-air density)** — the literature publishes the equations | *Applied Ballistics* "Atmosphere" chapter | **Implemented** in [`atmosphere.dart`](../lib/services/ballistics/atmosphere.dart). Uses ICAO standard atmosphere + Tetens vapor-pressure correction. | — | — |
| 18 | **Coriolis (horizontal + Eötvös vertical)** | *Applied Ballistics* "The Coriolis Effect" chapter | **Implemented** with full 3D `−2 Ω × v` formula ([solver.dart:111–127](../lib/services/ballistics/solver.dart)). | — | — |
| 19 | **Miller stability factor** | *Applied Ballistics* "Bullet Stability" chapter; original by Don Miller, 2005 *Precision Shooting* | **Implemented** in [projectile.dart:303](../lib/services/ballistics/projectile.dart). Returns a velocity-corrected Sg. | — | — |
| 20 | **Modified Point-Mass (MPM) solver** with add-ons | *Applied Ballistics* "Using Ballistics Programs"; McCoy as the academic reference | **Implemented** as the engine class. Cash-Karp adaptive RK45 default ([solver.dart:471–500](../lib/services/ballistics/solver.dart)) | — | — |

**Summary count:** of the 20 published Applied-Ballistics methodologies
surveyed, LoadOut ships **9 fully** (1, 2, 17, 18, 19, 20, plus
partial-but-shipped 3, 6, 11), **7 partially / service-only** (3, 4,
5, 6, 8, 11, 16) where items 4 and 5 have shipped services as of
2026-05-08 but no UI yet, and **5 not at all** (7, 9, 10, 12, 13, 14, 15).

The audit's recommended **closing priority** for v1.0 is to ship the
**UI surfaces** for the already-built WEZ analysis service (item 4)
and BC truing service (item 5), then add DPC wizard (6), atmosphere
presets (7), wind bracket card (8), and group MOA CI (9). Each has
effort small or medium, no licensing dependency, and lands real
industry-standard exterior-ballistics features without overclaiming.

---

## Side-by-side feature comparison (4-column)

Notation: ✓ shipped, ◐ partial / unconfirmed, ✗ not present, "?" =
unconfirmed in public sources. Where a column lists a number, the
source for the number is in the **Sources used** preamble. Sort order
is the same row groups as the v1 audit so the new columns slot in.

### Catalog

| Feature / data point | LoadOut | Strelok / BC2026 | AB Quantum | Ballistic AE |
|---|---|---|---|---|
| Cartridges | 203 (full SAAMI specs) + 4,143 factory loads | ≈4,000 cartridges, mostly user-input ([source](https://strelok-pro-ios.apps112.com/)) | "Thousands of projectile models" Doppler-CDM ([AB Quantum page](https://appliedballisticsllc.com/ab-quantum/)) | 5,000 projectiles + factory loads ([App Store](https://apps.apple.com/us/app/ballistic-advanced-edition/id303254296)) |
| Cartridge SAAMI specs (case dims, neck angle, shoulder, max pressure) | ✓ all 203 | ✗ | ✗ | ✗ |
| Bullets | 255 across 10 mfgs | 3,361 bullets ([Strelok Pro](https://www.strelokpro.online/StrelokPro/android/default.asp)) | Doppler CDM library, "thousands" | Listed in "5,000 projectiles + factory loads" |
| Bullets w/ measured drag (Doppler / 4DOF) | **300 Hornady 4DOF curves** ([curves.json](../assets/seed_data/drag_curves/curves.json)) | ◐ user must enter | **AB Doppler CDM library** (largest) — licensed | Applied-Ballistics custom G7 BCs (NOT Doppler CDMs) + Variable / Stepped BCs |
| Reticles | 258 ([reticles.json](../assets/seed_data/reticles.json)) | ≈2,277–3,300 | "Reticle library, online, auto-updating" — count not published, integrated with Kestrel | 175+ per Inert Solutions marketing (LoadOut v1 audit cited; not corroborated in retrieved App Store text) |
| Reticle hold-over visualization | ✓ + Scope View Pro w/ probability rings | ✓ static reticle | ✓ — uses Kestrel-loaded reticle library | ✓ Mil-Dot HUD |
| Optics (whole units) | 156 across 21 brands | ✗ | ✗ — reticle-centric | ◐ "optics profiles" stored per profile |
| Powders / Primers / Brass library | 178 / 83 / 348 | ✗ | ✗ | ✗ |
| Firearms reference library | 255 across 40 mfgs | ✗ | ✓ (rifle profile, not catalog) | ✓ (rifle profile, not catalog) |
| Targets | 55 shapes | ✗ | ✓ — sector / target cards | ✓ via target log |

### Solver

| Feature | LoadOut | Strelok / BC2026 | AB Quantum | Ballistic AE |
|---|---|---|---|---|
| Solver framing | Modified Point-Mass (McCoy MPM) + Applied-Ballistics add-ons | "Proprietary algorithm" ([Recoil](https://www.recoilweb.com/ballistics-in-the-palm-of-your-hand-109258.html)) | **AB Point-Mass Solver** (Applied Ballistics internal) | **JBM ballistics engine** ([App Store](https://apps.apple.com/us/app/ballistic-advanced-edition/id303254296)) |
| Engine pedigree | New (2026); fully documented internals | 19 years | Applied Ballistics / Berger; mil/LE field-validated | JBM open math; long-running |
| Drag tables (G1, G2, G5, G6, G7, G8) | ✓ all 6 | ✓ G1/G7 confirmed; others "?" | ✓ G1, G7 + Doppler CDM | ✓ G1, G7 + Variable/Stepped BC |
| Custom Drag Model (CDM / Doppler) | ✓ Hornady 4DOF (300 curves bundled) | ✓ user-entered Lapua DSF | ✓ AB Doppler library (largest) — **licensed material** | ✗ — not documented as a CDM container; only G1/G7 + Stepped BC |
| Drag-table interpolation | **Fritsch-Carlson PCHIP** ([custom_drag.dart](../lib/services/ballistics/custom_drag.dart)) | Linear (typical, not stated) | Doppler curve native (PCHIP-class smoothing implied) | JBM linear |
| Atmosphere model | ICAO + Tetens humid-air | Standard atmosphere + humidity | AB Atmosphere model (matches ICAO; *Applied Ballistics* "Atmosphere" ch.) | Standard + iPhone barometer integration |
| Density-altitude derivation | ✓ | ✓ | ✓ | ✓ |
| Zero atmosphere (separate from runtime) | ✓ | ✓ | ✓ | ✓ |
| **Multi-atmosphere preset library** | ✗ — single atmosphere on each profile | ? | ✓ via Range Card environmentals | ✓ — multiple "favorites" with env settings |
| Coriolis horizontal | ✓ | ✓ | ✓ | ✓ |
| Coriolis Eötvös vertical | ✓ | ✓ | ✓ | ✓ |
| Spin drift  | ✓ default | ✓ | ✓ | ✓ ("gyroscopic spin") |
| Spin drift (Pejsa) | ✓ alternate model ([solver.dart:527](../lib/services/ballistics/solver.dart)) | ? | ? | ? |
| Aerodynamic jump from cross-wind | ✓ explicit per-sample correction | ◐ implicit, not user-facing | ✓ | ◐ implicit |
| Aero jump from cant×cross-wind (Vol. III term) | ✓ ([solver.dart:893](../lib/services/ballistics/solver.dart)) | ✗ | ✓ | ◐ unconfirmed |
| Miller stability factor | ✓ velocity-corrected | ✓ | ✓ | ✓ |
| Cant correction | ✓ live tilt sensor | ✓ | ✓ | ✓ "Advanced HUD" |
| **Sight scale (vertical + horizontal) factor** | ✓ as static fields | ✗ | ✓ — "Ballistic truing interface" | ✗ |
| **DPC / sight-scale auto-calibration wizard** | ✗ | ✗ | ✓ — "Ballistic truing interface" | ✗ |
| Powder temperature sensitivity | ✓ | ✓ requires ≥2 chrono points | ✓ | ✓ |
| Powder **humidity** sensitivity | ✗ | ✗ | ? | ✗ |
| Incline / decline angle | ✓ | ✓ | ✓ | ✓ |
| Incline measurement via phone camera | ✓ | ✓ | ✓ | ✓ |
| **MV truing** | ✗ — not currently shipped | ✓ | ✓ — Downrange MV CDF calibration | ✓ "Custom BC via chronograph" |
| **BC truing (CDF)** | ◐ service shipped ([bc_truing_service.dart](../lib/services/bc_truing_service.dart)), UI pending | ✓ preferred mode | ✓ — Custom Drag Factor (CDF) | ◐ via Custom BC |
| Live multi-shot field validation | ✓ via group_stats | ◐ single distance | ✓ | ✓ |
| Integration scheme (disclosed) | **Cash-Karp adaptive RK45** w/ 1e-4 m tolerance ([solver.dart:471–500](../lib/services/ballistics/solver.dart)) | "Proprietary" (closed) | "AB Point-Mass Solver" (closed; the literature publishes the math but the implementation is closed) | JBM (open math; closed app) |
| Solver accuracy modes | 3 (`fast`, `precise`, `extreme`) | ✗ | ✓ | ✗ |

### Hardware integration (BLE)

| Feature | LoadOut | Strelok / BC2026 | AB Quantum | Ballistic AE |
|---|---|---|---|---|
| Kestrel 5xxx Link / Drop | ✓ ([kestrel_service.dart](../lib/services/ble/kestrel_service.dart)) | ✓ | ✓ — first-party (AB ships in Kestrel 5700X-WEZ / 5700X-Elite) | ✓ requires $9.99 IAP "Kestrel LiNK" |
| Kestrel 5700X-WEZ unlocks Pro features | ✗ — no analogue | ✗ | ✓ ([Science of Accuracy](https://thescienceofaccuracy.com/understanding-device-license-levels-and-their-benefits-in-ab-quantum/)) | ✗ |
| Garmin Xero C1 / C2 chronograph (.fit) | ✓ ([garmin_xero_service.dart](../lib/services/ble/garmin_xero_service.dart)) | ? | ✓ Pro tier (C2 specifically) | ✓ |
| MagnetoSpeed | ✗ | ? | ✗ | ◐ unconfirmed |
| LabRadar | ✗ | ? | ✗ | ◐ unconfirmed |
| Optex SpeedTracker chronograph | ✗ | ✗ | ✓ Pro tier | ✗ |
| Bushnell BDX rangefinder | ✓ | ? | ◐ unconfirmed | ◐ unconfirmed |
| Sig KILO BDX | ✓ | ? | ✓ via Connect | ◐ unconfirmed |
| Vortex Razor HD 4000 / Fury HD AB | ✓ | ? | ✓ via Connect | ◐ unconfirmed |
| Leica Geovid Pro / Pro AB+ | ✓ | ? | ✓ — Pro AB+ unlocks Pro features | ◐ unconfirmed |
| Leica Geovid Pro AB+ unlocks Pro features | ✗ | ✗ | ✓ | ✗ |
| Vectronix Terrapin X | ✓ ([vectronix_terrapin_service.dart](../lib/services/ble/vectronix_terrapin_service.dart)) | ✓ | ✓ via SORD/BOSS (mil/LE) | ◐ unconfirmed |
| WeatherFlow / Skywatch wind meters | ✗ | ✓ | ✗ | ◐ unconfirmed |
| Calypso AB wind meter | ✗ | ✓ Calypso Ultrasonic | ✓ — first-party | ✗ |
| Magnetometer / azimuth (phone) | ✓ ([sensors](../lib/services/sensors)) + WMM declination | ◐ implicit | ✓ — "Azimuth and Inclination camera capture with reticle overlay" | ✓ |
| BLE devices supported (rough count) | 7 (Kestrel + Xero + 5 RFs incl. Vectronix Terrapin X) | ≈10 | "50+" per [AB Quantum page](https://appliedballisticsllc.com/ab-quantum/) | 1 (Kestrel via $9.99 IAP) |

### Workflow / workspace

| Feature | LoadOut | Strelok / BC2026 | AB Quantum | Ballistic AE |
|---|---|---|---|---|
| Recipe management (60+ optional fields, lot, brass, batch) | ✓ — see [`marketing/CLAUDE.md` § 5](./CLAUDE.md#5-feature-catalog-what-we-ship) | ✗ | ✗ | ✗ |
| Lot tracking (powder/bullet/primer/brass) | ✓ | ✗ | ✗ | ✗ |
| Brass lifecycle (firings, anneal, neck wall, retired) | ✓ | ✗ | ✗ | ✗ |
| Batch tracking | ✓ | ✗ | ✗ | ✗ |
| Custom fields per recipe | ✓ Pro | ✗ | ✗ | ✗ |
| Auto-save (every keystroke) | ✓ | ✗ | ✗ | ✗ |
| Multiple cartridges per rifle | ✓ unlimited | ✓ 10 max (Strelok+) | ✓ profile groups | ✓ favorites |
| Recipe form templates (PRS, F-Class, etc.) | ✓ 7 templates | ✗ | ✗ | ✗ |
| Beginner mode | ✓ toggle | ✗ | ✗ | ✗ |

### Range day / live solve

| Feature | LoadOut | Strelok / BC2026 | AB Quantum | Ballistic AE |
|---|---|---|---|---|
| Range Day workspace | ✓ | ✗ | ✓ "Range Card" + "Target Card" modes | ✓ Target Log + Range Log |
| Live ballistic solution as inputs change | ✓ + contributing-component breakdown | ✓ | ✓ | ✓ |
| Aim-point placement on target | ✓ Pro (Scope View Pro) | ✗ | ✓ moving-target HUD | ◐ Mil-Dot HUD |
| **Single-aim-point hit probability** | ✓ ([hit_probability_service.dart](../lib/services/hit_probability_service.dart)) | ✗ | ✓ | ✗ |
| **Full WEZ analysis (range-window curve)** | ✓ — shipped 2026-05-08 ([wez_analysis_service.dart](../lib/services/wez_analysis_service.dart) + [wez_analysis_screen.dart](../lib/screens/range_day/wez_analysis_screen.dart)) | ✗ | **✓ Pro tier** ([WEZ page](https://appliedballisticsllc.com/weapon-employment-zone-wez/)) | ✗ |
| WEZ sensitivity analysis (which input drives misses?) | ✓ — variance-breakdown shipped in `WezAnalysisService` (factor: group/wind/range/MV) | ✗ | ✓ Pro tier — explicit "sensitivity analysis showing how each variable contributes" | ✗ |
| Post-shot correction (hold X mil left/up) | ✓ | ✗ | ✓ | ✓ |
| Group stats (ES, MR, group MOA, σ) | ✓ live update | ✗ | ✓ via shot-dispersion graph | ✓ via group calculator |
| **Group MOA confidence intervals** | ✗ | ✗ | ✓ — TOP Gun precision class (*Modern Advancements* Vol. III) | ✗ |
| Skill-level shoot timing | ✓ Pro | ✗ | ✗ | ✗ |
| Animated mover w/ ambush guides | ✓ Pro | ✗ | ✓ HUD wind lock + moving target | ✗ |
| GPS altitude + station pressure pull | ✓ Pro | ✓ "Get current weather from internet" | ✓ | ✓ iPhone barometer |
| **Wind bracket card (low/call/high holds)** | ✗ | ✗ | ✓ Pro — graph-based | ◐ Advanced Wind Kit (8 sources) |
| Sector / target group save+share | ◐ via export | ◐ | ✓ — Sector Management with grouped cards | ✓ via target log |

### Import / export / sync

| Feature | LoadOut | Strelok / BC2026 | AB Quantum | Ballistic AE |
|---|---|---|---|---|
| Photo OCR (snap notebook → recipes) | ✓ on-device ML Kit + 444-entry alias dict | ✗ | ✗ | ✗ |
| CSV / Excel import wizard | ✓ auto-mapping | ✗ | ✗ | ✗ |
| Sample notebook PDF | ✓ | ✗ | ✗ | ✗ |
| JSON / CSV export | ✓ | ◐ email of trajectory tables | ✓ E-Dope export Pro tier | ✓ via target log |
| PDF export of recipe / DOPE | ✓ | ◐ email image | ✓ Range Card / Target Card share | ✓ |
| **Continuous Cloud Sync (encrypted)** | ✓ — iCloud / Drive / OneDrive, AES-256-GCM + PBKDF2-200k, **never seen by us** | ✗ — manual file copy to Drive/Dropbox/Box | ✓ — **AB Quantum Sync** "encrypted cloud backup of rifle profiles" (encryption model not publicly documented; presumed AB-server-decryptable) | ◐ — iCloud Sync of "favorites, optics profiles & range log" (Apple-managed encryption; not E2EE-by-passphrase) |
| Sync model — server-decryptable? | **No — passphrase-only, we cannot decrypt** | N/A | ◐ AB Quantum Sync; encryption model unpublished | ◐ Apple-managed; Apple/iCloud key |
| Cross-device automatic sync | ✓ ~5s after each AutoSave | ✗ | ✓ AB Quantum Sync | ✓ iCloud, automatic |

### Platform reach

| Feature | LoadOut | Strelok / BC2026 | AB Quantum | Ballistic AE |
|---|---|---|---|---|
| iOS | ✓ | ✓ BC2026 (iOS 13+) | ✓ iOS 16+ | ✓ |
| iPad | ✓ universal | ✓ | ✓ universal | ✓ universal |
| Android | ✓ | ✓ BC2026 only | ✓ ([Google Play](https://play.google.com/store/apps/details?id=com.appliedballisticsllc.appliedballistics)) | ✗ |
| macOS native | ✓ Flutter native | ✓ Catalyst (BC2026 M1+) | ✓ macOS 13+ M1+ | ◐ Catalyst |
| Web | ✓ Flutter web | ✗ | ✗ | ✗ |
| Apple Watch | ✓ native SwiftUI scaffold | ✓ Strelok Pro | ✗ | ✓ companion |
| Wear OS | ✓ native Compose for Wear | ✓ | ✗ | ✗ |
| Apple Vision Pro | ✗ | ✓ BC2026 visionOS 1.0+ | ✓ visionOS 1.0+ | ✗ |
| Platform count | **6** | 4 | 4 | 3 |

### Pricing

| Tier | LoadOut | Strelok / BC2026 | AB Quantum | Ballistic AE |
|---|---|---|---|---|
| Free | ✓ extensive | ✓ | ✓ Ultralite (limited) | ✗ |
| 3-month | $14.99 | $11.99–$19.99 | ✗ | ✗ |
| Monthly | ✗ | ✗ | $2.99 (Elite) / $3.99 (Pro) | ✗ |
| Yearly | $39.99 | $23.99–$59.99 | $19.99 (Elite) / $29.99 (Pro) | ✗ |
| Yearly welcome / first-year offer | $24.99 | "$34.99" stated in Strelok Pro v1 audit (unconfirmed BC2026) | ✗ | ✗ |
| Lifetime / one-time | **$79.99** | ✗ (dropped) | ✗ | **$29.99** one-time |
| Hardware unlock (own a $$$ device → app features unlock) | ✗ | ✗ | ✓ — Kestrel 5700X-WEZ → Pro; Geovid Pro AB+ → Pro; Kestrel 5700X-Elite → Elite | ✗ — but $9.99 Kestrel LiNK IAP add-on |
| Subscription required for top tier | No (lifetime exists) | Yes | Yes (Pro/Elite annual or monthly) | No (one-time) |
| Total cost across 5 years (yearly tier × 5) | $39.99 × 5 = **$199.95** or $79.99 lifetime | $59.99 × 5 = $299.95 | $29.99 × 5 = **$149.95** Pro / $19.99 × 5 = $99.95 Elite | $29.99 once + $9.99 once = **$39.98** |
| Cost-effectiveness ranking (5-yr horizon) | 3rd | 4th | 2nd | **1st** (cheapest) |

### Privacy

| Feature | LoadOut | Strelok / BC2026 | AB Quantum | Ballistic AE |
|---|---|---|---|---|
| Local-first storage | ✓ SQLite + drift | ✓ | ◐ profiles synced via AB Quantum Sync | ✓ + iCloud copy |
| Auth required | ✗ optional | ✗ | ✓ likely (account-based device licensing); not confirmed in retrieved sources | ✗ |
| LoadOut / vendor-operated backend | **None** | **None** (Strelok Pro); BC2026 has third-party log analytics per [BC2026 privacy policy](https://pages.flycricket.io/ballistics-calcula/privacy.html) | **AB-operated backend** for AB Quantum Sync, AB Spotter (AI), AB Learn | iCloud only; no Inert backend documented |
| Server-decryptable user data | No (E2EE passphrase) | N/A (no server) | Likely yes (AB Quantum Sync) | iCloud-managed |
| Third-party analytics | None — Crashlytics-only opt-in | Yes per BC2026 privacy | Likely yes (no public privacy doc; AB Spotter is server-side) | iCloud + standard Apple |

### AI / advanced

| Feature | LoadOut | Strelok / BC2026 | AB Quantum | Ballistic AE |
|---|---|---|---|---|
| AI ballistics chatbot | ◐ Coming Soon (v1.1) | ✗ | **✓ AB Spotter (Pro tier)** — domain-trained AI ballistics expert | ✗ |
| AI photo OCR / handwriting reader | ✓ free, on-device + Pro Smart Import (server-assisted, opt-in) | ✗ | ✗ | ✗ |
| Educational content (videos, podcasts) | ◐ glossary, SAAMI screen | ✗ | **✓ AB Learn (Pro tier)** — integrated podcasts + videos | ✗ |
| Domain authority of AI chatbot | Anthropic-backed; LoadOut has no in-house ballistician | N/A | **Applied Ballistics content** — the chief ballistician's own R&D | N/A |

---

## Where we lead each competitor

### vs Strelok / Ballistic Calculator 2026

1. **Reloading workspace.** Strelok stops at the calculator; we are the workbench. Recipes with 60+ fields, lot tracking, brass lifecycle, batch tracking. Same lead claim as v1 audit; structurally true, structurally hard for them to replicate.
2. **Local-first encrypted Cloud Sync to user's own cloud.** Strelok Pro ships no sync; BC2026 ships manual file copy. We ship continuous E2EE sync to iCloud / Drive / OneDrive.
3. **Hornady 4DOF measured drag curves.** 300 curves pre-shipped. They have user-entered Lapua DSF only.
4. **Pricing.** $39.99/yr vs $59.99/yr (33% cheaper); $79.99 lifetime they don't sell.
5. **Photo OCR + smart import.** 444-entry handwriting alias dictionary; on-device. Strelok ships nothing equivalent.
6. **6 platforms vs 4.** We add Web and full native macOS / Wear OS.
7. **Disclosed solver internals.** Their engine is "proprietary" per [Recoil](https://www.recoilweb.com/ballistics-in-the-palm-of-your-hand-109258.html); ours is fully documented in [solver.dart](../lib/services/ballistics/solver.dart).
8. **Hit probability + post-shot correction.** Range Day workspace surfaces single-aim-point hit probability with Monte Carlo dispersion + per-source breakdown. They surface neither.
9. **Sight scale (vertical + horizontal) factor.** Surfaced in the form fields; Strelok doesn't surface it.
10. **Privacy.** BC2026's [privacy policy](https://pages.flycricket.io/ballistics-calcula/privacy.html) describes third-party log analytics. We ship Crashlytics-only with an off toggle.

### vs Applied Ballistics Quantum

1. **Reloading workspace.** AB Quantum has zero recipe / brass / batch concept. The closest analogue is rifle profiles. Reloaders who need both the math and the bench are stuck switching apps.
2. **Photo OCR for notebook conversion.** Pen-and-paper reloaders are 66% of the market per LoadOut survey data; AB Quantum has no equivalent.
3. **Lifetime pricing.** $79.99 once vs $29.99/yr (Pro) — break-even at year 3, perpetuity above. Plus the AB-Pro hardware-unlock model effectively requires a $700+ Kestrel 5700X-WEZ purchase; we have no such gate.
4. **Free tier scope.** Our free tier ships ballistics core, Range Day, group stats, hit probability, photo OCR, recipe management, brass / batch / lot tracking, manual encrypted backup, watch / wear, all catalogs. Their Ultralite tier is "basic ballistic solver functionality with limited features" — explicit limitation.
5. **Multi-platform reach.** They ship iOS / iPadOS / macOS / visionOS — Apple-only stack. We ship those plus Android, Web, Wear OS.
6. **Local-first / E2EE Cloud Sync.** AB Quantum Sync is described as "encrypted cloud backup of rifle profiles" but the encryption model is not publicly documented; the AB-operated backend is presumed server-decryptable. Our sync is passphrase-only AES-256-GCM, never seen by LoadOut.
7. **Solver disclosed.** AB's published math is in the books; the solver implementation in the app is closed. Ours is open in [solver.dart](../lib/services/ballistics/solver.dart) with line-level references to McCoy and the *Applied Ballistics* literature.
8. **Hornady 4DOF curves.** AB has its own (larger) Doppler library — but it's licensed material accessible only to AB-paying customers. We pre-ship 300 Hornady-published curves free.
9. **Beginner mode + onboarding.** AB Quantum is built for the AB-tier mil/LE / PRS top-end audience; the onboarding assumes you already understand DOPE, range cards, sectors. We ship Beginner Mode + 7 workflow templates + glossary.

### vs Ballistic AE

1. **Reloading workspace.** Same lead claim — Ballistic AE is a calculator, not a workbench.
2. **Cross-platform.** Ballistic AE is iOS-only. We ship Android, Web, Wear OS.
3. **Photo OCR / CSV import.** None in Ballistic AE.
4. **Hornady 4DOF Doppler curves.** Ballistic AE ships Stepped BCs and Applied-Ballistics custom G7 BCs, but no Doppler-radar Cd-vs-Mach curves.
5. **End-to-end encrypted Cloud Sync.** Ballistic AE uses iCloud Sync for "favorites, optics profiles & range log" — Apple-managed encryption (Apple holds the key for non-E2EE iCloud data, the user holds the key only with Advanced Data Protection). Our model is passphrase-only AES-256-GCM regardless of cloud.
6. **Hit probability + Range Day workspace.** Ballistic AE has Range Log + Mil-Dot HUD + group calculator, but no Monte Carlo hit probability with per-source breakdown.
7. **Glossary, SAAMI catalog, cartridge / chamber drawings.** Ballistic AE has none of these; their reference is the projectile / factory ammo library only.
8. **Lot tracking + brass lifecycle.** None.
9. **Wear OS.** None.
10. **PRS / F-Class match templates.** None — Ballistic AE is a hunter-favored solver.

---

## Where we trail each competitor

### vs Strelok / Ballistic Calculator 2026

(Carries the v1 audit's gaps; not re-litigating them here.)

1. Raw cartridge count (203 + 4,143 factory loads vs ≈4,000 cartridges).
2. Reticle library size (258 vs ≈2,277 Strelok / 3,300 BC2026 marketing).
3. Brand pedigree (we are new; they have 19 years).
4. Niche European rangefinders we don't ship (MTC Rapier, NTC Tomahawk, SHR RF1000, Calypso Ultrasonic) — Vectronix Terrapin X is now shipped via [`vectronix_terrapin_service.dart`](../lib/services/ble/vectronix_terrapin_service.dart).
5. Multi-language coverage breadth (we ship 6; Strelok Pro had 10+).
6. WeatherFlow / Skywatch wind meters.

### vs Applied Ballistics Quantum

1. **Doppler-radar CDM library.** AB has the largest commercial library, derived from Berger's R&D and licensed to 3rd parties (AB-equipped Kestrel models, Geovid Pro AB+, Vortex / Schmidt & Bender / Steiner AB-equipped optics). We can't access this — it's proprietary IP. Our 300 Hornady 4DOF curves close part of the gap on Hornady-bullet shooters; on Berger / Lapua / Sierra / Cutting Edge bullets we lag.
2. **Full WEZ analysis UI.** AB ships range-window WEZ at the Pro tier with sensitivity analysis (which input drives misses). The math is shipped on our side ([`wez_analysis_service.dart`](../lib/services/wez_analysis_service.dart) computes the curve + variance breakdown), but the user-facing screen is still pending. Once the UI ships, **this gap closes**.
3. **Hardware-unlock ecosystem.** AB Quantum's tier-unlock model is unique: a Kestrel 5700X-WEZ purchase ($700+) unlocks Pro features in the app. AB-equipped Geovid Pro AB+ likewise. We have no analogue. The AB ecosystem essentially makes the app subsidized for hardware buyers.
4. **AB Spotter (AI ballistics expert).** Pro-tier domain-trained AI assistant. Our AI Reloading Assistant is Coming Soon at v1.0; landing it before AB Quantum's gap closes is a v1.1 priority.
5. **AB Learn (educational content).** Integrated podcasts + videos at the Pro tier, drawing on the published research.
6. **Brand pedigree.** Applied Ballistics is led by the chief ballistician of the modern long-range field. We are not affiliated. We use the published math. The framing is "industry-standard exterior-ballistics math" — never "Applied-Ballistics-endorsed."
7. **MV truing + BC truing (CDF).** AB ships both as first-class workflows. BC truing service is shipped on our side ([`bc_truing_service.dart`](../lib/services/bc_truing_service.dart)) but the UI is pending. MV truing is v1.1.
8. **Sector management.** AB ships save/share grouped target sectors — useful for match shooters working ranges with multiple stages. We don't surface this.
9. **50+ Bluetooth devices.** AB integrates with 50+ devices including Optex chronographs, SORD/BOSS mil/LE solvers, Garmin Montana, multiple Kestrel models. We integrate with 6.
10. **Visionos.** AB Quantum runs on Apple Vision Pro; we don't.

### vs Ballistic AE

1. **5,000-projectile library.** Larger than Strelok and us. Their library includes Applied-Ballistics custom G7 BCs in the projectile records — a published-Applied-Ballistics benefit we'd need to license / re-derive.
2. **JBM ballistics engine pedigree.** [JBM](https://www.jbmballistics.com/) is a long-running open-math reference; it's not licensed but it's the engine pedigree the Apple-ecosystem audience is used to.
3. **3D Trajectory imaging.** We have a 2D trajectory display; their 3D trajectory imaging is more visually polished.
4. **Advanced Wind Kit (8 wind sources).** We support a single wind vector across the trajectory. Modeling 8 wind regions across a 1500-yard course is an ELR-shooter feature.
5. **Mil-Dot HUD ranging.** Estimate distance using on-screen Mil-Dot reticle. We have reticle subtension data on every reticle but no HUD-style range estimation tool from a Mil-Dot reading.
6. **One-touch atmospheric correction.** Their UI has a single-button "pull weather + recalc" — we have it gated as Pro and behind a confirmation.
7. **Lifetime price gap.** $29.99 one-time vs our $79.99 lifetime. We're 2.5× more expensive at lifetime. Defensible because we're a workspace, not a calculator — but the comparison is real.

---

## Roadmap to close gaps

### v1.0 — pre-launch (next 4–6 weeks)

The bar for v1.0 is "credible vs all three competitors." Items that
either close a structural gap or remove a misleading marketing claim.

| # | Item | Effort | Priority | Files |
|---|---|---|---|---|
| 1 | **WEZ analysis UI polish.** [`wez_analysis_service.dart`](../lib/services/wez_analysis_service.dart) computes the WEZ curve + variance breakdown; [`wez_analysis_screen.dart`](../lib/screens/range_day/wez_analysis_screen.dart) is shipped. v1.0 work: review against AB Quantum's WEZ output for parity (or a defensible difference), wire it into the Range Day tab bar, polish curve rendering. Optionally add a heatmap of `(range × wind)` for v1.2. | **Tiny** (~1 day; integration / polish) | **HIGH** — closes the only solver feature AB Quantum has and we don't | Existing: [`wez_analysis_screen.dart`](../lib/screens/range_day/wez_analysis_screen.dart). Wire into Range Day tabs. |
| 2 | **BC truing (CDF) UI + persistence.** [`bc_truing_service.dart`](../lib/services/bc_truing_service.dart) already provides single- and multi-observation truing. Build a screen that walks the user through (distance, observed mil hold) entry, runs the solver, and writes the trued BC back. Persist as `UserLoads.bcCorrectionFactor` (new col, schema bump). | **Small** (~2 days; UI + 1 schema column) | **HIGH** — every serious-precision competitor has truing as a first-class workflow; the v1 marketing claim "truing workspace" was incorrect | New: `lib/screens/ballistics/bc_truing_screen.dart`. Schema bump in [`database.dart`](../lib/database/database.dart). Reuses [`bc_truing_service.dart`](../lib/services/bc_truing_service.dart). |
| 3 | **Tall-target test wizard / DPC calibration.** Take dialed mils + measured impact spread → solve `sightScaleVertical = dialed / measured`. Persists to `UserFirearms.sightScaleVertical` and `.sightScaleHorizontal`. Pre-conditions are already on the form. | **Small** (~1-2 days; one screen + math) | **HIGH** — AB Quantum ships ballistic truing interface; we surface the inputs but no wizard | New: `lib/screens/ballistics/tall_target_wizard.dart`. |
| 4 | **Atmosphere preset library.** New table `AtmospherePresets(id, name, tempF, pressureInHg, humidityPct, elevationFt, lat, lon, notes, createdAt, updatedAt)`. Picker on the calculator + Range Day screens. Schema migration to v9 alongside #2. | **Small** (~2 days) | **HIGH** — the literature publishes atmospheric switching as core methodology; competitors all support multi-profile | Schema bump in [`database.dart`](../lib/database/database.dart); new `lib/repositories/atmosphere_preset_repository.dart`; new `lib/screens/ballistics/atmosphere_preset_picker.dart`. |
| 5 | **Wind bracket card.** Re-solve at (`wind_mph - U`, `wind_mph`, `wind_mph + U`). Surface 3 holds in MIL/MOA. Already wired through [`hit_probability_service.dart`](../lib/services/hit_probability_service.dart) — needs UI. | **Small** (~1-2 days) | **HIGH** | New: `lib/widgets/ballistics/wind_bracket_card.dart`. Add to ballistics + Range Day. |
| 6 | **Group MOA confidence intervals.** The literature publishes the `σ` distribution math: σ_estimated × √((n-1)/χ²(α/2, n-1)) for the lower/upper CI bound of σ. ES needs a Monte Carlo of order-statistics distribution (no closed form). | **Medium** (~2 days; math + UI) | **MEDIUM** — Honest framing of group quality; differentiates us from "every app reports group MOA" — we report the band | Update [`group_stats.dart`](../lib/services/ballistics/group_stats.dart). |
| 7 | **Form factor (i7) on bullet detail screen.** Surface `SD / G7BC` as a derived field. Read-only for v1.0. | **Small** (~1 day; UI only) | **MEDIUM** | Update bullet detail UI in `lib/screens/recipes/component_detail_*.dart`. |
| 8 | **Twist-rate BC correction.** When `Sg < 1.5` apply the published BC degradation curve from *Modern Advancements* Vol. I (1.5 → 1.0; 1.0 → 0.97; 0.5 → 0.90 — quote actual values from the book at implementation time; rough placeholder). Surface as a "Reduced BC" warning on the recipe screen. | **Small** (~1 day) | **MEDIUM** — *Modern Advancements* Vol. I research; Strelok / Ballistic AE don't surface this | Update [`projectile.dart`](../lib/services/ballistics/projectile.dart) `formFactor` getter. |
| 9 | **Powder humidity sensitivity field.** New optional column `mvHumiditySensitivityFpsPerPctHumid` on `UserLoads`; warn when humidity changes from baseline by > 20% RH. | **Small** (~1 day; schema bump + form field) | **LOW** — Vol. III Ch. 7; few users will populate it | Schema migration to v9 + form field in `lib/screens/recipes/recipe_form_screen.dart`. |
| 10 | **Update marketing copy + audit v1 to remove the "truing workspace" claim.** [`marketing/CLAUDE.md`](./CLAUDE.md) line under "Multi-shot field truing" needs to be cut or rephrased; the [v1 competitive audit table](./competitive_audit.md) row "Truing by ballistic coefficient" claims `Yes` — that needs to change to `Coming v1.0` until #2 ships, OR truthfully `No` if #2 slips past launch. | **Small** (~30 min) | **HIGH** — maintains marketing integrity | [`marketing/CLAUDE.md`](./CLAUDE.md), [`marketing/competitive_audit.md`](./competitive_audit.md) |

**Top 5 v1.0 in order of impact:** 1 (WEZ), 2 (BC truing), 3 (DPC
wizard), 5 (wind bracket card), 4 (atmosphere presets).

### v1.1 — 3 months post-launch

Items that close differentiator gaps but don't block launch.

| # | Item | Effort | Priority | Notes |
|---|---|---|---|---|
| 11 | **AI Reloading Assistant ships.** Anthropic-backed chat trained on user's recipes + the SAAMI / glossary catalogs. Already-Coming-Soon UI. Counters AB Spotter (their Pro-tier AI ballistics expert). | **Large** (~3-4 weeks; Cloudflare Worker + RAG over catalog) | HIGH | Already partially scoped per [`marketing/CLAUDE.md` § 10](./CLAUDE.md#10-whats-coming-dont-market-hard-yet). |
| 12 | **MV truing workflow.** Same shape as BC truing; back-solves a `mvCorrectionFps`. Adds a "Truing Mode" that lets the user choose MV-truing vs BC-truing per the published trade-off (calibrate the dominant error or both? *Applied Ballistics* argues BC if you have a chronograph). | Medium | HIGH | New: `lib/services/ballistics/mv_truing_service.dart`. |
| 13 | **Live multi-shot field validation.** Per-distance MV/BC regression across the user's shot history. Surfaces "your dataset says BC = 0.31 not the catalog 0.32." | Medium | HIGH | Builds on #2; needs a regression service. |
| 14 | **Sector management.** Save/share grouped target cards (8-target stage at PRS match). | Small | MEDIUM | New table; new screen. |
| 15 | **Reticle library to 1,000+.** Match Strelok's effective floor (currently 258). Data work. | Medium (sustained) | MEDIUM | [`reticles.json`](../assets/seed_data/reticles.json) |
| 16 | **Bullet library to 1,000+** with G7 BCs from Hornady, Berger, Sierra, Lapua, Nosler, Barnes, Cutting Edge. | Medium (sustained) | MEDIUM | [`bullets.json`](../assets/seed_data/bullets.json) |
| 17 | **Cartridge library to 500+.** SAAMI cartridges + common wildcats. | Medium | MEDIUM | [`cartridges.json`](../assets/seed_data/cartridges.json) |
| 18 | **MTC Rapier / NTC Tomahawk / SHR RF1000 BLE.** Niche European RFs that close the last competitive gap on Strelok's hardware list. | Small | LOW | Each is one new file under `lib/services/ble/`. |
| 19 | **Apple Vision Pro support.** AB Quantum + BC2026 ship visionOS; we don't. Flutter doesn't yet officially support visionOS but the iPad app may run via compatibility mode. | Medium (test + ship) | LOW | Test on real hardware first. |
| 20 | **Real-time atmosphere variation along the trajectory** (ELR feature; current model treats atmosphere as constant). | Medium | LOW | [`atmosphere.dart`](../lib/services/ballistics/atmosphere.dart) + [`solver.dart`](../lib/services/ballistics/solver.dart). |
| 21 | **AB-style learn / educational content.** Glossary expansion + SAAMI deep-dive screens. Differentiates us as "the reloading workspace that teaches." | Medium (content) | MEDIUM | [`/lib/screens/glossary/`](../lib/screens/glossary/) |

**Top 5 v1.1:** 11 (AI), 12 (MV truing), 13 (multi-shot validation),
15 (reticle catalog), 16 (bullet catalog).

### v1.2+ — 6+ months

Long-term plays.

| # | Item | Effort | Priority |
|---|---|---|---|
| 22 | **Custom drag curve drawing tool.** Let users sketch a Cd-vs-Mach curve from published radar data (community-shared CDMs). Closes the AB Doppler-library gap somewhat. | Large | HIGH |
| 23 | **WEZ UI polish.** v1.0 ships the math; v1.2 ships richer rendering — heatmap with contour overlay, animated wind-call brackets, "what would change my hit %" slider per input. | Medium | HIGH |
| 24 | **Reticle subtension drawing tool.** Let users sketch their own reticle for scopes we don't have. | Medium | MEDIUM |
| 25 | **"TOP Gun" precision-class formula.** Estimate rifle precision class from barrel quality + trigger + action inputs. Sourced from *Modern Advancements* Vol. III Ch. 3. Read the book first. | Medium | LOW |
| 26 | **More languages: Portuguese, Turkish, Polish.** Already-built ARB framework. | Medium (translation) | MEDIUM |
| 27 | **WeatherFlow + Skywatch BLE adapters.** EU / UK community demand. | Small | LOW |
| 28 | **MagnetoSpeed + LabRadar chronograph BLE.** Closes a gap with Ballistic AE / AB Quantum. | Medium | MEDIUM |
| 29 | **Optex SpeedTracker chronograph.** AB Quantum-only today; community is small but growing. | Small | LOW |
| 30 | **Doppler-radar curve community sharing.** User-uploaded Cd-vs-Mach curves from their own Doppler captures (LabRadar Doppler, MagnetoSpeed V3 Doppler). Privacy-preserving (anonymized; opt-in upload). | Large | LOW |
| 31 | **Federated bullet library.** Pull manufacturer-published BCs from Hornady / Berger / Sierra / Lapua APIs. Live updates not store-build-gated. We ship `seed_updater.dart` already; just expand its reach. | Medium | MEDIUM |
| 32 | **AB-attribution badge on the bullet detail screen.** When a bullet has an Applied-Ballistics-published custom G7 BC (from the *Applied Ballistics* book bullet table or the AB blog), surface "Applied-Ballistics custom G7 BC" with attribution. Ballistic AE does this. | Small | MEDIUM |

**Top 5 v1.2+:** 22 (CDM drawing), 23 (WEZ polish), 24 (reticle
drawing), 31 (federated bullet library), 32 (AB BC attribution).

---

## Applied-Ballistics-derived implementation backlog

This is the consolidated list of features derived from the published
Applied Ballistics literature, sourced directly from the methodology
table above. Each one ships under "industry-standard exterior-ballistics"
framing without overclaiming. Do NOT use phrasing that implies
endorsement, license, or affiliation.

| Feature | Literature source | Math summary | Files that change | Effort |
|---|---|---|---|---|
| **WEZ analysis surface** (service done; UI pending) | *Accuracy and Precision for Long Range Shooting* Part 3 | Range-window curve of hit probability with per-source variance breakdown. Implemented in [`wez_analysis_service.dart`](../lib/services/wez_analysis_service.dart) 2026-05-08. | Done: [`wez_analysis_service.dart`](../lib/services/wez_analysis_service.dart) + [`test/wez_analysis_test.dart`](../test/wez_analysis_test.dart). Pending: `lib/screens/range_day/wez_screen.dart`. | Small (UI only) |
| **BC truing (CDF)** (service done; UI pending) | *Applied Ballistics for Long Range Shooting* "Using Ballistics Programs"; full treatment in the [Applied Ballistics 2025 CDF paper](https://appliedballisticsllc.com/wp-content/uploads/2025/01/CDF.pdf) | Bisection on BC for single observation; golden-section search for multi-observation least-squares. Constraint `k ∈ [0.7, 1.3]`. Implemented in [`bc_truing_service.dart`](../lib/services/bc_truing_service.dart) 2026-05-08. | Done: [`bc_truing_service.dart`](../lib/services/bc_truing_service.dart) + [`test/bc_truing_test.dart`](../test/bc_truing_test.dart). Pending: schema migration v9 (`UserLoads.bcCorrectionFactor`), `lib/screens/ballistics/bc_truing_screen.dart`. | Small (UI + 1 column) |
| **MV truing** | *Applied Ballistics* "Using Ballistics Programs" | Same shape as BC truing, solving for `MV + Δ` instead of `BC × k`. | New: `lib/services/ballistics/mv_truing_service.dart`. Schema bump. | Medium |
| **Tall-target test / DPC wizard** | *Applied Ballistics* "Getting Control of Sights" | `sightScaleVertical = dialed_mils / measured_impact_mils`. Constraint `[0.95, 1.05]` (real scopes track within ~5%). | New: `lib/screens/ballistics/tall_target_wizard.dart`. Existing `UserFirearms.sightScaleVertical` already in schema. | Small |
| **Atmosphere preset library** | *Applied Ballistics* atmosphere chapter; the standard practice | New table `AtmospherePresets`. Picker UI. | Schema bump in [`database.dart`](../lib/database/database.dart). New: `lib/repositories/atmosphere_preset_repository.dart`. | Small |
| **Wind bracket card** | *Applied Ballistics* "Wind Deflection"; *Accuracy and Precision* Part 3 | Re-solve at `wind ± U`. Surface 3 holds. Math is in [`hit_probability_service.dart`](../lib/services/hit_probability_service.dart) already. | New: `lib/widgets/ballistics/wind_bracket_card.dart`. Embed in ballistics + Range Day screens. | Small |
| **Group MOA confidence intervals** | *Accuracy and Precision* Part 1 | For σ-based metrics (group SD): `σ × √((n-1)/χ²(α/2, n-1))`. For ES: Monte Carlo of order-statistics with `n` draws from N(0, σ_underlying). | Update [`group_stats.dart`](../lib/services/ballistics/group_stats.dart). New: `lib/services/ballistics/group_stats_ci.dart`. | Medium |
| **Twist-rate effects on BC** | *Modern Advancements* Vol. I twist chapters | When `Sg < 1.5`, multiply BC by published curve. Need the actual coefficients from Vol. I; placeholders for now. | Update [`projectile.dart`](../lib/services/ballistics/projectile.dart). | Small |
| **Form factor (i7) UX** | *Applied Ballistics* "The Ballistic Coefficient"; "[A Better BC](https://bergerbullets.com/a-better-ballistic-coefficient/)" | `i = SD / BC`. Already computed in [`projectile.dart:283`](../lib/services/ballistics/projectile.dart). Surface read-only on bullet detail. | Update bullet detail UI. | Small |
| **Powder humidity sensitivity** | *Modern Advancements* Vol. III Ch. 7 | Linear `Δfps = sensitivity × (humidity_pct - baseline)`. | Schema bump. Form field. | Small |
| **TOP Gun precision-class formula** | *Modern Advancements* Vol. III Ch. 3 | Read the book; coefficients from the published research. | Future. | Medium |
| **Spin-drift Pejsa option** (already shipped) | *Applied Ballistics* "Gyroscopic Drift" | 6th-order polynomial; already in [`solver.dart:527`](../lib/services/ballistics/solver.dart) as `SpinDriftModel.pejsa`. | — | — |
| **Aero jump per-sample** (already shipped) | *Modern Advancements* Vol. III; *Applied Ballistics* "Wind Deflection" | `aero_jump_in = -0.087 × cross_mph × tof × velocity_fps / 1000` per sample. Already in [`solver.dart:898–909`](../lib/services/ballistics/solver.dart). | — | — |

---

## Marketing claims we can defensibly add

Specific quotable lines, each cited.

### vs Strelok / Ballistic Calculator 2026

(Carries forward from v1 audit; no changes.)

- "33% cheaper at the yearly tier — $39.99 vs $59.99." [BC2026 App Store](https://apps.apple.com/us/app/ballistics-calculator-2026/id1605954590)
- "A lifetime tier they don't sell."
- "Strelok stops at the calculator. We give you the bench, the brass, the lots, the batches, and the calculator that knows about all of them."
- "We use Hornady's measured radar data, 300 bullets, courtesy of Hornady. Strelok requires you to type each curve in."

### vs Applied Ballistics Quantum

- **"Industry-standard exterior-ballistics math, for reloaders, on every platform."** Phrasing: we honor the published Applied Ballistics methodology (spin drift, Miller stability, aerodynamic jump per *Modern Advancements* Vol. III, Coriolis, atmosphere) — and we layer the bench on top. We do NOT claim affiliation, license, or endorsement. This is a defensible "industry-standard math" framing, not an "Applied-Ballistics-endorsed product" claim.
- **"AB Quantum is a calculator. LoadOut is the workspace your loads live in."** Defensible by their own product framing — AB Quantum has zero reloading concepts. Citation: [AB Quantum product page](https://appliedballisticsllc.com/ab-quantum/).
- **"Lifetime $79.99 vs $30/yr forever."** AB Quantum is subscription-only above the free tier (Pro $29.99/yr or Pro-licensed-hardware lock). Cite: [App Store](https://apps.apple.com/us/app/ab-quantum/id785619104).
- **"No Kestrel-required tier." (after #1 in v1.0 ships)** AB Quantum's Pro features unlock with a Kestrel 5700X-WEZ purchase or the Pro subscription. We don't have a hardware-unlock model — every tier is the same on every device. Cite: [Science of Accuracy](https://thescienceofaccuracy.com/understanding-device-license-levels-and-their-benefits-in-ab-quantum/).
- **"WEZ analysis on the free tier."** (after #1 in v1.0 ships) We can claim this if WEZ ships in our free tier. AB Quantum's WEZ is Pro-only.
- **"End-to-end encrypted across iCloud, Drive, and OneDrive — your passphrase, your data, our backend has nothing to give up."** AB Quantum Sync is described as "encrypted" but the encryption model isn't publicly documented; AB-server-decryptable is the safe assumption.

### vs Ballistic AE

- **"Beyond Apple."** Ballistic AE is iOS-only. Cite: [App Store](https://apps.apple.com/us/app/ballistic-advanced-edition/id303254296). We ship Android, Web, Wear OS, native macOS.
- **"More than a solver."** Ballistic AE is a polished calculator. We add the bench: recipes, lots, brass, batches, photo OCR, AI Smart Import.
- **"True end-to-end encryption — even iCloud doesn't have your key."** Ballistic AE iCloud Sync uses Apple-managed keys (without ADP); ours uses passphrase-only AES-256-GCM regardless of cloud provider.
- **"Hornady 4DOF Doppler curves out of the box."** Ballistic AE ships Stepped BCs and Applied-Ballistics custom G7 BCs but no Doppler-radar Cd-vs-Mach curves.
- **"Hit probability with sensitivity breakdown."** Ballistic AE ships Mil-Dot HUD + group calculator; no Monte Carlo dispersion model with per-source breakdown.

---

## Marketing claims to AVOID

Re-affirms and extends `marketing/CLAUDE.md` § 13 with the new
competitor-specific landmines. Every one of these is a real legal /
trust risk; none of them is theoretical.

### Applied-Ballistics-affiliation overclaims (highest risk)

- **"Built with Applied Ballistics"** — false. We have no relationship.
- **"Applied-Ballistics-endorsed"** — false. Same.
- **"Powered by Applied Ballistics"** — false. Applied Ballistics is the publisher of AB Quantum; we're a competitor.
- **"Berger / Applied Ballistics official partner"** — false.
- **"Applied-Ballistics custom G7 BCs included"** — only OK if we license them or only attribute the small handful that has been published in the *Applied Ballistics* book bullet table (and even then with explicit attribution and version).
- **"Doppler radar drag library"** — only OK in the narrow sense of "300 Hornady-published 4DOF curves." Do NOT imply we ship Berger / Lapua / Sierra Doppler curves we don't have.

The defensible framing is **"industry-standard exterior-ballistics math."**
That's truthful: we use the published Applied-Ballistics formulas (spin
drift, aero jump per *Modern Advancements* Vol. III) with attribution.
It does NOT imply endorsement, license, or affiliation. Use it
consistently.

### AB Quantum-specific claims to avoid

- **"Better than AB Quantum"** — unprovable. We have a different
  scope. Replace with "more than a calculator" or "the reloading
  workspace AB Quantum doesn't have."
- **"AB Quantum's solver is wrong"** — false. Theirs is the
  reference implementation; we use the same published math.
- **"AB Quantum's CDM library is small"** — false. Theirs is the
  largest in any consumer app. Replace with "we ship 300 Hornady
  4DOF curves free; AB Quantum ships its own larger library at $30/yr
  Pro."

### Ballistic AE-specific claims to avoid

- **"Ballistic AE is outdated"** — opinion, not citable. Replace
  with "Ballistic AE is iOS-only" (factual).
- **"JBM is a worse engine than ours"** — JBM is a long-respected
  reference. We use a similar Modified Point-Mass model. Don't
  attack their engine.

### Privacy-comparison claims to avoid

- **"AB Quantum is a privacy disaster"** — overclaim. AB Quantum has
  no published privacy policy violation; we just don't know their
  encryption model. Replace with "AB Quantum Sync's encryption model
  is not publicly documented; ours is passphrase-only AES-256-GCM."
- **"Ballistic AE leaks your data to iCloud"** — overclaim. iCloud
  with ADP enabled is E2EE. Replace with "iCloud-only sync with
  Apple-managed keys unless ADP is on; ours is passphrase-only
  regardless of provider."

### Pricing-comparison claims to avoid

- **"Cheaper than every competitor"** — Ballistic AE one-time
  $29.99 + $9.99 IAP is cheaper than our $79.99 lifetime over a 5-year
  horizon. Don't claim lowest-price-anywhere. Replace with "33%
  cheaper than Strelok's yearly tier; lifetime they don't sell."
- **"AB Quantum is overpriced"** — opinion. AB Quantum at $29.99/yr
  Pro is comparable to us. The differentiator is "you get a
  workspace, not a calculator."

### Solver / Engine claims to avoid

- **"6-DOF"** — same as v1 audit. We're MPM with empirical add-ons.
- **"More accurate than [X]"** — unprovable across all atmospheres,
  bullets, ranges. Replace with "documented Cash-Karp adaptive RK45
  with 1e-4 m position tolerance" (factual).
- **"Patented" or "proprietary"** — same as v1 audit.

---

## What we couldn't confirm

Frank list. Update this section when authoritative info surfaces.

1. **Ballistic AE 2025 / 2026 current pricing.** The App Store listing
   we retrieved confirms free + Kestrel LiNK $9.99 IAP, but the
   "Advanced Edition" upgrade price is not visible in retrieved text.
   Community references suggest ~$29.99 one-time but this should be
   confirmed against an actual purchase flow.
2. **AB Quantum reticle library size.** The product page mentions
   "Reticle library, online, auto-updating" but no count.
3. **Whether AB Quantum supports custom Cd-vs-Mach curves the user
   types in.** Strelok and LoadOut both let users enter custom curves;
   AB Quantum likely does too via the "custom drag curve" referenced
   in tier docs, but the workflow / format isn't documented publicly.
4. **AB Quantum Sync encryption model.** Described only as
   "encrypted." Whether it's E2EE-by-passphrase or AB-server-key is
   not documented. The safe assumption is server-decryptable
   (matching Apple iCloud without ADP, Google Drive, etc.).
5. **AB Quantum's exact Bluetooth device count.** "50+" is the
   marketing figure; the device-licensing page lists ~10 Pro/Elite
   tier devices.
6. **Ballistic AE Apple Watch / macOS native vs Catalyst.** App
   Store listing only confirms iPhone; community references mention
   Apple Watch + Mac apps but the architecture (separate apps vs
   universal Catalyst) is unconfirmed.
7. **Whether Ballistic AE supports any rangefinder beyond Kestrel
   LiNK.** The app description lists Kestrel as the only BLE
   integration; community references suggest some rangefinders work
   but the App Store listing doesn't confirm.
8. **AB Quantum's Applied-Ballistics custom G7 BCs in the bullet library.** The
   AB-published Doppler CDM library is mentioned; whether the
   library also contains the historical Applied-Ballistics custom G7 BCs (separate
   from CDMs) is unconfirmed.
9. **Whether the AB Quantum WEZ output matches the published WEZ
   examples** in *Accuracy and Precision*. We assume yes (it's
   maintained by the chief ballistician); confirming with a
   side-by-side test would require purchasing both.
10. **Specific page references** in the books for the
    methodologies cited above. We have chapter-level citations from
    publisher pages; pinpointing exact page numbers requires owning
    the books. The audit treats chapter-level citation as
    sufficient for now.

---

## Appendix: catalog count cross-check (re-verified 2026-05-08)

| Catalog | LoadOut shipped count | Source |
|---|---|---|
| Cartridges | 203 | `jq '. \| length' assets/seed_data/cartridges.json` |
| Factory loads | **4,143** (was 2,583 in v1 audit; expanded 2026-05-08) | `jq '. \| length' assets/seed_data/factory_loads.json` |
| Reticles | 258 | `jq '. \| length' assets/seed_data/reticles.json` |
| Targets | 55 | `jq '. \| length' assets/seed_data/targets.json` |
| Bullets | 255 (across 10 manufacturers) | `jq '[.manufacturers[].products \| length] \| add'` |
| Powders | 178 | same |
| Primers | 83 | same |
| Brass products | 348 | same |
| Firearms | 255 | same |
| Optics | 156 (across 21 manufacturers) | same |
| Hornady 4DOF curves | 300 | `jq '.curves \| length' assets/seed_data/drag_curves/curves.json` |

These numbers are authoritative as of the v2 audit on 2026-05-08.

**Discrepancy with `marketing/CLAUDE.md` § 14:** marketing copy says
"4,100+ factory ammo SKUs" — accurate now (4,143). It also says "258
reticles," which matches. No drift. The v1 competitive audit cited
2,583 factory loads — that figure was correct at v1-audit time and
needs updating in the v1 doc to track. (LAUNCH_CHECKLIST candidate.)

---

## Implementation: what comes after this audit

The audit hands the v1.0 / v1.1 / v1.2+ work over to engineering.
Concrete next steps:

1. **Wire the BC-truing service into a UI screen** ([`lib/services/bc_truing_service.dart`](../lib/services/bc_truing_service.dart) is ready). Add `UserLoads.bcCorrectionFactor` schema column. Smallest, highest-leverage v1.0 item.
2. **Wire the WEZ-analysis service into a UI screen** ([`lib/services/wez_analysis_service.dart`](../lib/services/wez_analysis_service.dart) is ready). Add a Range Day "WEZ" tab with the curve and variance breakdown.
3. Build the DPC / tall-target wizard (item v1.0 #3).
4. Build the atmosphere preset library (item v1.0 #4).
5. Build the wind bracket card (item v1.0 #5).
6. Marketing reviews "Marketing claims to AVOID" section before any new copy ships.
7. The two truing claims in [`marketing/CLAUDE.md`](./CLAUDE.md) and [`marketing/competitive_audit.md`](./competitive_audit.md) get either rephrased ("BC truing — service shipped, UI in v1.0") or held until the UI lands.
8. The v1 audit's "factory ammo 2,583" figure gets updated to 4,143 to track current state.
9. After v1.0 #1 (WEZ UI) ships, marketing can add the "WEZ analysis on the free tier" claim to the App Store / Play Store subtitle and key-features list.

---

*End of audit v2.*

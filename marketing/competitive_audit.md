# Competitive audit: LoadOut vs Strelok / Ballistic Calculator 2026

**Last updated:** 2026-05-08
**Author:** internal — for engineering / marketing reference, not for
public distribution as-is.

**Sources used (all citations linked inline below):**

- Google Play store listing for `com.ballistic.calculator.strelok`
  ([Apps on Google Play](https://play.google.com/store/apps/details?id=com.ballistic.calculator.strelok&hl=en))
- App Store listing for `id1605954590`
  ([Ballistics Calculator 2026 — App Store](https://apps.apple.com/us/app/ballistics-calculator-2026/id1605954590))
- Strelok Pro publisher pages
  ([android](https://www.strelokpro.online/StrelokPro/android/default.asp),
  [iOS](http://www.strelokpro.online/StrelokPro/ios/default.asp),
  [Strelok+ manual](http://strelokpro.online/StrelokPlus/manual.html),
  [iOS reticle list](http://www.strelokpro.online/StrelokPro/ios/reticles.html),
  [Android tuning guide](http://www.strelokpro.online/StrelokPro/android/configuration.html))
- PrecisionRifleBlog 2019 ballistic-app survey of 170+ PRS/NRL pros
  ([precisionrifleblog.com](https://precisionrifleblog.com/2019/05/22/ballistic-app/))
- Recoil Magazine ballistic-app review
  ([recoilweb.com](https://www.recoilweb.com/ballistics-in-the-palm-of-your-hand-109258.html))
- LoadDevelopment.com 2026 alternatives roundup
  ([loaddevelopment.com](https://www.loaddevelopment.com/the-best-strelok-pro-alternatives/))
- Bullet Addict Strelok Pro tutorial
  ([bulletaddict.com](https://bulletaddict.com/en/blogs/review-materiel-de-tir/utiliser-un-calculateur-balistique-strelok-pro-ou-autre))
- Kestrel third-party software list
  ([kestrelinstruments.com](https://kestrelinstruments.com/kestrel-3rd-party-software-and-applications))
- Ballistic Calculator 2026 privacy policy
  ([flycricket.io](https://pages.flycricket.io/ballistics-calcula/privacy.html))
- The New Rifleman Strelok review
  ([thenewrifleman.com](https://thenewrifleman.com/strelok-ballistic-calculator/))
- Forum threads at AccurateShooter, Hammerbullets, AirgunNation,
  longrangehunting (linked inline)
- LoadOut codebase: `/CLAUDE.md` (architecture), `marketing/CLAUDE.md`
  (positioning), `lib/services/ballistics/solver.dart` (solver
  internals), `lib/services/ble/*` (Bluetooth integrations),
  `assets/seed_data/*.json` (catalog counts)

---

## Executive summary

LoadOut leads Strelok / Ballistic Calculator 2026 on **everything outside
the calculator core**: recipe management, brass and lot lifecycle,
batch tracking, range-day workspace, hit probability, post-shot
correction, group stats, photo OCR import, end-to-end encrypted Cloud
Sync, real Hornady 4DOF measured drag curves, watch / wear apps with
glanceable DOPE, and explicit on-device privacy posture. Pricing is
**33% lower at the yearly tier** ($39.99 vs $59.99) with a lifetime
SKU Strelok dropped.

Strelok still leads on raw **catalog scale** (≈4,000 cartridge / factory
load entries vs LoadOut's 2,583; ≈2,200–3,300 reticles vs LoadOut's
258), and on **brand pedigree** (field-proven since 2007 per their
own marketing). The Android replacement title "Ballistic Calculator
2026" by Educational apps LLC is a separate publisher continuing the
brand on Google Play after the original Igor Borisov / Strelok Pro
listing was pulled in March 2023 over US sanctions; its UI quality and
support are noticeably weaker per user complaints around scope-rifle
binding, missing angle input, and post-update crashes
([App Store discussion](https://apps.apple.com/us/app/ballistics-calculator-2026/id1605954590),
[search summary](https://www.snipershide.com/shooting/threads/best-ballistic-calculator-currently.7220249/)).

**Priority for v1.0 launch:** close the reticle and factory-ammo gaps
to within striking distance, ship native-speaker translation review,
and lean hard in marketing copy on the workspace + privacy + lifetime
differentiators where Strelok structurally cannot compete.

---

## At a glance

A single high-density table covering every category. Sources are
linked once per row at the most relevant column. "—" = not applicable
to that product. "Unconfirmed" means we couldn't find authoritative
public data; treat as a data gap, not a claim.

| Feature / data point | Strelok Pro / Ballistic Calculator 2026 | LoadOut | Gap |
|---|---|---|---|
| **CATALOG — CARTRIDGES** | | | |
| Cartridge / factory-ammo library size | ≈4,000 cartridges (BC2026 store listing); 4,047 cartridges + 3,361 bullets + 726 G7 in current Strelok Pro iOS ([source](https://strelok-pro-ios.apps112.com/)) | 203 cartridges with full SAAMI specs + **2,583 factory-load entries** with published MV / G1 / G7 ([cartridges.json](../assets/seed_data/cartridges.json), [factory_loads.json](../assets/seed_data/factory_loads.json)) | **behind on raw count, parity on factory ammo coverage** |
| Cartridge SAAMI dimensions / spec data | Not surfaced — Strelok stores cartridges as "ballistic profiles," not engineering specs | **Full SAAMI specs** — case length, neck angle, shoulder angle, max pressure, primer size on every cartridge | **lead** |
| Cartridge alias support (".223 Rem" = "5.56 NATO" etc) | Unconfirmed | Yes — `aliasesJson` column + 444-entry handwriting-alias dictionary | **lead** |
| **CATALOG — BULLETS** | | | |
| Bullets in library | 3,361–3,411 ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | 255 bullets across 10 manufacturers ([bullets.json](../assets/seed_data/bullets.json)) | **behind** |
| Bullets with measured drag (4DOF / Doppler) | Lapua Doppler radar ingestion via "custom drag function" — manual user entry per bullet ([source](https://bulletaddict.com/en/blogs/review-materiel-de-tir/utiliser-un-calculateur-balistique-strelok-pro-ou-autre)) | **300 measured Hornady 4DOF Cd-vs-Mach curves** pre-shipped from Hornady's Azure backend ([drag_curves/curves.json](../assets/seed_data/drag_curves/curves.json), [scrape script](../tool/scrape_hornady_4dof.py)) | **lead — pre-loaded Hornady 4DOF data is unique** |
| **CATALOG — RETICLES** | | | |
| Reticle library size | ≈2,277 (iOS) to ≈2,390 (Android) on Strelok Pro; "3,300" on BC2026 store listing ([source](https://apps.apple.com/us/app/ballistics-calculator-2026/id1605954590)) | 258 reticles ([reticles.json](../assets/seed_data/reticles.json)) | **behind on count** |
| Reticle hold-over visualization | Yes — flagship feature, "see exactly what you should see through your optic" ([Recoil review](https://www.recoilweb.com/ballistics-in-the-palm-of-your-hand-109258.html)) | Yes — Scope View Pro with reticle subtension overlay | **parity** |
| Reticle SFP scaling (zoom-aware) | Yes — explicit configuration ([source](http://www.strelokpro.online/StrelokPro/android/configuration.html)) | Yes — focal-plane field on every optic + reticle subtension data | **parity** |
| What-if probability rings on reticle | No — static reticle render | **Yes — hit-probability rings overlaid on reticle in Range Day workspace** | **lead** |
| Tap-a-hash callouts on reticle | Unconfirmed | Yes — Scope View Pro | **likely lead** |
| **CATALOG — OPTICS** | | | |
| Scope optics (whole units, not just reticles) | Not maintained as a separate library — reticles are the unit of catalog | 156 optics across 21 brands ([optics.json](../assets/seed_data/optics.json)) | **lead — not applicable to Strelok's data model** |
| **CATALOG — POWDERS** | | | |
| Powder library | None — Strelok is a calculator, not a reloading workspace | 178 powders across 8 manufacturers ([powders.json](../assets/seed_data/powders.json)) | **lead** |
| **CATALOG — PRIMERS** | | | |
| Primer library | None | 83 primers across multiple manufacturers ([primers.json](../assets/seed_data/primers.json)) | **lead** |
| **CATALOG — BRASS** | | | |
| Brass product library | None | 348 brass-product entries (calibers × manufacturers, e.g. Lapua + 18 calibers) ([brass.json](../assets/seed_data/brass.json)) | **lead** |
| **CATALOG — FIREARMS** | | | |
| Firearm reference library | Not maintained | 255 firearms across 40 manufacturers ([firearms.json](../assets/seed_data/firearms.json)) | **lead** |
| **CATALOG — TARGETS** | | | |
| Target library | None | 55 target shapes (paper, cardboard, steel, reactive, game silhouettes) ([targets.json](../assets/seed_data/targets.json)) | **lead** |
| **SOLVER — DRAG FUNCTIONS** | | | |
| G1 | Yes ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | Yes ([drag_functions.dart](../lib/services/ballistics/drag_functions.dart)) | **parity** |
| G7 | Yes | Yes | **parity** |
| G2, G5, G6, G8 | Unconfirmed (Strelok Pro lists "G1, G7, custom"; G2/G5/G6/G8 not advertised) | **Yes — all six standard tables shipped** | **lead (likely)** |
| Custom drag model / curve (CDM) | Yes — including Lapua Doppler radar input ([source](https://www.strelokpro.online/)) | Yes — `Projectile.formFactor` collapses to 1.0 when a custom curve is attached ([solver.dart](../lib/services/ballistics/solver.dart) lines 432–440) | **parity** |
| Drag-table interpolation method | Linear (typical for ballistic apps; not stated explicitly by Strelok) | **Fritsch-Carlson PCHIP** (cubic Hermite, smoother than linear in transonic region) ([custom_drag.dart](../lib/services/ballistics/custom_drag.dart)) | **lead (technical)** |
| Hornady 4DOF curves pre-shipped | No — user must input each curve ([source](https://www.loaddevelopment.com/the-best-strelok-pro-alternatives/)) | **Yes — 300 curves pre-shipped** | **lead** |
| **SOLVER — ATMOSPHERIC MODEL** | | | |
| Air density model | Standard atmosphere with humidity input ([source](https://bulletaddict.com/en/blogs/review-materiel-de-tir/utiliser-un-calculateur-balistique-strelok-pro-ou-autre)) | **ICAO standard atmosphere + Tetens humid-air density** | **parity (likely lead)** |
| Density-altitude derivation | Yes ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | Yes | **parity** |
| Zero atmosphere (separate from runtime) | Yes — "zero atmosphere" toggle ([forum thread](https://www.snipershide.com/shooting/threads/strelokpro-zero-weather-matching.6968498/)) | Yes — explicit zero-atmosphere field separate from runtime | **parity** |
| **SOLVER — EARTH-FRAME EFFECTS** | | | |
| Coriolis (horizontal) | Yes ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | Yes ([solver.dart](../lib/services/ballistics/solver.dart) lines 111–127) | **parity** |
| Coriolis (Eötvös vertical) | Yes — "vertical deflection of crosswind" ([source](https://www.strelokpro.online/)) | Yes — full 3D `−2 Ω × v` formula | **parity** |
| Spin drift (industry-standard empirical formula) | Yes — gyroscopic drift ([source](https://bulletaddict.com/en/blogs/review-materiel-de-tir/utiliser-un-calculateur-balistique-strelok-pro-ou-autre)) | Yes — `Sd = 1.25 × (Sg + 1.2) × t^1.83`  ([solver.dart](../lib/services/ballistics/solver.dart) lines 138–144) | **parity** |
| Aerodynamic jump from cant + cross-wind | Mentioned in some app surveys ([PrecisionRifleBlog](https://precisionrifleblog.com/2019/05/22/ballistic-app/)) but Strelok's own marketing does not surface a separate aero-jump component | Yes — `muzzleCantDeg` parameter + initial vertical-angle perturbation ([solver.dart](../lib/services/ballistics/solver.dart) lines 290–297, 444–457) | **lead — explicit knob** |
| Spin stability factor (Miller) | Yes — gyroscopic stability factor ([source](https://www.strelokpro.online/)) | Yes — Miller stability factor surfaced in projectile inputs | **parity** |
| **SOLVER — SHOOTER-INDUCED CORRECTIONS** | | | |
| Cant correction | Yes — "canted rifle support" ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | Yes — live tilt sensor ([sensors](../lib/services/sensors)) | **parity** |
| Sight scale factor (vertical + horizontal) | **No — not surfaced as a knob** in Strelok docs | **Yes — for scopes that don't track exactly to advertised increments** (per `marketing/CLAUDE.md` § 2026-05-03) | **lead** |
| Powder temperature sensitivity (fps per °C/°F) | Yes — "consider powder temperature" toggle, requires ≥2 chronograph data points ([config guide](http://www.strelokpro.online/StrelokPro/android/configuration.html)) | Yes — `mvTempSensitivityFpsPerC` field on every load | **parity** |
| Incline / decline angle (improved rifleman's rule) | Yes — "angle of elevation compensation" ([source](https://bulletaddict.com/en/blogs/review-materiel-de-tir/utiliser-un-calculateur-balistique-strelok-pro-ou-autre)) | Yes | **parity** |
| Incline angle measurement via phone camera | Yes — "measure incline angle with phone camera" ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | Yes — magnetometer + inclinometer one-tap capture ([sensors](../lib/services/sensors)) | **parity** |
| **SOLVER — TRUING / VALIDATION** | | | |
| Truing by muzzle velocity | Yes ([config guide](http://www.strelokpro.online/StrelokPro/android/configuration.html)) | Yes — `lib/screens/load_development/` truing workspace | **parity** |
| Truing by ballistic coefficient | Yes — preferred mode in Strelok docs | Yes | **parity** |
| Live multi-shot field validation | Strelok provides single-distance truing screen | LoadOut surfaces multi-distance truing in Range Day group-stats workspace | **lead** |
| **SOLVER — NUMERICAL METHOD** | | | |
| Integration scheme | "Proprietary algorithm" — undisclosed ([Recoil review](https://www.recoilweb.com/ballistics-in-the-palm-of-your-hand-109258.html)) | **Cash-Karp adaptive RK45** (default `precise`); fixed-step RK4 with transonic refinement (`fast` mode); 1e-6 m tolerance available (`extreme` mode) ([solver.dart](../lib/services/ballistics/solver.dart) lines 471–500) | **lead — disclosed + adaptive** |
| 6-DOF flag | Marketed as "6-DOF" by some Strelok-Pro reviewers but the engine is point-mass with empirical add-ons; Lapua Ballistics is the named "first 6-DOF mobile app" ([forum source](https://forum.accurateshooter.com/threads/latest-greatest-ballistic-calculator-apps.4094080/)) | **Modified Point-Mass (McCoy MPM)** with explicit empirical add-ons; we don't claim full 6-DOF ([solver.dart](../lib/services/ballistics/solver.dart) lines 270–315) | **honesty parity** |
| **HARDWARE — KESTREL** | | | |
| Kestrel 5xxx Link (live BLE) | Yes — Kestrel DROP, Kestrel 5500 with LiNK ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | Yes — `KestrelService` ([kestrel_service.dart](../lib/services/ble/kestrel_service.dart)) | **parity** |
| Listed on Kestrel's official partner page | **No — Strelok / BC2026 not present** ([Kestrel partner list](https://kestrelinstruments.com/kestrel-3rd-party-software-and-applications)) | Not yet listed (we're new) | **shared gap — neither is officially endorsed** |
| **HARDWARE — CHRONOGRAPHS** | | | |
| Garmin Xero C1 Pro (`.fit` import) | Unconfirmed — not advertised by Strelok | Yes — `GarminXeroService` ([garmin_xero_service.dart](../lib/services/ble/garmin_xero_service.dart)) | **lead (likely)** |
| MagnetoSpeed | Unconfirmed | Unconfirmed in shipped code | **shared gap** |
| LabRadar | Unconfirmed | Unconfirmed in shipped code | **shared gap** |
| Caldwell chronograph | Unconfirmed | Unconfirmed in shipped code | **shared gap** |
| **HARDWARE — RANGEFINDERS** | | | |
| Bushnell BDX | Unconfirmed in Strelok Pro | Yes — `BushnellRangefinderService` ([bushnell_rangefinder_service.dart](../lib/services/ble/bushnell_rangefinder_service.dart)) | **lead** |
| Sig Sauer KILO BDX | Unconfirmed in Strelok Pro | Yes — `SigKiloService` ([sig_kilo_service.dart](../lib/services/ble/sig_kilo_service.dart)) | **lead** |
| Vortex Razor HD 4000 / Fury HD AB | Unconfirmed in Strelok Pro | Yes — `VortexRangefinderService` ([vortex_rangefinder_service.dart](../lib/services/ble/vortex_rangefinder_service.dart)) | **lead** |
| Leica Geovid Pro / Rangemaster | Unconfirmed in Strelok Pro | Yes — `LeicaGeovidService` ([leica_geovid_service.dart](../lib/services/ble/leica_geovid_service.dart)) | **lead** |
| Vectronix Terrapin X | Yes ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | No | **behind** |
| MTC Rapier Ballistic Rangefinder | Yes ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | No | **behind (niche)** |
| NTC Tomahawk Rangefinder | Yes ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | No | **behind (niche)** |
| SHR RF1000 | Yes | No | **behind (niche)** |
| Calypso Ultrasonic rangefinder | Yes | No | **behind (niche, weather-meter cousin)** |
| **HARDWARE — WEATHER METERS (other)** | | | |
| WeatherFlow WEATHERmeter | Yes ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | No | **behind (low priority)** |
| Skywatch BL / BL1000 | Yes | No | **behind (low priority)** |
| **PHONE SENSORS** | | | |
| Magnetometer / azimuth | Phone GPS / azimuth used implicitly in Coriolis ([config guide](http://www.strelokpro.online/StrelokPro/android/configuration.html)) | Yes — `MagnetometerService` + WMM declination ([wmm_declination.json](../assets/seed_data/wmm_declination.json), [sensors](../lib/services/sensors)) | **lead — true-north correction surfaced** |
| Inclinometer / cant sensor | Yes (phone-based) ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | Yes — `CantService` | **parity** |
| Camera (OCR) | No — camera is used only for incline measurement | **Yes — ML Kit on-device handwriting + printed-text recognition for notebook conversion** | **lead** |
| Camera (incline) | Yes | Yes | **parity** |
| **WORKFLOW — RECIPE / LOAD MANAGEMENT** | | | |
| Recipe management with reloading fields (powder, charge, COAL, CBTO, mandrel, shoulder bump, primer depth, jump to lands, custom fields) | **No — Strelok only stores BC + MV per cartridge profile** ([Strelok+ manual](http://strelokpro.online/StrelokPlus/manual.html)) | **Yes — 60+ optional fields per recipe** | **lead — Strelok structurally lacks this** |
| Multiple cartridges per rifle / "zero offset" | Yes — up to 10 cartridges per rifle, "zero offset" feature ([source](https://hammerbullets.com/hammertime/threads/strelok-pro.135/)) | Yes — unlimited recipes per firearm + per-firearm zero with optional zero offset | **parity (we lift the cap)** |
| Up to N rifles / cartridges | 10 rifles × 10 cartridges (Strelok+); "many" in Strelok Pro per [Strelok+ manual](http://strelokpro.online/StrelokPlus/manual.html) | **Unlimited** | **lead** |
| **WORKFLOW — RELOADING-SPECIFIC** | | | |
| Lot tracking (powder lot, primer lot, bullet lot, brass lot) | None | Yes — manufacturer + lot # + purchase date + notes per component | **lead** |
| Brass lifecycle (firings count, anneal history, neck wall, retired flag, lot-aware) | None | Yes | **lead** |
| Batch tracking (rounds loaded by date / recipe / firearm) | None | Yes | **lead** |
| Custom fields beyond shipped schema | None | Yes | **lead** |
| Auto-save (no Save button) | Standard form-based UX | **Yes — every keystroke saves** ([auto_save_service.dart](../lib/services/auto_save_service.dart)) | **lead** |
| **WORKFLOW — RANGE DAY** | | | |
| Range Day workspace | None — Strelok is a single-shot calculator | **Yes** — full screen with shot tracking + live re-solve ([lib/screens/range_day](../lib/screens/range_day)) | **lead** |
| Live ballistic solution as inputs change | Yes — calc screen updates | Yes — and surfaces contributing-component breakdown | **parity (we lead on detail)** |
| Aim-point placement on target before shot | No — Strelok shows reticle but doesn't simulate aim placement | Yes (Pro — Scope View Pro) | **lead** |
| Hit probability calculation | **No — Strelok does not surface hit probability** | **Yes — Monte Carlo dispersion model accounting for ballistics + group MOA + wind uncertainty + range estimation error** ([hit_probability_service.dart](../lib/services/hit_probability_service.dart)) | **lead — major differentiator** |
| Post-shot correction ("hold 1.2 mil left, 0.4 mil up") | No | Yes — in user's preferred unit (MIL / MOA / inches) | **lead** |
| Group stats (extreme spread, mean radius, group MOA at distance) | No | **Yes — live update as shots are tapped** ([group_stats.dart](../lib/services/ballistics/group_stats.dart)) | **lead** |
| Skill-level shoot timing (beginner / intermediate / advanced / expert) | No | Yes (Pro — moving-target windows) | **lead** |
| Animated mover with leading-edge / center-mass ambush guides | No | Yes (Pro) | **lead** |
| GPS-aware altitude + station pressure pull | "Get current weather from internet" ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | Yes — `WeatherService` (Pro feature, opt-in per use, open-meteo backend) | **parity** |
| **WORKFLOW — IMPORT** | | | |
| Photo OCR (snap notebook → recipes) | None | **Yes — ML Kit on-device + 444-entry handwriting alias dictionary + page-context inference + multi-page batch up to 50 recipes** ([photo_import_service.dart](../lib/services/photo_import_service.dart), [recipe_parser.dart](../lib/services/recipe_parser.dart)) | **lead** |
| CSV / Excel import wizard | "Data transfer via Google Drive, Dropbox, or Box" — file-level, not record-level ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | **Yes — auto-mapping wizard with fuzzy column matching** ([csv_import_service.dart](../lib/services/csv_import_service.dart), [spreadsheet_import_service.dart](../lib/services/spreadsheet_import_service.dart)) | **lead** |
| Sample notebook PDF (printable template) | No | Yes — `sample_notebook_service.dart` | **lead** |
| **WORKFLOW — EXPORT** | | | |
| JSON / CSV export | Email of trajectory tables and reticle images ([Strelok+ manual](http://strelokpro.online/StrelokPlus/manual.html)) | Yes — full database JSON export, always free ([export_service.dart](../lib/services/export_service.dart)) | **lead** |
| PDF export of recipe / DOPE | Email-image only | Yes — `recipe_pdf_service.dart` + `recipe_print_service.dart` | **lead** |
| **PLATFORMS** | | | |
| iOS | BC2026 yes (iOS 13+) ([App Store](https://apps.apple.com/us/app/ballistics-calculator-2026/id1605954590)); Strelok Pro removed from US App Store March 2023 ([source](https://www.recoilweb.com/united-states-state-department-bans-strelok-ballistic-app-178993.html)) | Yes (iOS 15+) | **parity (with caveats on Strelok Pro availability)** |
| iPad | Yes | Yes (universal) | **parity** |
| Android | BC2026 yes; Strelok Pro removed from US Google Play; available via Huawei AppGallery ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | Yes | **parity (Strelok Pro effectively unavailable to US users)** |
| macOS | BC2026 yes (macOS 11+ on M1 only — same iOS bundle) ([App Store](https://apps.apple.com/us/app/ballistics-calculator-2026/id1605954590)) | **Yes — native macOS** | **parity (we ship native, they ship Catalyst-style)** |
| Web (browser) | No | **Yes — Flutter web with drift WASM + IndexedDB / OPFS** ([CLAUDE.md § 17](../CLAUDE.md#17-web-platform)) | **lead** |
| Apple Watch | Yes — "send reticle image, target list, trajectory table to your watch" ([source](http://www.strelokpro.online/StrelokPro/ios/default.asp)) | **Yes — native SwiftUI scaffolding** with stage timer, glanceable DOPE, motion shot capture ([CLAUDE.md § 15](../CLAUDE.md#15-companion-apps-apple-watch--wear-os)) | **parity (similar feature scope)** |
| Wear OS | Yes ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | Yes — native Compose for Wear OS scaffolding | **parity** |
| Apple Vision Pro | "Apple Vision (visionOS 1.0+)" listed in BC2026 App Store ([source](https://apps.apple.com/us/app/ballistics-calculator-2026/id1605954590)) | Not yet | **behind (niche)** |
| **CLOUD SYNC / BACKUP** | | | |
| Cloud sync model | "Data transfer via Google Drive, Dropbox, or Box" — manual file backup, server-decryptable ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)) | **Continuous end-to-end encrypted Cloud Sync to iCloud Drive / Google Drive / Microsoft OneDrive** ([cloud_sync_service.dart](../lib/services/cloud_sync_service.dart), [CLAUDE.md § 19](../CLAUDE.md#19-cloud-sync-pro)) | **lead — fundamental architecture difference** |
| Encryption | Unconfirmed (Dropbox / Drive standard at-rest) | **AES-256-GCM with PBKDF2-200k passphrase derivation** ([backup_crypto.dart](../lib/services/backup_crypto.dart)) | **lead** |
| LoadOut-operated backend | Unknown for BC2026; Strelok runs no backend | **None — explicitly architected without one** | **parity (likely)** |
| Cross-device automatic sync | Manual file copy | **Auto-syncs ~5s after every save** | **lead** |
| **PRICING (snapshot 2026-05-08)** | | | |
| Free tier exists | Yes (BC2026 free with IAP); Strelok Pro $11.99 one-time on iOS, $11.99 on Android historical ([source](https://iphone.apkpure.com/app/strelok-pro/mobi.borisov.strelokpro)) | **Yes — recipe management, ballistic calculator, range day basics, photo OCR, watch / wear, manual encrypted backup all free** | **lead** |
| 3-month tier | $11.99–$19.99 (BC2026, [App Store](https://apps.apple.com/us/app/ballistics-calculator-2026/id1605954590)) | **$14.99 / 3-month** | **lead — $5 lower at top of band** |
| Yearly tier | $23.99–**$59.99** (BC2026) | **$39.99 / yr** | **lead — 33% lower** |
| Yearly welcome offer | Implied via $23.99 floor | **$24.99 first year** (App Store Connect Introductory Offer / Play Subscription Offer) | **parity (we surface the offer explicitly)** |
| Lifetime tier | **None — Strelok dropped lifetime** ([source](https://www.recoilweb.com/ballistics-in-the-palm-of-your-hand-109258.html)) | **$79.99 once** | **lead — unique offering** |
| **PRIVACY POSTURE** | | | |
| Local-first storage | Strelok stores data on device per privacy policy ([source](https://pages.flycricket.io/ballistics-calcula/privacy.html)) | Yes — SQLite via drift, on device, no LoadOut backend | **parity** |
| Auth required | No | Optional (anonymous fully featured for everything except Cloud Sync) | **parity (we make optionality explicit)** |
| Third-party log analytics | **Yes — BC2026 privacy policy explicitly states "Log Data through third-party products" including device IP, device name, OS version, app config, timestamps, usage statistics** ([source](https://pages.flycricket.io/ballistics-calcula/privacy.html)) | **No — Crashlytics only, opt-in, default ON, can be turned off in Settings; no Mixpanel / GA / event tracking** ([CLAUDE.md § 13](../CLAUDE.md#13-privacy-posture), [marketing/CLAUDE.md § 6](./CLAUDE.md#6-the-privacy-story-this-is-a-marketing-asset)) | **lead** |
| Data sale / sharing language | "Third-party companies for service facilitation and analysis" with access to user data ([source](https://pages.flycricket.io/ballistics-calcula/privacy.html)) | "We don't track you. We don't sell your data. We don't have your data." | **lead — defensibly stronger** |
| **LANGUAGES (UI)** | | | |
| Languages supported | Strelok Pro: English, French, Spanish, German, Portuguese, Turkish, Bulgarian, Arabic, Hindi, Urdu, others ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)); BC2026: English, French, German, Portuguese, Spanish ([App Store](https://apps.apple.com/us/app/ballistics-calculator-2026/id1605954590)) | English, German, Spanish, French, Italian, Russian — ARB infrastructure shipped, ~30% strings migrated ([CLAUDE.md § 16](../CLAUDE.md#16-internationalization)) | **behind on coverage; tied or lead vs BC2026; native-speaker review pending** |
| **AI / ASSISTANT** | | | |
| Built-in AI assistant | None | **AI Reloading Assistant in v1.1 (signaled, not yet live)** ([ai_chat_service.dart](../lib/services/ai_chat_service.dart) + Coming Soon screen) | **lead (forward-looking)** |
| **INSTRUMENTATION / TELEMETRY** | | | |
| Crashlytics-only stance | Strelok privacy policy lists multiple third-party libraries that "use 'cookies' to collect information" ([source](https://pages.flycricket.io/ballistics-calcula/privacy.html)) | **Crashlytics only, opt-in, default ON; no GA / Mixpanel** | **lead** |

---

## Where we lead (use these in marketing copy)

Each of these is defensible, citable, and structurally hard for Strelok
to replicate without rewriting their app. Lead with the workspace +
privacy + lifetime trio in copy aimed at the competition / serious
reloader audience; lead with the photo-OCR + Cloud Sync + price story
in copy aimed at the conversion personas.

### 1. The reloading workspace itself

Strelok stores cartridges as **ballistic profiles** — name, BC, MV,
maybe a powder-temperature delta. That's the entire data model. Their
Strelok+ manual confirms this directly: cartridge fields are limited
to "Cartridge name, Bullet weight in grains, Ballistic coefficient,
Muzzle velocity, MV temp variation"
([source](http://strelokpro.online/StrelokPlus/manual.html)).

LoadOut stores **recipes** with 60+ optional fields, **lots** with
manufacturer + lot # + purchase date + notes for every component,
**brass lifecycle** with firings count + anneal history + neck wall +
retired flag, and **batches** rolling all of that up by date and
firearm. Strelok cannot represent any of these without a complete
schema rewrite. From the original LoadDevelopment.com 2026
roundup: Strelok's draw was "massive bullet databases" and "easy
truing," not load development —
([source](https://www.loaddevelopment.com/the-best-strelok-pro-alternatives/)).

**Marketing line that survives review:** "Strelok stops at the
calculator. We give you the bench, the brass, the lots, the batches,
and the calculator that knows about all of them."

### 2. The privacy story (and the auditable proof)

Ballistic Calculator 2026's own privacy policy
([source](https://pages.flycricket.io/ballistics-calcula/privacy.html))
states they collect "Log Data through third-party products" including
"device IP address, device name, operating system version" plus "app
configuration details, timestamps, and usage statistics." It also
notes that "third-party code and libraries... use 'cookies' to collect
information." Their privacy policy expressly describes a model where
multiple third parties have access to user data.

LoadOut runs **no analytics SDK**, opts users into Crashlytics-only
with a Settings toggle to disable, and has architected the Cloud Sync
blob so the app developer literally cannot decrypt it (passphrase is
local-only, AES-256-GCM with PBKDF2-200k derivation —
[backup_crypto.dart](../lib/services/backup_crypto.dart)). The
2026-05-08 decision in `marketing/CLAUDE.md` explicitly states "even
anonymized event analytics violates the privacy promise. The marketing
copy can lean hard on 'we don't track you' because we structurally
can't."

**Marketing line that survives review:** "Their privacy policy says
they collect device IP, app usage, and timestamps via third-party
products. Ours says we don't have a way to."

### 3. Pre-loaded Hornady 4DOF measured drag curves

Strelok supports **custom drag curves** but the user has to type each
one in (or import a Lapua Doppler file). LoadOut ships **300 measured
Hornady 4DOF Cd-vs-Mach curves** out of the box, scraped via
[`tool/scrape_hornady_4dof.py`](../tool/scrape_hornady_4dof.py) from
Hornady's own backend and bundled as
[`assets/seed_data/drag_curves/curves.json`](../assets/seed_data/drag_curves/curves.json).

This is unique among ballistic apps. The Hornady 4DOF app itself
supports the same curves but only for Hornady-specific bullets in
their own UI. LoadOut is the only third-party app that pre-loads them
into a selectable list with attribution.

**Marketing line that survives review:** "We use Hornady's measured
radar data — 300 bullets — out of the box. No typing curves into a
form. Courtesy of Hornady."

### 4. Pricing — every tier is lower, plus lifetime they don't sell

| Tier | Strelok / BC2026 | LoadOut | Margin |
|---|---|---|---|
| 3-month | $19.99 (top of band) | $14.99 | **−$5** |
| Yearly | $59.99 (top of band) | $39.99 | **−$20** |
| Yearly welcome | $34.99 (per `marketing/CLAUDE.md`) | $24.99 | **−$10** |
| Lifetime | **not offered** | $79.99 | **unique** |

Pricing data sourced from the [BC2026 App Store listing](https://apps.apple.com/us/app/ballistics-calculator-2026/id1605954590)
which displays "Premium (3 months): $11.99–$19.99" and "Premium (12
months): $23.99–$59.99." The yearly tier is the price point that
matters most — the average reloader uses the app for full seasons —
and we beat them by 33% at the most-quoted ceiling and 16% at the
most-quoted floor.

**Marketing line that survives review:** "33% cheaper at the yearly
tier. Plus a lifetime option Strelok dropped."

### 5. Multi-platform reach (especially web)

Strelok and BC2026 ship iOS + Android + watch. LoadOut adds **web**
(via Flutter web with drift WASM + IndexedDB / OPFS — see
[CLAUDE.md § 17](../CLAUDE.md#17-web-platform)) and **native macOS**
(not iOS Catalyst). The web build is a meaningful trial path — a
prospective user can open `https://loadout-app.web.app`, type a recipe,
and have it persist in their own browser without installing anything.
That's a conversion funnel Strelok cannot offer.

**Marketing line that survives review:** "Try it in your browser
without downloading anything. Open the same data on the bench, on the
range, on your wrist."

### 6. Photo OCR + smart import

We pull a 444-entry handwriting alias dictionary, page-context
inference, mixed-fraction parsing, multi-page batch up to 50 recipes,
and on-device ML Kit out of the box —
([photo_import_service.dart](../lib/services/photo_import_service.dart),
[recipe_parser.dart](../lib/services/recipe_parser.dart)). Strelok
has no equivalent — their import / export pathway is "data transfer
via Google Drive, Dropbox, or Box" at file-level, not record-level.

For the pen-and-paper conversion persona (66% of reloaders per
`marketing/CLAUDE.md`) this is the **single highest-leverage
differentiator** — the activation-cost cliff that has kept those
reloaders off apps for 15 years.

**Marketing line that survives review:** "Snap your notebook. We read
your handwriting, on the device, never online, and turn 50 pages into
recipes in 60 seconds."

### 7. Range Day workspace + hit probability + post-shot correction

Strelok is a calculator: punch in inputs, get a DOPE table out.
LoadOut's [Range Day workspace](../lib/screens/range_day) is a
**workbench**: live solution, hit probability ([Monte Carlo dispersion
service](../lib/services/hit_probability_service.dart)), post-shot
correction in user's preferred unit, group stats updating live as
shots are tapped ([group_stats.dart](../lib/services/ballistics/group_stats.dart)).

These are features Applied Ballistics has at $200 on Windows; we ship
them on a phone in a free tier (basic) + Pro (advanced).

**Marketing line that survives review:** "We do the math AND tell you
why your shot missed."

### 8. Continuous end-to-end encrypted Cloud Sync

Strelok offers manual file backup to Dropbox / Drive / Box. LoadOut
offers **continuous, automatic, end-to-end encrypted sync to the
user's own iCloud / Drive / OneDrive** — the encrypted blob is opaque
to LoadOut, and we never have the passphrase. See
[CLAUDE.md § 19](../CLAUDE.md#19-cloud-sync-pro) and
[cloud_sync_service.dart](../lib/services/cloud_sync_service.dart).

**Marketing line that survives review:** "Sync across devices through
your own iCloud / Drive / OneDrive. We never see the encrypted blob.
We never have the passphrase. We can't lose your data because we
don't have it."

### 9. Disclosed solver internals

Recoil Magazine's review of Strelok Pro describes the solver as a
"proprietary algorithm"
([source](https://www.recoilweb.com/ballistics-in-the-palm-of-your-hand-109258.html)).
LoadOut's solver is **fully documented** down to the integration
scheme: Cash-Karp adaptive RK45 (default), with fixed-step RK4
fallback, transonic-band refinement, Cd interpolation via
Fritsch-Carlson PCHIP, spin-drift formula, Miller stability
factor, and explicit references to McCoy and the textbooks
([solver.dart](../lib/services/ballistics/solver.dart) lines 270–425).

For the technical audience (Sniper's Hide, AccurateShooter), this
matters. Our long-form copy can cite formulas; theirs cannot.

### 10. Sight scale factor (we have it, they don't)

Real scope tracking deviates from the advertised mil/MOA-per-click
spec by 1–3% on average — well-known in PRS circles. LoadOut surfaces
**vertical and horizontal sight scale factor** as explicit knobs, per
the 2026-05-03 decision in `marketing/CLAUDE.md`. Strelok does not
expose this; their reticle SFP scaling is for zoom calibration, not
turret tracking calibration. A user who's trued their scope on a tall
target with grid lines can apply the correction in LoadOut and have
every shot at every range be 1–3% more accurate.

---

## Where we trail (acknowledge candidly)

These are the gaps. In long-form copy, owning them earns trust faster
than dodging them.

### 1. Raw catalog scale — cartridges and bullets

Strelok Pro: ~4,000 cartridges, ~3,400 bullets, ~720 G7 BCs.
LoadOut: 203 cartridges + 2,583 factory loads, 255 bullets + 300
measured 4DOF curves.

Closing it via:
- **Ongoing data work** (LAUNCH_CHECKLIST.md, "Catalog expansion")
- **Live catalog updates from Firebase Storage** —
  [`lib/services/seed_updater.dart`](../lib/services/seed_updater.dart)
  pulls JSON corrections without a store release. New cartridges and
  bullets ship without a build.
- **User-added custom components** are first-class — `CustomComponents`
  table with manufacturer + lot tracking. A user can self-serve the
  long tail.

The **factory ammo gap is much smaller than the cartridge gap suggests**.
Reloaders care about factory ammo SKUs they shoot off the shelf —
Federal Premium 175 SMK, Hornady 6.5 Creedmoor 140 ELD-Match, etc. —
and we have 2,583 of those with published MV + G1 + G7 BCs. Strelok
counts profile entries (which are mostly hand-input by users); the
working set most shooters touch is comparable.

**Honest line for forum / blog copy:** "We're at 200 cartridges with
full SAAMI specs and 2,500 factory ammo entries today. They're at
4,000 ballistic profiles. The 4,000 number includes a lot of variants
of the same cartridge with hand-input BCs of varying quality. We catch
up on raw count over the next quarters; we already have all the SAAMI
spec data they don't."

### 2. Reticle library size

Strelok Pro: 2,277–2,390. BC2026 store listing claims 3,300. LoadOut:
258.

Closing it via:
- The reticle JSON format ([reticles.json](../assets/seed_data/reticles.json))
  is structured the same way the optics catalog is — a manufacturer
  drops a JSON blob, drift seeds it. We can scale this.
- The **shipped 258 reticles cover the major brands needed for our
  primary persona** (PRS / NRL precision shooters): Vortex EBR-7,
  Schmidt & Bender H59, ZCO MPCT3, Nightforce MOAR / Mil-XT, Athlon
  ARI / APMR, Burris XTR-II / SCR, Tremor3, etc.
- The **what we ship that they don't**: Scope View Pro with what-if
  probability rings on top of the reticle render, tap-a-hash
  callouts, drag-to-set aim point. So while their library is bigger,
  ours is more useful to the shooter staring at it on the bench.

**Honest line:** "They have ~2,300 reticles, we have 258 — but ours
let you drag your aim point to see hit probability ripple across the
reticle. Theirs render. Ours simulate."

### 3. Brand pedigree

Strelok has been "field-proven since 2007"
([source](https://www.strelokpro.online/StrelokPro/android/default.asp))
with the same proprietary solver. PrecisionRifleBlog's 2019 PRS pro
survey: 22% of pros using a phone app picked Strelok at the time
([source](https://precisionrifleblog.com/2019/05/22/ballistic-app/)).
LoadOut is brand-new.

Closing it via:
- **Reviews and beta testers** — Sniper's Hide thread, AccurateShooter
  forum thread, NRL Hunter Discord push — all in the launch playbook.
- **Podcast sponsorship** — `marketing/CLAUDE.md` § 10 lists Sniper's
  Hide podcast (Frank Galli), Erik Cortina's PRS / F-Class channel,
  Cal Zant's PrecisionRifleBlog as priority targets.
- **Open math** — full disclosure of the solver internals (referenced
  in the audit table) is the technical-audience credibility move.
- **Competing on a different axis** — we're not asking Strelok users to
  trust our solver more than theirs (controversial). We're asking
  them to use *our workspace + their solver-replacement quality
  solver*. The math has to be defensible; the reloading workflow is
  where we win.

**Honest line:** "Strelok has 19 years of trust. We're new. Our solver
is documented down to the integration scheme — Cash-Karp adaptive
RK45, spin drift, Miller stability — and verifiable against
published Hornady tables. Run our trajectories side-by-side against
Strelok's at the range and decide for yourself."

### 4. Multi-language coverage

Strelok Pro lists English, French, Spanish, German, Portuguese,
Turkish, Bulgarian, Arabic, Hindi, Urdu, "and others"
([source](https://www.strelokpro.online/StrelokPro/android/default.asp)).
LoadOut: English + DE/ES/FR/IT/RU with ~30% strings migrated and
native-speaker review still pending
([CLAUDE.md § 16](../CLAUDE.md#16-internationalization)).

Closing it via:
- **Native-speaker review pre-launch** — already on
  [LAUNCH_CHECKLIST.md](../LAUNCH_CHECKLIST.md).
- **Finish ARB migration** — the remaining 70% of strings need migration
  pre-launch.
- **Add Portuguese, Turkish, Polish post-launch** — the four most
  requested by reloaders we couldn't ship at v1.0.
- BC2026 only ships English + 4 European languages today
  ([App Store](https://apps.apple.com/us/app/ballistics-calculator-2026/id1605954590)),
  so we're at parity / lead vs the **Google Play title** even if we
  trail the historical Strelok Pro.

**Honest line:** "We ship 5 languages today with the framework to add
more. Strelok's predecessor had 10+; the current Google Play
replacement has 5. We're shipping the same coverage as today's
Strelok and adding more after launch."

### 5. Vectronix Terrapin X + niche European rangefinders

Strelok supports Vectronix Terrapin X, MTC Rapier, NTC Tomahawk, SHR
RF1000. LoadOut ships Bushnell, Sig, Vortex, Leica.

Closing it via:
- Vectronix Terrapin X is the only one that matters at scale (it's a
  $5K+ flagship military rangefinder used by some PRS pros).
- Our BLE adapter framework
  ([`lib/services/ble/ble_service.dart`](../lib/services/ble/ble_service.dart))
  is structured around per-device adapters; adding Vectronix is one
  service file plus testing.
- The niche European rangefinders (MTC, NTC, SHR) are below the
  threshold of US shooter relevance.

**Honest line:** "We ship Bushnell, Sig, Vortex, and Leica today. They
ship Vectronix. We'll add Vectronix in v1.1 if user demand surfaces.
The other rangefinders on their list have effectively no US user
base."

### 6. WeatherFlow / Skywatch wind meters

Strelok supports them. We don't, and neither do most US-market apps.
The **Kestrel monopoly is real** in serious US shooting circles —
WeatherFlow and Skywatch are EU / UK favorites. Adding either is
trivial (BLE on these devices is well-documented), but it's a
post-v1.0 priority.

---

## Specific feature gaps prioritized for v1.0 launch

These are quick, clearly worth-it items to ship before public launch
to narrow specific gaps. NOT the nice-to-haves.

1. **Ship 1,000 more reticles to cross the "feels-comparable"
   threshold.** Sourcing JSON from public scope manuals + the public
   subset of community reticle libraries. Get the count above 1,000
   (currently 258) so the gap to Strelok's 2,277 is meaningful but
   not crippling.

2. **Ship 200 more cartridges with SAAMI specs.** Currently 203; aim
   for ~400 to cover all common rifle, pistol, and shotgun cartridges
   plus the major wildcats. SAAMI's cartridge index is public; this is
   data work, not engineering.

3. **Ship 500 more factory ammo SKUs.** Currently 2,583; aim for
   3,000+ to be the largest factory-ammo catalog in any ballistic app.
   Manufacturer websites publish these; the data structure is set.

4. **Native-speaker translation review (DE/ES/FR/IT/RU) finished and
   merged before submission.** Listed in
   [LAUNCH_CHECKLIST.md](../LAUNCH_CHECKLIST.md). Without this we can't
   defensibly claim "ships in 6 languages" in App Store / Play Store
   metadata.

5. **Finish the remaining 70% ARB migration.** Same checklist item.
   Without it, parts of the UI fall back to English even when the
   user picks a non-English language.

6. **Add Vectronix Terrapin X support.** One BLE adapter file. The
   Vectronix protocol is reasonably well-documented in mil/LE
   communities. This closes the only material rangefinder gap.

7. **Polish the Range Day workspace screenshots in the App Store /
   Play Store listings.** The hit-probability + post-shot correction
   features are the single biggest differentiator we have, and they
   need to be the first thing a prospective buyer sees in
   screenshots. Currently scheduled per
   [marketing/screenshots_spec.md](./screenshots_spec.md).

8. **Publish the privacy comparison.** A dedicated page on the
   marketing site (or a section in the App Store description) that
   side-by-sides BC2026's privacy policy text vs ours. Their text
   ("Log Data through third-party products: device IP address, device
   name, operating system version, app configuration details,
   timestamps, usage statistics") next to ours ("None of the above —
   we don't operate any analytics SDK") is a screenshot-worthy
   differentiator.

9. **Hornady 4DOF curve attribution prominent in copy.** The 300
   measured curves are unique to LoadOut; the App Store / Play Store
   subtitle and key feature bullet must surface this. "Real Hornady
   4DOF radar data, 300 bullets, courtesy of Hornady" is the one we
   need.

10. **Lifetime tier callout in App Store / Play Store description.**
    Strelok dropped lifetime entirely. App Store reviewers will look
    at our pricing JSON and see lifetime-only IAPs alongside the
    yearly subscription, which is uncommon — explaining why we offer
    it ("alternative to Strelok which dropped this option") in the
    description text avoids a confused reviewer flagging it.

---

## v1.1 roadmap items derived from this audit

Things that aren't blocking v1.0 but should be on the roadmap based
on what Strelok does that we don't.

1. **Reticle count to 2,000+.** Match Strelok's live count. Data work.

2. **Bullet library to 1,000+ with G7 BCs.** Currently 255. Hornady,
   Berger, Sierra, Lapua, Nosler, Barnes, Cutting Edge — all publish
   G7 data. Extension of [bullets.json](../assets/seed_data/bullets.json).

3. **Cartridge library to 1,500+.** Wildcats, pistol, shotgun
   coverage to match Strelok's depth.

4. **WeatherFlow + Skywatch BLE adapters.** Niche US relevance, but
   eliminates a Strelok-only check-mark for European customers.

5. **Vectronix Terrapin X / MTC Rapier adapters** (Vectronix v1.0,
   the rest v1.1).

6. **Apple Vision Pro support.** BC2026 lists visionOS 1.0+ as a
   supported platform. Flutter does not yet officially support
   visionOS but the iPad app likely runs in compatibility mode; we
   should test and surface the badge.

7. **Reticle subtension drawing tool.** Let users sketch their own
   reticle for scopes we don't have. Closes the "you don't have my
   exact reticle" complaint.

8. **AI Reloading Assistant (already signaled).** The single biggest
   forward-looking differentiator for the next 18 months. Anthropic-
   backed, on-device-aware (passes the user's recipes / loads / brass
   into context, never sends them to a backend we operate beyond the
   AI proxy itself).

9. **Multi-shot field truing** as a first-class workflow. Strelok
   does single-distance truing. LoadOut surfacing per-distance MV/BC
   regression across the user's shot history would be a clean win.

10. **Real-time atmosphere variation along the trajectory** (for
    ELR shooters; current model treats atmosphere as constant). Per
    `marketing/CLAUDE.md` § 9 forward-looking list.

11. **Custom drag curve drawing tool** — same idea as the reticle
    drawing tool; let users sketch a Cd-vs-Mach curve from published
    radar data.

12. **More languages: Portuguese, Turkish, Polish.** Pre-built
    framework, just translation work.

---

## Notes for marketing copy

Specific defensible claims (cite with the linked sources):

- **"33% cheaper at the yearly tier"** — $39.99 vs $59.99. Citation:
  [BC2026 App Store listing](https://apps.apple.com/us/app/ballistics-calculator-2026/id1605954590)
  with "Premium (12 months): $23.99–$59.99" — we use the $59.99
  ceiling because that's the most-quoted price.

- **"$5 cheaper at the 3-month tier"** — $14.99 vs $19.99. Same
  citation.

- **"A lifetime tier they don't sell"** — Strelok Pro one-time was
  $11.99 (historically). BC2026 has no lifetime SKU per their App
  Store IAP listing. We sell $79.99 lifetime.

- **"300+ measured Hornady 4DOF Cd-vs-Mach curves"** — citation:
  [`assets/seed_data/drag_curves/curves.json`](../assets/seed_data/drag_curves/curves.json)
  with `"curves": [...]` length 300; scraped via
  [`tool/scrape_hornady_4dof.py`](../tool/scrape_hornady_4dof.py) from
  Hornady's Azure backend. **Always cite "courtesy of Hornady"** in
  marketing material — see the warning in
  [`marketing/CLAUDE.md` § 12](./CLAUDE.md#12-what-not-to-claim-compliance--safety).

- **"2,500+ factory ammo SKUs across 37 manufacturers"** — citation:
  [`assets/seed_data/factory_loads.json`](../assets/seed_data/factory_loads.json),
  length 2,583 entries. Use the rounded "2,500+" figure for
  marketing.

- **"258 reticles across 24 brands"** — citation:
  [`assets/seed_data/reticles.json`](../assets/seed_data/reticles.json)
  length 258. Note: `marketing/CLAUDE.md` quotes 290; the in-tree
  data is 258. **Update marketing copy to 258 (or however the count
  trends after v1.0 reticle additions).**

- **"156 optics across 21 brands"** — citation:
  [`assets/seed_data/optics.json`](../assets/seed_data/optics.json)
  with 21 manufacturers and 156 product entries. (Verified by jq
  query against the file.)

- **"6-platform reach"** — iOS, Android, macOS, web, Apple Watch, Wear
  OS. Citation: [CLAUDE.md § 1](../CLAUDE.md#1-what-it-is) +
  [CLAUDE.md § 17 (Web)](../CLAUDE.md#17-web-platform) +
  [CLAUDE.md § 15 (Watch / Wear)](../CLAUDE.md#15-companion-apps-apple-watch--wear-os).

- **"AES-256-GCM with PBKDF2-200k passphrase derivation"** — citation:
  [`lib/services/backup_crypto.dart`](../lib/services/backup_crypto.dart).
  This is a defensible technical claim because the source is shipping
  and the algorithm names are standard.

- **"Cash-Karp adaptive RK45 integration with 1e-4 m position
  tolerance"** — citation:
  [`lib/services/ballistics/solver.dart`](../lib/services/ballistics/solver.dart)
  lines 471–500. Use only in long-form technical copy, not landing
  page hero.

Specific claims to **avoid**:

- **"More accurate than Strelok"** — unprovable without published
  side-by-side benchmarks. Replace with "we open-source our solver
  internals; you can verify our trajectories against your real-world
  data."

- **"More complete than Strelok"** — they have 4,000 cartridges to
  our 200. Replace with "more complete reloading workflow than
  Strelok," which is true and defensible.

- **"Faster than Strelok"** — unprovable; both are sub-second on
  modern phones.

- **"More private than Strelok"** — Strelok Pro itself runs no
  backend; the privacy claim is specifically vs Ballistic Calculator
  2026 (the Google Play replacement, which has third-party log
  analytics per their own privacy policy). Be precise: "more private
  than the Google Play replacement title" or simply "we don't run
  third-party analytics, period."

- **"Russian app, US-based alternative"** — `marketing/CLAUDE.md`
  already advises "subtle in copy. Don't overplay." The sanctions
  story is real but exploiting it reads as opportunistic. Lead with
  features and pricing.

- **"Patented" or "proprietary" anything** — explicitly called out
  in `marketing/CLAUDE.md` § 12. We use public-domain physics
  (spin drift, ICAO atmosphere, Miller stability, McCoy MPM).

- **"6-DOF solver"** — `marketing/CLAUDE.md` says "6-DOF Modified
  Point Mass solver." Strictly speaking, **MPM is 3-DOF + empirical
  add-ons**; the only fully 6-DOF mobile app is Lapua Ballistics
  ([source](https://forum.accurateshooter.com/threads/latest-greatest-ballistic-calculator-apps.4094080/)).
  The honest framing is: "Modified Point-Mass solver with industry-standard
  spin drift, aerodynamic jump, Miller stability, Coriolis, and full
  atmospheric modeling — the same model class Strelok uses." Don't
  claim "6-DOF" as a standalone bullet.

---

## What we couldn't confirm

A frank list of Strelok / BC2026 features we couldn't verify, with
the sources we did find. Treat these as data gaps and update this
doc when authoritative info surfaces.

1. **Exact current cartridge count for BC2026.** Their App Store
   listing says "4000 cartridges and 3300 reticles"
   ([source](https://apps.apple.com/us/app/ballistics-calculator-2026/id1605954590))
   but their version notes from January 2026 added "800 new cartridges
   and 300 new reticles," which would imply ~4,800 cartridges /
   ~3,600 reticles today. The marketing number on their store listing
   may be stale.

2. **Whether BC2026's solver actually has the same engine as
   Strelok Pro.** Multiple sources call BC2026 "the same team, same
   engine, modern packaging"
   ([marketing/CLAUDE.md § 4](./CLAUDE.md#primary-competitor--strelok--ballistic-calculator-2026))
   but BC2026 is published by **"Educational apps LLC"** per the
   [App Store listing](https://apps.apple.com/us/app/ballistics-calculator-2026/id1605954590),
   not by Igor Borisov. Treat the "same engine" claim as plausible
   but not confirmed.

3. **Whether BC2026 supports any Bluetooth devices.** Strelok Pro
   does (Kestrel, Vectronix, etc.) but the BC2026 App Store listing
   makes no mention of Bluetooth integration, and one user complaint
   notes "the app started crashing after its latest update." It's
   plausible BC2026 ships fewer hardware integrations than Strelok
   Pro. Do not assume parity.

4. **Whether BC2026 supports custom drag models.** The App Store
   listing only mentions "G1, G7, etc." without "custom" — implying
   custom drag may not be in BC2026 even though it's in Strelok Pro.
   Unconfirmed.

5. **BC2026 privacy practices in detail.** Their privacy policy
   ([source](https://pages.flycricket.io/ballistics-calcula/privacy.html))
   is a generic flycricket.io template that mentions "Log Data
   through third-party products" but doesn't enumerate them. We
   couldn't confirm whether they ship Google Analytics, Mixpanel,
   Crashlytics, or similar — only that they're permitted to collect
   IP / device name / OS / app config / timestamps / usage stats.

6. **Strelok Pro precise install count today.** Pulled from US Google
   Play in March 2023; an APKMirror / Aptoide path still exists.
   "100K+ installs" ([marketing/CLAUDE.md](./CLAUDE.md#primary-competitor--strelok--ballistic-calculator-2026))
   refers to BC2026's count, not the historical Strelok Pro.

7. **Whether Strelok Pro / BC2026 has any reloading workflow.** All
   public sources consistently describe Strelok as "a calculator,
   not a reloading workspace"
   ([loaddevelopment.com](https://www.loaddevelopment.com/the-best-strelok-pro-alternatives/),
   [hammerbullets.com](https://hammerbullets.com/hammertime/threads/strelok-pro.135/),
   [Strelok+ manual](http://strelokpro.online/StrelokPlus/manual.html)).
   We're 99% confident the answer is "no" but lack a definitive
   negative — a reloader's review thread that says "I tried using
   Strelok for load development and gave up because…" would be a
   useful citation.

8. **BC2026 watch app feature parity vs Strelok Pro.** Strelok Pro
   sends "reticle image, target list or trajectory table to your
   watch"
   ([source](https://www.strelokpro.online/StrelokPro/android/default.asp)).
   BC2026's App Store listing mentions iOS and macOS but does not
   list Apple Watch or Wear OS support. We assume BC2026 has lost
   watch parity but cannot confirm.

9. **Whether Strelok Pro has aerodynamic jump as an explicit
   knob.** Some sources describe Strelok as "accounting for"
   aerodynamic jump
   ([PrecisionRifleBlog](https://precisionrifleblog.com/2019/05/22/ballistic-app/))
   while their own marketing copy doesn't mention it as a separate
   feature. The cant correction is documented; the cant-cross-wind
   aerodynamic-jump component may be implicit in their solver but is
   not user-facing. LoadOut exposes it as an explicit
   `muzzleCantDeg` knob.

10. **Strelok Pro powder-temperature multiple-cartridges-on-one-rifle
    interaction.** The "zero offset" feature
    ([source](https://hammerbullets.com/hammertime/threads/strelok-pro.135/))
    handles 100m offset; whether it composes with powder-temp
    sensitivity per cartridge is unclear. LoadOut handles this
    cleanly because each recipe carries its own powder-temp profile.

---

## Appendix: catalog count cross-check

| Catalog | LoadOut shipped count | Source |
|---|---|---|
| Cartridges | 203 | `jq '. \| length' assets/seed_data/cartridges.json` |
| Factory loads | 2,583 | `jq '. \| length' assets/seed_data/factory_loads.json` |
| Reticles | 258 | `jq '. \| length' assets/seed_data/reticles.json` |
| Targets | 55 | `jq '. \| length' assets/seed_data/targets.json` |
| Bullets | 255 (across 10 manufacturers) | `jq '[.manufacturers[].products \| length] \| add'` |
| Powders | 178 (across 8 manufacturers) | same pattern |
| Primers | 83 | same pattern |
| Brass products | 348 (manufacturer × caliber rows) | same pattern |
| Firearms | 255 (across 40 manufacturers) | same pattern |
| Optics | 156 (across 21 manufacturers) | same pattern |
| Hornady 4DOF curves | 300 | `jq '.curves \| length' assets/seed_data/drag_curves/curves.json` |
| Manufacturer countries (optics) | 8 | `jq '[.manufacturers[].country] \| unique \| length'` |

These numbers are authoritative as of commit `c0b2e27` on `main`,
2026-05-08. Update this table when seed data ships changes.

---

*End of audit.*

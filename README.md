# LoadOut

A local-first ammo reloading + ballistics platform for **iOS, Android, macOS, and the web**, built in Flutter. Reloaders catalog recipes, firearms, brass lots, batches, ballistic profiles, range-day sessions, and load-development tests; reach for a Modified Point-Mass exterior ballistics solver and a interior-ballistics estimator; and never send any of that data off-device.

> **Privacy promise (engineer summary).** All user reloading data lives in the on-device SQLite database. There is no LoadOut-operated backend that receives recipes, firearms, lots, batches, range-day sessions, or telemetry. Firebase Auth handles sign-in (email + OAuth). Optional Pro features (Cloud Backup, Cloud Sync, AI Smart Import) are off by default; when enabled, they're encrypted on-device with a passphrase only the user knows and stored in the user's own iCloud Drive / Google Drive / OneDrive — never on LoadOut infrastructure.

> **Audience for this README:** an engineer (probably future-you) coming back to the codebase. For the long-form architecture description and rules-of-the-road, read `CLAUDE.md`. For marketing copy / pitch / positioning, read `marketing/CLAUDE.md`.

---

## 1. Quick start

```sh
git clone <repo>
cd LoadOut
flutter pub get
flutter run                        # iOS, Android, macOS, or Chrome — pick a device
```

iOS: `open ios/Runner.xcworkspace` (NEVER the bare `.xcodeproj` — Pods break it).

Run before every commit:

```sh
flutter analyze                    # MUST be clean
flutter test                       # asset-presence test catches the missing-asset crash class
dart run build_runner build        # only after schema changes in lib/database/database.dart
```

Web build / deploy commands and platform-specific gotchas live in `CLAUDE.md` §§ 5, 8, 9, 10, 17.

---

## 2. What's in the app

**Five bottom-nav tabs:** Recipes, Firearms, Batches, Ballistics, Range Day.

**Drawer destinations:** How It Works, Reloading Guide, Glossary (153 terms across 10 categories), **Resources** (SAAMI Specs + Internal Ballistics Calculator + Component Inventory + Load Development entry tiles), Brass Lots, Load Development (Pro), Reloading Steps, AI Reloading Assistant (Coming Soon), Backup & Export, Settings, Privacy Policy.

**Free tier (everything below is free unless flagged Pro):**

- Recipes (Quick + Standard FAB; Core / Extended / Full detail levels; 7 import sources — Photo / CSV / Excel / Notes-Text File / PDF / Word Doc / OneNote / Apple Notes Share Sheet — and a free per-cartridge **Lookup Loads sheet** that deep-links to Hodgdon / Hornady / Sierra / Vihtavuori official load-data pages, see `lib/widgets/lookup_loads_sheet.dart`).
- Firearms with shots-fired counter, throat erosion fields, optic + reticle pairing.
- Batches with caliber-filtered process checklist.
- Brass Lots with firing-count cascade.
- Component Inventory (on-hand quantity tracker — schema v32, lives in Resources, intentionally NOT promoted in marketing copy; see CLAUDE.md § 26).
- The full Modified Point-Mass ballistics solver (G1–G8 drag tables, spin drift, Coriolis, aerodynamic jump, density altitude). Engineering reference: `lib/services/ballistics/`.
- Range Day workspace (Quick / Full mode toggle, target plot, group stats, hit probability, DOPE, last-shot correction).
- Glossary, SAAMI Specs (200+ cartridges), Reloading Guide, How It Works.
- Local JSON export, manual encrypted Cloud Backup (encrypted on-device, uploaded to user's own cloud).
- 15-language picker (English, German, Spanish, French, Italian, Russian reviewed; 9 added languages in beta — Finnish, Swedish, Norwegian Bokmål, Polish, Czech, Brazilian Portuguese, Hungarian, Danish, Dutch).

**Pro tier — single entitlement `pro`, two SKUs ($39.99/yr, $79.99 lifetime):**

- Continuous Cloud Sync to user's own iCloud Drive / Google Drive / OneDrive (same encryption stack as manual backup; ~5 sec debounced after each save).
- Hornady 4DOF / custom drag curves on top of G1 / G7.
- Bluetooth devices: Kestrel 5xxx Link, Garmin Xero C1 Pro (.fit import), 5 BLE rangefinders (Sig BDX, Bushnell BDX, Vortex Razor HD 4000 / Fury HD AB, Leica Geovid Pro, Vectronix Terrapin X — the only one publishing magnetic azimuth alongside LOS distance).
- Scope View Pro reticle visualization + training mode.
- Moving Target lead computation.
- Live weather pull (open-meteo) on the ballistics screen and the firearm form's Zero Atmosphere field.
- GPS altitude derivation in Range Day "Capture environment from sensors."
- AI Smart Import — Anthropic-call cleanup pass on top of low-confidence on-device OCR. **Off by default, opt-in per use.** The only Anthropic-using surface in the app today; engineering reference: CLAUDE.md § 20.
- AI Reloading Assistant chat — **Coming Soon**, placeholder UI today.
- **Load Development** — five named methods: OCW (Newberry), Audette Ladder, Satterlee 10-shot, Generic charge ladder, Seating depth ladder. Per-charge SD / ES / mean MV / group ES / mean radius. OCW vertical-impact flat-spot detection, Satterlee MV-plateau detection. Engineering reference: CLAUDE.md § 25.
- **Internal Ballistics Calculator** — interior-ballistics estimator for muzzle velocity + peak chamber pressure from a hypothetical recipe. ~40 powders in the burn-rate reference. Validation ±10% MV / ±15% pressure across the published-Hodgdon-data anchor set. Closes the GRT / QuickLOAD gap on mobile. Engineering reference: CLAUDE.md § 24.
- Unlimited custom fields per recipe / firearm / batch.

The full canonical Pro-feature list and gate call sites live in `CLAUDE.md` § Monetization.

---

## 3. Architecture (the 30-second briefing)

```
+-------------------------------------------------------+
|  UI (lib/screens/, lib/widgets/)                      |
|  Recipes / Firearms / Batches / Ballistics /          |
|  Range Day / Load Development / Inventory /           |
|  Internal Ballistics / Glossary / Resources / ...     |
+-------------------------------------------------------+
|  Repositories (lib/repositories/)                     |
|  RecipeRepo, FirearmRepo, ComponentRepo, BatchRepo,   |
|  BrassLotRepo, ProcessStepRepo, LoadDevelopmentRepo,  |
|  ComponentInventoryRepo, ...                          |
+-------------------------------------------------------+
|  Services (lib/services/)                             |
|  AppDatabase (drift / SQLite, schema v32)             |
|  AuthService (Firebase Auth, 7 providers)             |
|  Ballistics solver (Modified Point-Mass, pure Dart)   |
|  Internal Ballistics (interior-ballistics method, pure Dart)       |
|  ExportService + BackupCrypto (AES-256-GCM)           |
|  iCloud / Drive / OneDrive backup providers           |
|  CloudSyncService (continuous, debounced)             |
|  PurchasesService + EntitlementNotifier (RevenueCat)  |
|  AiSmartImportService (Anthropic, opt-in per use)     |
|  TextImportService (shared text/PDF parse plumbing)   |
|  ShareHandlerService (Apple Notes / system share in)  |
|  BLE adapters (Kestrel + 5 rangefinders + Garmin Xero)|
+-------------------------------------------------------+
|  External                                             |
|  Firebase Auth | RevenueCat | Anthropic API           |
|  iCloud Drive  | Google Drive (appDataFolder)         |
|  Microsoft OneDrive (approot)                         |
+-------------------------------------------------------+
```

`lib/main.dart` boots Firebase, opens the drift database, runs `SeedLoader.seedIfNeeded()`, initializes RevenueCat, and hands the singletons to `LoadOutApp`. `lib/app.dart` declares one `MultiProvider` with every service the rest of the tree needs; every screen reads its dependencies via `context.read<T>()` / `context.watch<T>()`.

For the deep-dive on the ballistics solver (state vector, integrator, drag tables, atmosphere model, zero solver), see `CLAUDE.md` and `lib/services/ballistics/solver.dart`.

For the deep-dive on the interior-ballistics method Internal Ballistics Calculator (model, calibration constants, validation results, scope), see `CLAUDE.md` § 24 and `lib/services/ballistics/internal_ballistics.dart`.

For the deep-dive on Load Development (5 methods, per-charge stats, schema delta), see `CLAUDE.md` § 25.

---

## 4. Schema (drift, currently v32)

**Schema version: 32.** Bumps require an `if (from < N) { ... }` block in `MigrationStrategy.onUpgrade` (fall-through, not else-if). SQLite cannot drop or alter columns — only add. Always re-run `dart run build_runner build` after touching `database.dart`.

Latest bumps:

| Version | What it added |
|---|---|
| **v31** | `LoadDevelopmentSessions.methodKind / distanceYd / shotsPerCharge` columns + new `LoadDevelopmentShots` per-shot child table. Enables OCW / Audette / Satterlee / Generic / Seating analysis. |
| **v32** | `ComponentInventory` + `ComponentInventoryAdjustments` tables. On-hand quantity tracking (free, Resources only). |

Earlier bumps (v2–v30) cover SAAMI/CIP fields, primer product lines, the big v4 user-data expansion, ballistic profiles, optics + reticles, drag curves, factory loads, manufactured ammo, target racks, atmosphere presets, sight calibrations, WEZ profiles, trued BC overrides, favorites, and component favorites. The full migration log lives in `lib/database/database.dart`'s `MigrationStrategy.onUpgrade`.

Reference tables (read-only, seeded from `assets/seed_data/*.json`): `Manufacturers`, `Cartridges`, `Powders`, `Bullets`, `Primers`, `BrassProducts`, `FirearmsRef`, `FirearmParts`, `Scopes`, `Reticles`, `Targets`, `TargetRacks`, `DragCurves`, `FactoryLoads`, `ManufacturedAmmo`. User data (writable, exported by `ExportService`): `CustomComponents`, `UserLoads`, `UserFirearms`, `BrassLots`, `Batches`, `UserProcessSteps`, `TestSessions`, `PowderLots`, `BulletLots`, `PrimerLots`, `UserCustomFields`, `UserCustomFieldValues`, `LoadDevelopmentSessions`, `LoadDevelopmentShots`, `BallisticProfiles`, `RangeDaySessions`, `ShotImpacts`, `WezProfiles`, `TruedBcOverrides`, `SightCalibrations`, `AtmospherePresets`, `UserFavorites`, `UserComponentFavorites`, `ComponentInventory`, `ComponentInventoryAdjustments`.

---

## 5. Identifiers (quick reference)

| | |
|---|---|
| App name | **LoadOut** |
| Store name | **LoadOut: Precision Reloading** |
| Bundle ID / Android package | `com.johnsondigital.loadout` |
| Firebase project ID | `loadout-precision-reloading` |
| Apple Team ID | `7265YL85SB` |
| Hosting URL (marketing) | https://loadout-precision-reloading.web.app |
| Hosting URL (web app) | https://loadout-app.web.app |
| iCloud container | `iCloud.com.johnsondigital.loadout` |
| Flutter SDK | `^3.11.5` (see `pubspec.yaml`) |
| App version | `1.1.0+2` |

---

## 6. Pointers to other docs

| Doc | What's in it |
|---|---|
| **`CLAUDE.md`** | Engineering reference. The long-form architecture / rules-of-the-road / per-feature deep-dive doc. **Authoritative** when this README disagrees. |
| `marketing/CLAUDE.md` | Marketing reference. Pricing, paywall pitch, positioning, competitive frame, voice rules, copy-safe stats. |
| `LAUNCH_CHECKLIST.md` | Pre-launch open items (Apple JWT rotation, Azure secret rotation, release keystore SHA, real-device QA passes, native-speaker translation review). |
| `SETUP.md` | Day-to-day setup runbook (read this for the daily workflow). |
| `REVENUECAT_SETUP.md` | App Store Connect + Play Console + RevenueCat dashboard configuration. |
| `PRIVACY_POLICY.md` | Full privacy stance (the hosted version is what the app stores link to). |
| `ROADMAP.md` | Product direction, Free vs Pro split, sequencing. |
| `docs/RETICLE_LICENSING.md` | IP posture for reticles (LoadOut-original + public-domain only; no trademarked reticle names ship). |
| `docs/seed-data-deployment.md` | Live reference-catalog updates via Firebase Storage. |
| `cloud_worker/anthropic-proxy/README.md` | Cloudflare Worker that proxies AI Smart Import (Pro). |
| `ios/RunnerWatchApp/README.md` | Apple Watch SwiftUI scaffold + Xcode wiring. |
| `ios/ShareExtension/README.md` | iOS Share Extension scaffold + Xcode wiring. |
| `android/wear/README.md` | Wear OS Compose scaffold (Gradle wired). |
| `assets/seed_data/README.md` | Seed-data format reference. |

# LoadOut – Setup

Flutter ammo reloading + ballistics app, local-first (SQLite via `drift`),
with Firebase Authentication for sign-in. Targets **iOS, Android, macOS,
and the web**.

> The authoritative architecture description lives in `CLAUDE.md` (the
> engineering guide). This file is the day-to-day setup runbook. When
> the two disagree, `CLAUDE.md` wins.

## Identifiers

| | |
|---|---|
| App name | LoadOut |
| Store name | LoadOut: Precision Reloading |
| Bundle ID / package | `com.johnsondigital.loadout` |
| Firebase project ID | `loadout-precision-reloading` |
| Apple Team ID | `7265YL85SB` |
| Firebase console | https://console.firebase.google.com/project/loadout-precision-reloading |
| Hosting URL | https://loadout-precision-reloading.web.app |

## Architecture (read this first)

- **User data is local only.** Recipes, firearms, brass lots, batches,
  ballistic profiles, custom components, range-day sessions, load-
  development tests, and on-hand component inventory all live in an
  on-device SQLite database via `drift` (schema v32 as of this
  release). They are never sent to any LoadOut-operated server. The
  one Pro feature that sends user-typed text outside the device is
  AI Smart Import — see `CLAUDE.md` § 20 — and that's scoped strictly
  to OCR'd photo text on a per-import opt-in basis.
- **Reference data ships with the app.** Cartridges, powders, bullets,
  primers, brass, firearms, parts, scopes, reticles, targets, drag
  curves, and factory-load reference are bundled as JSON in
  `assets/seed_data/` and seeded into SQLite on first run.
- **LoadOut never republishes manufacturer load data.** The recipe
  form and SAAMI screen surface a "Look Up Published Loads" sheet
  that opens Hodgdon / Hornady / Sierra / Vihtavuori official load-
  data pages in the system browser. We deep-link out — we don't
  re-host. See `CLAUDE.md` and `lib/widgets/lookup_loads_sheet.dart`
  for the rationale.
- **Firebase is auth only at runtime.** Email/password, email link
  (passwordless), anonymous, Google, Apple, Microsoft, and Yahoo
  sign-in. No Firestore, no Cloud Storage of user reload data.
  (Firebase Storage is used one-way for live reference-catalog
  updates — see `lib/services/seed_updater.dart` and
  `docs/seed-data-deployment.md`.)
- **Cloud Backup + Cloud Sync (Pro)** are end-to-end encrypted with
  the user's passphrase (AES-256-GCM + PBKDF2 200k iter) and stored
  in the user's own iCloud Drive / Google Drive / OneDrive. LoadOut
  has no backend that receives the encrypted blob.

## Already done

- Firebase project created (`loadout-precision-reloading`)
- iOS and Android apps registered under bundle `com.johnsondigital.loadout`
- All seven auth providers configured (six listed above + email link)
- Universal Links / App Links wired (associated domains entitlement, intent
  filter, Firebase Hosting serves AASA + assetlinks.json for
  `loadout-precision-reloading.web.app`)
- iOS entitlements: Sign In with Apple + Associated Domains
- iOS `DEVELOPMENT_TEAM` set to `7265YL85SB`, Podfile pinned to iOS 15.0,
  `ENABLE_USER_SCRIPT_SANDBOXING = NO` in post-install
- Android intent filter for `applinks:` and SHA-1/SHA-256 (debug) registered
- `drift` schema, generated code, seed loader, repositories all in place

## Run

```sh
flutter pub get
dart run build_runner build      # only after schema changes in lib/database/database.dart
flutter run                       # iOS, Android, macOS, or Chrome — pick a device
```

First run on a fresh install will seed the reference catalog from
`assets/seed_data/*.json` into SQLite. Subsequent runs skip seeding.

## Day-to-day commands

```sh
flutter analyze                                    # lint
flutter test                                       # run the test suite (always run after asset adds)
dart run build_runner build                        # regen drift code
dart run build_runner watch                        # watch mode while editing schema
firebase deploy --only hosting:marketing           # update AASA / assetlinks
firebase deploy --only hosting:app                 # deploy the Flutter web bundle (build/web/)
flutter build ios --debug --no-codesign            # quick iOS compile sanity
flutter build web --release                        # rebuild the web bundle
dart compile js -O2 -o web/drift_worker.dart.js web/drift_worker.dart  # rebuild drift web worker
```

## Project layout (high level)

The app long-since outgrew the four-tab nav described in earlier
revisions of this file. The current shell is **five bottom-nav tabs**
(Recipes, Firearms, Batches, Ballistics, Range Day) plus a drawer with
How It Works, Reloading Guide, Glossary, Resources, Brass Lots, Load
Development (Pro), Reloading Steps, AI Reloading Assistant
(Coming Soon), Backup & Export, Settings, Privacy Policy. SAAMI Specs
moved to Resources; the Internal Ballistics Calculator and Component
Inventory both live behind Resources too.

```
lib/
  main.dart                       Firebase init + DB open + seed + runApp
  app.dart                        Providers + auth gate + deep-link listener
  firebase_options.dart           Generated by `flutterfire configure`
  database/
    database.dart                 Drift schema (v32) + AppDatabase
    database.g.dart               Generated — do not edit
    seed_loader.dart              First-run JSON → SQLite
  repositories/                   30+ tables, one repo per logical area
  services/
    auth_service.dart             Wraps FirebaseAuth + 7 providers
    ballistics/
      solver.dart                 Modified Point-Mass solver
      internal_ballistics.dart    interior-ballistics MV / pressure predictor (Pro)
      powder_burn_rates.dart      ~40 reference powders for the estimator input
    backup_crypto.dart            AES-256-GCM + PBKDF2 200k
    cloud_sync_service.dart       Continuous Pro sync to user's own cloud
    text_import_service.dart      Shared text/PDF import plumbing
    share_handler_service.dart    Apple Notes / system Share inbound
  l10n/                           15-language pack (en, de, es, fr, it, ru,
                                  fi, sv, nb, pl, cs, pt-BR, hu, da, nl)
  screens/
    auth/login_screen.dart
    home/home_screen.dart         5-tab nav + drawer
    recipes/                      Recipe list + form (Quick + Standard FABs)
    firearms/                     Firearm list + form (shots-fired counter)
    batches/                      Batch list + form + detail
    brass_lots/                   Brass-lot list + form
    ballistics/                   External solver UI + Internal Ballistics
    range_day/                    Range Day workspace (~7800 LOC)
    load_development/             5-method workspace (Pro) — OCW, Audette,
                                  Satterlee, Generic, Seating
    inventory/                    Component on-hand tracking (free, Resources only)
    saami/saami_screen.dart       Cartridge picker + spec card
    glossary/glossary_screen.dart 153 terms across 10 categories
    how_it_works/                 Topical menu + Quick Tour
    resources/                    SAAMI Specs, Internal Ballistics, Component
                                  Inventory, Load Development entry tiles
    sync/cloud_sync_screen.dart   Pro continuous sync UI
    backup/backup_screen.dart     Manual encrypted Cloud Backup + local export
    settings/settings_screen.dart Account, App prefs, Cloud Sync, Watch & Wear,
                                  Connected Devices, AI features, Privacy & Data,
                                  Data Sources, Help & Support
  widgets/
    component_field.dart          Autocomplete-with-typed-custom field
    lookup_loads_sheet.dart       Per-cartridge "Look Up Published Loads" sheet
                                  (Hodgdon / Hornady / Sierra / Vihtavuori)
    pro_gate.dart                 ProGate + ensurePro
    cloud_sync_indicator.dart     AppBar sync icon + dot
  theme/app_theme.dart            Brass / charcoal palette + light / dark themes

assets/seed_data/                 Bundled reference catalog (JSON)
cloud_worker/anthropic-proxy/     Cloudflare Worker that proxies AI Smart Import
public/                           Firebase Hosting (marketing site, AASA, assetlinks)
web/                              Flutter web platform — drift WASM worker
ios/Runner/Runner.entitlements
ios/RunnerWatchApp/               Apple Watch SwiftUI scaffold (manual Xcode wiring)
ios/ShareExtension/               iOS Share Extension scaffold (manual Xcode wiring)
android/app/src/main/AndroidManifest.xml
android/wear/                     Wear OS Compose scaffold (Gradle wired)
LAUNCH_CHECKLIST.md               Pre-launch work tracker
CLAUDE.md                         Engineering reference (the long form)
README.md                         Engineer-oriented project orientation
marketing/CLAUDE.md               Marketing reference (copy / pitch / positioning)
```

## Adding a new auth provider

1. In the provider's portal (Microsoft Azure AD / Yahoo / etc.), register a
   web app with redirect URL
   `https://loadout-precision-reloading.firebaseapp.com/__/auth/handler`.
2. Get the OAuth client ID + secret.
3. POST to the Identity Platform admin API:
   ```sh
   TOKEN=$(gcloud auth print-access-token)
   curl -X POST \
     "https://identitytoolkit.googleapis.com/admin/v2/projects/loadout-precision-reloading/defaultSupportedIdpConfigs?idpId=<provider>.com" \
     -H "Authorization: Bearer $TOKEN" \
     -H "x-goog-user-project: loadout-precision-reloading" \
     -H "Content-Type: application/json" \
     -d '{"enabled": true, "clientId": "...", "clientSecret": "..."}'
   ```
4. Add a "Continue with X" button to `LoginScreen`. Use
   `_auth.signInWithProvider(<Provider>AuthProvider())` for the OAuth-popup
   flow, or a native package if the provider has one.

## Adding a new reference data category

1. Drop the JSON file in `assets/seed_data/<category>.json`.
2. Add a `Table` class to `lib/database/database.dart`.
3. Add a seeding method to `lib/database/seed_loader.dart` and call it from
   `seedIfNeeded()`.
4. Bump `schemaVersion` in `database.dart` and write a `MigrationStrategy`
   step (the `database.g.dart` will guide you).
5. `dart run build_runner build`.
6. Surface in `ComponentRepository` if the UI needs it.

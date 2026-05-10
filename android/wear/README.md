# LoadOut Wear OS Companion (v1)

Native Kotlin / Compose for Wear OS companion module for the LoadOut
Android app. Sibling Gradle module to `:app` (the Flutter Android
module). It is **not** a Flutter app — Flutter does not yet support
Wear OS as a first-class target, so the watch companion is implemented
natively.

| | |
|---|---|
| Module | `:wear` |
| Package | `com.johnsondigital.loadout.wear` |
| Application ID | `com.johnsondigital.loadout.wear` |
| `minSdk` | 30 (Wear OS 3 / Android 11) |
| `targetSdk` / `compileSdk` | 34 |
| UI framework | Compose for Wear OS 1.3.x |
| Phone-watch transport | Google Play Services Wearable Data Layer API |
| Status | **v1 shippable** — five live screens, motion-detected shot capture, par-time stage timer, phone-link diagnostic |

## What's in v1

The watch app launches into a five-page horizontal pager. The user
swipes between pages; cold launch lands on **DOPE** (the page a
shooter looks at most).

| # | Page | What it does |
|---|---|---|
| 0 | Timer | Par-time stage timer with haptic + tone alerts at 30/10/5 s, persisted total + quiet-mode toggle. Kotlin coroutine drives a 1 Hz tick. |
| 1 | DOPE | Active-load summary banner + range / drop / wind for the currently-pushed `dope` payload. < / > buttons advance the cursor through the ladder. |
| 2 | Stage Log | Three ways to log a shot: motion detection (accelerometer + 5 s confirm prompt), swipe right, or "Log Shot" button. Swipe left = skip. Each shot sends a `log_shot` Message to the phone. |
| 3 | Firearm Glance | Active firearm + barrel-life telemetry (shots fired / shots remaining). Red threshold below 200 remaining. |
| 4 | Settings | Read-only diagnostics: app version, phone-link state (Connected / Phone Unreachable / Not Paired), current shot-capture sensitivity preset. |

DOPE is the cold-launch landing because the at-the-line shooter
glances at it most often. Settings is at the far end so a swipe-left
from DOPE doesn't accidentally land on it.

## Source layout

```
android/wear/
├── build.gradle.kts                         Gradle config (Compose, deps, tests)
├── proguard-rules.pro                       Empty placeholder
├── README.md                                This file
├── .gitignore                               Ignore /build
└── src/
    ├── main/
    │   ├── AndroidManifest.xml              Activity + Data Layer service
    │   ├── java/com/johnsondigital/loadout/wear/
    │   │   ├── MainActivity.kt              Five-page pager root + GMS probe
    │   │   ├── bridge/
    │   │   │   ├── Payloads.kt              DopeRow, DopeSnapshot,
    │   │   │   │                            ActiveLoadSnapshot,
    │   │   │   │                            FirearmGlanceSnapshot
    │   │   │   ├── PhoneDataLayerListener.kt  Receives DataItems / Messages
    │   │   │   ├── PhoneDataLayerSender.kt    Sends Messages to the phone
    │   │   │   └── WatchPaths.kt              Reserved short-paths (CLAUDE.md §15)
    │   │   ├── motion/
    │   │   │   └── MotionDetector.kt        Accelerometer threshold detector
    │   │   ├── screens/
    │   │   │   ├── DopeScreen.kt            DOPE page (with active-load banner)
    │   │   │   ├── FirearmGlanceScreen.kt   Firearm + barrel-life page
    │   │   │   ├── SettingsScreen.kt        About / phone-link / sensitivity
    │   │   │   ├── StageLogScreen.kt        Shot capture page
    │   │   │   └── TimerScreen.kt           Stage timer page
    │   │   ├── state/
    │   │   │   └── WatchAppState.kt         Process-singleton state holder
    │   │   └── timer/
    │   │       └── TimerEngine.kt           1 Hz countdown + haptics + tones
    │   └── res/
    │       ├── values/strings.xml
    │       ├── values/wear.xml              Capability declaration
    │       ├── drawable/                    Adaptive launcher icon assets
    │       └── mipmap-anydpi-v26/           Launcher icon manifests
    ├── test/
    │   └── java/com/johnsondigital/loadout/wear/
    │       ├── MotionDetectorTest.kt        Robolectric — sensitivity table
    │       ├── PayloadsTest.kt              Pure JVM — JSON decoders
    │       ├── TimerEngineTest.kt           Robolectric — state machine
    │       └── WatchAppStateTest.kt         Pure JVM — cursor / shot count
    └── androidTest/
        └── java/com/johnsondigital/loadout/wear/
            └── MainActivityNavigationTest.kt   Compose UI — pager root
```

## Data flow

```
   ┌────────── Phone (Flutter / Dart) ──────────┐
   │  WatchBridgeService (lib/services/...)     │
   └──────────────┬──────────────────────────────┘
                  │ MethodChannel "loadout/watch_bridge"
                  ▼
   ┌────────── Phone (:app, Kotlin) ────────────┐
   │  WatchBridge.kt                             │
   │   ├─ DataClient.putDataItem("/loadout/...") │  lossy snapshot
   │   └─ MessageClient.sendMessage("/loadout/...") │  live message
   └──────────────┬──────────────────────────────┘
                  │ Wearable Data Layer (BLE / Wi-Fi)
                  ▼
   ┌────────── Watch (:wear) ────────────────────┐
   │  bridge/PhoneDataLayerListener (Service)    │
   │   parses JSON, dispatches by short-path     │
   │   ▼                                          │
   │  state/WatchAppState (singleton, StateFlow) │
   │   ▼                                          │
   │  screens/* (Compose)                         │
   │                                              │
   │  Watch -> phone:                             │
   │  bridge/PhoneDataLayerSender                 │
   │   └─ MessageClient.sendMessage(...)          │
   └──────────────────────────────────────────────┘
```

The reserved short-paths (CLAUDE.md §15) and which transport each
uses:

| Path | Direction | Transport | What it carries |
|---|---|---|---|
| `active_load` | phone → watch | DataItem (lossy) | Currently selected recipe summary |
| `dope` | phone → watch | DataItem (lossy) | Drop / windage chart for the active load |
| `firearm_glance` | phone → watch | DataItem (lossy) | Active firearm + barrel-life summary |
| `log_shot` | watch → phone | Message (queued via DataItem fallback) | Time-stamped shot, source = motion / swipe / manual |
| `timer_event` | bidirectional | Message (live) | Stage timer start / pause / warning / expired |
| `shot_capture_sensitivity` | phone → watch | DataItem (lossy) | Watch-shot motion-detect preset |

## Day-to-day commands

The `:wear` module is wired into the existing Flutter Android Gradle
build (see `android/settings.gradle.kts`), so any Gradle command
works against both modules.

```sh
# From the project root:
cd android

# Build only the wear APK (debug):
./gradlew :wear:assembleDebug

# Install onto a connected Wear OS device or emulator:
./gradlew :wear:installDebug

# JVM unit tests (Robolectric for the engines, pure JVM for parsers):
./gradlew :wear:testDebugUnitTest

# Compose UI tests on a connected Wear OS device:
./gradlew :wear:connectedDebugAndroidTest

# Build everything (phone APK via Flutter is not built by this command —
# use `flutter build apk` for that):
./gradlew build
```

`flutter build apk` only builds `:app`. It does **not** build
`:wear`, which is intentional — the watch APK is a separate artifact
uploaded to a separate Play Console listing (or the same listing as
a paired release set, once that is set up).

## Phone-side wiring (already in place)

The phone-side wrapper for the Wearable Data Layer lives at
`android/app/src/main/kotlin/com/johnsondigital/loadout/WatchBridge.kt`.
It exposes a MethodChannel `loadout/watch_bridge` and an EventChannel
`loadout/watch_bridge/events`, both consumed by the Dart
`WatchBridgeService`. Sends are routed through the bridge's `send`
method, which decides between DataItem (lossy snapshot) and Message
(live event) based on the `lossy` flag.

The watch advertises capability `loadout_watch_companion`
(`res/values/wear.xml`). The phone advertises
`loadout_phone_companion` (`android/app/src/main/res/values/wear.xml`).
The Settings screen on the watch polls for the phone's capability
every 3 seconds to surface the connectivity state.

## What the activity does on `onCreate`

1. Constructs `PhoneDataLayerSender(applicationContext)` — holds the
   GMS `MessageClient` + `CapabilityClient` + a single-thread executor.
2. Constructs `MotionDetector(applicationContext)` — rehydrates the
   user's saved sensitivity preset (default MEDIUM = 5.0 g / 50 ms).
3. Constructs `TimerEngine(applicationContext, sender)` — rehydrates
   the user's saved par-time and quiet-mode flag.
4. Calls `setContent { MaterialTheme { LoadOutWearRoot(...) } }`,
   which mounts the five-page pager.
5. The pager spins up a `LaunchedEffect(Unit)` that probes the GMS
   capability client every 3 seconds for the phone-link state.

`onDestroy` calls `sender.shutdown()` to release the executor — no
explicit teardown needed for the engines (they're `ViewModel`-shaped
and `viewModelScope` cancels itself when the activity is gone).

## Privacy posture

CLAUDE.md §15 specifies the rules; this module implements them
literally:

- **No HTTP / fetch from the watch app.** The only network calls
  are the Wearable Data Layer `MessageClient.sendMessage(...)` and
  `DataClient.putDataItem(...)` — both peer-to-peer over BLE / Wi-Fi
  through Google Play Services. Verified by grep: no `okhttp`,
  `retrofit`, `URL`, `HttpsURLConnection`, or `URLConnection` import
  in `:wear`.
- **No Firebase, RevenueCat, analytics, or crash-reporting SDKs in
  the wear module.** Pro entitlement checks live on the phone; the
  watch reflects whatever state the phone forwards via the Data
  Layer. The Settings screen even calls this out at the bottom: "All
  transport is peer-to-peer. No HTTP, no analytics."
- **Local state on the watch never leaves the user's wrist.** The
  `MotionDetector` writes the user's threshold + sensitivity preset
  to `wear_motion_prefs`; the `TimerEngine` writes par-time + quiet
  flag to `wear_timer_prefs`. Both are app-private SharedPreferences
  files, deleted when the watch app is uninstalled.

## Open follow-ups (operator)

- **Play Console listing.** v1 is shippable but the watch APK has
  no Play Console listing yet. Suggested workflow: list the wear
  APK alongside the phone APK as a paired release set (the user
  installs the phone app and Play offers the watch as a companion).
- **Release signing.** `:wear` currently signs release builds with
  the debug keystore (`build.gradle.kts` `release { signingConfig =
  signingConfigs.getByName("debug") }`). Before any Play Console
  upload, swap to the real release keystore — same one as `:app`
  via `key.properties`.
- **Launcher icon review.** v1 ships an adaptive icon with a brass
  ring + crosshair + centre dot (see
  `res/drawable/ic_launcher_foreground.xml`). The Play Store can
  reject overly-generic foregrounds — confirm the icon passes review
  before submitting, or swap to an SVG export of the LoadOut brass
  mark used by the phone app.
- **Real-device validation.** Robolectric covers the engines; the
  Compose UI test runs in CI / on emulator. Field-test the motion
  detector at the line (real recoil characteristics differ between
  bolt rifles, semi-autos, and pistols) before declaring shot
  capture production-ready.
- **Companion-pairing UX.** When the phone has the LoadOut app but
  the watch doesn't, GMS won't prompt the user to install — the
  watch listing has to do the surfacing. The Play Console "paired
  release" listing is the standard path.

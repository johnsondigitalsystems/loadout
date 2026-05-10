# LoadOut Watch App (watchOS companion)

Native SwiftUI watch companion for the LoadOut iOS app. Flutter does **not**
support watchOS as of the current stable channel, so this target is a
standalone Swift/SwiftUI app that ships in the same `.ipa` bundle as the
Flutter Runner.

| | |
|---|---|
| Target name | `RunnerWatchApp` |
| Bundle ID | `com.johnsondigital.loadout.watchkitapp` |
| Companion bundle ID | `com.johnsondigital.loadout` |
| Deployment target | watchOS 10.0 |
| UI framework | SwiftUI (native) |
| Phone-watch transport | `WatchConnectivity` (`WCSession`) |
| Status | **v1 — Stage Log + Timer + DOPE + About all reachable.** Sign-in / Pro / chat / analytics deliberately absent (per CLAUDE.md §15 privacy posture). |

## v1 feature surface

The watch app is page-based: the user swipes vertically (or rolls the
digital crown) between four pages. Each page reads its state from a
shared environment object the `WatchAppDelegate` owns for the app's
lifetime.

| Page | View | Owns | Reads from |
|---|---|---|---|
| 1. Stage Log | `StageLogView.swift` | `MotionDetector` (per-screen via `@StateObject`) | `ShotLogger`, `DopeViewModel`, `WatchConnectivityManager` |
| 2. Timer | `TimerView.swift` | — | `TimerEngine` |
| 3. DOPE | `DopeView.swift` + `ActiveLoadHeader.swift` + `FirearmGlanceBanner.swift` | — | `DopeViewModel` |
| 4. About | `AboutView.swift` | — | `WatchConnectivityManager` |

**Stage Log** is page 1 because it's the highest-frequency interaction
at the line — three log surfaces (motion, swipe, manual tap) funnel
through a single `ShotLogger` that emits `log_shot` payloads to the
phone. The motion detector pauses when the user swipes off this page
to save battery.

**Timer** runs entirely on the watch; phone connectivity is used to
mirror state for cross-device awareness. State machine: `idle →
running → (paused → running)? → finished → restart`. Warning beeps at
30 / 10 / 5 seconds remaining; quiet mode silences the speaker but
keeps the haptics.

**DOPE** renders the most-recent `dope` payload from the iPhone. The
top of the page surfaces two banners — the active load (cartridge +
powder + bullet summary) and the firearm glance (name + barrel-life
percent). The big numerals scroll via the digital crown or finger
chevrons. Empty state when no DOPE has arrived: "Open the Ballistics
screen on your iPhone."

**About** shows the bundled app version, the iPhone link state ("iPhone
Linked" vs "iPhone Not Linked"), and the most-recent shot-capture
sensitivity preset the phone pushed (read-only — sensitivity is
configured on the iPhone per CLAUDE.md §15).

## Files in this directory

```
ios/RunnerWatchApp/
├── LoadOutWatchApp.swift          @main entry, injects environment objects
├── ContentView.swift              Root TabView (4 pages)
├── WatchAppDelegate.swift         Owns connectivity + view-model singletons
├── WatchConnectivityManager.swift WCSession wrapper, inbound routing
├── WatchPaths.swift               Shared bridge-path string constants
│
├── DopeView.swift                 DOPE page (drop chart, crown scroll)
├── DopeViewModel.swift            Decoder for dope/active_load/firearm_glance
├── ActiveLoadHeader.swift         "Pick a Load on iPhone" banner / cartridge summary
├── FirearmGlanceBanner.swift      Firearm name + barrel-life gauge
│
├── TimerView.swift                Stage timer page
├── TimerEngine.swift              Timer state machine + haptics + audio
│
├── StageLogView.swift             Stage log page (motion + swipe + manual)
├── MotionDetector.swift           Threshold-based shot detection
├── ShotLogger.swift               Outbound log_shot emitter + haptic
│
├── AboutView.swift                Diagnostic / version / link-state page
│
├── Info.plist                     Watch app Info.plist (watchOS 10.0)
├── RunnerWatchApp.entitlements    App Group entitlement
├── Assets.xcassets/
│   ├── AppIcon.appiconset/        1024x1024 watchOS icon (brass LO mark)
│   └── AccentColor.colorset/      Brass accent (#C46E21)
└── Preview Content/               SwiftUI preview assets
```

Sibling test directory:

```
ios/RunnerWatchAppTests/
├── MotionDetectorTests.swift      Sensitivity preset table + decoder
├── TimerEngineTests.swift         State machine transitions
├── WatchPayloadDecoderTests.swift dope / active_load / firearm_glance decode
└── WatchConnectivityManagerTests.swift  Inbound routing contract
```

## Data flow at a glance

```
                  iPhone (Flutter Runner)
                  │
                  │  lib/services/watch_bridge_service.dart
                  │  sendDope / sendActiveLoad / sendFirearmGlance / etc.
                  ▼
         ios/Runner/WatchSessionBridge.swift
                  │   wraps payload in {path:..., payload:...}
                  │
              WCSession  ──── WatchConnectivity peer-to-peer ────▶
                                                                    │
                                                                    ▼
                                              WatchConnectivityManager
                                                  │
                                                  │  routeIncoming
                                                  │
                          ┌───────────────────────┼───────────────────────┐
                          │                       │                       │
                          ▼                       ▼                       ▼
                     "shot_capture       onIncomingPayload          {DOPE/active_load/
                      _sensitivity"      ─→ DopeViewModel            firearm_glance}
                      ─→ @Published         .handle(path:payload:)   decoded into
                          on manager                                 typed snapshots
                                                                     and rendered
                                                                     by SwiftUI views
```

Outbound (watch → phone) flows the same envelope shape in reverse:

```
   StageLogView tap            TimerEngine tick
        │                            │
        ▼                            ▼
   ShotLogger.log              TimerEngine.emit
        │                            │
        └─────────► WatchConnectivityManager.send(path:payload:)
                          │
                          │  WatchConnectivity peer-to-peer
                          ▼
              ios/Runner/WatchSessionBridge.swift
                          │
                          ▼ (EventChannel: loadout/watch_bridge/events)
                  Flutter Dart side
                  (WatchBridgeService.incomingShots / incomingTimerEvents)
```

## One-time wiring in Xcode

The Swift sources, plist, entitlements, and asset catalog already exist on
disk. Adding the target to `Runner.xcodeproj` programmatically is fragile
(the `project.pbxproj` schema for watch app targets has changed across
several Xcode versions), so this is a **manual step** the first time the
target is created.

### Step 1 — Add the watch target

1. Open `ios/Runner.xcworkspace` in Xcode.
2. **File → New → Target… → watchOS → App**.
   - Product Name: `RunnerWatchApp`
   - Team: `7265YL85SB` (Johnson Digital Systems)
   - Organization Identifier: `com.johnsondigital`
   - Bundle Identifier: should auto-fill as
     `com.johnsondigital.loadout.watchkitapp`. If it doesn't, set it
     explicitly. **Do not rename.** App Store Connect rejects watch app
     bundle IDs that don't follow the
     `<phone-app-bundle-id>.watchkitapp` pattern when pairing.
   - Interface: SwiftUI
   - Language: Swift
   - **Embed in Application: `Runner`** — this is what marks the watch
     target as a companion of the iPhone app.
   - Click "Finish".
3. Xcode generates a fresh `RunnerWatchApp/` folder with placeholder files.
   **Delete those generated files from the project navigator** (move to
   trash). Then **right-click `RunnerWatchApp` group → Add Files to
   "Runner"…** and re-add every Swift source from this directory:
   - `LoadOutWatchApp.swift`
   - `ContentView.swift`
   - `WatchAppDelegate.swift`
   - `WatchConnectivityManager.swift`
   - `WatchPaths.swift`
   - `DopeView.swift`
   - `DopeViewModel.swift`
   - `ActiveLoadHeader.swift`
   - `FirearmGlanceBanner.swift`
   - `TimerView.swift`
   - `TimerEngine.swift`
   - `StageLogView.swift`
   - `MotionDetector.swift`
   - `ShotLogger.swift`
   - `AboutView.swift`
   - `Info.plist`
   - `RunnerWatchApp.entitlements`
   - `Assets.xcassets`
   - `Preview Content` folder

   Make sure "Copy items if needed" is **unchecked** and "Create groups" is
   selected.

   Each new Swift file added to this directory in future commits also has
   to be added to the watch target this way — Xcode does not auto-discover
   them.

4. In the watch target's **Build Settings**:
   - `INFOPLIST_FILE` → `RunnerWatchApp/Info.plist`
   - `CODE_SIGN_ENTITLEMENTS` → `RunnerWatchApp/RunnerWatchApp.entitlements`
   - `DEVELOPMENT_ASSET_PATHS` → `"RunnerWatchApp/Preview Content"`
   - `WATCHOS_DEPLOYMENT_TARGET` → `10.0`
   - `ASSETCATALOG_COMPILER_APPICON_NAME` → `AppIcon`
   - `ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME` → `AccentColor`
   - `PRODUCT_BUNDLE_IDENTIFIER` → `com.johnsondigital.loadout.watchkitapp`
5. In the **Runner** (iPhone) target's **General** tab, scroll to "Frameworks,
   Libraries, and Embedded Content" and confirm `RunnerWatchApp.app` appears
   with status "Embed Watch Content". If it doesn't, click "+" and add it.
6. **Signing & Capabilities** for the watch target:
   - Add the **App Groups** capability and check
     `group.com.johnsondigital.loadout` (provision the group on
     developer.apple.com first, and add it to the iPhone target as well).
7. Build the Runner scheme. Xcode should sign both the iPhone app and the
   watch app and embed the watch app inside the iPhone app's `Watch/`
   folder.

### Step 2 — Add the watch test target (optional but recommended)

The unit tests in `ios/RunnerWatchAppTests/` cover the wire-format
decoder, motion-detector preset table, timer state machine, and inbound-
routing contract. They use `@testable import RunnerWatchApp` so the
test target needs to be a watchOS bundle linked against the watch app.

1. **File → New → Target… → watchOS → Watch App Unit Test Bundle** (if
   that template exists in your Xcode version) OR **iOS → Unit Test
   Bundle** with platform changed to watchOS in Build Settings.
2. Product Name: `RunnerWatchAppTests`.
3. Target to Be Tested: `RunnerWatchApp`.
4. Add the four test files from `ios/RunnerWatchAppTests/` to the new
   target via "Add Files to 'Runner'…", same way as Step 1.3.
5. In the test target's Build Settings, set
   `WATCHOS_DEPLOYMENT_TARGET = 10.0` to match.

Once added, the tests show up in Xcode's test navigator and run via
Cmd+U or `xcodebuild test -scheme RunnerWatchApp`.

## Day-to-day commands

```sh
# After making changes to watch sources, build the iPhone app — Xcode
# automatically rebuilds and re-embeds the watch app.
flutter build ios --debug --no-codesign

# Or run the iPhone app on a paired sim/device:
flutter run

# To run JUST the watch app on the watch sim, use Xcode's scheme picker
# (RunnerWatchApp scheme) — `flutter run` only knows about the iPhone target.

# Run watch unit tests (requires the test target to exist):
xcodebuild test -workspace ios/Runner.xcworkspace -scheme RunnerWatchApp \
  -destination 'platform=watchOS Simulator,name=Apple Watch Series 9 (45mm)'
```

## Reserved bridge paths

Mirror copies live in `lib/models/watch_payloads.dart` (Dart) and
`android/wear/src/main/java/com/.../bridge/WatchPaths.kt` (Wear OS).
Adding a new path means touching all three files at once.

| Path | Direction | Owner |
|---|---|---|
| `active_load` | phone → watch | `DopeViewModel.ingestActiveLoad` |
| `dope` | phone → watch | `DopeViewModel.ingestDope` |
| `firearm_glance` | phone → watch | `DopeViewModel.ingestFirearmGlance` |
| `log_shot` | watch → phone | `ShotLogger.log` |
| `timer_event` | bidirectional | `TimerEngine.emit` |
| `shot_capture_sensitivity` | phone → watch | `WatchConnectivityManager.routeIncoming` (sets `@Published shotCaptureSensitivity`; `MotionDetector.applySensitivity` reads it) |

Wire formats live next to the constants in `lib/models/watch_payloads.dart`.
The Swift decoders are in `DopeViewModel.swift` (per-key in
`ingestDope` / `ingestActiveLoad` / `ingestFirearmGlance`).

## Important — privacy posture

`CLAUDE.md` § 13 and § 15 say LoadOut never operates a backend that
receives reloading data. The watch app must follow the same rule:

- **No HTTP / network calls from the watch app.** All transport is
  `WatchConnectivity` (Apple-managed, peer-to-peer, encrypted in transit).
- The shared App Group container is on-device storage only.
- Do not import Firebase, RevenueCat, analytics, or crash-reporting SDKs
  into the watch target. Pro entitlement checks happen on the phone; the
  watch reflects whatever state the phone forwards to it.
- The Stage Log motion detector reads CoreMotion locally; nothing is
  uploaded.
- The Timer's audio + haptics are local watchOS APIs.

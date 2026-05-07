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

## Files in this directory

```
ios/RunnerWatchApp/
├── LoadOutWatchApp.swift          App entry point (`@main`)
├── ContentView.swift              Root SwiftUI view ("Coming Soon" UI)
├── WatchAppDelegate.swift         WKApplicationDelegate, owns the WC session
├── WatchConnectivityManager.swift WCSession wrapper + reachability state
├── Info.plist                     Watch app Info.plist
├── RunnerWatchApp.entitlements    App Group entitlement (future shared store)
├── Assets.xcassets/               App icon, accent color
└── Preview Content/               SwiftUI preview assets
```

## One-time wiring in Xcode

The Swift sources, plist, entitlements, and asset catalog already exist on
disk. Adding the target to `Runner.xcodeproj` programmatically is fragile
(the `project.pbxproj` schema for watch app targets has changed across
several Xcode versions), so this is a **manual step** the first time the
target is created.

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
   "Runner"…** and re-add every file from this directory:
   - `LoadOutWatchApp.swift`
   - `ContentView.swift`
   - `WatchAppDelegate.swift`
   - `WatchConnectivityManager.swift`
   - `Info.plist`
   - `RunnerWatchApp.entitlements`
   - `Assets.xcassets`
   - `Preview Content` folder
   Make sure "Copy items if needed" is **unchecked** and "Create groups" is
   selected.
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

## Day-to-day commands

```sh
# After making changes to watch sources, build the iPhone app — Xcode
# automatically rebuilds and re-embeds the watch app.
flutter build ios --debug --no-codesign

# Or run the iPhone app on a paired sim/device:
flutter run

# To run JUST the watch app on the watch sim, use Xcode's scheme picker
# (RunnerWatchApp scheme) — `flutter run` only knows about the iPhone target.
```

## Future feature work — WatchConnectivity wiring

The watch app already opens a `WCSession` at launch
(`WatchConnectivityManager.activate()`) but the iPhone side does **not** yet
have a counterpart. To enable bidirectional messaging:

### iPhone side (Flutter Runner target)

1. Add a `Runner/WatchSessionBridge.swift` to the iPhone target that mirrors
   `WatchConnectivityManager`:
   - `class WatchSessionBridge: NSObject, WCSessionDelegate { ... }`
   - On `application(_:didFinishLaunchingWithOptions:)`, instantiate the
     bridge and call `WCSession.default.activate()`.
2. Expose the bridge to Dart through a `MethodChannel`:
   - Channel name: `loadout/watch_bridge` (suggested).
   - Methods to surface: `sendToWatch(payload: Map)`,
     `latestFromWatch()` getter, plus an `EventChannel` for streaming
     incoming watch messages.
3. Wire it into `lib/main.dart` so Flutter can call `sendToWatch(...)` and
   subscribe to the watch event stream. Most LoadOut "phone → watch" use
   cases (e.g. push the active load to the watch when the user opens a
   range card) belong in a new `lib/services/watch_bridge_service.dart`.

### Suggested first feature — DOPE glance

Stream the active load + zero data from the iPhone to the watch so the
shooter sees:
- bullet name
- powder + charge
- last chrono velocity
- zeroed range / atmospheric DA at zero

Implementation sketch:
- iPhone: when user opens the load detail screen, call
  `sendToWatch({"type":"dope","loadId":...,"summary":{...}})` with a small
  JSON-serializable map.
- Watch: `WatchConnectivityManager.didReceiveMessage` decodes the payload
  into a `DopeSnapshot` struct and stores it in a published property the
  view tree can read.
- Persistence: cache the last snapshot in
  `UserDefaults(suiteName: "group.com.johnsondigital.loadout")` so the
  watch can display stale-but-useful data when the iPhone is asleep.

### Suggested second feature — shot logging

Watch records a tap → time-stamped shot → sends to iPhone for storage in
the on-device SQLite. Use `transferUserInfo` (queued, not real-time) so a
shooter at the range without their phone in their pocket still gets every
shot when the iPhone reconnects.

## Important — privacy posture

`CLAUDE.md` § Privacy posture says LoadOut never operates a backend that
receives reloading data. The watch app must follow the same rule:

- **No HTTP / network calls from the watch app.** All transport is
  `WatchConnectivity` (Apple-managed, peer-to-peer, encrypted in transit).
- The shared App Group container is on-device storage only.
- Do not import Firebase, RevenueCat, analytics, or crash-reporting SDKs
  into the watch target. Pro entitlement checks happen on the phone; the
  watch reflects whatever state the phone forwards to it.

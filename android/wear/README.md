# LoadOut Wear OS Companion

Native Kotlin / Compose for Wear OS companion module for the LoadOut
Android app. This is a sibling Gradle module to `:app` (the Flutter
Android module). It is **not** a Flutter app — Flutter does not yet
support Wear OS as a first-class target, so the watch companion is
implemented natively.

| | |
|---|---|
| Module | `:wear` |
| Package | `com.johnsondigital.loadout.wear` |
| Application ID | `com.johnsondigital.loadout.wear` |
| `minSdk` | 30 (Wear OS 3 / Android 11) |
| `targetSdk` / `compileSdk` | 34 |
| UI framework | Compose for Wear OS |
| Phone-watch transport | Google Play Services Wearable Data Layer API |

## Files in this module

```
android/wear/
├── build.gradle.kts                 Module Gradle config (Compose, deps)
├── proguard-rules.pro               Empty placeholder
├── .gitignore                       Ignore /build
└── src/main/
    ├── AndroidManifest.xml          Wear feature flag, Data Layer service
    ├── java/com/johnsondigital/loadout/wear/
    │   ├── MainActivity.kt          Compose for Wear OS "Coming Soon" UI
    │   └── PhoneDataLayerListener.kt Stub WearableListenerService
    └── res/
        ├── values/strings.xml
        ├── drawable/                Adaptive launcher icon assets
        └── mipmap-anydpi-v26/       Adaptive launcher icon manifests
```

## Day-to-day commands

The `:wear` module is wired into the existing Flutter Android Gradle build
(see `android/settings.gradle.kts`), so any Gradle command works against
both modules.

```sh
# From the project root:
cd android

# Build only the wear APK (debug):
./gradlew :wear:assembleDebug

# Install onto a connected Wear OS device or emulator:
./gradlew :wear:installDebug

# Build everything (phone APK via Flutter is not built by this command —
# use `flutter build apk` for that):
./gradlew build
```

`flutter build apk` only builds `:app`. It does **not** build `:wear`,
which is intentional — the watch APK is a separate artifact uploaded
to a separate Play Console listing (or the same listing as a paired
release set, once that is set up).

## Phone-watch transport — Data Layer API

The Wear OS counterpart of WatchConnectivity is Google Play Services'
**Wearable Data Layer API**. It supports:

| Mechanism | Use for |
|---|---|
| `MessageClient` | Real-time, fire-and-forget messages while both devices are reachable. Non-persistent. |
| `DataClient` (DataItem) | Synced state. Phone publishes a `DataItem` at a path; watch (and any other paired device) sees it on next reachability. Persistent. |
| `ChannelClient` | Streams (audio, large blobs). Not currently needed by LoadOut. |
| `CapabilityClient` | Discover whether a paired device has the LoadOut watch app installed. |

### Wiring up the phone side

The phone side lives in the Flutter `:app` module. Currently nothing in
`com.johnsondigital.loadout` (the Flutter Android host) talks to the
Wearable APIs — when feature work starts:

1. Add to `:app`'s `build.gradle.kts`:
   ```kotlin
   dependencies {
       implementation("com.google.android.gms:play-services-wearable:18.2.0")
   }
   ```
2. Create `android/app/src/main/kotlin/com/johnsondigital/loadout/WatchBridge.kt`
   that opens `Wearable.getMessageClient(this)` and exposes `sendMessage`,
   `addListener`, etc.
3. Bridge to Dart with a `MethodChannel`:
   - Channel name: `loadout/watch_bridge` (suggested, matches the iOS bridge).
   - Methods: `isWatchConnected()`, `sendToWatch(payload: Map)`.
   - Plus an `EventChannel` (`loadout/watch_bridge/events`) for streaming
     inbound watch messages back to Flutter.
4. From Dart, write `lib/services/watch_bridge_service.dart` that wraps the
   channel and is shared between iOS and Android implementations. The Swift
   side lives in `ios/Runner/WatchSessionBridge.swift` and uses the same
   channel names — so the Dart layer can be platform-agnostic.

### Wiring up the watch side (this module)

`PhoneDataLayerListener.kt` is registered in the manifest but its
`<intent-filter>` is **commented out**. Steps to enable it:

1. Uncomment the `<intent-filter>` block inside the `<service>` element in
   `AndroidManifest.xml`. Pick a path-prefix that matches what the phone
   is sending — `/loadout/` is the convention used in this module.
2. Implement `onMessageReceived` / `onDataChanged`:
   ```kotlin
   override fun onMessageReceived(messageEvent: MessageEvent) {
       when (messageEvent.path) {
           "/loadout/dope" -> {
               val payload = String(messageEvent.data)
               // Decode JSON, push into shared StateFlow, trigger UI.
           }
       }
   }
   ```
3. Hold the decoded snapshot in a process-scoped `StateFlow` (e.g. a
   `WatchAppState` object module that `MainActivity` collects in its
   `setContent { ... }` block). Don't put it in a singleton inside
   `MainActivity` — the listener service runs in its own process if the
   activity isn't open.

### Suggested first feature paths

| Path | Direction | Payload |
|---|---|---|
| `/loadout/active_load` | phone → watch | DataItem with bullet, powder, charge, primer, brass, last chrono velocity |
| `/loadout/dope` | phone → watch | Message with zero range, zero DA, drop / windage chart for current load |
| `/loadout/log_shot` | watch → phone | Message with timestamp + (optional) tap rhythm; phone enrolls into shot history |
| `/loadout/firearm_glance` | phone → watch | Message with active firearm name, total shots fired, barrel life remaining |

### Discovering whether the phone has the watch app installed

Useful for graceful degradation in the phone UI ("Open on watch" button):

```kotlin
Wearable.getCapabilityClient(context)
    .getCapability("loadout_watch_companion", CapabilityClient.FILTER_REACHABLE)
    .addOnSuccessListener { capabilityInfo ->
        val nodes = capabilityInfo.nodes
        val watchInstalled = nodes.isNotEmpty()
        // ...
    }
```

To declare the capability so the phone can find it:

1. Create `android/wear/src/main/res/values/wear.xml`:
   ```xml
   <resources>
       <string-array name="android_wear_capabilities">
           <item>loadout_watch_companion</item>
       </string-array>
   </resources>
   ```
2. Do the same on the phone module so the watch can detect the phone app.

This file is not created yet because no feature consumes the capability;
add it as part of the first feature that needs it.

## Important — privacy posture

`CLAUDE.md` § Privacy posture: LoadOut never operates a backend that
receives reloading data. The watch app must follow the same rule:

- **No HTTP / network calls from the watch app.** All transport is the
  Data Layer API (Google-managed, peer-to-peer, encrypted in transit).
- Do not import Firebase, RevenueCat, analytics, or crash-reporting SDKs
  into the `:wear` module. Pro entitlement checks happen on the phone;
  the watch reflects whatever state the phone forwards to it via the
  Data Layer.
- Local state on the watch (cached `DataItem`s, last shot, last DOPE)
  is fine — it never leaves the user's wrist.

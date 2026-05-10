// FILE: ios/RunnerWatchApp/WatchAppDelegate.swift
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Holds onto the long-lived companion-app state for the watch — the
// WatchConnectivity manager AND the four feature view-models the SwiftUI
// tree needs:
//   * `connectivity: WatchConnectivityManager` — transport.
//   * `dopeViewModel: DopeViewModel` — receives `dope` / `active_load` /
//     `firearm_glance` payloads from the phone.
//   * `timerEngine: TimerEngine` — drives the stage timer; emits
//     `timer_event` payloads to the phone for cross-device mirroring.
//   * `shotLogger: ShotLogger` — emits `log_shot` payloads from the
//     stage-log screen.
//
// On `applicationDidFinishLaunching` it:
//   1. Activates the WatchConnectivity session.
//   2. Binds `connectivity.onIncomingPayload` to
//      `dopeViewModel.handle(path:payload:)` so inbound payloads decode
//      into typed snapshots.
//   3. Binds `timerEngine.send` to a closure that wraps the timer event
//      in the `{path: "timer_event", payload: ...}` envelope.
//   4. Binds `shotLogger.send` to the same envelope shape under
//      `path: "log_shot"`.
//
// Using `WKApplicationDelegateAdaptor` (modern watchOS 7+ entry point)
// lets us own these objects without stuffing them into the SwiftUI App
// struct, which would re-instantiate them on every view rebuild.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// SwiftUI's environment-object injection works best when the producers
// of those objects live OUTSIDE the view tree. If `LoadOutWatchApp`
// instantiated `TimerEngine()` directly inside its `body`, the engine
// would be reinitialised every time the App's body re-evaluated — which
// would reset the timer mid-tick. The `@WKApplicationDelegateAdaptor`
// wrapper holds a single instance of the delegate for the app's
// lifetime, and we hang the long-lived state off it.
//
// Centralising the binding wiring here also means there's exactly one
// place to look when something doesn't reach the watch UI: "did the
// delegate instantiate it AND bind the closures?"
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Closure binding has to happen AFTER the manager is constructed
//    but BEFORE the session activates.** If we bind the inbound
//    routing closure after `activate()`, the very first delegate
//    callback can fire while `onIncomingPayload` is still nil, and the
//    payload gets logged-but-dropped. Order matters: build the engines
//    + closures first, activate the session last.
//
// 2. **`engine.send` and `logger.send` capture `[weak self]`.**
//    Otherwise the closure would create a retain cycle:
//    delegate → engine → closure → delegate. With `[weak self]`, the
//    closure no-ops cleanly if the delegate ever deinits (which it
//    won't in production, but matters for tests / previews).
//
// 3. **Both senders use the path-aware `connectivity.send(path:
//    payload:)` overload.** Wrapping the bare payload in
//    `{path: ..., payload: ...}` matches the Dart-side receiver in
//    `lib/services/watch_bridge_service.dart`'s `_onEvent` which
//    expects an envelope. If a feature shipped a raw payload, the
//    iPhone bridge would silently drop it.
//
// 4. **`@Published` properties on these engines fire on the main
//    queue.** SwiftUI requires that. The senders all hop to main
//    inside their respective implementations, so the delegate doesn't
//    need to do its own dispatching here — but if you ever bind a
//    sender that writes published state directly, double-check the
//    queue.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `LoadOutWatchApp.swift` — reads `appDelegate.connectivity`,
//   `dopeViewModel`, `timerEngine`, `shotLogger` and injects them as
//   environment objects.
//
// File ships on disk but only enters the Xcode build once the
// operator follows the watch-target wire-up in CLAUDE.md §15.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Activates `WCSession` once at launch (no-op on hardware that doesn't
//   support WatchConnectivity).
// - Bound closures emit peer-to-peer `WatchConnectivity` messages — no
//   HTTP / network calls.

import Foundation
import WatchKit

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    let connectivity = WatchConnectivityManager()
    let dopeViewModel = DopeViewModel()
    let timerEngine = TimerEngine()
    let shotLogger = ShotLogger()

    func applicationDidFinishLaunching() {
        // 1. Wire inbound routing FIRST so the very first delegate
        //    callback (which can land before activate() returns) is
        //    decoded into the typed view-model.
        connectivity.onIncomingPayload = { [weak self] path, payload in
            self?.dopeViewModel.handle(path: path, payload: payload)
        }

        // 2. Bind the outbound senders. Each engine produces a bare
        //    payload; we wrap it in the `{path, payload}` envelope so
        //    the iPhone bridge can route it.
        timerEngine.send = { [weak self] payload in
            self?.connectivity.send(path: WatchPaths.timerEvent, payload: payload)
        }
        shotLogger.send = { [weak self] payload in
            self?.connectivity.send(path: WatchPaths.logShot, payload: payload)
        }

        // 3. Activate the session last so any startup race lands on
        //    fully-bound closures.
        connectivity.activate()
    }
}

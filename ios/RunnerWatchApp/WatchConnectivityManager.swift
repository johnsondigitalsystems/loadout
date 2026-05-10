// FILE: ios/RunnerWatchApp/WatchConnectivityManager.swift
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Wrapper around Apple's `WCSession` for the LoadOut watch companion. Owns
// the activation lifecycle, publishes reachability state, sends outbound
// payloads (`active_load`, `dope`, `firearm_glance`, `log_shot`,
// `timer_event`, `shot_capture_sensitivity`), and dispatches inbound
// payloads to whatever consumer wants them.
//
// Public surface:
//   * `@Published var isReachable: Bool` — true while the iPhone is in the
//     foreground and reachable in real time. When false, outbound sends
//     fall back to `transferUserInfo` (queued).
//   * `@Published var lastReceivedPayload: [String: Any]` — most-recent
//     inbound dictionary; useful for debug HUDs.
//   * `@Published var shotCaptureSensitivity: String?` — most-recent
//     phone-pushed sensitivity preset. Persists via `MotionDetector`'s
//     own UserDefaults backing.
//   * `func activate()` — kick off `WCSession.activate()`. Idempotent.
//   * `func send(_ payload:)` — bare push of a `[String: Any]` envelope
//     produced by the caller (the caller stamps in `path` + `payload`
//     keys so the iPhone bridge can route it).
//   * `func send(path:payload:)` — convenience that builds the
//     `{"path": ..., "payload": ...}` envelope so per-feature callers
//     (TimerEngine, ShotLogger) don't have to.
//   * `var onIncomingPayload: ((String, [String: Any]) -> Void)?` —
//     bound by `WatchAppDelegate` to the DopeViewModel's `handle(path:
//     payload:)` so inbound `dope` / `active_load` / `firearm_glance`
//     payloads are decoded into typed structs without this class
//     knowing about them.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// SwiftUI views need an `ObservableObject` they can observe; raw
// `WCSession` is not one. This class is the boundary between Apple's
// callback-and-delegate API and the app's `@Published` reactive model.
//
// Keeping the class transport-only (no per-feature payload structs) means
// adding a feature is "instantiate a new view-model + bind a closure",
// not "extend the connectivity manager." DopeViewModel, TimerEngine,
// ShotLogger all sit beside this class — none of them subclass it.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **`WCSession.default` only works when `WCSession.isSupported()`.**
//    Some watch hardware is paired but doesn't support WatchConnectivity
//    (rare but possible). We capture the optional once at init so every
//    method downstream can early-return safely instead of trapping.
//
// 2. **`isReachable` writes hop to main.** The delegate callbacks fire
//    on a background queue. Writing to a `@Published` from off-main
//    breaks SwiftUI; every mutation is wrapped in
//    `DispatchQueue.main.async`.
//
// 3. **`send` falls back to `transferUserInfo` when unreachable.**
//    `sendMessage` requires the counterpart to be in the foreground;
//    `transferUserInfo` queues until the counterpart is reachable. For
//    `log_shot` events that fire while the iPhone is asleep, the
//    queued path is mandatory — without it the user would lose shots
//    they fired in the field.
//
// 4. **`onIncomingPayload` is optional and main-queue-sync.** We invoke
//    it from the main queue because the DopeViewModel hops to main
//    anyway and the auto-confirm queue plumbing is simpler when both
//    sides agree on the queue. When it's `nil` (preview / test
//    environments), the inbound is just stashed in
//    `lastReceivedPayload` for debug visibility.
//
// 5. **`shotCaptureSensitivity` is decoded inline because it's the
//    only path that tunes a published preference on this object.**
//    The watch UI reads it via the manager's `@Published` so the
//    settings sheet can mirror what the phone last pushed without
//    routing through DopeViewModel.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `WatchAppDelegate.swift` — instantiates one, calls `activate()` on
//   launch, binds `onIncomingPayload` to `DopeViewModel.handle(path:
//   payload:)`, and binds the `send` closures on `TimerEngine` and
//   `ShotLogger`.
// - `LoadOutWatchApp.swift` — reads `appDelegate.connectivity` and
//   injects via `.environmentObject(...)` so any view can observe.
// - `StageLogView.swift` — reads `shotCaptureSensitivity` to mirror the
//   phone's preset into the legacy settings sheet.
// - `AboutView.swift` — reads `isReachable` for the "iPhone Linked"
//   diagnostic row.
//
// File ships on disk but only enters the Xcode build once the operator
// follows the watch-target wire-up in CLAUDE.md §15.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Activates `WCSession` on `activate()`. WatchConnectivity is Apple-
//   managed encrypted peer-to-peer; nothing is sent off the user's
//   phone+watch pair. No HTTP, no analytics — see CLAUDE.md §13.
// - Mutates `@Published` state on the main queue.
// - Calls `onIncomingPayload` (best-effort) on every inbound message
//   that wasn't a known internal path.

import Foundation
import WatchConnectivity
import Combine

final class WatchConnectivityManager: NSObject, ObservableObject {
    @Published private(set) var isReachable: Bool = false
    @Published private(set) var lastReceivedPayload: [String: Any] = [:]

    /// Phone-pushed shot-capture sensitivity preset (`"off" | "low" |
    /// "medium" | "high"`). Drained by `MotionDetector.applySensitivity`.
    /// Persists across reboots via the detector's UserDefaults backing.
    @Published private(set) var shotCaptureSensitivity: String?

    /// Bound by `WatchAppDelegate` to the DopeViewModel's
    /// `handle(path:payload:)` so inbound `dope` / `active_load` /
    /// `firearm_glance` payloads land in the typed view-model. Optional
    /// — when nil (previews, tests) the manager still records the raw
    /// payload in `lastReceivedPayload` for diagnostic surfaces.
    var onIncomingPayload: ((String, [String: Any]) -> Void)?

    private let session: WCSession?

    override init() {
        self.session = WCSession.isSupported() ? WCSession.default : nil
        super.init()
    }

    // MARK: - Lifecycle

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    // MARK: - Sending

    /// Fire-and-forget push of a fully-formed `[String: Any]` envelope.
    /// Falls back to the queued `transferUserInfo` path when the
    /// counterpart is asleep so events fired in the field still land
    /// once the phone is back in range.
    func send(_ payload: [String: Any]) {
        guard let session, session.activationState == .activated else { return }
        guard session.isReachable else {
            session.transferUserInfo(payload)
            return
        }
        session.sendMessage(payload, replyHandler: nil) { _ in
            // Errors here are usually transient (counterpart went away).
            // The watch app intentionally has no logger; surface via
            // print() during local dev if needed.
        }
    }

    /// Convenience overload that builds the `{ "path": ..., "payload":
    /// ... }` envelope for callers (TimerEngine, ShotLogger) that only
    /// produce the inner payload. Mirrors the iPhone-side
    /// `WatchSessionBridge.send` shape so paths route through the
    /// bridge cleanly.
    func send(path: String, payload: [String: Any]) {
        let envelope: [String: Any] = [
            "path": path,
            "payload": payload
        ]
        send(envelope)
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.lastReceivedPayload = message
            self?.routeIncoming(message)
        }
    }

    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async { [weak self] in
            self?.lastReceivedPayload = userInfo
            self?.routeIncoming(userInfo)
        }
    }

    /// Pull the path/payload envelope out of the WatchConnectivity dict
    /// and dispatch. The phone bridge wraps every send in `{ "path":
    /// <short>, "payload": <map> }`; this matches that contract.
    ///
    /// Internal-only paths (today: `shot_capture_sensitivity`) update
    /// the manager's own `@Published` state. Everything else gets
    /// forwarded to `onIncomingPayload` so the DopeViewModel (or any
    /// future per-feature consumer) can decode.
    ///
    /// `internal` (the default access level) so the test shim
    /// `_test_routeIncoming` in the extension below can call it
    /// directly. The unit-test target uses `@testable import` to see
    /// internal symbols.
    func routeIncoming(_ envelope: [String: Any]) {
        guard let path = envelope["path"] as? String else { return }
        let payload = envelope["payload"] as? [String: Any] ?? [:]
        switch path {
        case WatchPaths.shotCaptureSensitivity:
            if let value = payload["value"] as? String {
                self.shotCaptureSensitivity = value
            }
        default:
            // Forward everything else to the bound consumer. When the
            // closure is unbound (preview / test), the payload is still
            // visible via `lastReceivedPayload`.
            onIncomingPayload?(path, payload)
        }
    }
}

// MARK: - Preview helpers

extension WatchConnectivityManager {
    /// SwiftUI preview-friendly instance that does not touch `WCSession`.
    static var preview: WatchConnectivityManager {
        let manager = WatchConnectivityManager()
        return manager
    }

    /// Test-only entry point that drives `routeIncoming` from XCTest.
    /// The unit-test target can't synthesize a `WCSession` argument to
    /// call the delegate methods, so this shim lets tests verify the
    /// routing contract directly. Production code never calls this;
    /// the underscore prefix telegraphs that.
    ///
    /// Mirrors the real delegate path: stash the raw payload first
    /// (so `lastReceivedPayload` stays the canonical "what came in
    /// last" surface), then dispatch.
    func _test_routeIncoming(_ envelope: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.lastReceivedPayload = envelope
            self?.routeIncoming(envelope)
        }
    }
}

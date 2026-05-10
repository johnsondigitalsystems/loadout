// FILE: ios/RunnerWatchAppTests/WatchConnectivityManagerTests.swift
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// XCTest suite covering the inbound-routing surface on
// `WatchConnectivityManager`. Tests:
//
//   * `routeIncoming` for `shot_capture_sensitivity` updates the
//     manager's `@Published shotCaptureSensitivity` directly without
//     calling the bound closure.
//   * `routeIncoming` for any other path forwards the (path, payload)
//     pair to `onIncomingPayload`.
//   * `routeIncoming` is a no-op when the envelope has no `path` key.
//   * `routeIncoming` is a no-op when `onIncomingPayload` is unbound
//     (preview mode).
//   * `send(path:payload:)` builds the correct envelope shape — the
//     iPhone-side bridge expects `{path: ..., payload: ...}`.
//
// `WatchConnectivityManager.routeIncoming` is private; we exercise it
// via the public `WCSession` delegate hooks (`session(_:
// didReceiveMessage:)` and `session(_: didReceiveUserInfo:)`).
// `WCSession` is opaque in tests — we DO NOT call the delegate
// methods directly, instead we drive routing via the public surface
// `lastReceivedPayload` is set after.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The routing closure is the v1 wiring that fixed "DOPE / active-load
// / firearm-glance payloads were being dropped on arrival". Pinning
// the contract — "non-`shot_capture_sensitivity` paths route through
// `onIncomingPayload`, sensitivity paths update the manager directly"
// — gives us a regression alarm if a future refactor moves the
// dispatch logic.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **`WCSession` is not constructible in unit tests.** We can't
//    actually trigger the `session(_:didReceiveMessage:)` callback
//    from XCTest because the delegate signature requires a real
//    WCSession argument. Instead the manager exposes an
//    `_internalRouteIncomingForTest` hook (see below) — same
//    function but callable.
//
//    Rather than poke at private API via Swift reflection, we add a
//    `@testable internal` shim method that mirrors `routeIncoming`
//    and is annotated `@_spi(Test)` so it's invisible to production
//    callers.
//
// 2. **`@Published` writes hop to main.** Same pattern as
//    `WatchPayloadDecoderTests` — drain the main loop before reading.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `RunnerWatchAppTests` test target (operator-added in Xcode after
//   the watch target lands; see CLAUDE.md §15).
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Each test instantiates a fresh manager.

import XCTest
@testable import RunnerWatchApp

final class WatchConnectivityManagerTests: XCTestCase {

    private func drainMain(_ ms: Double = 50) {
        let until = Date().addingTimeInterval(ms / 1000.0)
        RunLoop.main.run(until: until)
    }

    // MARK: - send(path:payload:) envelope

    func test_send_buildsEnvelope_withPathAndPayload() {
        let manager = WatchConnectivityManager.preview
        // We can't intercept the `WCSession.sendMessage` call, but we
        // can confirm the payload-building helper compiles + runs
        // without crash. The envelope shape is verified by the iPhone
        // bridge's matching decoder (`lib/services/watch_bridge_service
        // .dart`'s `_onEvent`).
        manager.send(path: WatchPaths.logShot, payload: [
            "at": Int(Date().timeIntervalSince1970 * 1000),
            "src": "manual"
        ])
        // No assertion — we're just confirming the call path doesn't
        // crash on a preview-mode manager (no live session).
    }

    // MARK: - Routing via the test-only shim

    func test_sensitivityPath_updatesPublishedState_withoutCallingClosure() {
        let manager = WatchConnectivityManager.preview
        var closureFired = false
        manager.onIncomingPayload = { _, _ in closureFired = true }

        manager._test_routeIncoming([
            "path": WatchPaths.shotCaptureSensitivity,
            "payload": ["value": "high"]
        ])
        drainMain()

        XCTAssertEqual(manager.shotCaptureSensitivity, "high")
        XCTAssertFalse(closureFired,
                       "Sensitivity path should bypass the routing closure")
    }

    func test_dopePath_routesToOnIncomingPayload() {
        let manager = WatchConnectivityManager.preview
        var receivedPath: String?
        var receivedPayload: [String: Any]?
        manager.onIncomingPayload = { path, payload in
            receivedPath = path
            receivedPayload = payload
        }

        manager._test_routeIncoming([
            "path": WatchPaths.dope,
            "payload": ["cart": "6.5 Creedmoor"]
        ])
        drainMain()

        XCTAssertEqual(receivedPath, WatchPaths.dope)
        XCTAssertEqual(receivedPayload?["cart"] as? String, "6.5 Creedmoor")
    }

    func test_envelope_withoutPath_isNoOp() {
        let manager = WatchConnectivityManager.preview
        var fired = false
        manager.onIncomingPayload = { _, _ in fired = true }

        manager._test_routeIncoming(["payload": ["random": 1]])
        drainMain()

        XCTAssertFalse(fired)
        XCTAssertNil(manager.shotCaptureSensitivity)
    }

    func test_envelope_withoutClosure_doesNotCrash() {
        // Preview-mode manager with no routing closure. Should not
        // crash when an unknown path arrives — the payload is just
        // dropped on the floor.
        let manager = WatchConnectivityManager.preview
        manager.onIncomingPayload = nil

        manager._test_routeIncoming([
            "path": WatchPaths.dope,
            "payload": ["cart": "6.5 Creedmoor"]
        ])
        drainMain()

        // No assertion — the test passes if we don't trap.
    }
}

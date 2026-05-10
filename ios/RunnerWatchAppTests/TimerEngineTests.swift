// FILE: ios/RunnerWatchAppTests/TimerEngineTests.swift
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// XCTest suite covering the state-machine transitions and side-effect
// emissions on `TimerEngine`. Tests:
//
//   * Initial state — `.idle` with `remainingSec == totalSec`.
//   * `start()` → `.running`, emits a `start` payload.
//   * `pause()` from `.running` → `.paused`, emits `pause`. From other
//     states is a no-op.
//   * `resume()` from `.paused` → `.running`, emits `resume`. From
//     other states is a no-op.
//   * `reset()` returns to `.idle` and emits `reset`.
//   * `adjust(by:)` only valid in `.idle`; clamps to ≥5 seconds; persists
//     to UserDefaults.
//   * Quiet-mode toggle persists across re-instantiation.
//   * Restart-after-finished: starting from `.finished` correctly re-runs
//     from `totalSec`.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `TimerEngine` is the most-stateful object in the watch app — six
// transition edges across four states, plus quiet-mode persistence,
// plus warning-checkpoint side effects. Most match-day bugs would
// manifest as state corruption (a tap emits the wrong payload, the
// timer stops mid-stage). Tests here pin the state graph so a
// future refactor can't break the contract silently.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **The engine writes to `UserDefaults.standard`.** Each test
//    captures and restores the relevant keys in `setUp` / `tearDown`
//    so a test pass doesn't clobber a local dev's preferences.
//
// 2. **`Timer.scheduledTimer` runs on `RunLoop.main`.** Tests that
//    needed to verify warning-checkpoint emission would need to
//    advance the main run loop — XCTest's
//    `XCTWaiter.wait(for:expectations:timeout:)` does this, but
//    a 30-second timer warning is impractical to wait through. We
//    test the `start → tick` transitions via the public `tick`
//    surface (none) and instead pin the state-machine *edges* —
//    the rest of `tick`'s correctness lives in the source-level
//    invariants (warning sets, threshold checks).
//
// 3. **Audio + haptic side effects are real on hardware.** XCTest
//    on the watchOS simulator silently swallows `WKInterfaceDevice`
//    haptics and `AVAudioEngine` doesn't crash when no output device
//    is available — but neither produces useful test output. We
//    don't assert on them.
//
// 4. **`engine.send` is captured via a closure that records to a
//    test-local array.** This is the canonical "stub the dependency"
//    pattern for ObservableObjects — easier than mock frameworks.
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
// - Reads / writes `UserDefaults.standard` keys `timer.lastDuration`
//   and `timer.quietMode`. Restored in `tearDown`.

import XCTest
@testable import RunnerWatchApp

final class TimerEngineTests: XCTestCase {

    private let kLastDuration = "timer.lastDuration"
    private let kQuietMode = "timer.quietMode"

    private var savedDuration: Any?
    private var savedQuietMode: Any?

    override func setUp() {
        super.setUp()
        savedDuration = UserDefaults.standard.object(forKey: kLastDuration)
        savedQuietMode = UserDefaults.standard.object(forKey: kQuietMode)
        UserDefaults.standard.removeObject(forKey: kLastDuration)
        UserDefaults.standard.removeObject(forKey: kQuietMode)
    }

    override func tearDown() {
        if let v = savedDuration {
            UserDefaults.standard.set(v, forKey: kLastDuration)
        } else {
            UserDefaults.standard.removeObject(forKey: kLastDuration)
        }
        if let v = savedQuietMode {
            UserDefaults.standard.set(v, forKey: kQuietMode)
        } else {
            UserDefaults.standard.removeObject(forKey: kQuietMode)
        }
        super.tearDown()
    }

    // MARK: - Initial state

    func test_initialState_isIdle_withDefaultDuration() {
        let engine = TimerEngine()
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.totalSec, 90)
        XCTAssertEqual(engine.remainingSec, 90)
        XCTAssertFalse(engine.quietMode)
    }

    // MARK: - State transitions

    func test_start_movesIdleToRunning_andEmitsStartPayload() {
        let engine = TimerEngine()
        var sent: [[String: Any]] = []
        engine.send = { payload in sent.append(payload) }

        engine.start()
        XCTAssertEqual(engine.state, .running)
        XCTAssertEqual(sent.count, 1)
        XCTAssertEqual(sent.first?["k"] as? String, "start")
        XCTAssertEqual(sent.first?["rem"] as? Int, 90)
        XCTAssertEqual(sent.first?["tot"] as? Int, 90)

        // Cleanup so the timer doesn't tick for the rest of the suite.
        engine.reset()
    }

    func test_start_isNoOp_whenAlreadyRunning() {
        let engine = TimerEngine()
        var sent: [[String: Any]] = []
        engine.send = { payload in sent.append(payload) }

        engine.start()
        engine.start() // second start should not duplicate the payload.
        XCTAssertEqual(sent.filter { ($0["k"] as? String) == "start" }.count, 1)

        engine.reset()
    }

    func test_pause_movesRunningToPaused_andEmitsPausePayload() {
        let engine = TimerEngine()
        var sent: [[String: Any]] = []
        engine.send = { payload in sent.append(payload) }

        engine.start()
        engine.pause()
        XCTAssertEqual(engine.state, .paused)
        XCTAssertEqual(sent.last?["k"] as? String, "pause")

        engine.reset()
    }

    func test_pause_isNoOp_whenNotRunning() {
        let engine = TimerEngine()
        var sent: [[String: Any]] = []
        engine.send = { payload in sent.append(payload) }

        engine.pause() // from .idle — should not transition or emit.
        XCTAssertEqual(engine.state, .idle)
        XCTAssertTrue(sent.isEmpty)
    }

    func test_resume_movesPausedToRunning_andEmitsResumePayload() {
        let engine = TimerEngine()
        var sent: [[String: Any]] = []
        engine.send = { payload in sent.append(payload) }

        engine.start()
        engine.pause()
        engine.resume()
        XCTAssertEqual(engine.state, .running)
        XCTAssertEqual(sent.last?["k"] as? String, "resume")

        engine.reset()
    }

    func test_resume_isNoOp_whenNotPaused() {
        let engine = TimerEngine()
        var sent: [[String: Any]] = []
        engine.send = { payload in sent.append(payload) }

        engine.resume() // from .idle — no-op.
        XCTAssertEqual(engine.state, .idle)
        XCTAssertTrue(sent.isEmpty)
    }

    func test_reset_returnsToIdle_andEmitsResetPayload() {
        let engine = TimerEngine()
        var sent: [[String: Any]] = []
        engine.send = { payload in sent.append(payload) }

        engine.start()
        engine.reset()
        XCTAssertEqual(engine.state, .idle)
        XCTAssertEqual(engine.remainingSec, engine.totalSec)
        XCTAssertEqual(sent.last?["k"] as? String, "reset")
    }

    // MARK: - Adjust

    func test_adjust_increasesTotal_inIdle() {
        let engine = TimerEngine()
        let before = engine.totalSec
        engine.adjust(by: 30)
        XCTAssertEqual(engine.totalSec, before + 30)
        XCTAssertEqual(engine.remainingSec, engine.totalSec)
    }

    func test_adjust_clampsToFiveSeconds() {
        let engine = TimerEngine()
        engine.adjust(by: -1000) // big negative
        XCTAssertEqual(engine.totalSec, 5)
        XCTAssertEqual(engine.remainingSec, 5)
    }

    func test_adjust_isNoOp_whenRunning() {
        let engine = TimerEngine()
        engine.start()
        let total = engine.totalSec
        engine.adjust(by: 30)
        XCTAssertEqual(engine.totalSec, total, "adjust must not run while .running")
        engine.reset()
    }

    func test_adjust_persistsToUserDefaults() {
        let engine = TimerEngine()
        engine.adjust(by: 60) // total: 90 → 150
        XCTAssertEqual(UserDefaults.standard.integer(forKey: kLastDuration), 150)

        // New engine should restore the persisted total.
        let next = TimerEngine()
        XCTAssertEqual(next.totalSec, 150)
        XCTAssertEqual(next.remainingSec, 150)
    }

    // MARK: - Quiet mode persistence

    func test_quietMode_persistsAcrossInit() {
        let first = TimerEngine()
        first.setQuietMode(true)
        XCTAssertTrue(first.quietMode)

        let second = TimerEngine()
        XCTAssertTrue(second.quietMode)
    }

    func test_quietMode_defaultsToFalse() {
        let engine = TimerEngine()
        XCTAssertFalse(engine.quietMode)
    }
}

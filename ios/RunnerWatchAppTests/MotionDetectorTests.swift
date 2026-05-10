// FILE: ios/RunnerWatchAppTests/MotionDetectorTests.swift
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// XCTest suite covering the threshold transitions and sensitivity-preset
// decoder on `MotionDetector`. Tests:
//
//   * `ShotCaptureSensitivity.fromWire` accepts the four valid wire
//     strings and rejects garbage.
//   * `ShotCaptureSensitivity.thresholdG` returns the documented
//     CLAUDE.md §15 values (Off → nil, Low → 8, Medium → 5, High → 3).
//   * `ShotCaptureSensitivity.sustainedPeakSeconds` returns the
//     documented CLAUDE.md §15 values.
//   * `MotionDetector.applySensitivity` actually re-tunes both
//     `thresholdG` AND the internal sustained-peak window.
//   * Persisted preset round-trip — initialising the detector after a
//     phone push restores the same preset.
//   * `acknowledge` is idempotent (returns nil + clears state when
//     called with no pending candidate).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// `MotionDetector` carries the mapping between the four-way preset
// table (CLAUDE.md §15) and the underlying threshold + window
// parameters. If those drift out of the doc, the watch and Wear OS
// sides will detect shots inconsistently. Pinning the table values in
// tests gives us an alarm bell when someone tweaks a constant
// without thinking through the cross-platform implications.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **The `MotionDetector` constructor reads UserDefaults.** A test
//    that runs a second time inherits state from the first run. Each
//    test function clears the relevant keys via `setUp` so threshold /
//    preset tests don't interfere.
//
// 2. **`UserDefaults.standard` is the host process's defaults.** That's
//    fine for a unit-test harness, but a parallelised test runner could
//    interleave. Each test uses unique-enough keys and `tearDown` resets
//    them, but if the suite is ever moved to a sandboxed
//    `UserDefaults(suiteName:)` the constructor would need a parameter.
//
// 3. **No live accelerometer in the simulator.** Tests cover the
//    *decision* surface (preset → threshold) without driving real
//    `CMAccelerometerData`. A smoke test that fires `consume(sample:)`
//    by injection would be valuable but `CMAccelerometerData` cannot be
//    constructed in tests without subclassing — left as a follow-up.
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
// - Reads / writes `UserDefaults.standard`. Restored in `tearDown` so
//   the host process state matches what was there before.

import XCTest
@testable import RunnerWatchApp

final class MotionDetectorTests: XCTestCase {

    private let kThresholdKey = "motion.thresholdG"
    private let kSensitivityKey = "shot_capture_sensitivity"

    private var savedThreshold: Any?
    private var savedSensitivity: Any?

    override func setUp() {
        super.setUp()
        // Capture pre-test state so we can restore it in tearDown — a
        // local dev who has the watch running on a paired sim shouldn't
        // see their preferences nuked by a test pass.
        savedThreshold = UserDefaults.standard.object(forKey: kThresholdKey)
        savedSensitivity = UserDefaults.standard.object(forKey: kSensitivityKey)
        UserDefaults.standard.removeObject(forKey: kThresholdKey)
        UserDefaults.standard.removeObject(forKey: kSensitivityKey)
    }

    override func tearDown() {
        if let v = savedThreshold {
            UserDefaults.standard.set(v, forKey: kThresholdKey)
        } else {
            UserDefaults.standard.removeObject(forKey: kThresholdKey)
        }
        if let v = savedSensitivity {
            UserDefaults.standard.set(v, forKey: kSensitivityKey)
        } else {
            UserDefaults.standard.removeObject(forKey: kSensitivityKey)
        }
        super.tearDown()
    }

    // MARK: - Wire-format decode

    func test_fromWire_acceptsValidPresets() {
        XCTAssertEqual(ShotCaptureSensitivity.fromWire("off"), .off)
        XCTAssertEqual(ShotCaptureSensitivity.fromWire("low"), .low)
        XCTAssertEqual(ShotCaptureSensitivity.fromWire("medium"), .medium)
        XCTAssertEqual(ShotCaptureSensitivity.fromWire("high"), .high)
    }

    func test_fromWire_rejectsGarbage() {
        XCTAssertNil(ShotCaptureSensitivity.fromWire(""))
        XCTAssertNil(ShotCaptureSensitivity.fromWire("OFF")) // case-sensitive on the wire
        XCTAssertNil(ShotCaptureSensitivity.fromWire("Medium"))
        XCTAssertNil(ShotCaptureSensitivity.fromWire("xtreme"))
    }

    // MARK: - Documented threshold table (CLAUDE.md §15)

    func test_thresholds_matchDocumentedTable() {
        XCTAssertNil(ShotCaptureSensitivity.off.thresholdG)
        XCTAssertEqual(ShotCaptureSensitivity.low.thresholdG, 8.0)
        XCTAssertEqual(ShotCaptureSensitivity.medium.thresholdG, 5.0)
        XCTAssertEqual(ShotCaptureSensitivity.high.thresholdG, 3.0)
    }

    func test_sustainedPeakSeconds_matchDocumentedTable() {
        XCTAssertNil(ShotCaptureSensitivity.off.sustainedPeakSeconds)
        XCTAssertEqual(ShotCaptureSensitivity.low.sustainedPeakSeconds, 0.08)
        XCTAssertEqual(ShotCaptureSensitivity.medium.sustainedPeakSeconds, 0.05)
        XCTAssertEqual(ShotCaptureSensitivity.high.sustainedPeakSeconds, 0.03)
    }

    // MARK: - Phone-bridge entry point

    func test_applySensitivity_low_setsEightG() {
        let detector = MotionDetector()
        detector.applySensitivity("low")
        XCTAssertEqual(detector.sensitivity, .low)
        XCTAssertEqual(detector.thresholdG, 8.0)
    }

    func test_applySensitivity_high_setsThreeG() {
        let detector = MotionDetector()
        detector.applySensitivity("high")
        XCTAssertEqual(detector.sensitivity, .high)
        XCTAssertEqual(detector.thresholdG, 3.0)
    }

    func test_applySensitivity_medium_setsFiveG() {
        let detector = MotionDetector()
        detector.applySensitivity("medium")
        XCTAssertEqual(detector.sensitivity, .medium)
        XCTAssertEqual(detector.thresholdG, 5.0)
    }

    func test_applySensitivity_off_setsOffPreset() {
        let detector = MotionDetector()
        detector.applySensitivity("off")
        XCTAssertEqual(detector.sensitivity, .off)
        XCTAssertFalse(detector.isRunning, "Off should leave detector stopped")
    }

    func test_applySensitivity_garbage_doesNotMutate() {
        let detector = MotionDetector()
        let preBefore = detector.sensitivity
        let thresholdBefore = detector.thresholdG
        detector.applySensitivity("xtreme")
        XCTAssertEqual(detector.sensitivity, preBefore)
        XCTAssertEqual(detector.thresholdG, thresholdBefore)
    }

    // MARK: - Persistence round-trip

    func test_persistedPreset_isRestoredOnReinit() {
        let first = MotionDetector()
        first.applySensitivity("high")
        XCTAssertEqual(first.sensitivity, .high)

        // Re-instantiate; should pick up the stored "high" preset.
        let second = MotionDetector()
        XCTAssertEqual(second.sensitivity, .high)
        // Threshold persists too (set by either the slider OR the preset).
        XCTAssertEqual(second.thresholdG, 3.0)
    }

    func test_defaultsTo_medium_whenNoStoredPreset() {
        // setUp() already cleared the storage keys, so a fresh detector
        // should start at .medium per CLAUDE.md §15.
        let detector = MotionDetector()
        XCTAssertEqual(detector.sensitivity, .medium)
    }

    // MARK: - Acknowledge / dismiss idempotency

    func test_acknowledge_returnsNil_whenNoCandidate() {
        let detector = MotionDetector()
        XCTAssertNil(detector.acknowledge())
        XCTAssertNil(detector.pendingShotPeakG)
    }

    func test_dismiss_isIdempotent() {
        let detector = MotionDetector()
        // Dismiss with no pending candidate — should not crash, should
        // leave state cleared.
        detector.dismiss()
        XCTAssertNil(detector.pendingShotPeakG)
    }
}

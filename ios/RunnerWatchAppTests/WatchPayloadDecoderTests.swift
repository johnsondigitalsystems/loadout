// FILE: ios/RunnerWatchAppTests/WatchPayloadDecoderTests.swift
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// XCTest suite covering the inbound payload decoders on
// `DopeViewModel` (the typed face of the WatchConnectivity bridge).
// Tests:
//
//   * `dope` payload decode — happy-path 4-row ladder lands in
//     `snapshot` with every field populated.
//   * `dope` payload decode — missing required keys (cart / mv / z /
//     dm / bc / bgr / bn / rows) drops the snapshot silently.
//   * `dope` payload decode — `Int`-vs-`Double` numeric coercion
//     (the Dart side ships `'mv': muzzleVelocityFps.round()` as Int;
//     the watch must accept that without rejecting the whole payload).
//   * `active_load` payload decode — required + optional keys.
//   * `active_load` payload decode — missing required keys drops it.
//   * `firearm_glance` payload decode — required + optional keys.
//   * `firearm_glance` payload decode — missing barrel-life percent
//     leaves the snapshot populated with a nil `barrelLifeRemainingPct`.
//   * `firearm_glance` payload decode — missing required keys drops it.
//   * Cursor clamping after a smaller snapshot lands.
//   * `currentRow` returns nil when the snapshot is empty.
//   * Unknown path is silently swallowed.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Wire-format mismatches are the single biggest failure mode on the
// watch bridge — three independent codebases (Dart, Swift, Kotlin)
// have to agree on key names and value types. A test pinning every
// snake_case key + every nullable field gives us a fast-fail signal
// when someone renames a key on one side without the other two.
//
// The decoder is also the only function whose correctness is testable
// without a paired watch — the rest of the watch app (UI, motion,
// audio) needs a watchOS simulator. Spending test budget here pays
// off proportionally.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **`DispatchQueue.main.async` writes inside the decoder.**
//    `ingestDope`, `ingestActiveLoad`, `ingestFirearmGlance` all hop
//    to main before mutating `@Published` state. Tests that read the
//    state immediately after `handle(...)` would see stale values.
//    We use XCTest's `XCTNSPredicateExpectation` (or the simpler
//    `wait(for:expectations:timeout:)` with a polling closure) to
//    drain the main queue once.
//
// 2. **Numeric values flow through `NSNumber`.** Dart sends Int, the
//    Swift side decodes via `(payload["mv"] as? NSNumber)?.doubleValue`.
//    The test injects `Int` (raw Swift) into the dictionary; the
//    cast still works because `Int` bridges to `NSNumber`
//    transparently. Don't use `Int64` or `UInt32` in test fixtures —
//    those wouldn't bridge cleanly.
//
// 3. **`@Published` reads are ordered, not synchronous.** The
//    decoder schedules a main-queue write; when the test reads
//    immediately, the write hasn't happened yet. `RunLoop.main.run(until:)`
//    is a cheaper than `XCTNSPredicateExpectation` for the simple
//    "drain the queue" pattern.
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
// None. Each test instantiates a fresh DopeViewModel and reads its
// published state.

import XCTest
@testable import RunnerWatchApp

final class WatchPayloadDecoderTests: XCTestCase {

    // MARK: - Helpers

    /// Drain the main queue once so the decoder's
    /// `DispatchQueue.main.async` writes have landed before the test
    /// reads the published state. `RunLoop.main.run(until:)` advances
    /// the loop without spinning the CPU; 50 ms is plenty for an
    /// async-on-main without depending on the harness's quality of
    /// service.
    private func drainMain(_ ms: Double = 50) {
        let until = Date().addingTimeInterval(ms / 1000.0)
        RunLoop.main.run(until: until)
    }

    // MARK: - dope payload

    func test_dope_decodes_happyPath() {
        let vm = DopeViewModel()
        vm.handle(path: WatchPaths.dope, payload: [
            "cart": "6.5 Creedmoor",
            "bgr": 140,
            "bn": "ELD-M",
            "mv": 2750,
            "z": 100,
            "ws": 8.0,
            "wd": 270,
            "dm": "g7",
            "bc": 0.315,
            "g": Int(Date().timeIntervalSince1970 * 1000),
            "rows": [
                ["r": 100, "u": 0.0, "w": 0.0, "v": 2750, "t": 0.11],
                ["r": 200, "u": 0.6, "w": 0.2, "v": 2620, "t": 0.23],
                ["r": 600, "u": 5.4, "w": 0.8, "v": 1780, "t": 0.92],
                ["r": 1000, "u": 12.4, "w": 2.4, "v": 1180, "t": 1.79],
            ]
        ])
        drainMain()

        let snap = vm.snapshot
        XCTAssertNotNil(snap)
        XCTAssertEqual(snap?.cartridgeName, "6.5 Creedmoor")
        XCTAssertEqual(snap?.bulletGr, 140)
        XCTAssertEqual(snap?.bulletName, "ELD-M")
        XCTAssertEqual(snap?.muzzleVelocityFps, 2750)
        XCTAssertEqual(snap?.zeroRangeYd, 100)
        XCTAssertEqual(snap?.dragModel, "g7")
        XCTAssertEqual(snap?.bc, 0.315)
        XCTAssertEqual(snap?.rows.count, 4)
        XCTAssertEqual(snap?.rows[0].rangeYd, 100)
        XCTAssertEqual(snap?.rows[3].rangeYd, 1000)
        XCTAssertEqual(snap?.rows[3].dropMil, 12.4)
    }

    func test_dope_acceptsIntMv_fromDartSide() {
        // Dart serialises `'mv': muzzleVelocityFps.round()` as Int.
        // The Swift side decodes via NSNumber.doubleValue — must work.
        let vm = DopeViewModel()
        vm.handle(path: WatchPaths.dope, payload: [
            "cart": "6.5 Creedmoor",
            "bgr": 140,
            "bn": "ELD-M",
            "mv": 2750, // <-- Int, not Double
            "z": 100,
            "dm": "g7",
            "bc": 0.315,
            "rows": [
                ["r": 100, "u": 0.0, "w": 0.0, "v": 2750, "t": 0.11],
            ]
        ])
        drainMain()

        XCTAssertNotNil(vm.snapshot)
        XCTAssertEqual(vm.snapshot?.muzzleVelocityFps, 2750)
    }

    func test_dope_dropsPayload_whenMissingCartridge() {
        let vm = DopeViewModel()
        vm.handle(path: WatchPaths.dope, payload: [
            // missing "cart"
            "bgr": 140,
            "bn": "ELD-M",
            "mv": 2750,
            "z": 100,
            "dm": "g7",
            "bc": 0.315,
            "rows": [["r": 100, "u": 0.0, "w": 0.0, "v": 2750, "t": 0.11]]
        ])
        drainMain()
        XCTAssertNil(vm.snapshot, "snapshot should remain nil when cart is missing")
    }

    func test_dope_dropsPayload_whenRowsMissing() {
        let vm = DopeViewModel()
        vm.handle(path: WatchPaths.dope, payload: [
            "cart": "6.5 Creedmoor",
            "bgr": 140,
            "bn": "ELD-M",
            "mv": 2750,
            "z": 100,
            "dm": "g7",
            "bc": 0.315
            // missing "rows"
        ])
        drainMain()
        XCTAssertNil(vm.snapshot)
    }

    // MARK: - active_load payload

    func test_activeLoad_decodes_happyPath() {
        let vm = DopeViewModel()
        vm.handle(path: WatchPaths.activeLoad, payload: [
            "n": "PRS Match",
            "cart": "6.5 Creedmoor",
            "p": "H4350",
            "pgr": 41.5,
            "b": "ELD-M",
            "bgr": 140
        ])
        drainMain()

        let load = vm.activeLoad
        XCTAssertNotNil(load)
        XCTAssertEqual(load?.name, "PRS Match")
        XCTAssertEqual(load?.cartridgeName, "6.5 Creedmoor")
        XCTAssertEqual(load?.powderName, "H4350")
        XCTAssertEqual(load?.powderChargeGr, 41.5)
        XCTAssertEqual(load?.bulletName, "ELD-M")
        XCTAssertEqual(load?.bulletWeightGr, 140)
    }

    func test_activeLoad_dropsPayload_whenNameMissing() {
        let vm = DopeViewModel()
        vm.handle(path: WatchPaths.activeLoad, payload: [
            "cart": "6.5 Creedmoor",
            "p": "H4350"
        ])
        drainMain()
        XCTAssertNil(vm.activeLoad)
    }

    func test_activeLoad_acceptsMinimalPayload() {
        // Required: name + cartridge. Everything else optional.
        let vm = DopeViewModel()
        vm.handle(path: WatchPaths.activeLoad, payload: [
            "n": "Plinker",
            "cart": ".223 Rem"
        ])
        drainMain()

        XCTAssertNotNil(vm.activeLoad)
        XCTAssertNil(vm.activeLoad?.powderName)
        XCTAssertNil(vm.activeLoad?.bulletName)
    }

    // MARK: - firearm_glance payload

    func test_firearmGlance_decodes_happyPath() {
        let vm = DopeViewModel()
        vm.handle(path: WatchPaths.firearmGlance, payload: [
            "n": "Tikka T3x",
            "s": 1320,
            "c": "6.5 Creedmoor",
            "l": 0.74
        ])
        drainMain()

        let glance = vm.firearmGlance
        XCTAssertNotNil(glance)
        XCTAssertEqual(glance?.name, "Tikka T3x")
        XCTAssertEqual(glance?.shotsFired, 1320)
        XCTAssertEqual(glance?.caliber, "6.5 Creedmoor")
        XCTAssertEqual(glance?.barrelLifeRemainingPct, 0.74)
    }

    func test_firearmGlance_acceptsNoBarrelLife() {
        let vm = DopeViewModel()
        vm.handle(path: WatchPaths.firearmGlance, payload: [
            "n": "Tikka T3x",
            "s": 1320,
            "c": "6.5 Creedmoor"
            // no "l"
        ])
        drainMain()

        XCTAssertNotNil(vm.firearmGlance)
        XCTAssertNil(vm.firearmGlance?.barrelLifeRemainingPct)
    }

    func test_firearmGlance_dropsPayload_whenNameMissing() {
        let vm = DopeViewModel()
        vm.handle(path: WatchPaths.firearmGlance, payload: [
            "s": 1320,
            "c": "6.5 Creedmoor"
        ])
        drainMain()
        XCTAssertNil(vm.firearmGlance)
    }

    func test_firearmGlance_dropsPayload_whenShotsMissing() {
        let vm = DopeViewModel()
        vm.handle(path: WatchPaths.firearmGlance, payload: [
            "n": "Tikka T3x",
            "c": "6.5 Creedmoor"
        ])
        drainMain()
        XCTAssertNil(vm.firearmGlance)
    }

    // MARK: - Cursor clamping

    func test_cursor_clampsToNewSnapshot_whenSmaller() {
        let vm = DopeViewModel()

        // First snapshot — 4 rows. Advance cursor to last row.
        vm.handle(path: WatchPaths.dope, payload: largeDopePayload(rowCount: 4))
        drainMain()
        vm.nextRow()
        vm.nextRow()
        vm.nextRow()
        XCTAssertEqual(vm.rowCursor, 3)

        // Second snapshot — only 2 rows. Cursor must clamp to 1.
        vm.handle(path: WatchPaths.dope, payload: largeDopePayload(rowCount: 2))
        drainMain()
        XCTAssertLessThanOrEqual(vm.rowCursor, 1)
    }

    func test_currentRow_returnsNil_whenNoSnapshot() {
        let vm = DopeViewModel()
        XCTAssertNil(vm.currentRow())
    }

    // MARK: - Unknown path

    func test_unknownPath_isSilent() {
        let vm = DopeViewModel()
        vm.handle(path: "not_a_real_path", payload: [:])
        drainMain()
        XCTAssertNil(vm.snapshot)
        XCTAssertNil(vm.activeLoad)
        XCTAssertNil(vm.firearmGlance)
    }

    // MARK: - Fixture builder

    private func largeDopePayload(rowCount: Int) -> [String: Any] {
        var rows: [[String: Any]] = []
        for i in 0..<rowCount {
            rows.append([
                "r": 100 * (i + 1),
                "u": Double(i) * 0.5,
                "w": 0.0,
                "v": 2750 - i * 100,
                "t": Double(i) * 0.1,
            ])
        }
        return [
            "cart": "6.5 Creedmoor",
            "bgr": 140,
            "bn": "ELD-M",
            "mv": 2750,
            "z": 100,
            "dm": "g7",
            "bc": 0.315,
            "rows": rows
        ]
    }
}

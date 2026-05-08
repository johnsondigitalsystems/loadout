// FILE: ios/RunnerWatchApp/MotionDetector.swift
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Threshold-based shot detector for the watch companion's Stage Log
// tab. Polls the accelerometer at 50 Hz, computes the total
// acceleration vector magnitude (in g), and fires a candidate "shot"
// event when the magnitude stays above a user-configurable threshold
// (default 5 g) for at least 50 ms.
//
// The threshold + sustained-peak duration are driven by a four-way
// "shot-capture sensitivity" preference (off / low / medium / high)
// that the phone pushes via the `shot_capture_sensitivity` bridge
// path. The user can override the threshold inside the watch settings
// sheet (legacy continuous-slider UI) too, but the phone setting
// always wins on receipt.
//
// Public surface:
//   * `@Published var sensitivity: ShotCaptureSensitivity` — current
//     sensitivity preset. Persists to `UserDefaults` under
//     `shot_capture_sensitivity`. Default `.medium`.
//   * `@Published var thresholdG` — derived from the sensitivity
//     preset (or set directly by the legacy slider). Persists to
//     `UserDefaults` under `motion.thresholdG`.
//   * `@Published var pendingShotPeakG: Double?` — non-nil after a
//     candidate is detected. The Stage Log screen surfaces a 5-second
//     confirm prompt when this changes.
//   * `@Published var liveMagnitude` — instantaneous magnitude
//     readout (1 g = stationary). Used by debug HUDs.
//   * `@Published var isRunning` — true between `start()` and
//     `stop()`.
//   * `func start()`, `stop()`, `acknowledge()`, `dismiss()` — drive
//     the lifecycle. `acknowledge` returns the captured peak and
//     clears state; `dismiss` clears without returning.
//   * `func applySensitivity(_ wireValue: String)` — phone-bridge
//     entry point. Looks up the preset (off/low/medium/high), updates
//     `thresholdG` + sustained-peak window, and pauses the
//     accelerometer entirely when `off` is selected.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Rifle recoil shows up on the wrist as a brief, high-magnitude
// transient (~5–10 g for a few milliseconds). Stage Log uses this to
// auto-log shots without making the user tap their watch every time
// they fire. Pulling the detection out of the view keeps the math
// testable in isolation and lets `StageLogView` focus on UI flow.
//
// (For watchOS newcomers: `CMMotionManager` from CoreMotion is the
// only way to read the accelerometer on Apple Watch. It runs entirely
// on the watch — no network, no Apple servers — which is what makes
// this feature compatible with the privacy promise in CLAUDE.md §13.)
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Sustained-peak rule rejects single-sample spikes.** A noisy
//    accelerometer can show a 6 g sample at 50 Hz from clapping the
//    wrist on a bench top. Real recoil HOLDS above the threshold for
//    multiple samples. Requiring `kMinPeakSeconds` (50 ms = ~2-3
//    samples at 50 Hz) gates out the single-sample noise without
//    missing real shots.
//
// 2. **Debounce prevents follow-up double-counting.** Without
//    `kSettleSeconds` (400 ms quiet), a follow-up shot ~500 ms after
//    the first would not register (the wrist hasn't settled and the
//    threshold check would re-trigger immediately on the trailing
//    oscillation of shot one). Real PRS / 3-Gun split times bottom
//    out around 0.6 s, so 400 ms is well under.
//
// 3. **`@Published` writes hop to main.** CMMotionManager delivers
//    samples on a custom OperationQueue (we use a `userInitiated`
//    queue here). Writing to `@Published` from off-main breaks
//    SwiftUI; every published mutation is wrapped in
//    `DispatchQueue.main.async`.
//
// 4. **Threshold persistence has a sane fallback.** If
//    `UserDefaults.double(forKey:)` returns 0 (key missing or never
//    set), the init clamps to the default 5.0; the >=3.0/<=10.0
//    range mirrors the slider bounds in the settings sheet so a
//    corrupted value can never lock the user out of detection.
//
// 5. **`acknowledge()` returns the peak and clears.** It's called
//    from both the user's tap (5-second window) AND the auto-confirm
//    timer. Either way the state must clear or the next shot will
//    not be registered. Keeping it idempotent (returns nil if there
//    was no pending) avoids races.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `StageLogView.swift` — owns one instance via `@StateObject`.
//   Starts on `onAppear`, stops on `onDisappear`, and reads
//   `pendingShotPeakG` to drive the confirm UI.
// - `WatchAppDelegate.swift` — does NOT own one. The detector lives
//   per-screen because we only want it running while Stage Log is
//   visible.
//
// File ships on disk but only enters the Xcode build once the
// operator follows the watch-target wire-up in CLAUDE.md §15.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Activates the accelerometer (`CMMotionManager.startAccelerometerUpdates`)
//   on `start()`; deactivates on `stop()`. CoreMotion is local-only
//   (sensor → CPU → app) — no network.
// - Reads / writes `UserDefaults` under `motion.thresholdG`.
// - No HTTP, no analytics, no peer-to-peer transport. The Stage Log
//   screen is what eventually emits a `log_shot` payload via
//   `ShotLogger`.

import Foundation
import CoreMotion
import Combine

/// Four-way preset describing how aggressively the watch listens for
/// shot impulses. Mirrors `ShotCaptureSensitivity` on the phone side
/// (`lib/services/watch_settings_service.dart`). Wire form is the
/// lowercased rawValue.
enum ShotCaptureSensitivity: String {
    case off
    case low
    case medium
    case high

    /// Threshold (g) the [MotionDetector] should compare each sample
    /// magnitude against. Returns nil for `.off` — the caller is
    /// expected to disable the detector entirely in that case.
    var thresholdG: Double? {
        switch self {
        case .off: return nil
        case .low: return 8.0
        case .medium: return 5.0
        case .high: return 3.0
        }
    }

    /// Sustained-peak duration (seconds). Returns nil for `.off`.
    var sustainedPeakSeconds: Double? {
        switch self {
        case .off: return nil
        case .low: return 0.08
        case .medium: return 0.05
        case .high: return 0.03
        }
    }

    /// Decode the wire-format string sent by the phone bridge. Falls
    /// back to nil so the caller can keep its current preset.
    static func fromWire(_ raw: String) -> ShotCaptureSensitivity? {
        return ShotCaptureSensitivity(rawValue: raw)
    }
}

final class MotionDetector: ObservableObject {

    // MARK: - Public

    /// 1 magnitude unit = 1 g. Default 5 g; range 3.0 .. 10.0 in the
    /// legacy slider settings. Stored in UserDefaults under
    /// `motion.thresholdG` so user preference persists. Updated
    /// automatically by [applySensitivity] when the phone pushes a
    /// new preset.
    @Published var thresholdG: Double {
        didSet {
            UserDefaults.standard.set(thresholdG, forKey: kThresholdKey)
        }
    }

    /// Currently-selected sensitivity preset. Set automatically by
    /// [applySensitivity] when the phone pushes a new value, and
    /// persisted under `kSensitivityKey` so the watch remembers the
    /// preset across reboots even before the next phone push lands.
    @Published var sensitivity: ShotCaptureSensitivity {
        didSet {
            UserDefaults.standard.set(
                sensitivity.rawValue,
                forKey: kSensitivityKey
            )
        }
    }

    /// True after a candidate spike. Resets to false after the host UI
    /// either consumes (`acknowledge`) or the auto-confirm timer fires
    /// (`confirmIfPending`).
    @Published private(set) var pendingShotPeakG: Double?

    /// Continuous magnitude readout (1g = stationary). Useful for the
    /// debug HUD on the Stage Log screen.
    @Published private(set) var liveMagnitude: Double = 1.0

    @Published private(set) var isRunning: Bool = false

    // MARK: - Tunables

    private let kThresholdKey = "motion.thresholdG"
    private let kSensitivityKey = "shot_capture_sensitivity"
    private let kSampleHz: Double = 50
    private let kSettleSeconds: Double = 0.4 // 400 ms quiet between events
    private var minPeakSeconds: Double = 0.05 // sustained for >50 ms; mutated by sensitivity preset

    // MARK: - State

    private let manager = CMMotionManager()
    private let queue: OperationQueue
    private var lastEventAt: Date?
    private var aboveSince: Date?
    private var currentPeak: Double = 0

    init() {
        let q = OperationQueue()
        q.qualityOfService = .userInitiated
        q.maxConcurrentOperationCount = 1
        self.queue = q
        let stored = UserDefaults.standard.double(forKey: kThresholdKey)
        self.thresholdG = stored >= 3.0 && stored <= 10.0 ? stored : 5.0
        // Sensitivity defaults to .medium (matches the phone-side
        // default in `WatchSettingsService`). If a previous session
        // persisted a different preset, restore it here.
        let storedPreset = UserDefaults.standard.string(forKey: kSensitivityKey)
        let resolved = storedPreset.flatMap(ShotCaptureSensitivity.init(rawValue:)) ?? .medium
        self.sensitivity = resolved
        if let secs = resolved.sustainedPeakSeconds {
            self.minPeakSeconds = secs
        }
        if let g = resolved.thresholdG, !(stored >= 3.0 && stored <= 10.0) {
            // No stored slider value — derive from the preset.
            self.thresholdG = g
        }
    }

    /// Phone-bridge entry point. Decodes the wire string into a preset
    /// and updates the threshold + sustained-peak window. When the
    /// preset is `.off`, also pauses the accelerometer immediately —
    /// the user expects "Off" to mean no battery cost.
    func applySensitivity(_ wireValue: String) {
        guard let preset = ShotCaptureSensitivity.fromWire(wireValue) else {
            return
        }
        sensitivity = preset
        if preset == .off {
            stop()
            return
        }
        if let g = preset.thresholdG {
            thresholdG = g
        }
        if let secs = preset.sustainedPeakSeconds {
            minPeakSeconds = secs
        }
    }

    // MARK: - Lifecycle

    func start() {
        guard manager.isAccelerometerAvailable else { return }
        if isRunning { return }
        manager.accelerometerUpdateInterval = 1.0 / kSampleHz
        manager.startAccelerometerUpdates(to: queue) { [weak self] data, _ in
            guard let self, let data = data else { return }
            self.consume(sample: data)
        }
        isRunning = true
    }

    func stop() {
        if manager.isAccelerometerActive {
            manager.stopAccelerometerUpdates()
        }
        DispatchQueue.main.async { [weak self] in
            self?.isRunning = false
            self?.aboveSince = nil
            self?.currentPeak = 0
            self?.liveMagnitude = 1.0
        }
    }

    /// User confirmed the candidate or auto-timer fired. Returns the
    /// captured peak in g and clears state.
    func acknowledge() -> Double? {
        let peak = pendingShotPeakG
        DispatchQueue.main.async { [weak self] in
            self?.pendingShotPeakG = nil
        }
        return peak
    }

    /// User dismissed the candidate ("not a shot").
    func dismiss() {
        DispatchQueue.main.async { [weak self] in
            self?.pendingShotPeakG = nil
        }
    }

    // MARK: - Internals

    private func consume(sample: CMAccelerometerData) {
        // CMAccelerometerData.acceleration is in g already (1.0 ≈ a
        // stationary wrist on the apple watch — gravity component).
        let a = sample.acceleration
        let mag = sqrt(a.x * a.x + a.y * a.y + a.z * a.z)
        DispatchQueue.main.async { [weak self] in
            self?.liveMagnitude = mag
        }

        if mag >= thresholdG {
            if aboveSince == nil { aboveSince = Date() }
            currentPeak = max(currentPeak, mag)

            // Sustained-peak rule: must remain above threshold for
            // > minPeakSeconds. Filters out single high-frequency
            // noise spikes. Window narrows under "high" sensitivity.
            if let since = aboveSince,
               Date().timeIntervalSince(since) >= minPeakSeconds {
                fireCandidate(peak: currentPeak)
            }
        } else {
            // Below threshold — reset the windowing.
            aboveSince = nil
            currentPeak = 0
        }
    }

    private func fireCandidate(peak: Double) {
        // Debounce: ignore if we just fired one.
        if let last = lastEventAt, Date().timeIntervalSince(last) < kSettleSeconds {
            return
        }
        lastEventAt = Date()
        aboveSince = nil
        currentPeak = 0
        DispatchQueue.main.async { [weak self] in
            self?.pendingShotPeakG = peak
        }
    }
}

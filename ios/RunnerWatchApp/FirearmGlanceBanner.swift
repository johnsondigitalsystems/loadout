// FILE: ios/RunnerWatchApp/FirearmGlanceBanner.swift
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Tiny banner showing the active firearm name + remaining barrel life,
// pulled from the most-recent `firearm_glance` payload pushed by the
// iPhone. Renders nothing when no payload has arrived (silent empty
// state — the firearm name isn't critical UI; the user already knows
// what's on the bench).
//
// Populated layout:
//   * Line 1: firearm name (e.g. "Tikka T3x").
//   * Line 2 (when barrel-life percent is present): a thin progress
//     bar + percent label ("87%"). Tints green when ≥ 50%, orange
//     20–50%, red < 20% — the same band thresholds used elsewhere in
//     the iPhone app.
//
// Reads `DopeViewModel.firearmGlance` from the SwiftUI environment.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Reloaders track barrel life because match-grade rifles have a
// useful lifespan measured in thousands of rounds; once a barrel
// passes its expected cycle count, point of impact starts walking
// shot-to-shot. Surfacing the percent at the line lets the shooter
// glance at the watch and decide "do I need to swap rifles for the
// next stage?". Without the banner the user would have to dig
// through the iPhone app — and probably wouldn't.
//
// Putting this in a dedicated file (rather than inlining in
// DopeView) means the banner can be reused on the About / Stage
// Log screens later without copying the gauge logic.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **The banner self-hides when there's no payload.** Per
//    CLAUDE.md §0, we don't placeholder a firearm name on the watch.
//    Returning an `EmptyView` from the body collapses the layout
//    so the DOPE rows don't get pushed down by an "unknown firearm"
//    placeholder.
//
// 2. **Percent gauge only renders when the value is non-nil.**
//    `barrelLifeRemainingPct` is null when the user hasn't set an
//    expected cycle count on the iPhone. In that case we show the
//    firearm name alone — never a fake "100%" or "—" gauge that
//    would mislead the shooter.
//
// 3. **`Capsule()` + GeometryReader is the simplest watchOS
//    progress bar.** SwiftUI `ProgressView` on watchOS is
//    deliberately stylised by the system (a different shape on
//    every OS version), which makes thresholds like "red < 20%"
//    impossible to express. A two-layer Capsule rendered against
//    the available width gives us pixel control.
//
// 4. **The threshold colours mirror the iPhone-side firearms list.**
//    Don't diverge — if the user sees "65% green" on the iPhone they
//    should see "65% green" on the watch. The thresholds are
//    documented in `lib/screens/firearms/firearms_list_screen.dart`.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `DopeView.swift` — embeds the banner inside the populated layout
//   when a firearm-glance payload has arrived.
//
// File ships on disk but only enters the Xcode build once the
// operator follows the watch-target wire-up in CLAUDE.md §15.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure presentation; reads published state and renders.

import SwiftUI

struct FirearmGlanceBanner: View {
    @EnvironmentObject private var model: DopeViewModel

    var body: some View {
        if let glance = model.firearmGlance {
            populated(glance)
        } else {
            EmptyView()
        }
    }

    private func populated(_ glance: FirearmGlanceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(glance.name)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            if let pct = glance.barrelLifeRemainingPct {
                gauge(pct: clamped(pct))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func gauge(pct: Double) -> some View {
        HStack(spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.25))
                    Capsule()
                        .fill(tint(for: pct))
                        .frame(width: geo.size.width * pct)
                }
            }
            .frame(height: 4)
            Text(String(format: "%.0f%%", pct * 100))
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    /// Mirrors the iPhone-side firearm list barrel-life tint thresholds.
    /// Keeping the bands here in source means a future tweak to the
    /// thresholds has to update both files — grep for `barrelLife` to
    /// find them.
    private func tint(for pct: Double) -> Color {
        if pct >= 0.50 { return .green }
        if pct >= 0.20 { return .orange }
        return .red
    }

    /// Defensive clamp to [0, 1]. The iPhone side rounds to three
    /// decimals, but a custom barrel-life formula could in principle
    /// over- or under-shoot if the user counts shots beyond the
    /// expected cycle count.
    private func clamped(_ value: Double) -> Double {
        return max(0.0, min(1.0, value))
    }
}

#Preview("Populated") {
    let vm = DopeViewModel()
    vm.handle(path: WatchPaths.firearmGlance, payload: [
        "n": "Tikka T3x",
        "s": 1320,
        "c": "6.5 Creedmoor",
        "l": 0.74
    ])
    return FirearmGlanceBanner()
        .environmentObject(vm)
        .padding()
}

#Preview("No Barrel Life") {
    let vm = DopeViewModel()
    vm.handle(path: WatchPaths.firearmGlance, payload: [
        "n": "Tikka T3x",
        "s": 1320,
        "c": "6.5 Creedmoor"
    ])
    return FirearmGlanceBanner()
        .environmentObject(vm)
        .padding()
}

#Preview("Empty") {
    return FirearmGlanceBanner()
        .environmentObject(DopeViewModel())
        .padding()
}

// FILE: ios/RunnerWatchApp/ActiveLoadHeader.swift
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Tiny SwiftUI view used at the top of the DOPE page to surface the
// most-recent `active_load` payload pushed from the iPhone.
//
// Two states:
//   * Populated — renders cartridge name on line 1 and a single-line
//     summary on line 2 ("44.0 gr H4350 · 140 ELD-M"). Both fields
//     fall back gracefully when the optional payload pieces are
//     absent (powder name only / bullet only / nothing but
//     cartridge).
//   * Empty — renders a single-line "Pick a Load on iPhone" hint in
//     secondary text. Per CLAUDE.md §0, this is NOT placeholder
//     ballistic data — there's no fake bullet weight or charge.
//
// Reads `DopeViewModel.activeLoad` from the SwiftUI environment.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// The DOPE rows scroll independently of the active load — when the
// shooter is dialling 600 yd, the cartridge / bullet identity stays
// fixed. Pulling that identity into a header banner means the user
// glances at the watch and sees both "what am I shooting?" and "what
// dial does 600 yd take?" in one read. Without the header, the user
// would have to swipe to the about-page and back, breaking flow.
//
// Pulling it into its own file (instead of inlining in `DopeView`)
// keeps the row-scrolling view focused on its job and lets the
// banner stand on its own preview / future reuse.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **The empty-state line is "Pick a Load on iPhone", not "No
//    active load".** Per CLAUDE.md §0a, the watch ships Title Case
//    on labels. Per §0, the empty surface points the user back to
//    the phone where they CAN pick a load — we never invent or
//    placeholder a load on the watch side.
//
// 2. **The summary line concatenates only the fields that arrived.**
//    `ActiveLoadSnapshot` has six optional fields (powder /
//    powder charge / bullet / bullet weight / primer / brass / COAL
//    / CBTO). The header surfaces the four most useful ones and
//    omits anything missing — never substitutes a placeholder. If
//    only powder + charge arrived, the line reads "44.0 gr H4350";
//    if only bullet + weight arrived, the line reads "140 ELD-M";
//    if both, separator " · " glues them.
//
// 3. **`.lineLimit(1)` + truncation is essential.** Long load names
//    + long bullet names ("300 Norma Mag Long Body 230 Berger
//    Hybrid OTM") would overflow the watch face. The system's mid-
//    ellipsis truncation keeps the header readable.
//
// 4. **No grain unit on the bullet line.** The DOPE header already
//    shows the bullet weight as part of `headerText(snap)`; this
//    banner intentionally skips repeating it on the bullet line so
//    the two surfaces don't read as "140 gr ELD-M / 140 ELD-M".
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `DopeView.swift` — embeds at the top of the populated layout.
//
// File ships on disk but only enters the Xcode build once the
// operator follows the watch-target wire-up in CLAUDE.md §15.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure presentation; reads published state and renders.

import SwiftUI

struct ActiveLoadHeader: View {
    @EnvironmentObject private var model: DopeViewModel

    var body: some View {
        if let load = model.activeLoad {
            populated(load)
        } else {
            empty
        }
    }

    private func populated(_ load: ActiveLoadSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(load.cartridgeName)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            if let summary = summaryLine(load), !summary.isEmpty {
                Text(summary)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var empty: some View {
        Text("Pick a Load on iPhone")
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Builds a "44.0 gr H4350 · 140 ELD-M" style summary out of the
    /// fields that actually arrived. Returns nil when neither side
    /// of the separator has anything to show.
    private func summaryLine(_ load: ActiveLoadSnapshot) -> String? {
        var parts: [String] = []

        // Powder side: "44.0 gr H4350" / "H4350" / "44.0 gr".
        if let charge = load.powderChargeGr, let powder = load.powderName {
            parts.append(String(format: "%.1f gr %@", charge, powder))
        } else if let powder = load.powderName {
            parts.append(powder)
        } else if let charge = load.powderChargeGr {
            parts.append(String(format: "%.1f gr", charge))
        }

        // Bullet side: "140 ELD-M" / "ELD-M" / "140 gr".
        if let weight = load.bulletWeightGr, let bullet = load.bulletName {
            parts.append(String(format: "%.0f %@", weight, bullet))
        } else if let bullet = load.bulletName {
            parts.append(bullet)
        } else if let weight = load.bulletWeightGr {
            parts.append(String(format: "%.0f gr", weight))
        }

        if parts.isEmpty { return nil }
        return parts.joined(separator: " · ")
    }
}

#Preview("Populated") {
    let vm = DopeViewModel()
    vm.handle(path: WatchPaths.activeLoad, payload: [
        "n": "PRS Match",
        "cart": "6.5 Creedmoor",
        "p": "H4350",
        "pgr": 41.5,
        "b": "ELD-M",
        "bgr": 140
    ])
    return ActiveLoadHeader()
        .environmentObject(vm)
        .padding()
}

#Preview("Empty") {
    return ActiveLoadHeader()
        .environmentObject(DopeViewModel())
        .padding()
}

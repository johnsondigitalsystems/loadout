// FILE: ios/RunnerWatchApp/AboutView.swift
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Diagnostic / About page for the LoadOut watch companion. Renders four
// rows:
//   * Header — "LoadOut" wordmark + the bundled app version pulled
//     from `Bundle.main.infoDictionary[CFBundleShortVersionString]`.
//   * iPhone link status — "iPhone Linked" green dot when reachable,
//     "iPhone Not Linked" amber dot when WatchConnectivity reports
//     the counterpart asleep / unpaired.
//   * Shot capture sensitivity — read-only label showing whichever
//     preset the phone last pushed (`Off` / `Low` / `Medium` / `High`).
//     Configured on the iPhone per CLAUDE.md §15; the watch never
//     edits it from this screen.
//   * Privacy footer — single-line reminder that the watch sends
//     nothing off the user's phone+watch pair (mirrors CLAUDE.md §13
//     posture).
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Without an About / Settings page the user has no way to confirm the
// watch app is the version they expect, no way to see whether the
// iPhone link is live (the existing tabs all assume it works), and no
// way to verify the sensitivity preset their phone pushed actually
// landed. All three rows are diagnostic, not interactive — but every
// "is this thing working?" question has a known answer here.
//
// Implementation note: the sensitivity row is intentionally read-only
// on the watch. The iPhone is the source of truth (per § 15 — the
// preset table lives in `lib/services/watch_settings_service.dart`).
// Letting the user edit it from the watch would mean two writers and
// inevitable drift.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **`Bundle.main.infoDictionary` keys can return `nil` in
//    previews.** Force-unwrapping would crash inside Xcode preview
//    canvas. We default to "—" so the preview renders cleanly even
//    when the bundle isn't fully populated.
//
// 2. **The link-status dot uses `Image(systemName: "circle.fill")`
//    not a custom shape.** SwiftUI's symbol cache is pre-warmed for
//    SF Symbols; rendering a custom `Circle()` allocates a fresh
//    shape on every redraw. The status dot updates at most once per
//    reachability change, so this is cheap, but the SF-symbol path
//    is faster and matches the rest of the app.
//
// 3. **Sensitivity formatting is Title Case for display.**
//    Per CLAUDE.md §0a, every user-visible label uses Title Case.
//    The wire format ships lowercased ("medium"), so we capitalize
//    on the way to the screen. Don't change the wire string — every
//    Wear OS / iOS / Dart copy has to agree on lowercase.
//
// 4. **No interactive controls.** This page is intentionally a
//    read-only diagnostic. If a future contributor wants to add a
//    "Push for Help" action or similar, route it through the iPhone
//    bridge (`connectivity.send(...)`) — never through HTTP.
//
// 5. **`@EnvironmentObject` for both the connectivity manager AND
//    the motion detector's preference.** The preset can come from
//    two sources: a phone push (lands in `connectivity
//    .shotCaptureSensitivity`) or the watch's persisted preference
//    (lands in `MotionDetector.sensitivity`). We prefer the manager
//    value when present because it's the most-recent phone push;
//    fall back to the persisted preference so the row is always
//    populated even before the phone has pushed once this session.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `ContentView.swift` — hosts this as the fourth page of the
//   `TabView`.
//
// File ships on disk but only enters the Xcode build once the
// operator follows the watch-target wire-up in CLAUDE.md §15.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None. Pure diagnostic view. Reads `Bundle.main.infoDictionary`
// and the connectivity manager's published state.

import SwiftUI

struct AboutView: View {
    @EnvironmentObject private var connectivity: WatchConnectivityManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                header
                Divider()
                phoneLinkRow
                sensitivityRow
                Divider()
                privacyFooter
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("LoadOut Watch")
                .font(.system(size: 14, weight: .semibold))
            Text("Version \(versionString)")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var phoneLinkRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill")
                .imageScale(.small)
                .foregroundStyle(connectivity.isReachable ? .green : .orange)
            VStack(alignment: .leading, spacing: 0) {
                Text(connectivity.isReachable ? "iPhone Linked" : "iPhone Not Linked")
                    .font(.system(size: 11, weight: .medium))
                Text(connectivity.isReachable
                     ? "Live messages active."
                     : "Awaiting reachability.")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sensitivityRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "scope")
                .imageScale(.small)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 0) {
                Text("Shot Capture Sensitivity")
                    .font(.system(size: 11, weight: .medium))
                Text(sensitivityDisplay)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var privacyFooter: some View {
        Text("Watch data stays on your phone+watch pair. No HTTP, no analytics.")
            .font(.system(size: 9))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.leading)
    }

    // MARK: - Helpers

    /// Pulls the bundled app version. Falls back to "—" inside Xcode
    /// previews where the Info.plist is mocked.
    private var versionString: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        if short == "—" && build == "—" { return "—" }
        return "\(short) (\(build))"
    }

    /// "Off" / "Low" / "Medium" / "High" / "Default (Medium)".
    /// Prefers the phone push; falls back to a default blurb when the
    /// phone hasn't pushed and the persisted value is the .medium
    /// fallback (so the user sees "Default (Medium) — Configure on
    /// iPhone" rather than a bare "Medium" that misleads them into
    /// thinking they set it).
    private var sensitivityDisplay: String {
        if let raw = connectivity.shotCaptureSensitivity, !raw.isEmpty {
            return "\(titleCase(raw)) — Configure on iPhone"
        }
        return "Default (Medium) — Configure on iPhone"
    }

    private func titleCase(_ raw: String) -> String {
        guard let first = raw.first else { return raw }
        return first.uppercased() + raw.dropFirst()
    }
}

#Preview("Linked") {
    let m = WatchConnectivityManager.preview
    return AboutView()
        .environmentObject(m)
}

#Preview("Not Linked") {
    return AboutView()
        .environmentObject(WatchConnectivityManager.preview)
}

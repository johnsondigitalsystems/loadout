// FILE: ios/RunnerWatchApp/ContentView.swift
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// Root SwiftUI view for the LoadOut Apple Watch companion. Hosts a
// page-style `TabView` with four pages, in this order:
//
//   1. **Stage Log** — `StageLogView`. The most-frequent interaction
//      at the line, so it's the first page the user sees on launch.
//   2. **Timer** — `TimerView`. PRS / NRL stage timer with par-time
//      alerts.
//   3. **DOPE** — `DopeView`. Drop / windage card driven by the most
//      recent `dope` payload from the iPhone.
//   4. **About** — `AboutView`. Diagnostic page showing app version,
//      iPhone-pair status, and the motion-capture sensitivity preset
//      the phone last pushed (read-only).
//
// SwiftUI's page-based `TabView` (`.tabViewStyle(.verticalPage)` on
// watchOS 10) lets the user swipe between pages with the digital
// crown OR a finger gesture. Each child view reads the engine /
// view-model it needs from `@EnvironmentObject` — the App struct
// injected those at root so they exist for the lifetime of the app.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Pre-v1 this file rendered a "Coming Soon" stub. The four feature
// views existed on disk but were unreachable. This v1 wiring is
// purely "drop the existing screens onto the right page index and
// stop being a placeholder." If a future contributor wants to
// reorder pages, change the `TabView { ... }` block — every child
// view stays untouched.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **Page index 0 is what the user sees first.** Stage Log is
//    deliberately first because it's the highest-frequency
//    interaction at the line. Putting Timer or DOPE first would
//    cost a swipe on every shot. If you reorder, weigh the wrist-
//    economics carefully — DOPE is a glance ("what dial?"), Timer
//    is a stage setup, Stage Log is per-shot.
//
// 2. **`tag(...)` values are stable strings, not page indices.**
//    SwiftUI's `TabView(selection:)` binding takes whatever Hashable
//    you give it. Keeping these as strings ("stageLog", "timer",
//    "dope", "about") means inserting a new page in the middle does
//    not silently re-route the user's prior selection to the wrong
//    screen.
//
// 3. **No environment objects are constructed here.** They all live
//    on `WatchAppDelegate` and are injected by `LoadOutWatchApp`'s
//    `WindowGroup` body — building them inside this view would
//    re-instantiate them on every rebuild and reset timer state /
//    DOPE cursor mid-render. Do not move construction here.
//
// 4. **`.indexViewStyle(.page(...))` adds the dot indicator.**
//    watchOS 10's default is no indicator on `.verticalPage`. We
//    surface it because four pages is too many to keep oriented
//    without it.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - `LoadOutWatchApp.swift` — instantiates one `ContentView()` as the
//   root of `WindowGroup`. Injects all four environment objects.
//
// File ships on disk but only enters the Xcode build once the
// operator follows the watch-target wire-up in CLAUDE.md §15.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// None directly. Each child view's side effects (haptics, audio,
// motion sensor, peer-to-peer messages) fire when the user
// interacts with that page.

import SwiftUI

struct ContentView: View {
    /// Watch a couple of environment objects so the tab bar can
    /// respond to inbound state (e.g. the future "blink the DOPE tab
    /// when a fresh snapshot arrives" behaviour). Today the children
    /// are responsible for their own observation; this just keeps the
    /// type checker happy if we add diagnostic chrome here later.
    @EnvironmentObject private var connectivity: WatchConnectivityManager

    /// Persisted across launches so the watch remembers which page the
    /// user was on. `@SceneStorage` is the watchOS-friendly equivalent
    /// of `@AppStorage` for view state.
    @SceneStorage("rootTabSelection") private var selection: String = Self.defaultSelection

    private static let defaultSelection = "stageLog"

    var body: some View {
        TabView(selection: $selection) {
            StageLogView()
                .tag("stageLog")

            TimerView()
                .tag("timer")

            DopeView()
                .tag("dope")

            AboutView()
                .tag("about")
        }
        .tabViewStyle(.verticalPage)
        .indexViewStyle(.page(backgroundDisplayMode: .always))
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityManager.preview)
        .environmentObject(DopeViewModel())
        .environmentObject(TimerEngine())
        .environmentObject(ShotLogger())
}

// FILE: ios/RunnerWatchApp/LoadOutWatchApp.swift
//
// ============================================================================
// WHAT THIS FILE DOES
// ============================================================================
// `@main` entry point for the LoadOut Apple Watch companion. Owns the
// SwiftUI `Scene` graph (a single `WindowGroup` rooted at
// `ContentView`) and injects every environment object the view tree
// needs:
//   * `WatchConnectivityManager` — peer-to-peer transport.
//   * `DopeViewModel` — typed snapshots from the phone.
//   * `TimerEngine` — stage timer state machine.
//   * `ShotLogger` — outbound shot log.
//
// All four come off the `WatchAppDelegate` so they live for the app's
// lifetime, not the view tree's. Each child view reads what it needs
// via `@EnvironmentObject`.
//
// ============================================================================
// WHY IT EXISTS IN THE ARCHITECTURE
// ============================================================================
// Native SwiftUI watchOS app — Flutter does not support watchOS as of
// the current stable channel, so the watch companion is a standalone
// target that lives alongside the Flutter Runner. To wire this target
// up to the Xcode project, follow the step-by-step instructions in
// `ios/RunnerWatchApp/README.md`. Once the target exists, every file
// in this directory is added to it.
//
// ============================================================================
// WHY THIS IS HARDER THAN IT LOOKS
// ============================================================================
// 1. **`@WKApplicationDelegateAdaptor` is the modern entry point.**
//    Pre-watchOS 7 you stuffed long-lived state into the App struct,
//    which would re-instantiate it on every body re-evaluation. The
//    delegate adaptor pattern keeps the engines stable across the
//    app's lifetime.
//
// 2. **Every view that needs an engine reads it via
//    `@EnvironmentObject`.** Don't pass them through the constructor
//    chain — that breaks SwiftUI's ability to inject mock instances
//    in previews.
//
// 3. **The order of the `.environmentObject(...)` calls doesn't
//    matter,** but adding a new environment object means adding it
//    to BOTH this file AND any preview block in the app that
//    instantiates the same view tree. Previews fail at runtime if a
//    consumer reads an environment object that hasn't been provided.
//
// ============================================================================
// WHO CONSUMES THIS FILE
// ============================================================================
// - watchOS — picks up `@main` and runs the app.
// - `WatchAppDelegate.swift` — instantiated via the adaptor.
// - `ContentView.swift` — the root view inside `WindowGroup`.
//
// File ships on disk but only enters the Xcode build once the
// operator follows the watch-target wire-up in CLAUDE.md §15.
//
// ============================================================================
// SIDE EFFECTS
// ============================================================================
// - Indirectly, via the delegate's `applicationDidFinishLaunching`:
//   activates the WatchConnectivity session and binds the inbound /
//   outbound closures. No HTTP calls.

import SwiftUI

@main
struct LoadOutWatchApp: App {
    /// The session delegate owns every long-lived engine + the
    /// WatchConnectivity activation lifecycle. See
    /// `WatchAppDelegate.swift` for the wiring.
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.connectivity)
                .environmentObject(appDelegate.dopeViewModel)
                .environmentObject(appDelegate.timerEngine)
                .environmentObject(appDelegate.shotLogger)
        }
    }
}

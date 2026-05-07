// LoadOutWatchApp.swift
// LoadOut Watch App entry point.
//
// Native SwiftUI watchOS app — Flutter does not support watchOS as of the
// current stable channel, so the watch companion is implemented as a
// standalone target that lives alongside the Flutter Runner.
//
// To wire this target up to the Xcode project, follow the step-by-step
// instructions in `ios/RunnerWatchApp/README.md`. Once the target exists,
// every file in this directory is added to it automatically.

import SwiftUI

@main
struct LoadOutWatchApp: App {
    // The session delegate owns the WatchConnectivity activation lifecycle.
    // Even though there is nothing for the watch to send to the phone yet,
    // we activate the session at launch so future feature work can plug in
    // without restructuring the app.
    @WKApplicationDelegateAdaptor(WatchAppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appDelegate.connectivity)
        }
    }
}

// WatchAppDelegate.swift
// Holds onto the WatchConnectivity session for the lifetime of the app.
//
// Using `WKApplicationDelegateAdaptor` is the modern (watchOS 7+) entry
// point — it lets us own a long-lived `WatchConnectivityManager` without
// stuffing one into the SwiftUI App struct, which would re-instantiate it
// on view changes.

import Foundation
import WatchKit

final class WatchAppDelegate: NSObject, WKApplicationDelegate {
    let connectivity = WatchConnectivityManager()

    func applicationDidFinishLaunching() {
        // Activate eagerly so the iPhone side gets the
        // `session(_:activationDidCompleteWith:)` callback as soon as the
        // watch app launches. No-op on simulators that don't have a paired
        // iPhone.
        connectivity.activate()
    }
}

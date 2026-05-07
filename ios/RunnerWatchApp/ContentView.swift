// ContentView.swift
// Root view for the LoadOut Apple Watch companion.
//
// At this scaffolding stage the watch app shows a single "Coming Soon"
// screen. The view already pulls `WatchConnectivityManager` out of the
// environment so that future features (shot recording, DOPE glance,
// load picker, range card preview) can drop in without restructuring the
// view tree.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var connectivity: WatchConnectivityManager

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "scope")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .foregroundStyle(.tint)

            Text("LoadOut Watch")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Coming Soon")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Tiny diagnostic hint so devs can confirm the WatchConnectivity
            // session reached the iPhone during local testing. Pulled from
            // the manager so it updates live as the session activates.
            if connectivity.isReachable {
                Text("iPhone linked")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else {
                Text("iPhone not reachable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityManager.preview)
}

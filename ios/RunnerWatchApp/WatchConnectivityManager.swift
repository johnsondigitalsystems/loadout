// WatchConnectivityManager.swift
// Wrapper around `WCSession` for the LoadOut watch companion.
//
// At scaffolding stage this only provides:
//   - session activation
//   - reachability tracking (`@Published var isReachable`)
//   - a stub `send(_:)` helper for future message-sending
//   - a stub message-received handler that future feature code can hook.
//
// When real features land, do not extend this class with feature-specific
// payload structs. Instead, add a separate `WatchMessageRouter` that owns
// the typed encoding/decoding and use this class purely as transport.

import Foundation
import WatchConnectivity
import Combine

final class WatchConnectivityManager: NSObject, ObservableObject {
    @Published private(set) var isReachable: Bool = false
    @Published private(set) var lastReceivedPayload: [String: Any] = [:]

    /// Phone-pushed shot-capture sensitivity preset (`"off" | "low" |
    /// "medium" | "high"`). Drained by `MotionDetector.applySensitivity`.
    /// Persists across reboots via the detector's UserDefaults backing.
    @Published private(set) var shotCaptureSensitivity: String?

    private let session: WCSession?

    override init() {
        self.session = WCSession.isSupported() ? WCSession.default : nil
        super.init()
    }

    // MARK: - Lifecycle

    func activate() {
        guard let session else { return }
        session.delegate = self
        session.activate()
    }

    // MARK: - Sending

    /// Fire-and-forget message delivery to the iPhone. Falls back silently
    /// when the session isn't reachable; future feature code may want to
    /// queue these for later delivery via `transferUserInfo` instead.
    func send(_ payload: [String: Any]) {
        guard let session, session.activationState == .activated else { return }
        guard session.isReachable else {
            // Use background user-info transfer when the iPhone is not
            // currently reachable. The system holds the message until the
            // counterpart wakes up.
            session.transferUserInfo(payload)
            return
        }
        session.sendMessage(payload, replyHandler: nil) { _ in
            // Errors here are usually transient (counterpart went away);
            // log via the host app's logger when one is added.
        }
    }
}

extension WatchConnectivityManager: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
        }
    }

    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { [weak self] in
            self?.isReachable = session.isReachable
        }
    }

    func session(_ session: WCSession,
                 didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.lastReceivedPayload = message
            self?.routeIncoming(message)
        }
    }

    func session(_ session: WCSession,
                 didReceiveUserInfo userInfo: [String: Any] = [:]) {
        DispatchQueue.main.async { [weak self] in
            self?.lastReceivedPayload = userInfo
            self?.routeIncoming(userInfo)
        }
    }

    /// Pull the path/payload envelope out of the WatchConnectivity dict
    /// and update any per-path published state. The phone bridge wraps
    /// every send in `{ "path": <short>, "payload": <map> }`; we mirror
    /// that contract here. Adding a new published preference is
    /// `case "<short>":` plus a `@Published` line above.
    private func routeIncoming(_ envelope: [String: Any]) {
        guard let path = envelope["path"] as? String else { return }
        let payload = envelope["payload"] as? [String: Any] ?? [:]
        switch path {
        case WatchPaths.shotCaptureSensitivity:
            if let value = payload["value"] as? String {
                self.shotCaptureSensitivity = value
            }
        default:
            break
        }
    }
}

// MARK: - Preview helpers

extension WatchConnectivityManager {
    /// SwiftUI preview-friendly instance that does not touch `WCSession`.
    static var preview: WatchConnectivityManager {
        let manager = WatchConnectivityManager()
        return manager
    }
}

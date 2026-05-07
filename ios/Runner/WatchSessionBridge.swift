// WatchSessionBridge.swift
// iPhone-side companion to `RunnerWatchApp/WatchConnectivityManager.swift`.
//
// Lives in the Flutter Runner target. Activates a WCSession at app launch
// and exposes a small surface to Dart over a MethodChannel so future
// feature code (DOPE glance, shot logging, load picker) can talk to the
// watch without writing more Swift each time.
//
// To wire this up:
//   1. Make sure this file is added to the Runner target in Xcode.
//   2. In `AppDelegate.swift`, after `GeneratedPluginRegistrant.register(with: self)`,
//      add:
//
//         WatchSessionBridge.shared.activate(with: self)
//
//   3. On the Dart side, see `lib/services/watch_bridge_service.dart`
//      (when you create it) for the matching MethodChannel client.

import Foundation
import Flutter
import WatchConnectivity

final class WatchSessionBridge: NSObject {
    static let shared = WatchSessionBridge()

    /// MethodChannel name shared with Dart. Keep in sync with
    /// `lib/services/watch_bridge_service.dart`.
    static let methodChannelName = "loadout/watch_bridge"

    /// EventChannel name for streaming inbound messages from the watch
    /// to Flutter.
    static let eventChannelName = "loadout/watch_bridge/events"

    private var methodChannel: FlutterMethodChannel?
    private var eventSink: FlutterEventSink?

    private let session: WCSession?

    override init() {
        self.session = WCSession.isSupported() ? WCSession.default : nil
        super.init()
    }

    func activate(with controller: FlutterViewController) {
        guard let session else { return }
        session.delegate = self
        session.activate()

        let messenger = controller.binaryMessenger
        let method = FlutterMethodChannel(
            name: Self.methodChannelName,
            binaryMessenger: messenger
        )
        method.setMethodCallHandler { [weak self] call, result in
            self?.handle(call: call, result: result)
        }
        self.methodChannel = method

        let event = FlutterEventChannel(
            name: Self.eventChannelName,
            binaryMessenger: messenger
        )
        event.setStreamHandler(self)
    }

    private func handle(call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isWatchPaired":
            result(session?.isPaired ?? false)
        case "isWatchAppInstalled":
            result(session?.isWatchAppInstalled ?? false)
        case "isReachable":
            result(session?.isReachable ?? false)
        case "send":
            guard let payload = call.arguments as? [String: Any] else {
                result(FlutterError(code: "BAD_ARGS",
                                    message: "send() expects Map<String,Object>",
                                    details: nil))
                return
            }
            send(payload)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func send(_ payload: [String: Any]) {
        guard let session, session.activationState == .activated else { return }
        guard session.isReachable else {
            session.transferUserInfo(payload)
            return
        }
        session.sendMessage(payload, replyHandler: nil) { _ in }
    }

    private func emit(_ payload: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(payload)
        }
    }
}

extension WatchSessionBridge: WCSessionDelegate {
    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) { /* no-op */ }

    // Required iOS-only callbacks. They have to exist or `WCSession` will
    // crash on activation.
    func sessionDidBecomeInactive(_ session: WCSession) { /* no-op */ }
    func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate so subsequent paired watches still work.
        session.activate()
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        emit(message)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any] = [:]) {
        emit(userInfo)
    }
}

extension WatchSessionBridge: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?,
                  eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

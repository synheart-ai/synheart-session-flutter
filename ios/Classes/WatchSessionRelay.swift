import Foundation
import WatchConnectivity

/// Phone-side relay that bridges session commands and HSI events between the
/// Flutter plugin and a companion watchOS app via `WCSession`.
///
/// Lifecycle:
///   1. Plugin calls `startSession` → relay sends command to watch.
///   2. Watch engine emits events → relay receives them in `didReceiveMessage`
///      and forwards to the stored `eventCallback`.
///   3. On terminal events (`session_summary` / `error`) the relay cleans up
///      automatically.
///
/// If `sendMessage` fails (watch unreachable, app not installed, etc.) the
/// `onSendFailed` closure fires so the plugin can fall back to a local engine.
class WatchSessionRelay: NSObject, WCSessionDelegate {

    typealias EventCallback = ([String: Any]) -> Void

    private var eventCallback: EventCallback?
    private var activeSessionId: String?
    private var activated = false

    override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Status

    /// Full connectivity snapshot for the Dart layer.
    var status: [String: Any] {
        guard WCSession.isSupported(), activated else {
            return ["supported": WCSession.isSupported(), "reachable": false,
                    "paired": false, "installed": false]
        }
        let s = WCSession.default
        return ["supported": true, "reachable": s.isReachable,
                "paired": s.isPaired, "installed": s.isWatchAppInstalled]
    }

    /// Whether the watch companion is reachable right now.
    /// This is the *authoritative* check — `isReachable` requires the watch app
    /// to be installed, paired, and in the foreground.
    var isReachable: Bool {
        guard WCSession.isSupported(), activated else { return false }
        return WCSession.default.isReachable
    }

    // MARK: - Session commands

    /// Send a start-session command to the watch.
    ///
    /// - Parameters:
    ///   - config: Session configuration to forward.
    ///   - callback: Called for each event the watch streams back.
    ///   - onSendFailed: Called (on main queue) if `sendMessage` fails,
    ///     allowing the caller to fall back to a local engine.
    func startSession(config: SessionConfig,
                      callback: @escaping EventCallback,
                      onSendFailed: @escaping () -> Void) {
        activeSessionId = config.sessionId
        eventCallback = callback

        var message: [String: Any] = [
            "command": "start_session",
            "session_id": config.sessionId,
            "mode": config.mode.rawValue,
            "duration_sec": config.durationSec,
            "profile": [
                "window_sec": config.profile.windowSec,
                "emit_interval_sec": config.profile.emitIntervalSec
            ]
        ]
        if let label = config.windowLabel {
            message["window_label"] = label
        }

        WCSession.default.sendMessage(message, replyHandler: nil) { [weak self] error in
            NSLog("[WatchRelay] sendMessage failed: \(error.localizedDescription)")
            DispatchQueue.main.async {
                self?.cleanup()
                onSendFailed()
            }
        }
    }

    /// Send a stop-session command to the watch.
    func stopSession(sessionId: String) {
        WCSession.default.sendMessage(
            ["command": "stop_session", "session_id": sessionId],
            replyHandler: nil
        ) { error in
            NSLog("[WatchRelay] stop sendMessage failed: \(error.localizedDescription)")
        }
    }

    // MARK: - WCSessionDelegate (iOS required)

    func session(_ session: WCSession,
                 activationDidCompleteWith activationState: WCSessionActivationState,
                 error: Error?) {
        activated = (activationState == .activated)
        if let error = error {
            NSLog("[WatchRelay] activation error: \(error.localizedDescription)")
        }
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        WCSession.default.activate()
    }

    // MARK: - Receiving events from watch

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async { [weak self] in
            self?.eventCallback?(message)

            let type = message["type"] as? String ?? ""
            if type == "session_summary" || type == "session_error" {
                self?.cleanup()
            }
        }
    }

    // MARK: - Private

    private func cleanup() {
        activeSessionId = nil
        eventCallback = nil
    }
}

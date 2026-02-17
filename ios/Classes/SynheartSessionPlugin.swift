import Flutter

/// Flutter plugin entry point for Synheart Session on iOS.
///
/// Routing strategy for `startSession`:
///   1. If the watch companion is reachable → relay the command to the watch.
///      The watch runs its `SessionEngine` and streams events back via WCSession.
///      If the send fails (watch killed, BT dropped) → fall back to step 2.
///   2. Otherwise → run a local `SessionEngine` on the phone.
///
/// In both cases, events flow through the same `FlutterEventSink` so the Dart
/// layer doesn't need to know which path was taken.
public class SynheartSessionPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private let engine = SessionEngine()
    private let watchRelay = WatchSessionRelay()
    private var eventSink: FlutterEventSink?
    private var usingWatch = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = SynheartSessionPlugin()

        let methodChannel = FlutterMethodChannel(
            name: "ai.synheart.session/methods",
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(instance, channel: methodChannel)

        let eventChannel = FlutterEventChannel(
            name: "ai.synheart.session/events",
            binaryMessenger: registrar.messenger()
        )
        eventChannel.setStreamHandler(instance)
    }

    // MARK: - FlutterPlugin (MethodChannel)

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "startSession":  handleStartSession(call: call, result: result)
        case "stopSession":   handleStopSession(call: call, result: result)
        case "getStatus":     handleGetStatus(result: result)
        case "getWatchStatus": handleGetWatchStatus(result: result)
        default:              result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Start

    private func handleStartSession(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any] else {
            result(FlutterError(code: "invalid_state", message: "Invalid arguments", details: nil))
            return
        }

        do {
            let config = try SessionConfig(from: args)
            let sink: ([String: Any]) -> Void = { [weak self] event in
                DispatchQueue.main.async { self?.eventSink?(event) }
            }

            if watchRelay.isReachable {
                usingWatch = true
                watchRelay.startSession(config: config, callback: sink) { [weak self] in
                    // Watch send failed — transparent fallback
                    guard let self = self else { return }
                    self.usingWatch = false
                    try? self.engine.start(config: config, callback: sink)
                }
            } else {
                usingWatch = false
                try engine.start(config: config, callback: sink)
            }
            result(nil)
        } catch let error as SessionError {
            result(FlutterError(code: error.code.rawValue, message: error.description, details: nil))
        } catch {
            result(FlutterError(code: "invalid_state", message: error.localizedDescription, details: nil))
        }
    }

    // MARK: - Stop

    private func handleStopSession(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let sessionId = args["session_id"] as? String else {
            result(FlutterError(code: "invalid_state", message: "Missing session_id", details: nil))
            return
        }

        if usingWatch {
            watchRelay.stopSession(sessionId: sessionId)
            usingWatch = false
            result(nil)
        } else {
            do {
                try engine.stop(sessionId: sessionId)
                result(nil)
            } catch let error as SessionError {
                result(FlutterError(code: error.code.rawValue, message: error.description, details: nil))
            } catch {
                result(FlutterError(code: "invalid_state", message: error.localizedDescription, details: nil))
            }
        }
    }

    // MARK: - Status

    private func handleGetStatus(result: @escaping FlutterResult) {
        result(engine.getStatus())
    }

    private func handleGetWatchStatus(result: @escaping FlutterResult) {
        result(watchRelay.status)
    }

    // MARK: - FlutterStreamHandler (EventChannel)

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }
}

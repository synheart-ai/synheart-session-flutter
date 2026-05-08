import Flutter

/// Flutter plugin entry point for Synheart Session on iOS.
///
/// After the refactor to Dart-side `LiveSessionEngine`, this plugin only
/// handles the Apple Watch relay path. All local session compute is done
/// in Dart. The watch relay is kept because WCSession requires a native host.
public class SynheartSessionPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {

    private let watchRelay = WatchSessionRelay()
    private var eventSink: FlutterEventSink?

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
        case "getStatus":     result(nil) // Local status handled in Dart
        case "getWatchStatus": handleGetWatchStatus(result: result)
        default:              result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - Start (watch relay only)

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
                watchRelay.startSession(config: config, callback: sink) { /* onSendFailed — Dart handles locally */ }
            }
            // If watch not reachable, just return — Dart LiveSessionEngine handles locally
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

        watchRelay.stopSession(sessionId: sessionId)
        result(nil)
    }

    // MARK: - Watch status

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

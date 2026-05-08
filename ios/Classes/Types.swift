import Foundation

/// Session mode matching the Dart `SessionMode` enum wire values.
enum SessionMode: String {
    case focus = "focus"
    case breathing = "breathing"

    init?(from string: String) {
        self.init(rawValue: string)
    }
}

/// Error codes matching the Dart `SessionErrorCode` enum wire values.
enum SessionErrorCode: String {
    case permissionDenied = "permission_denied"
    case sensorUnavailable = "sensor_unavailable"
    case invalidState = "invalid_state"
    case lowBattery = "low_battery"
    case osTerminated = "os_terminated"
}

/// Compute profile controlling HSI emission timing.
struct ComputeProfile {
    let windowSec: Int
    let emitIntervalSec: Int
    let rawEmitIntervalSec: Int?

    init(windowSec: Int = 60, emitIntervalSec: Int = 5, rawEmitIntervalSec: Int? = nil) {
        self.windowSec = windowSec
        self.emitIntervalSec = emitIntervalSec
        self.rawEmitIntervalSec = rawEmitIntervalSec
    }

    init(from map: [String: Any]) {
        self.windowSec = map["window_sec"] as? Int ?? 60
        self.emitIntervalSec = map["emit_interval_sec"] as? Int ?? 5
        self.rawEmitIntervalSec = map["raw_emit_interval_sec"] as? Int
    }
}

/// Session configuration received from the Dart side via MethodChannel.
struct SessionConfig {
    let sessionId: String
    let mode: SessionMode
    let durationSec: Int
    let profile: ComputeProfile
    let windowLabel: String?
    let includeRawSamples: Bool

    init(sessionId: String, mode: SessionMode, durationSec: Int,
         profile: ComputeProfile = ComputeProfile(),
         windowLabel: String? = nil,
         includeRawSamples: Bool = false) {
        self.sessionId = sessionId
        self.mode = mode
        self.durationSec = durationSec
        self.profile = profile
        self.windowLabel = windowLabel
        self.includeRawSamples = includeRawSamples
    }

    init(from map: [String: Any]) throws {
        guard let sessionId = map["session_id"] as? String else {
            throw SessionError.invalidState("Missing session_id")
        }
        guard let modeStr = map["mode"] as? String,
              let mode = SessionMode(from: modeStr) else {
            throw SessionError.invalidState("Missing or invalid mode")
        }
        guard let durationSec = map["duration_sec"] as? Int else {
            throw SessionError.invalidState("Missing duration_sec")
        }
        self.sessionId = sessionId
        self.mode = mode
        self.durationSec = durationSec
        if let profileMap = map["profile"] as? [String: Any] {
            self.profile = ComputeProfile(from: profileMap)
        } else {
            self.profile = ComputeProfile()
        }
        self.windowLabel = map["window_label"] as? String
        self.includeRawSamples = map["include_raw_samples"] as? Bool ?? false
    }
}

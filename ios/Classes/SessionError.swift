import Foundation

/// Session error enum following the SwipError pattern.
enum SessionError: Error, CustomStringConvertible {
    case permissionDenied(String)
    case sensorUnavailable(String)
    case invalidState(String)
    case lowBattery(String)
    case osTerminated(String)

    var code: SessionErrorCode {
        switch self {
        case .permissionDenied: return .permissionDenied
        case .sensorUnavailable: return .sensorUnavailable
        case .invalidState: return .invalidState
        case .lowBattery: return .lowBattery
        case .osTerminated: return .osTerminated
        }
    }

    var description: String {
        switch self {
        case .permissionDenied(let msg): return "PermissionDenied: \(msg)"
        case .sensorUnavailable(let msg): return "SensorUnavailable: \(msg)"
        case .invalidState(let msg): return "InvalidState: \(msg)"
        case .lowBattery(let msg): return "LowBattery: \(msg)"
        case .osTerminated(let msg): return "OsTerminated: \(msg)"
        }
    }
}

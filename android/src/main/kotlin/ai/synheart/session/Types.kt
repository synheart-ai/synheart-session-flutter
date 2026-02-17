package ai.synheart.session

/** Session mode matching the Dart `SessionMode` enum wire values. */
enum class SessionMode(val value: String) {
    FOCUS("focus"),
    BREATHING("breathing");

    companion object {
        fun fromString(value: String): SessionMode? =
            entries.firstOrNull { it.value == value }
    }
}

/** Error codes matching the Dart `SessionErrorCode` enum wire values. */
enum class SessionErrorCode(val value: String) {
    PERMISSION_DENIED("permission_denied"),
    SENSOR_UNAVAILABLE("sensor_unavailable"),
    INVALID_STATE("invalid_state"),
    LOW_BATTERY("low_battery"),
    OS_TERMINATED("os_terminated")
}

/** Compute profile controlling HSI emission timing. */
data class ComputeProfile(
    val windowSec: Int = 60,
    val emitIntervalSec: Int = 5
) {
    companion object {
        fun fromMap(map: Map<String, Any>): ComputeProfile = ComputeProfile(
            windowSec = (map["window_sec"] as? Number)?.toInt() ?: 60,
            emitIntervalSec = (map["emit_interval_sec"] as? Number)?.toInt() ?: 5
        )
    }
}

/** Session configuration received from the Dart side via MethodChannel. */
data class SessionConfig(
    val sessionId: String,
    val mode: SessionMode,
    val durationSec: Int,
    val profile: ComputeProfile = ComputeProfile(),
    val windowLabel: String? = null
) {
    companion object {
        @Suppress("UNCHECKED_CAST")
        fun fromMap(map: Map<String, Any>): SessionConfig {
            val sessionId = map["session_id"] as? String
                ?: throw SessionError.InvalidState("Missing session_id")
            val modeStr = map["mode"] as? String
                ?: throw SessionError.InvalidState("Missing mode")
            val mode = SessionMode.fromString(modeStr)
                ?: throw SessionError.InvalidState("Invalid mode: $modeStr")
            val durationSec = (map["duration_sec"] as? Number)?.toInt()
                ?: throw SessionError.InvalidState("Missing duration_sec")
            val profile = (map["profile"] as? Map<String, Any>)
                ?.let { ComputeProfile.fromMap(it) }
                ?: ComputeProfile()
            val windowLabel = map["window_label"] as? String
            return SessionConfig(sessionId, mode, durationSec, profile, windowLabel)
        }
    }
}

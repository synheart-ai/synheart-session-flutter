package ai.synheart.session

import android.os.Handler
import android.os.Looper
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin
import kotlin.random.Random

/** Timer-driven mock session engine. Generates sinusoidal HR data and emits session frames. */
class SessionEngine {

    private var config: SessionConfig? = null
    private var callback: ((Map<String, Any>) -> Unit)? = null
    private val handler = Handler(Looper.getMainLooper())
    private var emitRunnable: Runnable? = null
    private var durationRunnable: Runnable? = null
    private var startedAtMs: Long = 0
    private var seq: Int = 0

    /**
     * Start a new session.
     *
     * @param config Session configuration from Dart.
     * @param callback Called for each event map to be sent to the EventChannel.
     * @throws SessionError.InvalidState if a session is already running.
     */
    fun start(config: SessionConfig, callback: (Map<String, Any>) -> Unit) {
        this.config?.let {
            throw SessionError.InvalidState("Session ${it.sessionId} is already running")
        }

        this.config = config
        this.callback = callback
        this.seq = 0
        this.startedAtMs = System.currentTimeMillis()

        // Emit session_started
        callback(mapOf(
            "type" to "session_started",
            "session_id" to config.sessionId,
            "started_at_ms" to startedAtMs
        ))

        // Schedule periodic session frame emission
        val intervalMs = config.profile.emitIntervalSec.toLong() * 1000
        emitRunnable = object : Runnable {
            override fun run() {
                emitFrame()
                handler.postDelayed(this, intervalMs)
            }
        }
        handler.postDelayed(emitRunnable!!, intervalMs)

        // Schedule auto-stop at durationSec
        val durationMs = config.durationSec.toLong() * 1000
        durationRunnable = Runnable {
            config.sessionId.let { doStop(it) }
        }
        handler.postDelayed(durationRunnable!!, durationMs)
    }

    /**
     * Stop a running session.
     *
     * @param sessionId The session ID to stop. Must match the active session.
     * @throws SessionError.InvalidState if no session is running or IDs don't match.
     */
    fun stop(sessionId: String) {
        val cfg = config ?: throw SessionError.InvalidState("No active session")
        if (cfg.sessionId != sessionId) {
            throw SessionError.InvalidState("Session ID mismatch: expected ${cfg.sessionId}, got $sessionId")
        }
        doStop(sessionId)
    }

    /**
     * Get the status of the current session.
     *
     * @return A status map or null if no session is active.
     */
    fun getStatus(): Map<String, Any>? {
        val cfg = config ?: return null
        return mapOf(
            "session_id" to cfg.sessionId,
            "active" to true,
            "last_seq" to seq
        )
    }

    // -- Private --

    private fun emitFrame() {
        val cfg = config ?: return
        val cb = callback ?: return

        seq++
        val nowMs = System.currentTimeMillis()
        val windowSec = cfg.profile.windowSec
        val sampleCount = windowSec // 1 sample per second
        val samples = generateMockSamples(sampleCount, nowMs - windowSec * 1000L)

        val metrics = computeMetrics(samples)

        cb(mapOf(
            "type" to "session_frame",
            "session_id" to cfg.sessionId,
            "seq" to seq,
            "emitted_at_ms" to nowMs,
            "metrics" to metrics
        ))
    }

    private fun doStop(sessionId: String) {
        emitRunnable?.let { handler.removeCallbacks(it) }
        emitRunnable = null
        durationRunnable?.let { handler.removeCallbacks(it) }
        durationRunnable = null

        val cfg = config ?: return
        val cb = callback ?: return

        val nowMs = System.currentTimeMillis()
        val durationActualSec = ((nowMs - startedAtMs) / 1000).toInt()

        // Build a summary from the full duration
        val samples = generateMockSamples(durationActualSec, startedAtMs)
        val metrics = computeMetrics(samples)

        cb(mapOf(
            "type" to "session_summary",
            "session_id" to cfg.sessionId,
            "duration_actual_sec" to durationActualSec,
            "metrics" to metrics
        ))

        this.config = null
        this.callback = null
    }

    /** Compute raw physiological metrics from HR samples. */
    private fun computeMetrics(samples: List<Pair<Long, Double>>): Map<String, Any> {
        if (samples.isEmpty()) {
            return mapOf(
                "hr_mean_bpm" to 0.0,
                "hr_sdnn_ms" to 0.0,
                "rmssd_ms" to 0.0,
                "sample_count" to 0
            )
        }

        val bpms = samples.map { it.second }
        val meanBpm = bpms.average()

        // Derive RR intervals from BPM
        val rrIntervals = bpms.map { 60000.0 / it }
        val meanRR = rrIntervals.average()
        val variance = rrIntervals.map { (it - meanRR) * (it - meanRR) }.average()
        val sdnn = kotlin.math.sqrt(variance)

        // RMSSD from successive RR differences
        var rmssd = 0.0
        if (rrIntervals.size >= 2) {
            var sumSqDiff = 0.0
            for (i in 1 until rrIntervals.size) {
                val diff = rrIntervals[i] - rrIntervals[i - 1]
                sumSqDiff += diff * diff
            }
            rmssd = kotlin.math.sqrt(sumSqDiff / (rrIntervals.size - 1))
        }

        return mapOf(
            "hr_mean_bpm" to (meanBpm * 10).toLong() / 10.0,
            "hr_sdnn_ms" to (sdnn * 100).toLong() / 100.0,
            "rmssd_ms" to (rmssd * 100).toLong() / 100.0,
            "sample_count" to samples.size,
            "start_ms" to samples.first().first,
            "end_ms" to samples.last().first
        )
    }

    /** Generate mock HR samples with sinusoidal baseline + noise (matches Dart MockHrGenerator). */
    private fun generateMockSamples(count: Int, startMs: Long): List<Pair<Long, Double>> {
        if (count <= 0) return emptyList()
        val baseline = 72.0
        val amplitude = 5.0
        val cycleSec = 4.0
        val samples = mutableListOf<Pair<Long, Double>>()

        for (i in 0 until count) {
            val t = i.toDouble()
            val sinComponent = amplitude * sin(2.0 * PI * t / cycleSec)
            val noise = Random.nextDouble(-2.0, 2.0)
            val bpm = min(200.0, max(40.0, baseline + sinComponent + noise))
            val ts = startMs + i * 1000L
            samples.add(Pair(ts, bpm))
        }
        return samples
    }
}

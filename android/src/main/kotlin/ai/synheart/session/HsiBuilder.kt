package ai.synheart.session

import kotlin.math.sqrt
import kotlin.math.round

/** Builds HSI 1.0 JSON maps from HR samples. Mock implementation matching the Dart MockSessionEngine. */
object HsiBuilder {

    /**
     * Build an HSI 1.0 map from HR samples.
     *
     * @param samples List of (timestampMs, bpm) pairs.
     * @param config The active session configuration.
     * @param seq Sequence number of this HSI frame.
     * @return A map matching the Dart `hsi_json` wire format.
     */
    fun build(samples: List<Pair<Long, Double>>, config: SessionConfig, seq: Int): Map<String, Any> {
        if (samples.isEmpty()) return emptyHsi(config, seq)

        val startMs = samples.first().first
        val endMs = samples.last().first

        // Compute mean BPM
        val bpmValues = samples.map { it.second }
        val meanBpm = bpmValues.sum() / bpmValues.size

        // Convert BPM to RR intervals (ms)
        val rrIntervals = bpmValues.map { 60000.0 / it }
        val meanRR = rrIntervals.sum() / rrIntervals.size

        // SDNN: population standard deviation of RR intervals
        val variance = rrIntervals.sumOf { (it - meanRR) * (it - meanRR) } / rrIntervals.size
        val sdnn = sqrt(variance)

        // RMSSD approximation (matches Dart mock: sdnn * 0.8)
        val rmssd = sdnn * 0.8

        return mapOf(
            "hsi_version" to "1.0",
            "producer" to "synheart-session-android/0.1.0",
            "windows" to listOf(
                mapOf(
                    "start_ms" to startMs,
                    "end_ms" to endMs,
                    "sample_count" to samples.size
                )
            ),
            "axes" to mapOf(
                "physiological" to mapOf(
                    "hr_mean_bpm" to round(meanBpm * 10) / 10,
                    "hr_sdnn_ms" to round(sdnn * 100) / 100,
                    "rmssd_ms" to round(rmssd * 100) / 100
                )
            ),
            "privacy" to mapOf(
                "raw_samples_included" to false
            ),
            "meta" to mapOf(
                "mock" to true,
                "session_id" to config.sessionId,
                "mode" to config.mode.value,
                "seq" to seq
            )
        )
    }

    private fun emptyHsi(config: SessionConfig, seq: Int): Map<String, Any> = mapOf(
        "hsi_version" to "1.0",
        "producer" to "synheart-session-android/0.1.0",
        "windows" to emptyList<Map<String, Any>>(),
        "axes" to mapOf(
            "physiological" to mapOf(
                "hr_mean_bpm" to 0.0,
                "hr_sdnn_ms" to 0.0,
                "rmssd_ms" to 0.0
            )
        ),
        "privacy" to mapOf(
            "raw_samples_included" to false
        ),
        "meta" to mapOf(
            "mock" to true,
            "session_id" to config.sessionId,
            "mode" to config.mode.value,
            "seq" to seq
        )
    )
}

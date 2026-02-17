import Foundation

/// Builds HSI 1.0 JSON maps from HR samples. Mock implementation matching the Dart MockSessionEngine.
enum HsiBuilder {

    /// A single HR sample with timestamp and BPM value.
    typealias HrSample = (timestampMs: Int64, bpm: Double)

    /// Build an HSI 1.0 dict from HR samples.
    ///
    /// - Parameters:
    ///   - samples: Array of (timestampMs, bpm) tuples.
    ///   - config: The active session configuration.
    ///   - seq: Sequence number of this HSI frame.
    /// - Returns: A dictionary matching the Dart `hsi_json` wire format.
    static func build(samples: [HrSample], config: SessionConfig, seq: Int) -> [String: Any] {
        guard !samples.isEmpty else {
            return emptyHsi(config: config, seq: seq)
        }

        let startMs = samples.first!.timestampMs
        let endMs = samples.last!.timestampMs

        // Compute mean BPM
        let bpmValues = samples.map { $0.bpm }
        let meanBpm = bpmValues.reduce(0, +) / Double(bpmValues.count)

        // Convert BPM to RR intervals (ms)
        let rrIntervals = bpmValues.map { 60000.0 / $0 }
        let meanRR = rrIntervals.reduce(0, +) / Double(rrIntervals.count)

        // SDNN: population standard deviation of RR intervals
        let variance = rrIntervals.reduce(0.0) { $0 + ($1 - meanRR) * ($1 - meanRR) }
            / Double(rrIntervals.count)
        let sdnn = sqrt(variance)

        // RMSSD approximation (matches Dart mock: sdnn * 0.8)
        let rmssd = sdnn * 0.8

        let window: [String: Any] = [
            "start_ms": startMs,
            "end_ms": endMs,
            "sample_count": samples.count
        ]
        let physio: [String: Any] = [
            "hr_mean_bpm": round(meanBpm * 10) / 10,
            "hr_sdnn_ms": round(sdnn * 100) / 100,
            "rmssd_ms": round(rmssd * 100) / 100
        ]
        let meta: [String: Any] = [
            "mock": true,
            "session_id": config.sessionId,
            "mode": config.mode.rawValue,
            "seq": seq
        ]

        return [
            "hsi_version": "1.0",
            "producer": "synheart-session-ios/0.1.0",
            "windows": [window],
            "axes": ["physiological": physio],
            "privacy": ["raw_samples_included": false],
            "meta": meta
        ]
    }

    private static func emptyHsi(config: SessionConfig, seq: Int) -> [String: Any] {
        let physio: [String: Any] = [
            "hr_mean_bpm": 0.0,
            "hr_sdnn_ms": 0.0,
            "rmssd_ms": 0.0
        ]
        let meta: [String: Any] = [
            "mock": true,
            "session_id": config.sessionId,
            "mode": config.mode.rawValue,
            "seq": seq
        ]

        return [
            "hsi_version": "1.0",
            "producer": "synheart-session-ios/0.1.0",
            "windows": [] as [[String: Any]],
            "axes": ["physiological": physio],
            "privacy": ["raw_samples_included": false],
            "meta": meta
        ]
    }
}

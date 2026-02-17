import Foundation

/// Timer-driven mock session engine. Generates sinusoidal HR data and emits HSI frames.
class SessionEngine {

    typealias EventCallback = ([String: Any]) -> Void

    private var config: SessionConfig?
    private var callback: EventCallback?
    private var emitTimer: Timer?
    private var durationTimer: Timer?
    private var rawEmitTimer: Timer?
    private var startedAtMs: Int64 = 0
    private var seq: Int = 0
    private var rawSeq: Int = 0

    /// Start a new session.
    ///
    /// - Parameters:
    ///   - config: Session configuration from Dart.
    ///   - callback: Closure called for each event map to be sent to the EventChannel.
    /// - Throws: `SessionError.invalidState` if a session is already running.
    func start(config: SessionConfig, callback: @escaping EventCallback) throws {
        guard self.config == nil else {
            throw SessionError.invalidState("Session \(self.config!.sessionId) is already running")
        }

        self.config = config
        self.callback = callback
        self.seq = 0
        self.rawSeq = 0
        self.startedAtMs = Int64(Date().timeIntervalSince1970 * 1000)

        // Emit session_started
        callback([
            "type": "session_started",
            "session_id": config.sessionId,
            "started_at_ms": startedAtMs
        ])

        // Schedule periodic HSI frame emission
        let interval = TimeInterval(config.profile.emitIntervalSec)
        emitTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.emitFrame()
        }

        // Schedule auto-stop at durationSec
        let duration = TimeInterval(config.durationSec)
        durationTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self = self, let cfg = self.config else { return }
            self.doStop(sessionId: cfg.sessionId)
        }

        if config.includeRawSamples {
            let rawInterval = TimeInterval(config.profile.rawEmitIntervalSec ?? config.profile.emitIntervalSec)
            rawEmitTimer = Timer.scheduledTimer(withTimeInterval: rawInterval, repeats: true) { [weak self] _ in
                self?.emitBiosignalFrame()
            }
        }
    }

    /// Stop a running session.
    ///
    /// - Parameter sessionId: The session ID to stop. Must match the active session.
    /// - Throws: `SessionError.invalidState` if no session is running or IDs don't match.
    func stop(sessionId: String) throws {
        guard let cfg = config else {
            throw SessionError.invalidState("No active session")
        }
        guard cfg.sessionId == sessionId else {
            throw SessionError.invalidState("Session ID mismatch: expected \(cfg.sessionId), got \(sessionId)")
        }
        doStop(sessionId: sessionId)
    }

    /// Get the status of the current session.
    ///
    /// - Returns: A status map or `nil` if no session is active.
    func getStatus() -> [String: Any]? {
        guard let cfg = config else { return nil }
        return [
            "session_id": cfg.sessionId,
            "active": true,
            "last_seq": seq
        ]
    }

    // MARK: - Private

    private func emitFrame() {
        guard let cfg = config, let cb = callback else { return }

        seq += 1
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let windowSec = cfg.profile.windowSec
        let sampleCount = windowSec // 1 sample per second
        let samples = generateMockSamples(count: sampleCount, startMs: nowMs - Int64(windowSec * 1000))

        let startMs = samples.first?.timestampMs ?? nowMs
        let hsi = FluxBridge.hrWindowToHsi(
            sessionId: cfg.sessionId,
            deviceId: "watch",
            timezone: TimeZone.current.identifier,
            startEpochMs: startMs,
            endEpochMs: nowMs,
            samples: samples
        ) ?? HsiBuilder.build(samples: samples, config: cfg, seq: seq)

        cb([
            "type": "hsi_frame",
            "session_id": cfg.sessionId,
            "seq": seq,
            "emitted_at_ms": nowMs,
            "hsi_json": hsi
        ])
    }

    private func doStop(sessionId: String) {
        emitTimer?.invalidate()
        emitTimer = nil
        durationTimer?.invalidate()
        durationTimer = nil
        rawEmitTimer?.invalidate()
        rawEmitTimer = nil

        guard let cfg = config, let cb = callback else { return }

        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let durationActualSec = Int((nowMs - startedAtMs) / 1000)

        // Build a summary HSI from the full duration
        let samples = generateMockSamples(count: durationActualSec, startMs: startedAtMs)
        let hsi = FluxBridge.hrWindowToHsi(
            sessionId: cfg.sessionId,
            deviceId: "watch",
            timezone: TimeZone.current.identifier,
            startEpochMs: startedAtMs,
            endEpochMs: nowMs,
            samples: samples
        ) ?? HsiBuilder.build(samples: samples, config: cfg, seq: seq)

        cb([
            "type": "session_summary",
            "session_id": cfg.sessionId,
            "duration_actual_sec": durationActualSec,
            "hsi_json": hsi
        ])

        self.config = nil
        self.callback = nil
    }

    private func emitBiosignalFrame() {
        guard let cfg = config, let cb = callback else { return }
        rawSeq += 1
        let nowMs = Int64(Date().timeIntervalSince1970 * 1000)
        let intervalSec = cfg.profile.rawEmitIntervalSec ?? cfg.profile.emitIntervalSec
        let samples = generateMockSamples(count: intervalSec, startMs: nowMs - Int64(intervalSec * 1000))

        cb([
            "type": "biosignal_frame",
            "session_id": cfg.sessionId,
            "seq": rawSeq,
            "emitted_at_ms": nowMs,
            "samples": samples.map { sample -> [String: Any] in
                var dict: [String: Any] = [
                    "timestamp_ms": sample.timestampMs,
                    "bpm": sample.bpm,
                    "rr_interval_ms": 60000.0 / sample.bpm,
                ]
                dict["accelerometer"] = [
                    "x": Double.random(in: -0.1...0.1),
                    "y": Double.random(in: -0.05...0.05),
                    "z": Double.random(in: 0.95...1.05),
                ]
                return dict
            }
        ])
    }

    /// Generate mock HR samples with sinusoidal baseline + noise (matches Dart MockHrGenerator).
    private func generateMockSamples(count: Int, startMs: Int64) -> [HsiBuilder.HrSample] {
        guard count > 0 else { return [] }
        var samples: [HsiBuilder.HrSample] = []
        let baseline = 72.0
        let amplitude = 5.0
        let cycleSec = 4.0

        for i in 0..<count {
            let t = Double(i)
            let sinComponent = amplitude * sin(2.0 * .pi * t / cycleSec)
            let noise = Double.random(in: -2.0...2.0)
            let bpm = min(200.0, max(40.0, baseline + sinComponent + noise))
            let ts = startMs + Int64(i) * 1000
            samples.append((timestampMs: ts, bpm: bpm))
        }
        return samples
    }
}

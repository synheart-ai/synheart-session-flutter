import Foundation

// MARK: - C Function Types

private typealias HrWindowToHsiFn = @convention(c) (
    UnsafePointer<CChar>?,  // session_id
    UnsafePointer<CChar>?,  // device_id
    UnsafePointer<CChar>?,  // timezone
    Int64,                   // start_epoch_ms
    Int64,                   // end_epoch_ms
    UnsafePointer<Float>?,  // bpm_values
    UnsafePointer<Int64>?,  // timestamp_ms_values
    UInt32                   // sample_count
) -> UnsafeMutablePointer<CChar>?

private typealias FreeStringFn = @convention(c) (
    UnsafeMutablePointer<CChar>?
) -> Void

private typealias LastErrorFn = @convention(c) () -> UnsafePointer<CChar>?

// MARK: - FluxBridge

/// Bridge to synheart-flux Rust library for HSI-compliant HR window computation.
///
/// Uses `dlsym` for soft-linking so the plugin works gracefully if the Flux
/// binary is not bundled. Returns `nil` if symbols aren't available, letting
/// `HsiBuilder` serve as fallback.
enum FluxBridge {

    // Resolve symbols lazily via dlsym — returns nil if Flux is not linked.
    private static let _hrWindowToHsi: HrWindowToHsiFn? = {
        guard let sym = dlsym(dlopen(nil, RTLD_LAZY), "flux_hr_window_to_hsi") else { return nil }
        return unsafeBitCast(sym, to: HrWindowToHsiFn.self)
    }()

    private static let _freeString: FreeStringFn? = {
        guard let sym = dlsym(dlopen(nil, RTLD_LAZY), "flux_free_string") else { return nil }
        return unsafeBitCast(sym, to: FreeStringFn.self)
    }()

    private static let _lastError: LastErrorFn? = {
        guard let sym = dlsym(dlopen(nil, RTLD_LAZY), "flux_last_error") else { return nil }
        return unsafeBitCast(sym, to: LastErrorFn.self)
    }()

    /// Whether Flux symbols are available at runtime.
    static var isAvailable: Bool { _hrWindowToHsi != nil }

    /// Convert HR samples to HSI 1.0 JSON dict via Flux FFI.
    /// Returns nil if Flux is unavailable or computation fails.
    static func hrWindowToHsi(
        sessionId: String,
        deviceId: String,
        timezone: String,
        startEpochMs: Int64,
        endEpochMs: Int64,
        samples: [HsiBuilder.HrSample]
    ) -> [String: Any]? {
        guard let fn = _hrWindowToHsi else { return nil }

        var bpmValues = samples.map { Float($0.bpm) }
        var timestamps = samples.map { $0.timestampMs }

        guard let resultPtr = fn(
            sessionId, deviceId, timezone,
            startEpochMs, endEpochMs,
            &bpmValues, &timestamps,
            UInt32(samples.count)
        ) else {
            if let errFn = _lastError, let errPtr = errFn() {
                NSLog("[FluxBridge] error: \(String(cString: errPtr))")
            }
            return nil
        }

        let jsonString = String(cString: resultPtr)
        _freeString?(resultPtr)

        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }

        return dict
    }
}

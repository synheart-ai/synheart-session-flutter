# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.2.0] - 2026-02-19

### Changed

- **Breaking**: Removed `PayloadEncoding` enum — structured message types replace the encoding field on `SessionFrame` and `SessionSummary`, aligning with the updated `session.proto` spec.

### Added

- Privacy & Security section in README.
- SDK Usage section in README with error handling and mock provider patterns.
- Testing section in README.

### Fixed

- Updated installation version in README from `^0.1.0` to `^0.2.0`.
- Aligned README sections with AGENTS.md mandatory structure for platform SDKs.

## [0.1.0] - 2026-02-18

### Added

- `SynheartSession` main class with live and mock constructors.
- `LiveSessionEngine` — Dart-side session engine that consumes real HR data from `synheart_wear` (via `SynheartWear.streamHR()` or `BleHrmProvider.onHeartRate`) and behavioral signals from `synheart_behavior` (`SynheartBehavior.getCurrentStats()`).
- `_HrRingBuffer` — circular buffer for time-windowed HR sample storage with real SDNN/RMSSD computation from actual RR intervals.
- `SynheartSession` constructor accepts optional `wear`, `bleHrm`, and `behavior` parameters for live mode.
- `SynheartSession.mock()` constructor for local development and testing (sinusoidal HR generation).
- `MockSessionEngine` with `MockHrGenerator` for deterministic mock HR data.
- `BehaviorSnapshot` class and `BehaviorProvider` abstract class for pluggable behavioral signal sources (pull-based).
- `MockBehaviorProvider` — returns stable mid-range behavioral values for testing.
- `SessionFrame` and `SessionSummary` carry an optional `behavior` field (`Map<String, dynamic>?`).
- Dart type definitions matching `session.proto` schema (`SessionConfig`, `SessionEvent`, `SessionStatus`).
- Platform channel bridge (`MethodChannel` + `EventChannel`) for iOS watch relay.
- iOS `SynheartSessionPlugin.swift` — watch relay + `getWatchStatus` only (via WCSession).
- Android `SynheartSessionPlugin.kt` — minimal no-op stub for plugin registration.
- `synheart_wear` and `synheart_behavior` as dependencies.
- Type-safe session events: `SessionStarted`, `SessionFrame`, `BiosignalFrame`, `SessionSummary`, `SessionError`.
- Configurable `ComputeProfile` (window size, emit interval).
- Tests: `mock_session_test.dart`, `session_test.dart`, `behavior_provider_test.dart`, `live_session_engine_test.dart`, `types_test.dart`.

[0.2.0]: https://github.com/synheart-ai/synheart-session-dart/releases/tag/v0.2.0
[0.1.0]: https://github.com/synheart-ai/synheart-session-dart/releases/tag/v0.1.0

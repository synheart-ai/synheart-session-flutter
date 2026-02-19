# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
## [0.1.0] - 2025-02-18

### Added


- `BehaviorSnapshot` class and `BehaviorProvider` abstract class for pluggable behavioral signal sources (pull-based).
- `MockBehaviorProvider` — returns stable mid-range behavioral values for testing.
- `SessionFrame` and `SessionSummary` now carry an optional `behavior` field (`Map<String, dynamic>?`).
- `SynheartSession.mock()` accepts an optional `behaviorProvider` parameter — behavioral snapshot is fused into `SessionFrame` and `SessionSummary` events.
- In production mode, the native `SessionEngine` (Swift/Kotlin) now fuses behavioral data automatically when a `BehaviorProvider` is configured on the native side.
- New tests: `behavior_provider_test.dart` (12 tests).

## [0.1.1] - 2026-02-18

### Changed

- Updated documentation to reflect real biosignal streaming support in native SDKs.
- Native `SessionEngine` (Swift/Kotlin) now accepts a pluggable `BiosignalProvider` — when a BLE HRM is connected via synheart-wear, real HR data flows through the platform channel automatically. No Dart code changes required.



- Dart type definitions matching `session.proto` schema (`SessionConfig`, `SessionEvent`, `SessionStatus`).
- Platform channel bridge (`MethodChannel` + `EventChannel`) for native iOS/Android.
- Mock session engine for local development and testing (sinusoidal HR generation).
- `SynheartSession` main class with production and mock constructors.
- Native iOS plugin (Swift) — timer-driven mock HR engine.
- Native Android plugin (Kotlin) — handler-driven mock HR engine.
- HSI 1.0 JSON builder producing `hr_mean_bpm`, `hr_sdnn_ms`, `rmssd_ms`.


[0.1.0]: https://github.com/synheart-ai/synheart-session-dart/releases/tag/v0.1.0

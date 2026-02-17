# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2025-02-16

### Added

- Dart type definitions matching `session.proto` schema (`SessionConfig`, `SessionEvent`, `SessionStatus`).
- Platform channel bridge (`MethodChannel` + `EventChannel`) for native iOS/Android.
- Mock session engine for local development and testing (sinusoidal HR generation).
- `SynheartSession` main class with production and mock constructors.
- Native iOS plugin (Swift) — timer-driven mock HR engine.
- Native Android plugin (Kotlin) — handler-driven mock HR engine.
- HSI 1.0 JSON builder producing `hr_mean_bpm`, `hr_sdnn_ms`, `rmssd_ms`.

[0.1.0]: https://github.com/synheart-ai/synheart-session-dart/releases/tag/v0.1.0

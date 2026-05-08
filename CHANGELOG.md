# Changelog

All notable changes to this package will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.2.0] - 2026-05-06

Initial open-source release of the Synheart Session SDK for Flutter.

The SDK runs a live session engine that consumes a `BiosignalProvider`
(any HR/HRV source — `synheart_wear`, a BLE HRM, an Apple Watch relay,
or your own implementation) and an optional `BehaviorProvider`, then
emits typed session events: `SessionStarted`, `BiosignalFrame`,
`SessionFrame`, `SessionSummary`, `SessionError`.

### Public surface
- `SynheartSession` facade with `live` and `mock` constructors.
- `LiveSessionEngine` — Dart-side engine driving real HR data through
  a circular buffer with SDNN/RMSSD computed from real RR intervals.
- `BiosignalProvider` / `BehaviorProvider` abstractions for pluggable
  inputs. `MockBiosignalProvider` (sinusoidal BPM at 1 Hz) and
  `MockBehaviorProvider` ship for local development.
- `WatchBiosignalProvider` for relaying HR from a paired Apple Watch
  via `WCSession`.
- Configurable `ComputeProfile` (window size, emit interval).
- iOS plugin (`SynheartSessionPlugin.swift`) and Android plugin
  (`SynheartSessionPlugin.kt` + `WatchSessionRelay.kt`) implement
  the watch relay over `WCSession` and the Wearable Data Layer
  `MessageClient`.

### Platform support
- iOS 13.0+
- Android API 21+ (Android 5.0+)
- Flutter 3.22.0+

[Unreleased]: https://github.com/synheart-ai/synheart-session-flutter/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/synheart-ai/synheart-session-flutter/releases/tag/v0.2.0

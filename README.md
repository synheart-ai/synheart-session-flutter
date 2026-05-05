# Synheart Session

[![pub package](https://img.shields.io/pub/v/synheart_session.svg)](https://pub.dev/packages/synheart_session)
[![CI](https://github.com/synheart-ai/synheart-session-flutter/actions/workflows/ci.yml/badge.svg)](https://github.com/synheart-ai/synheart-session-flutter/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)

> **Source-available.** This repository is open for reading, auditing, and
> filing issues. We do **not** accept pull requests — see
> [CONTRIBUTING.md](CONTRIBUTING.md) for the rationale and how to contribute
> via issues. Security reports go through [SECURITY.md](SECURITY.md).

Dart / Flutter SDK for Synheart Session — stream-based session API with typed events for HR metrics and behavioral signals.

## Features

- Pluggable BiosignalProvider interface for any HR source (BLE HRM, HealthKit, mock)
- Optional BehaviorProvider interface for behavioral signal fusion (typing, scrolling, taps)
- Dart-side `LiveSessionEngine` with HRV metrics (SDNN, RMSSD, pNN50) from session-runtime; mean HR computed locally
- Watch relay — Apple Watch (WCSession) and Wear OS (Wearable Data Layer)
- Built-in mock engine for local development and testing (no wearable required)
- Type-safe session events: `SessionStarted`, `SessionFrame`, `SessionSummary`, `SessionError`
- Configurable compute profile (window size, emit interval)

## Installation

```yaml
dependencies:
  synheart_session: ^0.2.0
```

```bash
flutter pub add synheart_session
```

## Quick Start

### Live mode (real wearable data)

```dart
import 'package:synheart_session/synheart_session.dart';

// Wire in your own BiosignalProvider / BehaviorProvider adapters.
final session = SynheartSession(
  biosignalProvider: myBiosignalProvider,
  behaviorProvider: myBehaviorProvider,
);

// Or no args (watch relay on iOS/Android, timer-only otherwise):
// final session = SynheartSession();

final config = SessionConfig(
  mode: SessionMode.focus,
  durationSec: 300,
  profile: ComputeProfile(windowSec: 60, emitIntervalSec: 5),
);

final stream = session.startSession(config);
stream.listen((event) {
  switch (event) {
    case SessionStarted():
      print('Session started: ${event.sessionId}');
    case SessionFrame():
      print('HR: ${event.metrics['hr_mean_bpm']} bpm');
      print('RMSSD: ${event.metrics['rmssd_ms']} ms');
      if (event.behavior != null) {
        print('Stability: ${event.behavior!['stability_index']}');
      }
    case SessionSummary():
      print('Session complete: ${event.durationActualSec}s');
    case SessionError():
      print('Error: ${event.code} - ${event.message}');
    default:
      break;
  }
});

// Stop early (optional — auto-stops at durationSec)
await session.stopSession(config.sessionId);

// Clean up
session.dispose();
```

### Mock mode (development)

```dart
import 'package:synheart_session/synheart_session.dart';

// Mock engine, no wearable needed
final session = SynheartSession.mock(
  behaviorProvider: MockBehaviorProvider(),
);

final stream = session.startSession(config);
stream.listen((event) {
  switch (event) {
    case SessionFrame():
      print('HR: ${event.metrics['hr_mean_bpm']}');
      if (event.behavior != null) {
        print('Stability: ${event.behavior!['stability_index']}');
      }
    case SessionSummary():
      print('Session complete');
    default:
      break;
  }
});
```

## SDK Usage

### Error Handling

```dart
stream.listen(
  (event) {
    switch (event) {
      case SessionError():
        switch (event.code) {
          case SessionErrorCode.permissionDenied:
            print('HR permission not granted');
          case SessionErrorCode.sensorUnavailable:
            print('No HR sensor available');
          case SessionErrorCode.lowBattery:
            print('Device battery too low');
          case SessionErrorCode.osTerminated:
            print('Session killed by OS');
          case SessionErrorCode.invalidState:
            print('Invalid session state');
        }
      default:
        break;
    }
  },
);
```

### Mock Provider for Testing

```dart
// Use MockBehaviorProvider for deterministic behavioral data
final session = SynheartSession.mock(
  behaviorProvider: MockBehaviorProvider(),
);

// Mock engine generates sinusoidal HR data — no wearable needed
// Ideal for unit tests, integration tests, and UI development
```

## Architecture

```
SynheartSession (Dart)
├── .mock(seed, behaviorProvider)
│    └── MockSessionEngine (sinusoidal HR, optional behavior)
│
└── (default: biosignalProvider?, behaviorProvider?)
     ├── LiveSessionEngine [Dart]
     │    ├── BiosignalProvider.startStreaming() → _HrRingBuffer
     │    ├── BehaviorProvider.currentSnapshot() [sync at each tick]
     │    ├── _computeMetrics() [mean HR local + HRV from session-runtime]
     │    └── Timer.periodic → SessionFrame / SessionSummary
     │
     └── SessionChannel (watch relay — iOS + Android)
          ├── MethodChannel: ai.synheart.session/methods
          └── EventChannel: ai.synheart.session/events

iOS Native:
  SynheartSessionPlugin.swift → watch relay + getWatchStatus
  WatchSessionRelay.swift → WCSession bridge (Apple Watch)

Android Native:
  SynheartSessionPlugin.kt → watch relay + getWatchStatus
  WatchSessionRelay.kt → Wearable Data Layer bridge (Wear OS)
```

### Session Lifecycle

```
IDLE → startSession() → SessionStarted
                          → SessionFrame (every emitIntervalSec)
                          → SessionFrame ...
       stopSession() ──→ SessionSummary
                          → Stream closes
```

## API Reference

### `SynheartSession`

| Constructor | Description |
|-------------|-------------|
| `SynheartSession({biosignalProvider?, behaviorProvider?})` | Live mode — real data via provider abstractions |
| `SynheartSession.mock({seed?, behaviorProvider?})` | Mock mode — simulated data |

| Method | Description |
|--------|-------------|
| `startSession(config)` | Start a session, returns `Stream<SessionEvent>` |
| `stopSession(sessionId)` | Stop a running session |
| `getStatus()` | Query current session status |
| `getWatchStatus()` | Query watch connectivity (iOS + Android) |
| `dispose()` | Clean up resources |

### `SessionConfig`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `sessionId` | `String` | UUID v4 | Unique session identifier |
| `mode` | `SessionMode` | required | `.focus` or `.breathing` |
| `durationSec` | `int` | required | Maximum session duration |
| `profile` | `ComputeProfile` | 60s/5s | Window and emit configuration |
| `includeRawSamples` | `bool` | `false` | Emit `BiosignalFrame` events with raw samples |
| `windowLabel` | `String?` | null | Optional label for the session window |

### `SessionEvent` Types

| Type | Key Fields |
|------|------------|
| `SessionStarted` | `sessionId`, `startedAtMs` |
| `SessionFrame` | `sessionId`, `seq`, `emittedAtMs`, `metrics`, `behavior?` |
| `BiosignalFrame` | `sessionId`, `seq`, `emittedAtMs`, `samples` |
| `SessionSummary` | `sessionId`, `durationActualSec`, `metrics`, `behavior?` |
| `SessionError` | `sessionId`, `code`, `message` |

## Privacy & Security

- **Session-Based Only**: No passive or background HR tracking
- **On-Device Processing**: All metrics computation happens locally (Dart-side `LiveSessionEngine`)
- **No Raw HR Transmission**: Raw heart rate samples stay on device unless explicitly enabled via `includeRawSamples`
- **No Network Calls**: The SDK makes zero network calls — you control what gets persisted or transmitted
- **No Data Retention**: Raw biometric data is not retained after processing
- **Not a Medical Device**: This library is for wellness and research purposes only

## Standalone vs Core SDK

**With Synheart Core SDK:** HRV metrics (SDNN, RMSSD, pNN50) are automatically piped from the Synheart Runtime via `ingestHsiMetrics()`. No action needed — the core SDK wires this up during session lifecycle.

**Standalone (without core SDK):** Your app must call `engine.ingestHsiMetrics(sessionId, metrics)` with pre-computed HRV values. If not called, HRV metrics default to `0.0` — mean HR is still computed locally from the sample buffer.

```dart
// Standalone usage: manually provide HRV
engine.ingestHsiMetrics(sessionId, {
  'hrv.sdnn_ms': 42.5,
  'hrv.rmssd_ms': 38.1,
  'hrv.pnn50': 21.3,
});
```

## Platform Setup

### iOS

Requires iOS 13.0+. For BLE HR streaming, connect a heart rate monitor before starting a session.

### Android

Requires API 21+. All session compute runs in Dart. The native plugin bridges to a Wear OS companion watch app via the Wearable Data Layer (`MessageClient`). Requires Google Play Services on the phone.

## Testing

```bash
# Run tests
flutter test

# Analyze
dart analyze

# Format
dart format .

# Dry-run publish
dart pub publish --dry-run
```

## Watch Companion Apps

The Session SDK is designed to work with watch companion apps that unlock real-time biometric streaming. Due to HealthKit (iOS) and Health Services (Android) API limitations, real-time HR/HRV data requires an active workout or exercise session on the watch — the Session SDK handles this automatically.

- [synheart-wear-watch-ios](https://github.com/synheart-ai/synheart-wear-watch-ios) — watchOS companion (HKWorkoutSession, WCSession relay)
- [synheart-wear-watch-android](https://github.com/synheart-ai/synheart-wear-watch-android) — Wear OS companion (Health Services, MessageClient/DataClient relay)

When a session starts on the phone, the companion app starts a workout/exercise session on the watch, enabling continuous HR, HRV, and accelerometer streaming back to the phone SDK.

## Related Packages

| Package | Description |
|---------|-------------|
| `synheart_wear` | Unified wearable SDK — Apple Watch, Fitbit, Garmin, BLE HRM |
| `synheart_behavior` | Digital behavioral signals — typing, scrolling, taps, app switches |

## Links

- **Source of Truth**: [synheart-session](https://github.com/synheart-ai/synheart-session) — RFCs, protocol definitions, and cross-platform examples

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.

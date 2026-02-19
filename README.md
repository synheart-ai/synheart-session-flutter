# Synheart Session

[![pub package](https://img.shields.io/pub/v/synheart_session.svg)](https://pub.dev/packages/synheart_session)
[![CI](https://github.com/synheart-ai/synheart-session-dart/actions/workflows/ci.yml/badge.svg)](https://github.com/synheart-ai/synheart-session-dart/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)

Dart / Flutter SDK for Synheart Session — stream-based session API with typed events for HR metrics and behavioral signals.

## Features

- Stream real-time HR data from wearables (`synheart_wear`) or any BLE HRM (via `BleHrmProvider`)
- Fuse behavioral signals (`synheart_behavior`) alongside HR metrics in session frames
- Dart-side `LiveSessionEngine` with real SDNN/RMSSD computation from RR intervals
- Apple Watch relay via WCSession (iOS)
- Built-in mock engine for local development and testing (no wearable required)
- Type-safe session events: `SessionStarted`, `SessionFrame`, `SessionSummary`, `SessionError`
- Configurable compute profile (window size, emit interval)

## Installation

```yaml
dependencies:
  synheart_session: ^0.1.0
```

```bash
flutter pub add synheart_session
```

## Quick Start

### Live mode (real wearable data)

```dart
import 'package:synheart_session/synheart_session.dart';
import 'package:synheart_wear/synheart_wear.dart';
import 'package:synheart_behavior/synheart_behavior.dart';

// Initialize wear + behavior SDKs
final wear = SynheartWear(config: SynheartWearConfig.production());
await wear.initialize();
final behavior = await SynheartBehavior.initialize();

// Create session with real data sources
final session = SynheartSession(wear: wear, behavior: behavior);

// Or with BLE HRM directly:
// final session = SynheartSession(bleHrm: bleHrm, behavior: behavior);

// Or no args (watch relay on iOS, timer-only otherwise):
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

## Architecture

```
SynheartSession (Dart)
├── .mock(seed, behaviorProvider)
│    └── MockSessionEngine (sinusoidal HR, optional behavior)
│
└── (default: wear?, bleHrm?, behavior?)
     ├── LiveSessionEngine [Dart]
     │    ├── BleHrmProvider.onHeartRate → _HrRingBuffer
     │    │   OR SynheartWear.streamHR() → mapped → _HrRingBuffer
     │    ├── SynheartBehavior.getCurrentStats() [async at each tick]
     │    ├── _computeMetrics() [SDNN, RMSSD from real RR intervals]
     │    └── Timer.periodic → SessionFrame / SessionSummary
     │
     └── SessionChannel (iOS watch relay only)
          ├── MethodChannel: ai.synheart.session/methods
          └── EventChannel: ai.synheart.session/events

iOS Native (simplified):
  SynheartSessionPlugin.swift → watch relay + getWatchStatus only
  WatchSessionRelay.swift → WCSession bridge

Android Native (minimal stub):
  SynheartSessionPlugin.kt → plugin registration only
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
| `SynheartSession({wear?, bleHrm?, behavior?})` | Live mode — real data from wear/behavior SDKs |
| `SynheartSession.mock({seed?, behaviorProvider?})` | Mock mode — simulated data |

| Method | Description |
|--------|-------------|
| `startSession(config)` | Start a session, returns `Stream<SessionEvent>` |
| `stopSession(sessionId)` | Stop a running session |
| `getStatus()` | Query current session status |
| `getWatchStatus()` | Query Apple Watch connectivity (iOS only) |
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

## Platform Setup

### iOS

Requires iOS 13.0+. For BLE HR streaming, connect a heart rate monitor via `synheart_wear` before starting a session.

### Android

Requires API 21+. All session compute runs in Dart. The native plugin is a registration stub.

## Development

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

## Related Packages

| Package | Description |
|---------|-------------|
| `synheart_wear` | Unified wearable SDK — Apple Watch, Fitbit, Garmin, BLE HRM |
| `synheart_behavior` | Digital behavioral signals — typing, scrolling, taps, app switches |

## Links

- **Source of Truth**: [synheart-session](https://github.com/synheart-ai/synheart-session) — RFCs, protocol definitions, and cross-platform examples

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.

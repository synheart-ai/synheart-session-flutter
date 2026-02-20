# Synheart Session

[![pub package](https://img.shields.io/pub/v/synheart_session.svg)](https://pub.dev/packages/synheart_session)
[![CI](https://github.com/synheart-ai/synheart-session-dart/actions/workflows/ci.yml/badge.svg)](https://github.com/synheart-ai/synheart-session-dart/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)

Dart / Flutter SDK for Synheart Session — stream-based session API with typed events for HR metrics and behavioral signals.

## Features

- Stream real-time biosignal data from wearables or HR BLE HRMs via (`synheart_wear`) 
- Fuse behavioral signals (`synheart_behavior`) alongside Biosignal metrics in session frames
- Dart-side `LiveSessionEngine` with real SDNN/RMSSD computation from RR intervals
- Apple Watch relay via WCSession (iOS)
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

### Integration with synheart-wear

```dart
import 'package:synheart_wear/synheart_wear.dart';

// BLE HRM streaming
final bleHrm = BleHrmProvider();
final devices = await bleHrm.scan(timeoutMs: 10000);
await bleHrm.connect(deviceId: devices.first.deviceId);
final session = SynheartSession(bleHrm: bleHrm);

// Or via SynheartWear (Apple Watch relay, Health Connect, etc.)
final wear = SynheartWear(config: SynheartWearConfig.production());
await wear.initialize();
final session2 = SynheartSession(wear: wear);
```

### Integration with synheart-behavior

```dart
import 'package:synheart_behavior/synheart_behavior.dart';

final behavior = await SynheartBehavior.initialize();
final session = SynheartSession(wear: wear, behavior: behavior);

// session_frame events include a "behavior" key with:
// typing_cadence, scroll_velocity, tap_rate, app_switches_per_minute,
// idle_gap_seconds, stability_index, fragmentation_index, etc.
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

## Privacy & Security

- **Session-Based Only**: No passive or background HR tracking
- **On-Device Processing**: All metrics computation happens locally (Dart-side `LiveSessionEngine`)
- **No Raw HR Transmission**: Raw heart rate samples stay on device unless explicitly enabled via `includeRawSamples`
- **No Network Calls**: The SDK makes zero network calls — you control what gets persisted or transmitted
- **No Data Retention**: Raw biometric data is not retained after processing
- **Not a Medical Device**: This library is for wellness and research purposes only

## Platform Setup

### iOS

Requires iOS 13.0+. For BLE HR streaming, connect a heart rate monitor via `synheart_wear` before starting a session.

### Android

Requires API 21+. All session compute runs in Dart. The native plugin is a registration stub.

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

## Related Packages

| Package | Description |
|---------|-------------|
| `synheart_wear` | Unified wearable SDK — Apple Watch, Fitbit, Garmin, BLE HRM |
| `synheart_behavior` | Digital behavioral signals — typing, scrolling, taps, app switches |

## Links

- **Source of Truth**: [synheart-session](https://github.com/synheart-ai/synheart-session) — RFCs, protocol definitions, and cross-platform examples

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.

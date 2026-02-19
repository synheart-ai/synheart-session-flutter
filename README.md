# synheart_session

[![pub package](https://img.shields.io/pub/v/synheart_session.svg)](https://pub.dev/packages/synheart_session)
[![CI](https://github.com/synheart-ai/synheart-session-dart/actions/workflows/ci.yml/badge.svg)](https://github.com/synheart-ai/synheart-session-dart/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)

Flutter SDK for Synheart Session — real-time session capture with on-device HR metrics and behavioral signal fusion.

## Features

- Start and stop HR capture sessions on iOS (HealthKit) and Android (Health Services)
- Stream real-time session frames via `EventChannel`
- Optional behavioral signal fusion (typing, scrolling, taps, app switches, idle gaps) alongside HR metrics
- Built-in mock engine for local development and testing (no wearable required)
- Type-safe session events: `SessionStarted`, `SessionFrame`, `SessionSummary`, `SessionError`
- Pluggable `BehaviorProvider` with built-in `MockBehaviorProvider` for development
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

```dart
import 'package:synheart_session/synheart_session.dart';

// Production (uses native iOS/Android plugins)
final session = SynheartSession();

// Development (mock engine, no wearable needed)
final session = SynheartSession.mock();

// Start a session
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
    case HsiFrame():
      print('HSI frame #${event.seq}: ${event.hsiJson}');
    case SessionSummary():
      print('Session complete: ${event.durationActualSec}s');
    case SessionError():
      print('Error: ${event.code} - ${event.message}');
  }
});

// Stop early (optional — auto-stops at durationSec)
await session.stopSession(config.sessionId);

// Clean up
session.dispose();
```

### With behavioral signals (mock mode)

```dart
import 'package:synheart_session/synheart_session.dart';

// Use mock behavior provider for development
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
      if (event.behavior != null) {
        print('Final stability: ${event.behavior!['stability_index']}');
      }
    default:
      break;
  }
});
```

In production mode, behavioral data flows automatically from the native `SessionEngine` when a `BehaviorProvider` is configured on the native side — no Dart code changes needed.

## Architecture

```
Flutter App
  └── SynheartSession (Dart)
        ├── MockSessionEngine (development — sinusoidal HR, optional behavior)
        │     └── BehaviorProvider? (pull-based)
        │           ├── MockBehaviorProvider (stable mid-range values)
        │           └── custom BehaviorProvider
        └── SessionChannel (production)
              ├── MethodChannel: ai.synheart.session/methods
              └── EventChannel:  ai.synheart.session/events
                    ├── iOS: SynheartSessionPlugin (Swift)
                    │         └── SessionEngine(provider, behaviorProvider?)
                    └── Android: SynheartSessionPlugin (Kotlin)
                                  └── SessionEngine(provider, behaviorProvider?)
```

The native `SessionEngine` on both platforms accepts a pluggable `BiosignalProvider`. When the native plugin is initialized with a connected BLE HRM (via synheart-wear), real heart rate data flows through the platform channel automatically. No Dart code changes are needed — the same `SessionEvent` stream emits real data instead of mock data.

### Session Lifecycle

```
IDLE → startSession() → SessionStarted
                          → HsiFrame (every emitIntervalSec)
                          → HsiFrame ...
       stopSession() ──→ SessionSummary
                          → Stream closes
```

## API Reference

### `SynheartSession`

| Method | Description |
|--------|-------------|
| `startSession(config)` | Start a session, returns `Stream<SessionEvent>` |
| `stopSession(sessionId)` | Stop a running session |
| `getStatus()` | Query current session status |
| `dispose()` | Clean up resources |

### `SessionConfig`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `sessionId` | `String` | UUID v4 | Unique session identifier |
| `mode` | `SessionMode` | required | `.focus` or `.breathing` |
| `durationSec` | `int` | required | Maximum session duration |
| `profile` | `ComputeProfile` | 60s/5s | Window and emit configuration |
| `windowLabel` | `String?` | null | Optional label for the session window |

### `SessionEvent` Types

| Type | Key Fields |
|------|------------|
| `SessionStarted` | `sessionId`, `startedAtMs` |
| `SessionFrame` | `sessionId`, `seq`, `emittedAtMs`, `metrics`, `behavior?` |
| `SessionSummary` | `sessionId`, `durationActualSec`, `metrics`, `behavior?` |
| `SessionError` | `sessionId`, `code`, `message` |

### `BehaviorProvider`

| Method/Property | Description |
|----------------|-------------|
| `isAvailable` | Whether the provider is ready |
| `name` | Provider identifier (e.g. `"mock"`) |
| `currentSnapshot()` | Returns current `BehaviorSnapshot?` |

### `BehaviorSnapshot` Fields

| Field | Type | Description |
|-------|------|-------------|
| `typingCadence` | `double?` | Keys per second |
| `interKeyLatency` | `double?` | Milliseconds between keystrokes |
| `burstLength` | `int?` | Keys in current burst |
| `scrollVelocity` | `double?` | Pixels per second |
| `scrollAcceleration` | `double?` | Pixels per second squared |
| `scrollJitter` | `double?` | Variance in scroll speed |
| `tapRate` | `double?` | Taps per second |
| `appSwitchesPerMinute` | `int` | App switches per minute |
| `foregroundDuration` | `double?` | Seconds in foreground |
| `idleGapSeconds` | `double?` | Seconds since last interaction |
| `stabilityIndex` | `double?` | 0.0 to 1.0 |
| `fragmentationIndex` | `double?` | 0.0 to 1.0 |
| `timestamp` | `int` | Capture timestamp (ms since epoch) |

## Platform Setup

### iOS

Requires iOS 13.0+. No additional setup needed for mock mode. For real BLE HR streaming, connect a heart rate monitor via synheart-wear before starting a session. HealthKit workout session integration (future phase) will require:

```xml
<!-- ios/Runner/Info.plist -->
<key>NSHealthShareUsageDescription</key>
<string>This app reads heart rate data during sessions.</string>
```

### Android

Requires API 21+. No additional setup needed for mock mode. For real BLE HR streaming, connect a heart rate monitor via synheart-wear before starting a session. Health Services ExerciseClient integration (future phase) will require:

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<uses-permission android:name="android.permission.BODY_SENSORS" />
```

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

| Package | Platform | Description |
|---------|----------|-------------|
| [synheart-session-swift](https://github.com/synheart-ai/synheart-session-swift) | iOS/watchOS | Standalone Swift SDK |
| [synheart-session-kotlin](https://github.com/synheart-ai/synheart-session-kotlin) | Android/Wear OS | Standalone Kotlin SDK |

## Links

- **Source of Truth**: [synheart-session](https://github.com/synheart-ai/synheart-session) — RFCs, protocol definitions, and cross-platform examples

## License

Apache 2.0 — see [LICENSE](LICENSE) for details.

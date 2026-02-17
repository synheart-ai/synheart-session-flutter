# synheart_session

[![pub package](https://img.shields.io/pub/v/synheart_session.svg)](https://pub.dev/packages/synheart_session)
[![CI](https://github.com/synheart-ai/synheart-session-dart/actions/workflows/ci.yml/badge.svg)](https://github.com/synheart-ai/synheart-session-dart/actions/workflows/ci.yml)
[![License: Apache-2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://www.apache.org/licenses/LICENSE-2.0)

Flutter SDK for Synheart Session — real-time wearable HR capture with on-device HSI computation.

## Features

- Start and stop HR capture sessions on iOS (HealthKit) and Android (Health Services)
- Stream real-time HSI 1.0 frames via `EventChannel`
- Built-in mock engine for local development and testing (no wearable required)
- Type-safe session events: `SessionStarted`, `HsiFrame`, `SessionSummary`, `SessionError`
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

## Architecture

```
Flutter App
  └── SynheartSession (Dart)
        ├── MockSessionEngine (development)
        └── SessionChannel (production)
              ├── MethodChannel: ai.synheart.session/methods
              └── EventChannel:  ai.synheart.session/events
                    ├── iOS: SynheartSessionPlugin (Swift)
                    └── Android: SynheartSessionPlugin (Kotlin)
```

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
| `HsiFrame` | `sessionId`, `seq`, `emittedAtMs`, `hsiJson` |
| `SessionSummary` | `sessionId`, `durationActualSec`, `hsiJson` |
| `SessionError` | `sessionId`, `code`, `message` |

## Platform Setup

### iOS

Requires iOS 13.0+. No additional setup needed for mock mode. HealthKit integration (future phase) will require:

```xml
<!-- ios/Runner/Info.plist -->
<key>NSHealthShareUsageDescription</key>
<string>This app reads heart rate data during sessions.</string>
```

### Android

Requires API 21+. No additional setup needed for mock mode. Health Services integration (future phase) will require:

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

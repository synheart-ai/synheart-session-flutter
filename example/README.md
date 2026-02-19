# synheart_session example

Demonstrates usage of the `synheart_session` Flutter plugin.

This app shows how to:
- Start and stop a wearable HR capture session
- Receive real-time heart-rate and HSI data via streams
- Display session state transitions in the UI
- Fuse behavioral signals (typing, scrolling, taps, app switches) alongside HR metrics

## Behavioral signals (mock mode)

```dart
import 'package:synheart_session/synheart_session.dart';

final session = SynheartSession.mock(
  behaviorProvider: MockBehaviorProvider(),
);

final stream = session.startSession(config);
stream.listen((event) {
  if (event is SessionFrame && event.behavior != null) {
    print('Stability: ${event.behavior!['stability_index']}');
  }
});
```

In production mode, behavioral data flows automatically from the native `SessionEngine` when a `BehaviorProvider` is configured on the native side.

See `lib/main.dart` for the full source.

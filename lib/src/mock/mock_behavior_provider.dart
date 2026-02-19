import 'package:synheart_session/src/types/behavior_provider.dart';

/// Mock behavior provider that returns stable mid-range values for testing.
/// Parallels `MockBiosignalProvider` for behavioral signals.
class MockBehaviorProvider implements BehaviorProvider {
  @override
  bool get isAvailable => true;

  @override
  String get name => 'mock';

  @override
  BehaviorSnapshot currentSnapshot() {
    return BehaviorSnapshot(
      typingCadence: 3.5,
      interKeyLatency: 120.0,
      burstLength: 8,
      scrollVelocity: 120.5,
      scrollAcceleration: 15.2,
      scrollJitter: 3.1,
      tapRate: 2.3,
      appSwitchesPerMinute: 4,
      foregroundDuration: 45.0,
      idleGapSeconds: 2.1,
      stabilityIndex: 0.82,
      fragmentationIndex: 0.15,
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

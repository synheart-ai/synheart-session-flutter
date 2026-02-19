import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_session/synheart_session.dart';

/// A test behavior provider that lets us control availability and snapshot.
class TestBehaviorProvider implements BehaviorProvider {
  TestBehaviorProvider({this.isAvailable = true, this.snapshot});

  @override
  bool isAvailable;

  @override
  String get name => 'test';

  BehaviorSnapshot? snapshot;

  @override
  BehaviorSnapshot? currentSnapshot() => snapshot;
}

void main() {
  group('MockBehaviorProvider', () {
    test('returns snapshot with all fields populated', () {
      final provider = MockBehaviorProvider();
      final snapshot = provider.currentSnapshot();

      expect(snapshot, isNotNull);
      expect(snapshot!.typingCadence, 3.5);
      expect(snapshot.interKeyLatency, 120.0);
      expect(snapshot.burstLength, 8);
      expect(snapshot.scrollVelocity, 120.5);
      expect(snapshot.scrollAcceleration, 15.2);
      expect(snapshot.scrollJitter, 3.1);
      expect(snapshot.tapRate, 2.3);
      expect(snapshot.appSwitchesPerMinute, 4);
      expect(snapshot.foregroundDuration, 45.0);
      expect(snapshot.idleGapSeconds, 2.1);
      expect(snapshot.stabilityIndex, 0.82);
      expect(snapshot.fragmentationIndex, 0.15);
      expect(snapshot.timestamp, greaterThan(0));
    });

    test('isAvailable returns true, name is mock', () {
      final provider = MockBehaviorProvider();
      expect(provider.isAvailable, isTrue);
      expect(provider.name, 'mock');
    });
  });

  group('BehaviorSnapshot', () {
    test('toJson produces snake_case keys', () {
      const snapshot = BehaviorSnapshot(
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
        timestamp: 1708300000000,
      );

      final json = snapshot.toJson();
      expect(json['typing_cadence'], 3.5);
      expect(json['inter_key_latency'], 120.0);
      expect(json['burst_length'], 8);
      expect(json['scroll_velocity'], 120.5);
      expect(json['scroll_acceleration'], 15.2);
      expect(json['scroll_jitter'], 3.1);
      expect(json['tap_rate'], 2.3);
      expect(json['app_switches_per_minute'], 4);
      expect(json['foreground_duration'], 45.0);
      expect(json['idle_gap_seconds'], 2.1);
      expect(json['stability_index'], 0.82);
      expect(json['fragmentation_index'], 0.15);
      expect(json['timestamp'], 1708300000000);
    });

    test('toJson omits null fields', () {
      const snapshot = BehaviorSnapshot(
        appSwitchesPerMinute: 2,
        stabilityIndex: 0.5,
        timestamp: 1000,
      );

      final json = snapshot.toJson();
      expect(json.containsKey('typing_cadence'), isFalse);
      expect(json.containsKey('scroll_velocity'), isFalse);
      expect(json['app_switches_per_minute'], 2);
      expect(json['stability_index'], 0.5);
      expect(json['timestamp'], 1000);
    });

    test('fromJson roundtrip', () {
      const original = BehaviorSnapshot(
        scrollVelocity: 100.0,
        stabilityIndex: 0.9,
        appSwitchesPerMinute: 3,
        timestamp: 5000,
      );

      final json = original.toJson();
      // Add required fields that toJson omits when null
      json['typing_cadence'] = null;
      final decoded = BehaviorSnapshot.fromJson(json);
      expect(decoded.scrollVelocity, 100.0);
      expect(decoded.stabilityIndex, 0.9);
      expect(decoded.appSwitchesPerMinute, 3);
      expect(decoded.timestamp, 5000);
    });
  });

  group('SessionFrame with behavior', () {
    test('fromJson parses behavior key', () {
      final event = SessionEvent.fromJson({
        'type': 'session_frame',
        'session_id': 'abc',
        'seq': 1,
        'emitted_at_ms': 2000,
        'encoding': 'json_utf8',
        'metrics': <String, dynamic>{'hr_mean_bpm': 72.0},
        'behavior': <String, dynamic>{
          'stability_index': 0.82,
          'timestamp': 1708300000000,
        },
      });

      expect(event, isA<SessionFrame>());
      final frame = event as SessionFrame;
      expect(frame.behavior, isNotNull);
      expect(frame.behavior!['stability_index'], 0.82);
    });

    test('fromJson handles missing behavior key', () {
      final event = SessionEvent.fromJson({
        'type': 'session_frame',
        'session_id': 'abc',
        'seq': 1,
        'emitted_at_ms': 2000,
        'encoding': 'json_utf8',
        'metrics': <String, dynamic>{'hr_mean_bpm': 72.0},
      });

      expect(event, isA<SessionFrame>());
      final frame = event as SessionFrame;
      expect(frame.behavior, isNull);
    });

    test('toJson includes behavior when present', () {
      const frame = SessionFrame(
        sessionId: 'x',
        seq: 1,
        emittedAtMs: 1000,
        metrics: {'hr_mean_bpm': 72.0},
        behavior: {'stability_index': 0.82},
      );

      final json = frame.toJson();
      expect(json.containsKey('behavior'), isTrue);
      expect((json['behavior'] as Map)['stability_index'], 0.82);
    });

    test('toJson omits behavior when null', () {
      const frame = SessionFrame(
        sessionId: 'x',
        seq: 1,
        emittedAtMs: 1000,
        metrics: {'hr_mean_bpm': 72.0},
      );

      final json = frame.toJson();
      expect(json.containsKey('behavior'), isFalse);
    });
  });

  group('SessionSummary with behavior', () {
    test('fromJson parses behavior key', () {
      final event = SessionEvent.fromJson({
        'type': 'session_summary',
        'session_id': 'abc',
        'duration_actual_sec': 300,
        'encoding': 'json_utf8',
        'metrics': <String, dynamic>{'hr_mean_bpm': 72.0},
        'behavior': <String, dynamic>{
          'stability_index': 0.82,
          'timestamp': 1708300000000,
        },
      });

      expect(event, isA<SessionSummary>());
      final summary = event as SessionSummary;
      expect(summary.behavior, isNotNull);
      expect(summary.behavior!['stability_index'], 0.82);
    });

    test('toJson omits behavior when null', () {
      const summary = SessionSummary(
        sessionId: 'x',
        durationActualSec: 100,
        metrics: {'hr_mean_bpm': 72.0},
      );

      final json = summary.toJson();
      expect(json.containsKey('behavior'), isFalse);
    });
  });

  group('MockSessionEngine with BehaviorProvider', () {
    test('frames include behavior when provider is configured', () async {
      final behaviorProvider = TestBehaviorProvider(
        snapshot: const BehaviorSnapshot(
          stabilityIndex: 0.82,
          fragmentationIndex: 0.15,
          appSwitchesPerMinute: 4,
          timestamp: 1708300000000,
        ),
      );

      final session = SynheartSession.mock(
        seed: 42,
        behaviorProvider: behaviorProvider,
      );

      final config = SessionConfig(
        sessionId: 'behavior-test',
        mode: SessionMode.focus,
        durationSec: 2,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final events = await session.startSession(config).toList();

      final frames = events.whereType<SessionFrame>().toList();
      expect(frames, isNotEmpty);
      expect(frames.first.behavior, isNotNull);
      expect(frames.first.behavior!['stability_index'], 0.82);

      final summaries = events.whereType<SessionSummary>().toList();
      expect(summaries, hasLength(1));
      expect(summaries.first.behavior, isNotNull);

      session.dispose();
    });

    test('frames omit behavior when no provider', () async {
      final session = SynheartSession.mock(seed: 42);

      final config = SessionConfig(
        sessionId: 'no-behavior-test',
        mode: SessionMode.focus,
        durationSec: 2,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final events = await session.startSession(config).toList();

      final frames = events.whereType<SessionFrame>().toList();
      expect(frames, isNotEmpty);
      expect(frames.first.behavior, isNull);

      session.dispose();
    });

    test('frames omit behavior when provider unavailable', () async {
      final behaviorProvider = TestBehaviorProvider(
        isAvailable: false,
        snapshot: const BehaviorSnapshot(
          stabilityIndex: 0.82,
          timestamp: 1708300000000,
        ),
      );

      final session = SynheartSession.mock(
        seed: 42,
        behaviorProvider: behaviorProvider,
      );

      final config = SessionConfig(
        sessionId: 'unavail-test',
        mode: SessionMode.focus,
        durationSec: 2,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final events = await session.startSession(config).toList();

      final frames = events.whereType<SessionFrame>().toList();
      expect(frames, isNotEmpty);
      expect(frames.first.behavior, isNull);

      session.dispose();
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_session/src/mock/mock_hr_generator.dart';
import 'package:synheart_session/src/mock/mock_session_engine.dart';
import 'package:synheart_session/synheart_session.dart';

void main() {
  group('MockHrGenerator', () {
    test('generates BPM in 40-200 range', () {
      final gen = MockHrGenerator(seed: 42);
      final samples = gen.generate(startMs: 0, count: 100);
      expect(samples, hasLength(100));
      for (final s in samples) {
        expect(s.bpm, greaterThanOrEqualTo(40.0));
        expect(s.bpm, lessThanOrEqualTo(200.0));
      }
    });

    test('seeded generator is deterministic', () {
      final gen1 = MockHrGenerator(seed: 42);
      final gen2 = MockHrGenerator(seed: 42);
      final s1 = gen1.generate(startMs: 0, count: 50);
      final s2 = gen2.generate(startMs: 0, count: 50);
      for (var i = 0; i < 50; i++) {
        expect(s1[i].bpm, s2[i].bpm);
        expect(s1[i].timestampMs, s2[i].timestampMs);
      }
    });

    test('timestamps are correctly spaced', () {
      final gen = MockHrGenerator(seed: 1);
      final samples = gen.generate(startMs: 1000, count: 5, intervalMs: 500);
      expect(samples[0].timestampMs, 1000);
      expect(samples[1].timestampMs, 1500);
      expect(samples[2].timestampMs, 2000);
      expect(samples[3].timestampMs, 2500);
      expect(samples[4].timestampMs, 3000);
    });
  });

  group('MockSessionEngine', () {
    late MockSessionEngine engine;

    setUp(() {
      engine = MockSessionEngine(seed: 42);
    });

    tearDown(() {
      engine.dispose();
    });

    test('emits SessionStarted then session frames then SessionSummary', () async {
      final config = SessionConfig(
        sessionId: 'test-1',
        mode: SessionMode.focus,
        durationSec: 2,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final events = await engine.startSession(config).toList();

      expect(events.first, isA<SessionStarted>());
      expect(events.last, isA<SessionSummary>());

      final frames = events.whereType<SessionFrame>().toList();
      expect(frames, isNotEmpty);
    });

    test('SessionFrame has required session metrics keys', () async {
      final config = SessionConfig(
        sessionId: 'test-metrics',
        mode: SessionMode.breathing,
        durationSec: 2,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final events = await engine.startSession(config).toList();
      final frame = events.whereType<SessionFrame>().first;
      final m = frame.metrics;

      expect(m['hr_mean_bpm'], isA<double>());
      expect(m['hr_sdnn_ms'], isA<double>());
      expect(m['rmssd_ms'], isA<double>());
    });

    test('stop triggers early summary', () async {
      final config = SessionConfig(
        sessionId: 'test-stop',
        mode: SessionMode.focus,
        durationSec: 60,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final stream = engine.startSession(config);
      final events = <SessionEvent>[];

      await for (final event in stream) {
        events.add(event);
        if (event is SessionFrame) {
          // Stop after first frame
          await engine.stopSession('test-stop');
        }
      }

      expect(events.first, isA<SessionStarted>());
      expect(events.last, isA<SessionSummary>());
    });

    test('getStatus returns status while running', () async {
      final config = SessionConfig(
        sessionId: 'test-status',
        mode: SessionMode.focus,
        durationSec: 60,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final stream = engine.startSession(config);
      // Listen to keep stream alive
      final sub = stream.listen((_) {});

      // Give it a moment to start
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final status = engine.getStatus('test-status');
      expect(status, isNotNull);
      expect(status!.sessionId, 'test-status');
      expect(status.active, isTrue);

      await engine.stopSession('test-status');
      await sub.cancel();

      final statusAfter = engine.getStatus('test-status');
      expect(statusAfter, isNull);
    });

    test('duplicate session ID throws', () {
      final config = SessionConfig(
        sessionId: 'dup',
        mode: SessionMode.focus,
        durationSec: 60,
      );

      engine.startSession(config);

      expect(() => engine.startSession(config), throwsStateError);
    });
  });
}

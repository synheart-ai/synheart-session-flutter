import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_session/synheart_session.dart';

void main() {
  group('LiveSessionEngine', () {
    late LiveSessionEngine engine;

    setUp(() {
      engine = LiveSessionEngine();
    });

    tearDown(() {
      engine.dispose();
    });

    test(
      'emits SessionStarted then SessionSummary with no HR source',
      () async {
        final config = SessionConfig(
          sessionId: 'live-1',
          mode: SessionMode.focus,
          durationSec: 2,
          profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
        );

        final events = await engine.startSession(config).toList();

        expect(events.first, isA<SessionStarted>());
        expect(events.last, isA<SessionSummary>());
      },
    );

    test('emits SessionFrame with zeroed metrics when no HR source', () async {
      final config = SessionConfig(
        sessionId: 'live-zeroed',
        mode: SessionMode.focus,
        durationSec: 2,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final events = await engine.startSession(config).toList();
      final frames = events.whereType<SessionFrame>().toList();

      // Should have at least one frame before duration expires
      expect(frames, isNotEmpty);

      // With no HR source, metrics should be zeroed
      final m = frames.first.metrics;
      expect(m['hr_mean_bpm'], 0.0);
      expect(m['hr_sdnn_ms'], 0.0);
      expect(m['rmssd_ms'], 0.0);
      expect(m['sample_count'], 0);
    });

    test('behavior is null when no behavior SDK provided', () async {
      final config = SessionConfig(
        sessionId: 'live-no-behavior',
        mode: SessionMode.focus,
        durationSec: 2,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final events = await engine.startSession(config).toList();
      final frames = events.whereType<SessionFrame>().toList();
      expect(frames, isNotEmpty);
      expect(frames.first.behavior, isNull);

      final summary = events.whereType<SessionSummary>().first;
      expect(summary.behavior, isNull);
    });

    test('stopSession triggers early summary', () async {
      final config = SessionConfig(
        sessionId: 'live-stop',
        mode: SessionMode.focus,
        durationSec: 60,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final stream = engine.startSession(config);
      final events = <SessionEvent>[];

      await for (final event in stream) {
        events.add(event);
        if (event is SessionFrame) {
          await engine.stopSession('live-stop');
        }
      }

      expect(events.first, isA<SessionStarted>());
      expect(events.last, isA<SessionSummary>());
    });

    test('getStatus returns status while running', () async {
      final config = SessionConfig(
        sessionId: 'live-status',
        mode: SessionMode.focus,
        durationSec: 60,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final stream = engine.startSession(config);
      final sub = stream.listen((_) {});

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final status = engine.getStatus('live-status');
      expect(status, isNotNull);
      expect(status!.sessionId, 'live-status');
      expect(status.active, isTrue);

      await engine.stopSession('live-status');
      // Allow the async finish to complete
      await Future<void>.delayed(const Duration(milliseconds: 100));
      await sub.cancel();

      final statusAfter = engine.getStatus('live-status');
      expect(statusAfter, isNull);
    });

    test('duplicate session ID throws', () {
      final config = SessionConfig(
        sessionId: 'live-dup',
        mode: SessionMode.focus,
        durationSec: 60,
      );

      engine.startSession(config);

      expect(() => engine.startSession(config), throwsStateError);
    });

    test('SessionSummary contains durationActualSec', () async {
      final config = SessionConfig(
        sessionId: 'live-duration',
        mode: SessionMode.breathing,
        durationSec: 2,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final events = await engine.startSession(config).toList();
      final summary = events.whereType<SessionSummary>().first;

      expect(summary.durationActualSec, greaterThanOrEqualTo(1));
      expect(summary.sessionId, 'live-duration');
    });

    test('ingestHsiMetrics populates HRV in emitted frame metrics', () async {
      final config = SessionConfig(
        sessionId: 'live-hsi',
        mode: SessionMode.focus,
        durationSec: 3,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final stream = engine.startSession(config);
      final events = <SessionEvent>[];

      // Ingest HRV metrics before frames are emitted
      engine.ingestHsiMetrics('live-hsi', {
        'hrv.sdnn_ms': 42.5,
        'hrv.rmssd_ms': 38.1,
        'hrv.pnn50': 21.3,
      });

      await for (final event in stream) {
        events.add(event);
        if (event is SessionFrame) {
          expect(event.metrics['hr_sdnn_ms'], 42.5);
          expect(event.metrics['rmssd_ms'], 38.1);
          expect(event.metrics['pnn50'], 21.3);
          await engine.stopSession('live-hsi');
        }
      }

      expect(events.whereType<SessionFrame>(), isNotEmpty);
    });

    test('ingestHsiMetrics for unknown session is a no-op', () {
      // Should not throw
      engine.ingestHsiMetrics('nonexistent-session', {
        'hrv.sdnn_ms': 50.0,
      });
    });
  });
}

import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_session/synheart_session.dart';

void main() {
  group('SynheartSession.mock()', () {
    late SynheartSession session;

    setUp(() {
      session = SynheartSession.mock(seed: 42);
    });

    tearDown(() {
      session.dispose();
    });

    test('full lifecycle: start -> frames -> stop -> summary', () async {
      final config = SessionConfig(
        sessionId: 'lifecycle-1',
        mode: SessionMode.focus,
        durationSec: 2,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final events = await session.startSession(config).toList();

      expect(events.first, isA<SessionStarted>());
      expect(events.last, isA<SessionSummary>());
      expect((events.first as SessionStarted).sessionId, 'lifecycle-1');

      final frames = events.whereType<HsiFrame>().toList();
      expect(frames, isNotEmpty);
    });

    test('stopSession triggers early SessionSummary', () async {
      final config = SessionConfig(
        sessionId: 'stop-test',
        mode: SessionMode.breathing,
        durationSec: 60,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final stream = session.startSession(config);
      final events = <SessionEvent>[];

      await for (final event in stream) {
        events.add(event);
        if (event is HsiFrame) {
          await session.stopSession('stop-test');
        }
      }

      expect(events.first, isA<SessionStarted>());
      expect(events.last, isA<SessionSummary>());
    });

    test('getStatus returns status while running, null after stop', () async {
      final config = SessionConfig(
        sessionId: 'status-test',
        mode: SessionMode.focus,
        durationSec: 60,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final stream = session.startSession(config);
      final sub = stream.listen((_) {});

      await Future<void>.delayed(const Duration(milliseconds: 50));

      final status = await session.getStatus();
      expect(status, isNotNull);
      expect(status!.sessionId, 'status-test');
      expect(status.active, isTrue);

      await session.stopSession('status-test');
      await sub.cancel();

      // Small delay for cleanup
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final statusAfter = await session.getStatus();
      expect(statusAfter, isNull);
    });

    test('duplicate session ID throws SessionInvalidStateError', () {
      final config = SessionConfig(
        sessionId: 'dup-test',
        mode: SessionMode.focus,
        durationSec: 60,
      );

      session.startSession(config);

      expect(
        () => session.startSession(config),
        throwsA(isA<SessionInvalidStateError>()),
      );
    });

    test('dispose closes streams, subsequent calls throw', () async {
      final config = SessionConfig(
        sessionId: 'dispose-test',
        mode: SessionMode.focus,
        durationSec: 60,
      );

      session
        ..startSession(config)
        ..dispose();

      expect(
        () => session.startSession(
          SessionConfig(
            sessionId: 'after-dispose',
            mode: SessionMode.focus,
            durationSec: 60,
          ),
        ),
        throwsA(isA<SessionInvalidStateError>()),
      );

      expect(
        () async => session.stopSession('dispose-test'),
        throwsA(isA<SessionInvalidStateError>()),
      );

      expect(
        () async => session.getStatus(),
        throwsA(isA<SessionInvalidStateError>()),
      );
    });

    test('frame seq increments monotonically', () async {
      final config = SessionConfig(
        sessionId: 'seq-test',
        mode: SessionMode.focus,
        durationSec: 3,
        profile: const ComputeProfile(windowSec: 10, emitIntervalSec: 1),
      );

      final events = await session.startSession(config).toList();
      final frames = events.whereType<HsiFrame>().toList();

      expect(frames, isNotEmpty);
      for (var i = 1; i < frames.length; i++) {
        expect(frames[i].seq, greaterThan(frames[i - 1].seq));
      }

      // First frame seq should be 1
      if (frames.isNotEmpty) {
        expect(frames.first.seq, 1);
      }
    });
  });
}

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_session/synheart_session.dart';

/// Fake channel that exposes a controller for injecting events.
class FakeSessionChannel extends SessionChannel {
  FakeSessionChannel()
    : _controller = StreamController<SessionEvent>.broadcast();

  final StreamController<SessionEvent> _controller;

  @override
  Stream<SessionEvent> get events => _controller.stream;

  void emitEvent(SessionEvent event) => _controller.add(event);
  void emitError(Object error) => _controller.addError(error);
  void closeChannel() => _controller.close();
}

void main() {
  group('WatchBiosignalProvider', () {
    late FakeSessionChannel fakeChannel;
    late WatchBiosignalProvider provider;

    setUp(() {
      fakeChannel = FakeSessionChannel();
      provider = WatchBiosignalProvider(channel: fakeChannel);
    });

    tearDown(() {
      provider.stopStreaming();
      fakeChannel.closeChannel();
    });

    test('isAvailable returns true', () {
      expect(provider.isAvailable, isTrue);
    });

    test('name is "watch"', () {
      expect(provider.name, 'watch');
    });

    test('channel getter exposes underlying SessionChannel', () {
      expect(provider.channel, same(fakeChannel));
    });

    test('emits samples from BiosignalFrame events', () async {
      final stream = provider.startStreaming();
      final collected = <BiosignalSample>[];
      final sub = stream.listen(collected.add);

      const sample1 = BiosignalSample(
        timestampMs: 1000,
        bpm: 72,
        rrIntervalMs: 833.3,
      );
      const sample2 = BiosignalSample(
        timestampMs: 2000,
        bpm: 75,
        rrIntervalMs: 800,
      );

      fakeChannel.emitEvent(
        const BiosignalFrame(
          sessionId: 'test-1',
          seq: 1,
          emittedAtMs: 1000,
          samples: [sample1, sample2],
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(collected, hasLength(2));
      expect(collected[0].bpm, 72.0);
      expect(collected[0].timestampMs, 1000);
      expect(collected[1].bpm, 75.0);
      expect(collected[1].timestampMs, 2000);

      await sub.cancel();
    });

    test('synthesizes samples from SessionFrame metrics', () async {
      final stream = provider.startStreaming();
      final collected = <BiosignalSample>[];
      final sub = stream.listen(collected.add);

      fakeChannel.emitEvent(
        const SessionFrame(
          sessionId: 'test-1',
          seq: 1,
          emittedAtMs: 5000,
          metrics: {'hr_mean_bpm': 80.0},
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(collected, hasLength(1));
      expect(collected[0].bpm, 80.0);
      expect(collected[0].timestampMs, 5000);
      expect(collected[0].rrIntervalMs, 750.0);

      await sub.cancel();
    });

    test('ignores SessionFrame with zero bpm', () async {
      final stream = provider.startStreaming();
      final collected = <BiosignalSample>[];
      final sub = stream.listen(collected.add);

      fakeChannel.emitEvent(
        const SessionFrame(
          sessionId: 'test-1',
          seq: 1,
          emittedAtMs: 5000,
          metrics: {'hr_mean_bpm': 0.0},
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(collected, isEmpty);

      await sub.cancel();
    });

    test('ignores non-data events', () async {
      final stream = provider.startStreaming();
      final collected = <BiosignalSample>[];
      final sub = stream.listen(collected.add);

      fakeChannel
        ..emitEvent(
          const SessionStarted(sessionId: 'test-1', startedAtMs: 1000),
        )
        ..emitEvent(
          const SessionSummary(
            sessionId: 'test-1',
            durationActualSec: 60,
            metrics: {'hr_mean_bpm': 72.0},
          ),
        )
        ..emitEvent(
          const SessionError(
            sessionId: 'test-1',
            code: SessionErrorCode.invalidState,
            message: 'test error',
          ),
        );

      await Future<void>.delayed(Duration.zero);

      expect(collected, isEmpty);

      await sub.cancel();
    });

    test('stopStreaming cancels subscription', () async {
      final stream = provider.startStreaming();
      final collected = <BiosignalSample>[];
      final sub = stream.listen(collected.add);

      fakeChannel.emitEvent(
        const BiosignalFrame(
          sessionId: 'test-1',
          seq: 1,
          emittedAtMs: 1000,
          samples: [BiosignalSample(timestampMs: 1000, bpm: 72)],
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(collected, hasLength(1));

      provider.stopStreaming();

      fakeChannel.emitEvent(
        const BiosignalFrame(
          sessionId: 'test-1',
          seq: 2,
          emittedAtMs: 2000,
          samples: [BiosignalSample(timestampMs: 2000, bpm: 80)],
        ),
      );

      await Future<void>.delayed(Duration.zero);
      expect(collected, hasLength(1));

      await sub.cancel();
    });
  });
}

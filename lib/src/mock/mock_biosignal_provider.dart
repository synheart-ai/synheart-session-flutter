import 'dart:async';

import 'package:synheart_session/src/mock/mock_hr_generator.dart';
import 'package:synheart_session/src/types/biosignal_provider.dart';
import 'package:synheart_session/src/types/biosignal_sample.dart';

/// Mock biosignal provider that produces sinusoidal BPM at 1 Hz.
/// Wraps [MockHrGenerator] behind the [BiosignalProvider] interface.
class MockBiosignalProvider implements BiosignalProvider {
  MockBiosignalProvider({int? seed}) : _generator = MockHrGenerator(seed: seed);

  final MockHrGenerator _generator;
  Timer? _timer;
  StreamController<BiosignalSample>? _controller;

  @override
  bool get isAvailable => true;

  @override
  String get name => 'mock';

  @override
  Stream<BiosignalSample> startStreaming() {
    _controller = StreamController<BiosignalSample>.broadcast(
      onCancel: stopStreaming,
    );

    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now().millisecondsSinceEpoch;
      final samples = _generator.generate(startMs: now, count: 1);
      if (samples.isNotEmpty) {
        final s = samples.first;
        _controller?.add(
          BiosignalSample(
            timestampMs: s.timestampMs,
            bpm: s.bpm,
            rrIntervalMs: 60000.0 / s.bpm,
          ),
        );
      }
    });

    return _controller!.stream;
  }

  @override
  void stopStreaming() {
    _timer?.cancel();
    _timer = null;
    _controller?.close();
    _controller = null;
  }
}

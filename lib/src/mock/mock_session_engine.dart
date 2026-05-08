import 'dart:async';
import 'dart:math';

import 'package:synheart_session/src/mock/mock_hr_generator.dart';
import 'package:synheart_session/src/types/behavior_provider.dart';
import 'package:synheart_session/src/types/biosignal_sample.dart';
import 'package:synheart_session/src/types/session_config.dart';
import 'package:synheart_session/src/types/session_event.dart';
import 'package:synheart_session/src/types/session_status.dart';

class MockSessionEngine {
  MockSessionEngine({int? seed, this.behaviorProvider})
    : _hrGenerator = MockHrGenerator(seed: seed);

  final MockHrGenerator _hrGenerator;
  final BehaviorProvider? behaviorProvider;
  final Map<String, _RunningSession> _sessions = {};

  Stream<SessionEvent> startSession(SessionConfig config) {
    if (_sessions.containsKey(config.sessionId)) {
      throw StateError('Session ${config.sessionId} is already running');
    }

    final controller = StreamController<SessionEvent>();
    final session = _RunningSession(
      config: config,
      controller: controller,
      startedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    _sessions[config.sessionId] = session;

    // Emit SessionStarted immediately
    controller.add(
      SessionStarted(
        sessionId: config.sessionId,
        startedAtMs: session.startedAtMs,
      ),
    );

    // Schedule SessionFrame emissions
    final intervalDuration = Duration(seconds: config.profile.emitIntervalSec);
    session
      ..timer = Timer.periodic(intervalDuration, (_) {
        if (controller.isClosed) return;

        session.seq++;
        final now = DateTime.now().millisecondsSinceEpoch;
        final elapsed = (now - session.startedAtMs) ~/ 1000;

        // Check if duration exceeded
        if (elapsed >= config.durationSec) {
          _finishSession(config.sessionId);
          return;
        }

        controller.add(
          SessionFrame(
            sessionId: config.sessionId,
            seq: session.seq,
            emittedAtMs: now,
            metrics: _buildMockMetrics(config, session),
            behavior: _pullBehavior(),
          ),
        );
      })
      ..durationTimer = Timer(
        Duration(seconds: config.durationSec),
        () => _finishSession(config.sessionId),
      );

    if (config.includeRawSamples) {
      final rawInterval = Duration(
        seconds:
            config.profile.rawEmitIntervalSec ?? config.profile.emitIntervalSec,
      );
      session.rawTimer = Timer.periodic(rawInterval, (_) {
        if (controller.isClosed) return;
        session.rawSeq++;
        final now = DateTime.now().millisecondsSinceEpoch;
        final intervalSec =
            config.profile.rawEmitIntervalSec ?? config.profile.emitIntervalSec;
        final samples = _hrGenerator.generate(
          startMs: now - intervalSec * 1000,
          count: intervalSec,
        );

        controller.add(
          BiosignalFrame(
            sessionId: config.sessionId,
            seq: session.rawSeq,
            emittedAtMs: now,
            samples: samples
                .map(
                  (s) => BiosignalSample(
                    timestampMs: s.timestampMs,
                    bpm: s.bpm,
                    rrIntervalMs: 60000.0 / s.bpm,
                    accelerometer: _mockAccelerometer(),
                  ),
                )
                .toList(),
          ),
        );
      });
    }

    return controller.stream;
  }

  Future<void> stopSession(String sessionId) async {
    _finishSession(sessionId);
  }

  SessionStatus? getStatus(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return null;
    return SessionStatus(
      sessionId: sessionId,
      active: true,
      lastSeq: session.seq,
    );
  }

  void dispose() {
    for (final id in _sessions.keys.toList()) {
      _cancelSession(id);
    }
  }

  void _finishSession(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return;

    session
      ..timer?.cancel()
      ..durationTimer?.cancel()
      ..rawTimer?.cancel();

    final now = DateTime.now().millisecondsSinceEpoch;
    final durationActual = (now - session.startedAtMs) ~/ 1000;

    session.controller
      ..add(
        SessionSummary(
          sessionId: sessionId,
          durationActualSec: durationActual,
          metrics: _buildMockMetrics(session.config, session),
          behavior: _pullBehavior(),
        ),
      )
      ..close();
    _sessions.remove(sessionId);
  }

  void _cancelSession(String sessionId) {
    final session = _sessions.remove(sessionId);
    if (session == null) return;
    session
      ..timer?.cancel()
      ..durationTimer?.cancel()
      ..rawTimer?.cancel()
      ..controller.close();
  }

  static final _accelRng = Random();

  static ({double x, double y, double z}) _mockAccelerometer() => (
    x: (_accelRng.nextDouble() - 0.5) * 0.2,
    y: (_accelRng.nextDouble() - 0.5) * 0.1,
    z: 0.95 + _accelRng.nextDouble() * 0.1,
  );

  Map<String, dynamic>? _pullBehavior() {
    final bp = behaviorProvider;
    if (bp == null || !bp.isAvailable) return null;
    return bp.currentSnapshot()?.toJson();
  }

  Map<String, dynamic> _buildMockMetrics(
    SessionConfig config,
    _RunningSession session,
  ) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final windowSamples = _hrGenerator.generate(
      startMs: now - config.profile.windowSec * 1000,
      count: config.profile.windowSec,
    );

    final bpmValues = windowSamples.map((s) => s.bpm).toList();
    final meanBpm = bpmValues.reduce((a, b) => a + b) / bpmValues.length;
    final sdnn = _computeSdnn(bpmValues);

    return {
      'hr_mean_bpm': double.parse(meanBpm.toStringAsFixed(1)),
      'hr_sdnn_ms': double.parse(sdnn.toStringAsFixed(2)),
      'rmssd_ms': double.parse((sdnn * 0.8).toStringAsFixed(2)),
      'sample_count': windowSamples.length,
      'start_ms': windowSamples.first.timestampMs,
      'end_ms': windowSamples.last.timestampMs,
      'mock': true,
      'session_id': config.sessionId,
      'mode': config.mode.value,
      'seq': session.seq,
    };
  }

  double _computeSdnn(List<double> bpmValues) {
    if (bpmValues.length < 2) return 0;
    final rrIntervals = bpmValues.map((bpm) => 60000.0 / bpm).toList();
    final mean = rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;
    final variance =
        rrIntervals
            .map((rr) => (rr - mean) * (rr - mean))
            .reduce((a, b) => a + b) /
        rrIntervals.length;
    return _sqrt(variance);
  }

  static double _sqrt(double value) {
    if (value <= 0) return 0;
    var x = value;
    for (var i = 0; i < 20; i++) {
      x = (x + value / x) / 2;
    }
    return x;
  }
}

class _RunningSession {
  _RunningSession({
    required this.config,
    required this.controller,
    required this.startedAtMs,
  });

  final SessionConfig config;
  final StreamController<SessionEvent> controller;
  final int startedAtMs;
  int seq = 0;
  int rawSeq = 0;
  Timer? timer;
  Timer? durationTimer;
  Timer? rawTimer;
}

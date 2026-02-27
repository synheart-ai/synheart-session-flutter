import 'dart:async';
import 'dart:math';

import 'package:synheart_session/src/types/behavior_provider.dart';
import 'package:synheart_session/src/types/biosignal_provider.dart';
import 'package:synheart_session/src/types/session_config.dart';
import 'package:synheart_session/src/types/session_event.dart';
import 'package:synheart_session/src/types/session_status.dart';

/// Dart-side session engine that consumes real HR data from a
/// [BiosignalProvider] and behavioral signals from a [BehaviorProvider].
///
/// Follows the same lifecycle as `MockSessionEngine`:
///   startSession → SessionStarted → SessionFrame* → SessionSummary
class LiveSessionEngine {
  LiveSessionEngine({
    BiosignalProvider? biosignalProvider,
    BehaviorProvider? behaviorProvider,
  }) : _biosignalProvider = biosignalProvider,
       _behaviorProvider = behaviorProvider;

  final BiosignalProvider? _biosignalProvider;
  final BehaviorProvider? _behaviorProvider;
  final Map<String, _RunningSession> _sessions = {};

  Stream<SessionEvent> startSession(SessionConfig config) {
    if (_sessions.containsKey(config.sessionId)) {
      throw StateError('Session ${config.sessionId} is already running');
    }

    final controller = StreamController<SessionEvent>();
    final buffer = _HrRingBuffer(capacity: config.profile.windowSec);
    final session = _RunningSession(
      config: config,
      controller: controller,
      startedAtMs: DateTime.now().millisecondsSinceEpoch,
      buffer: buffer,
    );
    _sessions[config.sessionId] = session;

    // Emit SessionStarted immediately
    controller.add(
      SessionStarted(
        sessionId: config.sessionId,
        startedAtMs: session.startedAtMs,
      ),
    );

    // Subscribe to HR source
    _subscribeHr(session);

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

        _emitFrame(session, now);
      })
      ..durationTimer = Timer(
        Duration(seconds: config.durationSec),
        () => _finishSession(config.sessionId),
      );

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
    _biosignalProvider?.stopStreaming();
  }

  // -- Private --

  void _subscribeHr(_RunningSession session) {
    final provider = _biosignalProvider;
    if (provider == null || !provider.isAvailable) return;

    session.hrSubscription = provider.startStreaming().listen(
      (sample) => session.buffer.add(
        _HrSample(
          timestampMs: sample.timestampMs,
          bpm: sample.bpm,
          rrIntervalsMs: sample.rrIntervalMs != null
              ? [sample.rrIntervalMs!]
              : const [],
        ),
      ),
    );
  }

  void _emitFrame(_RunningSession session, int nowMs) {
    if (session.controller.isClosed) return;
    final metrics = _computeMetrics(session.config, session, nowMs);
    session.controller.add(
      SessionFrame(
        sessionId: session.config.sessionId,
        seq: session.seq,
        emittedAtMs: nowMs,
        metrics: metrics,
        behavior: _pullBehavior(),
      ),
    );
  }

  void _finishSession(String sessionId) {
    final session = _sessions[sessionId];
    if (session == null) return;

    session.dispose();

    final now = DateTime.now().millisecondsSinceEpoch;
    final durationActual = (now - session.startedAtMs) ~/ 1000;
    final metrics = _computeMetrics(session.config, session, now);

    session.controller
      ..add(
        SessionSummary(
          sessionId: sessionId,
          durationActualSec: durationActual,
          metrics: metrics,
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
      ..dispose()
      ..controller.close();
  }

  Map<String, dynamic>? _pullBehavior() {
    final bp = _behaviorProvider;
    if (bp == null || !bp.isAvailable) return null;
    return bp.currentSnapshot()?.toJson();
  }

  Map<String, dynamic> _computeMetrics(
    SessionConfig config,
    _RunningSession session,
    int nowMs,
  ) {
    final windowMs = config.profile.windowSec * 1000;
    final samples = session.buffer.samplesInWindow(nowMs - windowMs, nowMs);

    if (samples.isEmpty) {
      return {
        'hr_mean_bpm': 0.0,
        'hr_sdnn_ms': 0.0,
        'rmssd_ms': 0.0,
        'sample_count': 0,
        'start_ms': nowMs,
        'end_ms': nowMs,
        'session_id': config.sessionId,
        'mode': config.mode.value,
        'seq': session.seq,
      };
    }

    final bpmValues = samples.map((s) => s.bpm).toList();
    final meanBpm = bpmValues.reduce((a, b) => a + b) / bpmValues.length;

    // Collect all RR intervals from samples
    final allRr = <double>[];
    for (final s in samples) {
      if (s.rrIntervalsMs.isNotEmpty) {
        allRr.addAll(s.rrIntervalsMs);
      } else {
        // Approximate RR from BPM when real RR not available
        allRr.add(60000.0 / s.bpm);
      }
    }

    final sdnn = _computeSdnn(allRr);
    final rmssd = _computeRmssd(allRr);

    return {
      'hr_mean_bpm': double.parse(meanBpm.toStringAsFixed(1)),
      'hr_sdnn_ms': double.parse(sdnn.toStringAsFixed(2)),
      'rmssd_ms': double.parse(rmssd.toStringAsFixed(2)),
      'sample_count': samples.length,
      'start_ms': samples.first.timestampMs,
      'end_ms': samples.last.timestampMs,
      'session_id': config.sessionId,
      'mode': config.mode.value,
      'seq': session.seq,
    };
  }

  static double _computeSdnn(List<double> rrIntervals) {
    if (rrIntervals.length < 2) return 0;
    final mean = rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;
    final variance =
        rrIntervals
            .map((rr) => (rr - mean) * (rr - mean))
            .reduce((a, b) => a + b) /
        rrIntervals.length;
    return sqrt(variance);
  }

  static double _computeRmssd(List<double> rrIntervals) {
    if (rrIntervals.length < 2) return 0;
    var sumSquaredDiffs = 0.0;
    for (var i = 1; i < rrIntervals.length; i++) {
      final diff = rrIntervals[i] - rrIntervals[i - 1];
      sumSquaredDiffs += diff * diff;
    }
    return sqrt(sumSquaredDiffs / (rrIntervals.length - 1));
  }
}

/// Circular buffer for HR samples with time-windowed retrieval.
class _HrRingBuffer {
  _HrRingBuffer({required int capacity})
    : _data = List<_HrSample?>.filled(capacity, null),
      _capacity = capacity;

  final List<_HrSample?> _data;
  final int _capacity;
  int _head = 0;
  int _count = 0;

  void add(_HrSample sample) {
    _data[_head] = sample;
    _head = (_head + 1) % _capacity;
    if (_count < _capacity) _count++;
  }

  List<_HrSample> samplesInWindow(int fromMs, int toMs) {
    final result = <_HrSample>[];
    for (var i = 0; i < _count; i++) {
      final idx = (_head - _count + i) % _capacity;
      final s = _data[idx < 0 ? idx + _capacity : idx];
      if (s != null && s.timestampMs >= fromMs && s.timestampMs <= toMs) {
        result.add(s);
      }
    }
    return result;
  }

  int get count => _count;

  bool get isEmpty => _count == 0;
}

class _HrSample {
  const _HrSample({
    required this.timestampMs,
    required this.bpm,
    required this.rrIntervalsMs,
  });

  final int timestampMs;
  final double bpm;
  final List<double> rrIntervalsMs;
}

class _RunningSession {
  _RunningSession({
    required this.config,
    required this.controller,
    required this.startedAtMs,
    required this.buffer,
  });

  final SessionConfig config;
  final StreamController<SessionEvent> controller;
  final int startedAtMs;
  final _HrRingBuffer buffer;
  int seq = 0;
  Timer? timer;
  Timer? durationTimer;
  StreamSubscription<dynamic>? hrSubscription;

  void dispose() {
    timer?.cancel();
    durationTimer?.cancel();
    hrSubscription?.cancel();
  }
}

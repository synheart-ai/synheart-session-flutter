import 'dart:async';

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

  /// Ingest pre-computed HRV metrics from the Rust runtime (session-runtime).
  /// These are artifact-filtered and authoritative — the session SDK does not
  /// compute HRV locally.
  void ingestHsiMetrics(String sessionId, Map<String, dynamic> hsiMetrics) {
    final session = _sessions[sessionId];
    if (session == null) return;
    session.lastHsiMetrics = hsiMetrics;
  }

  Map<String, dynamic> _computeMetrics(
    SessionConfig config,
    _RunningSession session,
    int nowMs,
  ) {
    final windowMs = config.profile.windowSec * 1000;
    final samples = session.buffer.samplesInWindow(nowMs - windowMs, nowMs);

    // Base metrics: sample count and mean HR (no artifact filtering needed)
    final sampleCount = samples.length;
    final meanBpm = sampleCount > 0
        ? samples.map((s) => s.bpm).reduce((a, b) => a + b) / sampleCount
        : 0.0;

    // HRV metrics come from session-runtime (artifact-filtered, authoritative)
    final hsi = session.lastHsiMetrics ?? {};

    return {
      'hr_mean_bpm': double.parse(meanBpm.toStringAsFixed(1)),
      'hr_sdnn_ms': (hsi['hrv.sdnn_ms'] as num?)?.toDouble() ?? 0.0,
      'rmssd_ms': (hsi['hrv.rmssd_ms'] as num?)?.toDouble() ?? 0.0,
      'pnn50': (hsi['hrv.pnn50'] as num?)?.toDouble() ?? 0.0,
      'sample_count': sampleCount,
      'start_ms': sampleCount > 0 ? samples.first.timestampMs : nowMs,
      'end_ms': sampleCount > 0 ? samples.last.timestampMs : nowMs,
      'session_id': config.sessionId,
      'mode': config.mode.value,
      'seq': session.seq,
    };
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
  Map<String, dynamic>? lastHsiMetrics;

  void dispose() {
    timer?.cancel();
    durationTimer?.cancel();
    hrSubscription?.cancel();
  }
}

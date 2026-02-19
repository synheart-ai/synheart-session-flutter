import 'dart:async';

import 'package:flutter/material.dart';
import 'package:synheart_session/synheart_session.dart';

void main() {
  runApp(const SessionExampleApp());
}

class SessionExampleApp extends StatelessWidget {
  const SessionExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Synheart Session',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF6C3CE1),
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      home: const SessionPage(),
    );
  }
}

class SessionPage extends StatefulWidget {
  const SessionPage({super.key});

  @override
  State<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends State<SessionPage> {
  SynheartSession? _session;
  StreamSubscription<SessionEvent>? _subscription;
  SessionMode _mode = SessionMode.focus;
  int _durationSec = 30;

  // Session state
  bool _running = false;
  SessionConfig? _activeConfig;
  int _currentSeq = 0;
  double _lastHr = 0;
  double _lastSdnn = 0;
  double _lastRmssd = 0;
  double? _lastStability;
  double? _lastFragmentation;
  final List<_LogEntry> _log = [];
  final List<double> _hrHistory = [];
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _session = SynheartSession.mock(
      seed: 42,
      behaviorProvider: MockBehaviorProvider(),
    );
    _logWatchStatus();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _session?.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Query watch connectivity on init to demonstrate getWatchStatus() / WatchStatus.
  Future<void> _logWatchStatus() async {
    final ws = await _session!.getWatchStatus();
    if (ws != null) {
      _addLog(
        'Watch: supported=${ws.supported} reachable=${ws.reachable} '
        'paired=${ws.paired} installed=${ws.installed}',
        _LogType.info,
      );
    } else {
      _addLog('Watch: not available (mock mode)', _LogType.info);
    }
  }

  void _start() {
    final config = SessionConfig(
      mode: _mode,
      durationSec: _durationSec,
      windowLabel: '${_mode.value}_session',
      profile: ComputeProfile(
        windowSec: 10,
        emitIntervalSec: 3,
        rawEmitIntervalSec: 2,
      ),
      includeRawSamples: true,
    );

    setState(() {
      _activeConfig = config;
      _running = true;
      _currentSeq = 0;
      _lastHr = 0;
      _lastSdnn = 0;
      _lastRmssd = 0;
      _lastStability = null;
      _lastFragmentation = null;
      _log.clear();
      _hrHistory.clear();
    });

    _addLog('Starting session (label=${config.windowLabel})...', _LogType.info);

    try {
      _subscription = _session!
          .startSession(config)
          .listen(
            _handleEvent,
            onDone: () {
              setState(() => _running = false);
              _addLog('Stream closed', _LogType.info);
            },
            onError: (Object e) {
              if (e is SessionInvalidStateError) {
                _addLog('Invalid state: ${e.message}', _LogType.error);
              } else if (e is SessionPermissionDeniedError) {
                _addLog('Permission denied: ${e.message}', _LogType.error);
              } else if (e is SessionSensorUnavailableError) {
                _addLog('Sensor unavailable: ${e.message}', _LogType.error);
              } else if (e is SynheartSessionError) {
                _addLog('Session error: ${e.message}', _LogType.error);
              } else {
                _addLog('Stream error: $e', _LogType.error);
              }
              setState(() => _running = false);
            },
          );
    } on SessionInvalidStateError catch (e) {
      _addLog('Cannot start: ${e.message}', _LogType.error);
      setState(() => _running = false);
    }
  }

  void _handleEvent(SessionEvent event) {
    // Demonstrate toJson() serialization on every event
    final json = event.toJson();
    assert(json['type'] is String, 'toJson() must include type');

    switch (event) {
      case SessionStarted():
        _addLog(
          'Session started (${_activeConfig!.mode.value}) '
          'at ${DateTime.fromMillisecondsSinceEpoch(event.startedAtMs).toIso8601String()}',
          _LogType.success,
        );
        _queryStatus();

      case SessionFrame():
        _handleSessionFrame(event);

      case BiosignalFrame():
        _handleBiosignalFrame(event);

      case SessionSummary():
        _handleSessionSummary(event);

      case SessionError():
        _handleSessionError(event);
    }
  }

  Future<void> _queryStatus() async {
    final status = await _session!.getStatus();
    if (status != null) {
      _addLog(
        'Status: id=${status.sessionId.substring(0, 8)}... '
        'active=${status.active} seq=${status.lastSeq}',
        _LogType.info,
      );
    }
  }

  void _handleSessionFrame(SessionFrame frame) {
    final m = frame.metrics;
    final hr = (m['hr_mean_bpm'] as num?)?.toDouble() ?? 0;
    final sdnn = (m['hr_sdnn_ms'] as num?)?.toDouble() ?? 0;
    final rmssd = (m['rmssd_ms'] as num?)?.toDouble() ?? 0;

    // Extract behavioral signals beyond just stability_index
    final behavior = frame.behavior;
    final stability = (behavior?['stability_index'] as num?)?.toDouble();
    final fragmentation = (behavior?['fragmentation_index'] as num?)
        ?.toDouble();
    final appSwitches = behavior?['app_switches_per_minute'] as int?;

    setState(() {
      _currentSeq = frame.seq;
      _lastHr = hr;
      _lastSdnn = sdnn;
      _lastRmssd = rmssd;
      if (stability != null) _lastStability = stability;
      if (fragmentation != null) _lastFragmentation = fragmentation;
      _hrHistory.add(hr);
      if (_hrHistory.length > 60) _hrHistory.removeAt(0);
    });

    // Show emittedAtMs, encoding, and behavioral fields
    final emittedAt = DateTime.fromMillisecondsSinceEpoch(frame.emittedAtMs);
    final encodingStr = frame.encoding.value;
    _addLog(
      '#${frame.seq}  HR ${hr.toStringAsFixed(1)} bpm  '
      'SDNN ${sdnn.toStringAsFixed(1)} ms  '
      'enc=$encodingStr  '
      'at ${emittedAt.hour}:${emittedAt.minute.toString().padLeft(2, '0')}:${emittedAt.second.toString().padLeft(2, '0')}'
      '${stability != null ? '  stab=${stability.toStringAsFixed(2)}' : ''}'
      '${fragmentation != null ? '  frag=${fragmentation.toStringAsFixed(2)}' : ''}'
      '${appSwitches != null ? '  appSw=$appSwitches' : ''}',
      _LogType.data,
    );
  }

  void _handleBiosignalFrame(BiosignalFrame frame) {
    if (frame.samples.isEmpty) return;
    final latest = frame.samples.last;

    setState(() {
      _lastHr = latest.bpm;
      _hrHistory.add(latest.bpm);
      if (_hrHistory.length > 60) _hrHistory.removeAt(0);
    });

    final accelMag = latest.accelerometer != null
        ? _sqrt(
            latest.accelerometer!.x * latest.accelerometer!.x +
                latest.accelerometer!.y * latest.accelerometer!.y +
                latest.accelerometer!.z * latest.accelerometer!.z,
          )
        : 0.0;

    // Show all BiosignalSample fields: timestampMs, bpm, rrIntervalMs, accelerometer, spo2
    // Also show BiosignalFrame.emittedAtMs
    _addLog(
      'BIO #${frame.seq}  '
      'ts=${latest.timestampMs}  '
      'BPM ${latest.bpm.toStringAsFixed(1)}  '
      'RR ${latest.rrIntervalMs?.toStringAsFixed(0) ?? "-"} ms  '
      'Accel ${accelMag.toStringAsFixed(2)}  '
      'SpO2 ${latest.spo2?.toStringAsFixed(0) ?? "-"}  '
      'emitted=${frame.emittedAtMs}',
      _LogType.data,
    );
  }

  void _handleSessionSummary(SessionSummary event) {
    // Show summary metrics, encoding, and behavioral summary
    final sm = event.metrics;
    final summaryHr = (sm['hr_mean_bpm'] as num?)?.toDouble();
    final summarySdnn = (sm['hr_sdnn_ms'] as num?)?.toDouble();
    final summaryRmssd = (sm['rmssd_ms'] as num?)?.toDouble();
    final sampleCount = sm['sample_count'] as int?;

    final behavior = event.behavior;
    final stability = (behavior?['stability_index'] as num?)?.toDouble();
    final fragmentation = (behavior?['fragmentation_index'] as num?)
        ?.toDouble();
    final typingCadence = (behavior?['typing_cadence'] as num?)?.toDouble();
    final scrollVelocity = (behavior?['scroll_velocity'] as num?)?.toDouble();
    final idleGap = (behavior?['idle_gap_seconds'] as num?)?.toDouble();

    _addLog(
      'Session complete: ${event.durationActualSec}s  '
      'enc=${event.encoding.value}',
      _LogType.success,
    );

    if (summaryHr != null) {
      _addLog(
        '  Metrics: HR=${summaryHr.toStringAsFixed(1)} '
        'SDNN=${summarySdnn?.toStringAsFixed(1) ?? "-"} '
        'RMSSD=${summaryRmssd?.toStringAsFixed(1) ?? "-"} '
        'samples=$sampleCount',
        _LogType.success,
      );
    }

    if (behavior != null) {
      _addLog(
        '  Behavior: stab=${stability?.toStringAsFixed(2) ?? "-"} '
        'frag=${fragmentation?.toStringAsFixed(2) ?? "-"} '
        'typing=${typingCadence?.toStringAsFixed(1) ?? "-"}/s '
        'scroll=${scrollVelocity?.toStringAsFixed(1) ?? "-"}px/s '
        'idle=${idleGap?.toStringAsFixed(1) ?? "-"}s',
        _LogType.success,
      );
    }
  }

  void _handleSessionError(SessionError event) {
    // Use SessionErrorCode enum directly (not string matching)
    final String msg;
    switch (event.code) {
      case SessionErrorCode.permissionDenied:
        msg = 'Permission denied: ${event.message}';
      case SessionErrorCode.sensorUnavailable:
        msg = 'Sensor unavailable: ${event.message}';
      case SessionErrorCode.lowBattery:
        msg = 'Low battery: ${event.message}';
      case SessionErrorCode.osTerminated:
        msg = 'OS terminated session: ${event.message}';
      case SessionErrorCode.invalidState:
        msg = 'Invalid state: ${event.message}';
    }
    _addLog(msg, _LogType.error);
  }

  static double _sqrt(double v) {
    if (v <= 0) return 0;
    var x = v;
    for (var i = 0; i < 20; i++) {
      x = (x + v / x) / 2;
    }
    return x;
  }

  Future<void> _stop() async {
    if (_activeConfig == null) return;
    _addLog('Stopping session...', _LogType.info);
    await _session!.stopSession(_activeConfig!.sessionId);
  }

  void _addLog(String message, _LogType type) {
    final now = DateTime.now();
    final ts =
        '${now.hour.toString().padLeft(2, '0')}:'
        '${now.minute.toString().padLeft(2, '0')}:'
        '${now.second.toString().padLeft(2, '0')}';
    setState(() => _log.add(_LogEntry(time: ts, message: message, type: type)));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Synheart Session')),
      body: Column(
        children: [
          // ---- Live stats cards ----
          if (_running || _lastHr > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  _StatCard(
                    label: 'HR',
                    value: _lastHr.toStringAsFixed(1),
                    unit: 'bpm',
                    color: cs.primary,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    label: 'SDNN',
                    value: _lastSdnn.toStringAsFixed(1),
                    unit: 'ms',
                    color: cs.tertiary,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    label: 'RMSSD',
                    value: _lastRmssd.toStringAsFixed(1),
                    unit: 'ms',
                    color: cs.secondary,
                  ),
                  const SizedBox(width: 8),
                  _StatCard(
                    label: 'Stability',
                    value: _lastStability?.toStringAsFixed(2) ?? '--',
                    unit: '',
                    color: Colors.tealAccent,
                  ),
                ],
              ),
            ),

          // ---- Fragmentation indicator ----
          if (_lastFragmentation != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Fragmentation: ${_lastFragmentation!.toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 11, color: cs.outline),
                  ),
                ],
              ),
            ),

          // ---- HR sparkline ----
          if (_hrHistory.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SizedBox(
                height: 80,
                child: CustomPaint(
                  size: const Size(double.infinity, 80),
                  painter: _SparklinePainter(
                    values: _hrHistory,
                    color: cs.primary,
                  ),
                ),
              ),
            ),

          // ---- Controls ----
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Mode selector
                Flexible(
                  child: DropdownButton<SessionMode>(
                    value: _mode,
                    isExpanded: false,
                    onChanged: _running
                        ? null
                        : (v) => setState(() => _mode = v!),
                    items: const [
                      DropdownMenuItem(
                        value: SessionMode.focus,
                        child: Text('Focus'),
                      ),
                      DropdownMenuItem(
                        value: SessionMode.breathing,
                        child: Text('Breathe'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Duration selector
                DropdownButton<int>(
                  value: _durationSec,
                  onChanged: _running
                      ? null
                      : (v) => setState(() => _durationSec = v!),
                  items: const [
                    DropdownMenuItem(value: 15, child: Text('15s')),
                    DropdownMenuItem(value: 30, child: Text('30s')),
                    DropdownMenuItem(value: 60, child: Text('60s')),
                    DropdownMenuItem(value: 300, child: Text('5m')),
                  ],
                ),
                const Spacer(),
                // Start/Stop
                IconButton.filled(
                  onPressed: _running ? null : _start,
                  icon: const Icon(Icons.play_arrow),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _running ? _stop : null,
                  icon: const Icon(Icons.stop),
                ),
              ],
            ),
          ),

          // ---- Status bar ----
          if (_running)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              color: cs.primaryContainer,
              child: Text(
                'Session ${_activeConfig?.sessionId.substring(0, 8) ?? ''}'
                '...  |  Frame #$_currentSeq  |  '
                '${_mode.value.toUpperCase()}',
                style: TextStyle(
                  fontSize: 12,
                  color: cs.onPrimaryContainer,
                  fontFamily: 'monospace',
                ),
              ),
            ),

          // ---- Event log ----
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              itemCount: _log.length,
              itemBuilder: (_, i) {
                final entry = _log[i];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 1),
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      children: [
                        TextSpan(
                          text: '${entry.time}  ',
                          style: TextStyle(color: cs.outline),
                        ),
                        TextSpan(
                          text: entry.message,
                          style: TextStyle(color: entry.type.color(cs)),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---- Helpers ----

enum _LogType { info, success, data, error }

extension on _LogType {
  Color color(ColorScheme cs) => switch (this) {
    _LogType.info => cs.outline,
    _LogType.success => Colors.greenAccent,
    _LogType.data => cs.onSurface,
    _LogType.error => cs.error,
  };
}

class _LogEntry {
  const _LogEntry({
    required this.time,
    required this.message,
    required this.type,
  });
  final String time;
  final String message;
  final _LogType type;
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  final String label;
  final String value;
  final String unit;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 11, color: color)),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: TextStyle(
                      fontSize: 11,
                      color: color.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final minV = values.reduce((a, b) => a < b ? a : b) - 2;
    final maxV = values.reduce((a, b) => a > b ? a : b) + 2;
    final range = maxV - minV;
    if (range == 0) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Fill gradient under the line
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.3), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(fillPath, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      values.length != old.values.length ||
      (values.isNotEmpty &&
          old.values.isNotEmpty &&
          values.last != old.values.last);
}

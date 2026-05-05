import 'dart:async';

import 'package:synheart_session/src/channel/session_channel.dart';
import 'package:synheart_session/src/live/live_session_engine.dart';
import 'package:synheart_session/src/mock/mock_session_engine.dart';
import 'package:synheart_session/src/session_error.dart';
import 'package:synheart_session/src/types/behavior_provider.dart';
import 'package:synheart_session/src/types/biosignal_provider.dart';
import 'package:synheart_session/src/types/session_config.dart';
import 'package:synheart_session/src/types/session_event.dart';
import 'package:synheart_session/src/types/session_status.dart';
import 'package:synheart_session/src/types/watch_status.dart';
import 'package:synheart_session/src/watch/watch_biosignal_provider.dart';

class SynheartSession {
  /// Live mode — consumes real data from provider abstractions.
  ///
  /// All parameters are optional. When [biosignalProvider] is a
  /// [WatchBiosignalProvider], watch relay commands (start/stop) are sent
  /// automatically via the provider's channel.
  SynheartSession({
    BiosignalProvider? biosignalProvider,
    BehaviorProvider? behaviorProvider,
  }) : _mockEngine = null,
       _liveEngine = LiveSessionEngine(
         biosignalProvider: biosignalProvider,
         behaviorProvider: behaviorProvider,
       ),
       _channel = biosignalProvider is WatchBiosignalProvider
           ? biosignalProvider.channel
           : null;

  /// Mock mode — simulates sessions locally for development.
  SynheartSession.mock({int? seed, BehaviorProvider? behaviorProvider})
    : _mockEngine = MockSessionEngine(
        seed: seed,
        behaviorProvider: behaviorProvider,
      ),
      _liveEngine = null,
      _channel = null;

  final MockSessionEngine? _mockEngine;
  final LiveSessionEngine? _liveEngine;
  final SessionChannel? _channel;
  final Map<String, StreamController<SessionEvent>> _controllers = {};
  bool _disposed = false;

  /// Start a session. Returns stream of SessionEvents.
  /// Stream lifecycle: SessionStarted -> SessionFrame* -> SessionSummary
  Stream<SessionEvent> startSession(SessionConfig config) {
    _checkDisposed();

    if (_controllers.containsKey(config.sessionId)) {
      throw const SessionInvalidStateError(
        'Session with this ID is already running',
      );
    }

    if (_mockEngine != null) {
      return _startMockSession(config);
    }
    return _startLiveSession(config);
  }

  /// Stop a running session (triggers SessionSummary).
  Future<void> stopSession(String sessionId) async {
    _checkDisposed();

    if (_mockEngine != null) {
      await _mockEngine.stopSession(sessionId);
      return;
    }

    // Always stop local engine (emits SessionSummary + closes stream)
    if (_liveEngine != null) {
      await _liveEngine.stopSession(sessionId);
    }

    // Also tell the watch to stop (no-op if no channel)
    try {
      await _channel?.stopSession(sessionId);
    } catch (e) {
      assert(() {
        // ignore: avoid_print
        print('WatchSession: stopSession channel error: $e');
        return true;
      }(), 'stopSession channel error: $e');
    }
  }

  /// Query current session status. Returns null if no session active.
  Future<SessionStatus?> getStatus() async {
    _checkDisposed();

    if (_mockEngine != null) {
      for (final id in _controllers.keys) {
        final status = _mockEngine.getStatus(id);
        if (status != null) return status;
      }
      return null;
    }

    if (_liveEngine != null) {
      for (final id in _controllers.keys) {
        final status = _liveEngine.getStatus(id);
        if (status != null) return status;
      }
      return null;
    }

    return null;
  }

  /// Query watch connectivity status (iOS + Android).
  /// Returns null in mock mode.
  Future<WatchStatus?> getWatchStatus() async {
    _checkDisposed();
    if (_channel == null) return null;
    return _channel.getWatchStatus();
  }

  /// Ingest pre-computed HRV metrics from the Synheart Runtime into the live engine.
  /// No-op in mock mode or if no session with [sessionId] is active.
  void ingestHsiMetrics(String sessionId, Map<String, dynamic> hsiMetrics) {
    if (_disposed) return;
    _liveEngine?.ingestHsiMetrics(sessionId, hsiMetrics);
  }

  /// Release all resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _mockEngine?.dispose();
    _liveEngine?.dispose();

    for (final controller in _controllers.values) {
      controller.close();
    }
    _controllers.clear();
  }

  Stream<SessionEvent> _startMockSession(SessionConfig config) {
    final mockStream = _mockEngine!.startSession(config);

    final controller = StreamController<SessionEvent>.broadcast();
    _controllers[config.sessionId] = controller;

    final sub = mockStream.listen(
      (event) {
        if (controller.isClosed) return;
        controller.add(event);
        if (event is SessionSummary || event is SessionError) {
          controller.close();
          _controllers.remove(config.sessionId);
        }
      },
      onError: (Object error) {
        if (!controller.isClosed) controller.addError(error);
      },
      onDone: () {
        if (!controller.isClosed) {
          controller.close();
        }
        _controllers.remove(config.sessionId);
      },
    );

    controller.onCancel = () {
      sub.cancel();
      _controllers.remove(config.sessionId);
    };

    return controller.stream;
  }

  Stream<SessionEvent> _startLiveSession(SessionConfig config) {
    final liveStream = _liveEngine!.startSession(config);

    final controller = StreamController<SessionEvent>.broadcast();
    _controllers[config.sessionId] = controller;

    // Tell the watch to start (no-op if no channel / watch not connected).
    // No delay needed: EventChannel onListen was triggered by
    // provider.startStreaming() (called inside startSession above),
    // which is queued on the platform thread before this MethodChannel call.
    _channel?.startSession(config);

    final sub = liveStream.listen(
      (event) {
        if (controller.isClosed) return;
        controller.add(event);
        if (event is SessionSummary || event is SessionError) {
          controller.close();
          _controllers.remove(config.sessionId);
        }
      },
      onError: (Object error) {
        if (!controller.isClosed) controller.addError(error);
      },
      onDone: () {
        if (!controller.isClosed) {
          controller.close();
        }
        _controllers.remove(config.sessionId);
      },
    );

    controller.onCancel = () {
      sub.cancel();
      _controllers.remove(config.sessionId);
    };

    return controller.stream;
  }

  void _checkDisposed() {
    if (_disposed) {
      throw const SessionInvalidStateError('SynheartSession has been disposed');
    }
  }
}

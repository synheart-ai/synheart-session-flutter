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

class SynheartSession {
  /// Live mode — consumes real data from provider abstractions.
  ///
  /// All parameters are optional. When no [biosignalProvider] is supplied,
  /// falls back to the iOS watch relay (via [SessionChannel]) if reachable,
  /// or emits zeroed metrics otherwise.
  SynheartSession({
    BiosignalProvider? biosignalProvider,
    BehaviorProvider? behaviorProvider,
  }) : _mockEngine = null,
       _liveEngine = LiveSessionEngine(
         biosignalProvider: biosignalProvider,
         behaviorProvider: behaviorProvider,
       ),
       _channel = SessionChannel();

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
  StreamSubscription<SessionEvent>? _channelSubscription;
  bool _disposed = false;

  /// Start a session. Returns stream of SessionEvents.
  /// Stream lifecycle: SessionStarted -> SessionFrame* -> SessionSummary
  ///
  /// When [watchOnly] is true, the local [LiveSessionEngine] is not started;
  /// only events from the watch relay are emitted. Use this for watch sessions
  /// so [hr_mean_bpm] and other metrics come from the watch instead of
  /// zeroed local frames.
  Stream<SessionEvent> startSession(SessionConfig config, {bool watchOnly = false}) {
    _checkDisposed();

    if (_controllers.containsKey(config.sessionId)) {
      throw const SessionInvalidStateError(
        'Session with this ID is already running',
      );
    }

    if (_mockEngine != null) {
      return _startMockSession(config);
    }
    if (watchOnly) {
      return _startWatchOnlySession(config);
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

    final channel = _channel;
    final hasWatchSession = channel != null && _controllers.containsKey(sessionId);

    if (hasWatchSession) {
      // Cancel local engine first so its duration timer cannot fire and emit a
      // local summary; then tell the watch to stop. The stream stays open until
      // the watch sends SessionSummary.
      _liveEngine?.cancelSession(sessionId);
      try {
        await channel.stopSession(sessionId);
      } catch (_) {}
      return;
    }

    if (_liveEngine != null) {
      await _liveEngine.stopSession(sessionId);
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

  /// Release all resources.
  void dispose() {
    if (_disposed) return;
    _disposed = true;

    _mockEngine?.dispose();
    _liveEngine?.dispose();
    _channelSubscription?.cancel();

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

    // Subscribe to watch relay events FIRST so the native eventSink is set
    // before we send startSession (otherwise early watch frames can be dropped).
    _channelSubscription ??= _channel?.events.listen(
      _routeChannelEvent,
      onError: (Object error) {
        for (final c in _controllers.values) {
          c.addError(error);
        }
      },
    );

    // Small delay so the platform has time to call onListen and set eventSink
    // before the watch sends its first events.
    final channel = _channel;
    if (channel != null) {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 200), () async {
          try {
            await channel.startSession(config);
          } catch (e, _) {
            assert(() {
              // ignore: avoid_print
              print('WatchSession: startSession channel error: $e');
              return true;
            }());
          }
        }),
      );
    }

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

  /// Starts a session that only receives events from the watch relay.
  /// No local [LiveSessionEngine] frames are emitted, so metrics like
  /// [hr_mean_bpm] come only from the watch.
  Stream<SessionEvent> _startWatchOnlySession(SessionConfig config) {
    final controller = StreamController<SessionEvent>.broadcast();
    _controllers[config.sessionId] = controller;

    _channelSubscription ??= _channel?.events.listen(
      _routeChannelEvent,
      onError: (Object error) {
        for (final c in _controllers.values) {
          c.addError(error);
        }
      },
    );

    final channel = _channel;
    if (channel != null) {
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 200), () async {
          try {
            await channel.startSession(config);
          } catch (e, _) {
            assert(() {
              // ignore: avoid_print
              print('WatchSession: startSession channel error: $e');
              return true;
            }());
          }
        }),
      );
    } else {
      controller.addError(const SessionInvalidStateError(
        'Watch-only session requires a session channel (watch relay)',
      ));
      controller.close();
      _controllers.remove(config.sessionId);
    }

    controller.onCancel = () {
      _controllers.remove(config.sessionId);
    };

    return controller.stream;
  }

  void _routeChannelEvent(SessionEvent event) {
    final controller = _controllers[event.sessionId];
    if (controller == null) return;

    controller.add(event);
    if (event is SessionSummary || event is SessionError) {
      controller.close();
      _controllers.remove(event.sessionId);
    }
  }

  void _checkDisposed() {
    if (_disposed) {
      throw const SessionInvalidStateError('SynheartSession has been disposed');
    }
  }
}

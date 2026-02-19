import 'dart:async';

import 'package:synheart_session/src/channel/session_channel.dart';
import 'package:synheart_session/src/mock/mock_session_engine.dart';
import 'package:synheart_session/src/session_error.dart';
import 'package:synheart_session/src/types/behavior_provider.dart';
import 'package:synheart_session/src/types/session_config.dart';
import 'package:synheart_session/src/types/session_event.dart';
import 'package:synheart_session/src/types/session_status.dart';
import 'package:synheart_session/src/types/watch_status.dart';

class SynheartSession {
  /// Production mode — uses platform channels to native iOS/Android.
  SynheartSession() : _mockEngine = null, _channel = SessionChannel();

  /// Mock mode — simulates sessions locally for development.
  SynheartSession.mock({int? seed, BehaviorProvider? behaviorProvider})
    : _mockEngine = MockSessionEngine(
        seed: seed,
        behaviorProvider: behaviorProvider,
      ),
      _channel = null;

  final MockSessionEngine? _mockEngine;
  final SessionChannel? _channel;
  final Map<String, StreamController<SessionEvent>> _controllers = {};
  StreamSubscription<SessionEvent>? _channelSubscription;
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
    return _startChannelSession(config);
  }

  /// Stop a running session (triggers SessionSummary).
  Future<void> stopSession(String sessionId) async {
    _checkDisposed();

    if (_mockEngine != null) {
      await _mockEngine.stopSession(sessionId);
    } else {
      await _channel!.stopSession(sessionId);
    }
  }

  /// Query current session status. Returns null if no session active.
  Future<SessionStatus?> getStatus() async {
    _checkDisposed();

    if (_mockEngine != null) {
      // Return status for the first active session, or null
      for (final id in _controllers.keys) {
        final status = _mockEngine.getStatus(id);
        if (status != null) return status;
      }
      return null;
    }
    return _channel!.getStatus();
  }

  /// Query Apple Watch connectivity status. Returns null in mock mode.
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

  Stream<SessionEvent> _startChannelSession(SessionConfig config) {
    final controller = StreamController<SessionEvent>.broadcast();
    _controllers[config.sessionId] = controller;

    // Subscribe to channel events once (shared across sessions)
    _channelSubscription ??= _channel!.events.listen(
      _routeChannelEvent,
      onError: (Object error) {
        // Broadcast error to all active sessions
        for (final c in _controllers.values) {
          c.addError(error);
        }
      },
    );

    // Fire the platform start command
    _channel!.startSession(config).catchError((Object error) {
      controller
        ..addError(error)
        ..close();
      _controllers.remove(config.sessionId);
    });

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

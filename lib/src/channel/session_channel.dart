import 'package:flutter/services.dart';
import 'package:synheart_session/src/channel/channel_codec.dart';
import 'package:synheart_session/src/types/session_config.dart';
import 'package:synheart_session/src/types/session_event.dart';
import 'package:synheart_session/src/types/session_status.dart';
import 'package:synheart_session/src/types/watch_status.dart';

class SessionChannel {
  SessionChannel()
    : _methodChannel = const MethodChannel('ai.synheart.session/methods'),
      _eventChannel = const EventChannel('ai.synheart.session/events');

  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;

  Stream<SessionEvent>? _eventStream;

  Future<void> startSession(SessionConfig config) async {
    await _methodChannel.invokeMethod<void>(
      'startSession',
      encodeStartSession(config),
    );
  }

  Future<void> stopSession(String sessionId) async {
    await _methodChannel.invokeMethod<void>(
      'stopSession',
      encodeStopSession(sessionId),
    );
  }

  Future<SessionStatus?> getStatus() async {
    final result = await _methodChannel.invokeMethod<dynamic>('getStatus');
    return decodeSessionStatus(result);
  }

  Future<WatchStatus?> getWatchStatus() async {
    final result = await _methodChannel.invokeMapMethod<String, dynamic>(
      'getWatchStatus',
    );
    if (result == null) return null;
    return WatchStatus.fromJson(result);
  }

  Stream<SessionEvent> get events {
    _eventStream ??= _eventChannel.receiveBroadcastStream().map(
      decodeSessionEvent,
    );
    return _eventStream!;
  }
}

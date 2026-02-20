import 'package:synheart_session/src/types/session_config.dart';
import 'package:synheart_session/src/types/session_event.dart';
import 'package:synheart_session/src/types/session_status.dart';

Map<String, dynamic> encodeStartSession(SessionConfig config) {
  return config.toJson();
}

Map<String, dynamic> encodeStopSession(String sessionId) {
  return {'session_id': sessionId};
}

SessionEvent decodeSessionEvent(dynamic raw) {
  final map = _deepCast(raw as Map);
  return SessionEvent.fromJson(map);
}

SessionStatus? decodeSessionStatus(dynamic raw) {
  if (raw == null) return null;
  return SessionStatus.fromJson(_deepCast(raw as Map));
}

/// Recursively converts platform channel maps (`Map<Object?, Object?>`)
/// into `Map<String, dynamic>` so that `as Map<String, dynamic>` casts
/// succeed on nested dictionaries like `metrics`.
Map<String, dynamic> _deepCast(Map<dynamic, dynamic> map) {
  return map.map<String, dynamic>((key, value) {
    return MapEntry(key as String, _deepCastValue(value));
  });
}

dynamic _deepCastValue(dynamic value) {
  if (value is Map) return _deepCast(value);
  if (value is List) return value.map(_deepCastValue).toList();
  return value;
}

import 'package:meta/meta.dart';

@immutable
class SessionStatus {
  const SessionStatus({
    required this.sessionId,
    required this.active,
    required this.lastSeq,
  });

  factory SessionStatus.fromJson(Map<String, dynamic> json) {
    return SessionStatus(
      sessionId: json['session_id'] as String,
      active: json['active'] as bool,
      lastSeq: json['last_seq'] as int,
    );
  }

  final String sessionId;
  final bool active;
  final int lastSeq;

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'active': active,
    'last_seq': lastSeq,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionStatus &&
          sessionId == other.sessionId &&
          active == other.active &&
          lastSeq == other.lastSeq;

  @override
  int get hashCode => Object.hash(sessionId, active, lastSeq);

  @override
  String toString() =>
      'SessionStatus(sessionId: $sessionId, active: $active, '
      'lastSeq: $lastSeq)';
}

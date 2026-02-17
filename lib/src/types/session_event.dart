import 'package:meta/meta.dart';
import 'package:synheart_session/src/types/biosignal_sample.dart';
import 'package:synheart_session/src/types/enums.dart';

sealed class SessionEvent {
  const SessionEvent({required this.sessionId});

  factory SessionEvent.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    return switch (type) {
      'session_started' => SessionStarted.fromJson(json),
      'hsi_frame' => HsiFrame.fromJson(json),
      'biosignal_frame' => BiosignalFrame.fromJson(json),
      'session_summary' => SessionSummary.fromJson(json),
      'session_error' => SessionError.fromJson(json),
      _ => throw ArgumentError('Unknown SessionEvent type: $type'),
    };
  }

  final String sessionId;

  Map<String, dynamic> toJson();
}

@immutable
class SessionStarted extends SessionEvent {
  const SessionStarted({required super.sessionId, required this.startedAtMs});

  factory SessionStarted.fromJson(Map<String, dynamic> json) {
    return SessionStarted(
      sessionId: json['session_id'] as String,
      startedAtMs: json['started_at_ms'] as int,
    );
  }

  final int startedAtMs;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'session_started',
    'session_id': sessionId,
    'started_at_ms': startedAtMs,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionStarted &&
          sessionId == other.sessionId &&
          startedAtMs == other.startedAtMs;

  @override
  int get hashCode => Object.hash(sessionId, startedAtMs);

  @override
  String toString() =>
      'SessionStarted(sessionId: $sessionId, startedAtMs: $startedAtMs)';
}

@immutable
class HsiFrame extends SessionEvent {
  const HsiFrame({
    required super.sessionId,
    required this.seq,
    required this.emittedAtMs,
    required this.hsiJson,
    this.encoding = PayloadEncoding.jsonUtf8,
  });

  factory HsiFrame.fromJson(Map<String, dynamic> json) {
    return HsiFrame(
      sessionId: json['session_id'] as String,
      seq: json['seq'] as int,
      emittedAtMs: json['emitted_at_ms'] as int,
      encoding: json['encoding'] != null
          ? PayloadEncoding.fromString(json['encoding'] as String)
          : PayloadEncoding.jsonUtf8,
      hsiJson: json['hsi_json'] as Map<String, dynamic>,
    );
  }

  final int seq;
  final int emittedAtMs;
  final PayloadEncoding encoding;
  final Map<String, dynamic> hsiJson;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'hsi_frame',
    'session_id': sessionId,
    'seq': seq,
    'emitted_at_ms': emittedAtMs,
    'encoding': encoding.value,
    'hsi_json': hsiJson,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HsiFrame &&
          sessionId == other.sessionId &&
          seq == other.seq &&
          emittedAtMs == other.emittedAtMs &&
          encoding == other.encoding;

  @override
  int get hashCode => Object.hash(sessionId, seq, emittedAtMs, encoding);

  @override
  String toString() =>
      'HsiFrame(sessionId: $sessionId, seq: $seq, '
      'emittedAtMs: $emittedAtMs, encoding: ${encoding.value})';
}

@immutable
class SessionSummary extends SessionEvent {
  const SessionSummary({
    required super.sessionId,
    required this.durationActualSec,
    required this.hsiJson,
    this.encoding = PayloadEncoding.jsonUtf8,
  });

  factory SessionSummary.fromJson(Map<String, dynamic> json) {
    return SessionSummary(
      sessionId: json['session_id'] as String,
      durationActualSec: json['duration_actual_sec'] as int,
      encoding: json['encoding'] != null
          ? PayloadEncoding.fromString(json['encoding'] as String)
          : PayloadEncoding.jsonUtf8,
      hsiJson: json['hsi_json'] as Map<String, dynamic>,
    );
  }

  final int durationActualSec;
  final PayloadEncoding encoding;
  final Map<String, dynamic> hsiJson;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'session_summary',
    'session_id': sessionId,
    'duration_actual_sec': durationActualSec,
    'encoding': encoding.value,
    'hsi_json': hsiJson,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionSummary &&
          sessionId == other.sessionId &&
          durationActualSec == other.durationActualSec &&
          encoding == other.encoding;

  @override
  int get hashCode => Object.hash(sessionId, durationActualSec, encoding);

  @override
  String toString() =>
      'SessionSummary(sessionId: $sessionId, '
      'durationActualSec: $durationActualSec, '
      'encoding: ${encoding.value})';
}

@immutable
class SessionError extends SessionEvent {
  const SessionError({
    required super.sessionId,
    required this.code,
    required this.message,
  });

  factory SessionError.fromJson(Map<String, dynamic> json) {
    return SessionError(
      sessionId: json['session_id'] as String,
      code: SessionErrorCode.fromString(json['code'] as String),
      message: json['message'] as String,
    );
  }

  final SessionErrorCode code;
  final String message;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'session_error',
    'session_id': sessionId,
    'code': code.value,
    'message': message,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionError &&
          sessionId == other.sessionId &&
          code == other.code &&
          message == other.message;

  @override
  int get hashCode => Object.hash(sessionId, code, message);

  @override
  String toString() =>
      'SessionError(sessionId: $sessionId, code: ${code.value}, '
      'message: $message)';
}

@immutable
class BiosignalFrame extends SessionEvent {
  const BiosignalFrame({
    required super.sessionId,
    required this.seq,
    required this.emittedAtMs,
    required this.samples,
  });

  factory BiosignalFrame.fromJson(Map<String, dynamic> json) {
    final rawSamples = json['samples'] as List<dynamic>;
    return BiosignalFrame(
      sessionId: json['session_id'] as String,
      seq: json['seq'] as int,
      emittedAtMs: json['emitted_at_ms'] as int,
      samples: rawSamples
          .map((s) => BiosignalSample.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  final int seq;
  final int emittedAtMs;
  final List<BiosignalSample> samples;

  @override
  Map<String, dynamic> toJson() => {
    'type': 'biosignal_frame',
    'session_id': sessionId,
    'seq': seq,
    'emitted_at_ms': emittedAtMs,
    'samples': samples.map((s) => s.toJson()).toList(),
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BiosignalFrame &&
          sessionId == other.sessionId &&
          seq == other.seq &&
          emittedAtMs == other.emittedAtMs;

  @override
  int get hashCode => Object.hash(sessionId, seq, emittedAtMs);

  @override
  String toString() =>
      'BiosignalFrame(sessionId: $sessionId, seq: $seq, '
      'emittedAtMs: $emittedAtMs, samples: ${samples.length})';
}

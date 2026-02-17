import 'package:meta/meta.dart';
import 'package:synheart_session/src/types/compute_profile.dart';
import 'package:synheart_session/src/types/enums.dart';
import 'package:uuid/uuid.dart';

@immutable
class SessionConfig {
  SessionConfig({
    required this.mode,
    required this.durationSec,
    String? sessionId,
    this.profile = const ComputeProfile(),
    this.windowLabel,
    this.includeRawSamples = false,
  }) : sessionId = sessionId ?? const Uuid().v4();

  factory SessionConfig.fromJson(Map<String, dynamic> json) {
    return SessionConfig(
      sessionId: json['session_id'] as String?,
      mode: SessionMode.fromString(json['mode'] as String),
      durationSec: json['duration_sec'] as int,
      profile: json['profile'] != null
          ? ComputeProfile.fromJson(json['profile'] as Map<String, dynamic>)
          : const ComputeProfile(),
      windowLabel: json['window_label'] as String?,
      includeRawSamples: json['include_raw_samples'] as bool? ?? false,
    );
  }

  final String sessionId;
  final SessionMode mode;
  final int durationSec;
  final ComputeProfile profile;
  final String? windowLabel;
  final bool includeRawSamples;

  Map<String, dynamic> toJson() => {
    'session_id': sessionId,
    'mode': mode.value,
    'duration_sec': durationSec,
    'profile': profile.toJson(),
    if (windowLabel != null) 'window_label': windowLabel,
    'include_raw_samples': includeRawSamples,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionConfig &&
          sessionId == other.sessionId &&
          mode == other.mode &&
          durationSec == other.durationSec &&
          profile == other.profile &&
          windowLabel == other.windowLabel &&
          includeRawSamples == other.includeRawSamples;

  @override
  int get hashCode => Object.hash(
    sessionId,
    mode,
    durationSec,
    profile,
    windowLabel,
    includeRawSamples,
  );

  @override
  String toString() =>
      'SessionConfig(sessionId: $sessionId, mode: ${mode.value}, '
      'durationSec: $durationSec, profile: $profile, '
      'windowLabel: $windowLabel, '
      'includeRawSamples: $includeRawSamples)';
}

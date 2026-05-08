import 'package:meta/meta.dart';

@immutable
class ComputeProfile {
  const ComputeProfile({
    this.windowSec = 60,
    this.emitIntervalSec = 5,
    this.rawEmitIntervalSec,
  });

  factory ComputeProfile.fromJson(Map<String, dynamic> json) {
    return ComputeProfile(
      windowSec: json['window_sec'] as int? ?? 60,
      emitIntervalSec: json['emit_interval_sec'] as int? ?? 5,
      rawEmitIntervalSec: json['raw_emit_interval_sec'] as int?,
    );
  }

  final int windowSec;
  final int emitIntervalSec;
  final int? rawEmitIntervalSec;

  Map<String, dynamic> toJson() => {
    'window_sec': windowSec,
    'emit_interval_sec': emitIntervalSec,
    if (rawEmitIntervalSec != null) 'raw_emit_interval_sec': rawEmitIntervalSec,
  };

  ComputeProfile copyWith({
    int? windowSec,
    int? emitIntervalSec,
    int? rawEmitIntervalSec,
  }) {
    return ComputeProfile(
      windowSec: windowSec ?? this.windowSec,
      emitIntervalSec: emitIntervalSec ?? this.emitIntervalSec,
      rawEmitIntervalSec: rawEmitIntervalSec ?? this.rawEmitIntervalSec,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComputeProfile &&
          windowSec == other.windowSec &&
          emitIntervalSec == other.emitIntervalSec &&
          rawEmitIntervalSec == other.rawEmitIntervalSec;

  @override
  int get hashCode =>
      Object.hash(windowSec, emitIntervalSec, rawEmitIntervalSec);

  @override
  String toString() =>
      'ComputeProfile('
      'windowSec: $windowSec, '
      'emitIntervalSec: $emitIntervalSec, '
      'rawEmitIntervalSec: $rawEmitIntervalSec)';
}

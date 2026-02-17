import 'package:meta/meta.dart';

@immutable
class BiosignalSample {
  const BiosignalSample({
    required this.timestampMs,
    required this.bpm,
    this.rrIntervalMs,
    this.accelerometer,
    this.spo2,
  });

  factory BiosignalSample.fromJson(Map<String, dynamic> json) {
    ({double x, double y, double z})? accel;
    if (json['accelerometer'] is Map<String, dynamic>) {
      final a = json['accelerometer'] as Map<String, dynamic>;
      accel = (
        x: (a['x'] as num).toDouble(),
        y: (a['y'] as num).toDouble(),
        z: (a['z'] as num).toDouble(),
      );
    }

    return BiosignalSample(
      timestampMs: json['timestamp_ms'] as int,
      bpm: (json['bpm'] as num).toDouble(),
      rrIntervalMs: (json['rr_interval_ms'] as num?)?.toDouble(),
      accelerometer: accel,
      spo2: (json['spo2'] as num?)?.toDouble(),
    );
  }

  final int timestampMs;
  final double bpm;
  final double? rrIntervalMs;
  final ({double x, double y, double z})? accelerometer;
  final double? spo2;

  Map<String, dynamic> toJson() => {
    'timestamp_ms': timestampMs,
    'bpm': bpm,
    if (rrIntervalMs != null) 'rr_interval_ms': rrIntervalMs,
    if (accelerometer != null)
      'accelerometer': {
        'x': accelerometer!.x,
        'y': accelerometer!.y,
        'z': accelerometer!.z,
      },
    if (spo2 != null) 'spo2': spo2,
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BiosignalSample &&
          timestampMs == other.timestampMs &&
          bpm == other.bpm &&
          rrIntervalMs == other.rrIntervalMs &&
          accelerometer == other.accelerometer &&
          spo2 == other.spo2;

  @override
  int get hashCode =>
      Object.hash(timestampMs, bpm, rrIntervalMs, accelerometer, spo2);

  @override
  String toString() => 'BiosignalSample(timestampMs: $timestampMs, bpm: $bpm)';
}

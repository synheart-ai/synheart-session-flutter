import 'package:meta/meta.dart';

/// Minimal interface for providing BLE heart-rate samples to `SynheartSession`.
///
/// This package does not mandate a specific BLE implementation; any app can
/// adapt its BLE stack to this interface.
abstract class BleHrmProvider {
  Stream<BleHeartRateSample> get onHeartRate;
}

@immutable
class BleHeartRateSample {
  const BleHeartRateSample({
    required this.timestampMs,
    required this.bpm,
    this.rrIntervalsMs = const <double>[],
  });

  /// Unix epoch timestamp in milliseconds.
  final int timestampMs;

  /// Heart rate in BPM.
  final double bpm;

  /// RR-intervals in milliseconds, if available.
  final List<double> rrIntervalsMs;

  @override
  String toString() =>
      'BleHeartRateSample(timestampMs: $timestampMs, bpm: $bpm, '
      'rrIntervalsMs: ${rrIntervalsMs.length})';
}

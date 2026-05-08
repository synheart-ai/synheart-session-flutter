import 'dart:math';

class MockHrGenerator {
  MockHrGenerator({int? seed}) : _random = Random(seed);

  final Random _random;

  static const _baselineBpm = 72.0;
  static const _breathingCycleSec = 4.0;
  static const _breathingAmplitude = 5.0;
  static const _noiseAmplitude = 2.0;

  List<({int timestampMs, double bpm})> generate({
    required int startMs,
    required int count,
    int intervalMs = 1000,
  }) {
    final samples = <({int timestampMs, double bpm})>[];
    for (var i = 0; i < count; i++) {
      final ts = startMs + i * intervalMs;
      final elapsedSec = (i * intervalMs) / 1000.0;

      // Breathing modulation (sinusoidal)
      final breathingPhase = 2 * pi * elapsedSec / _breathingCycleSec;
      final breathingComponent = _breathingAmplitude * sin(breathingPhase);

      // Random noise
      final noise = (_random.nextDouble() * 2 - 1) * _noiseAmplitude;

      final bpm = (_baselineBpm + breathingComponent + noise).clamp(
        40.0,
        200.0,
      );
      samples.add((timestampMs: ts, bpm: bpm));
    }
    return samples;
  }
}

import 'package:meta/meta.dart';

/// A point-in-time snapshot of behavioral signals.
/// Mirrors `BehaviorStats` from synheart_behavior field-for-field
/// but lives in synheart_session to avoid an import dependency.
@immutable
class BehaviorSnapshot {
  const BehaviorSnapshot({
    required this.timestamp,
    this.typingCadence,
    this.interKeyLatency,
    this.burstLength,
    this.scrollVelocity,
    this.scrollAcceleration,
    this.scrollJitter,
    this.tapRate,
    this.appSwitchesPerMinute = 0,
    this.foregroundDuration,
    this.idleGapSeconds,
    this.stabilityIndex,
    this.fragmentationIndex,
  });

  factory BehaviorSnapshot.fromJson(Map<String, dynamic> json) {
    return BehaviorSnapshot(
      typingCadence: (json['typing_cadence'] as num?)?.toDouble(),
      interKeyLatency: (json['inter_key_latency'] as num?)?.toDouble(),
      burstLength: json['burst_length'] as int?,
      scrollVelocity: (json['scroll_velocity'] as num?)?.toDouble(),
      scrollAcceleration: (json['scroll_acceleration'] as num?)?.toDouble(),
      scrollJitter: (json['scroll_jitter'] as num?)?.toDouble(),
      tapRate: (json['tap_rate'] as num?)?.toDouble(),
      appSwitchesPerMinute: json['app_switches_per_minute'] as int? ?? 0,
      foregroundDuration: (json['foreground_duration'] as num?)?.toDouble(),
      idleGapSeconds: (json['idle_gap_seconds'] as num?)?.toDouble(),
      stabilityIndex: (json['stability_index'] as num?)?.toDouble(),
      fragmentationIndex: (json['fragmentation_index'] as num?)?.toDouble(),
      timestamp: json['timestamp'] as int,
    );
  }

  /// Current typing cadence (keys per second).
  final double? typingCadence;

  /// Current inter-key latency in milliseconds.
  final double? interKeyLatency;

  /// Current burst length (number of keys in current burst).
  final int? burstLength;

  /// Current scroll velocity (pixels per second).
  final double? scrollVelocity;

  /// Current scroll acceleration (pixels per second squared).
  final double? scrollAcceleration;

  /// Current scroll jitter (variance in scroll speed).
  final double? scrollJitter;

  /// Current tap rate (taps per second).
  final double? tapRate;

  /// Number of app switches in the last minute.
  final int appSwitchesPerMinute;

  /// Current foreground duration in seconds.
  final double? foregroundDuration;

  /// Current idle gap duration in seconds.
  final double? idleGapSeconds;

  /// Current session stability index (0.0 to 1.0).
  final double? stabilityIndex;

  /// Current fragmentation index (0.0 to 1.0).
  final double? fragmentationIndex;

  /// Timestamp when these stats were captured.
  final int timestamp;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'app_switches_per_minute': appSwitchesPerMinute,
      'timestamp': timestamp,
    };
    if (typingCadence != null) map['typing_cadence'] = typingCadence;
    if (interKeyLatency != null) map['inter_key_latency'] = interKeyLatency;
    if (burstLength != null) map['burst_length'] = burstLength;
    if (scrollVelocity != null) map['scroll_velocity'] = scrollVelocity;
    if (scrollAcceleration != null) {
      map['scroll_acceleration'] = scrollAcceleration;
    }
    if (scrollJitter != null) map['scroll_jitter'] = scrollJitter;
    if (tapRate != null) map['tap_rate'] = tapRate;
    if (foregroundDuration != null) {
      map['foreground_duration'] = foregroundDuration;
    }
    if (idleGapSeconds != null) map['idle_gap_seconds'] = idleGapSeconds;
    if (stabilityIndex != null) map['stability_index'] = stabilityIndex;
    if (fragmentationIndex != null) {
      map['fragmentation_index'] = fragmentationIndex;
    }
    return map;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BehaviorSnapshot &&
          typingCadence == other.typingCadence &&
          interKeyLatency == other.interKeyLatency &&
          burstLength == other.burstLength &&
          scrollVelocity == other.scrollVelocity &&
          scrollAcceleration == other.scrollAcceleration &&
          scrollJitter == other.scrollJitter &&
          tapRate == other.tapRate &&
          appSwitchesPerMinute == other.appSwitchesPerMinute &&
          foregroundDuration == other.foregroundDuration &&
          idleGapSeconds == other.idleGapSeconds &&
          stabilityIndex == other.stabilityIndex &&
          fragmentationIndex == other.fragmentationIndex &&
          timestamp == other.timestamp;

  @override
  int get hashCode => Object.hash(
    typingCadence,
    interKeyLatency,
    burstLength,
    scrollVelocity,
    scrollAcceleration,
    scrollJitter,
    tapRate,
    appSwitchesPerMinute,
    foregroundDuration,
    idleGapSeconds,
    stabilityIndex,
    fragmentationIndex,
    timestamp,
  );

  @override
  String toString() =>
      'BehaviorSnapshot(stabilityIndex: $stabilityIndex, '
      'fragmentationIndex: $fragmentationIndex, '
      'timestamp: $timestamp)';
}

/// Abstraction over any behavioral signal source (mock, synheart-behavior SDK).
/// Pull-based — `MockSessionEngine` queries [currentSnapshot] at each frame
/// tick.
abstract class BehaviorProvider {
  bool get isAvailable;
  String get name;
  BehaviorSnapshot? currentSnapshot();
}

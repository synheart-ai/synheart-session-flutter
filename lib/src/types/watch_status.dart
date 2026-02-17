/// Immutable snapshot of Apple Watch connectivity status.
class WatchStatus {
  const WatchStatus({
    required this.supported,
    required this.reachable,
    required this.paired,
    required this.installed,
  });

  factory WatchStatus.fromJson(Map<String, dynamic> json) {
    return WatchStatus(
      supported: json['supported'] as bool? ?? false,
      reachable: json['reachable'] as bool? ?? false,
      paired: json['paired'] as bool? ?? false,
      installed: json['installed'] as bool? ?? false,
    );
  }

  final bool supported;
  final bool reachable;
  final bool paired;
  final bool installed;

  @override
  String toString() =>
      'WatchStatus(supported: $supported, reachable: $reachable, '
      'paired: $paired, installed: $installed)';
}

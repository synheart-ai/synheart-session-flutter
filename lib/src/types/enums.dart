enum SessionMode {
  focus('focus'),
  breathing('breathing');

  const SessionMode(this.value);

  final String value;

  static SessionMode fromString(String value) {
    return SessionMode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown SessionMode: $value'),
    );
  }
}

enum SessionErrorCode {
  permissionDenied('permission_denied'),
  sensorUnavailable('sensor_unavailable'),
  lowBattery('low_battery'),
  osTerminated('os_terminated'),
  invalidState('invalid_state');

  const SessionErrorCode(this.value);

  final String value;

  static SessionErrorCode fromString(String value) {
    return SessionErrorCode.values.firstWhere(
      (e) => e.value == value,
      orElse: () => throw ArgumentError('Unknown SessionErrorCode: $value'),
    );
  }
}

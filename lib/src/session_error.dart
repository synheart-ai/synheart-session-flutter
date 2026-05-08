class SynheartSessionError implements Exception {
  const SynheartSessionError(this.message);

  final String message;

  @override
  String toString() => 'SynheartSessionError: $message';
}

class SessionPermissionDeniedError extends SynheartSessionError {
  const SessionPermissionDeniedError([super.message = 'Permission denied']);

  @override
  String toString() => 'SessionPermissionDeniedError: $message';
}

class SessionSensorUnavailableError extends SynheartSessionError {
  const SessionSensorUnavailableError([super.message = 'Sensor unavailable']);

  @override
  String toString() => 'SessionSensorUnavailableError: $message';
}

class SessionInvalidStateError extends SynheartSessionError {
  const SessionInvalidStateError([super.message = 'Invalid state']);

  @override
  String toString() => 'SessionInvalidStateError: $message';
}

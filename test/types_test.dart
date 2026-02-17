import 'package:flutter_test/flutter_test.dart';
import 'package:synheart_session/synheart_session.dart';

void main() {
  group('SessionMode', () {
    test('value returns wire string', () {
      expect(SessionMode.focus.value, 'focus');
      expect(SessionMode.breathing.value, 'breathing');
    });

    test('fromString roundtrips', () {
      for (final mode in SessionMode.values) {
        expect(SessionMode.fromString(mode.value), mode);
      }
    });

    test('fromString throws on unknown', () {
      expect(() => SessionMode.fromString('unknown'), throwsArgumentError);
    });
  });

  group('SessionErrorCode', () {
    test('value returns wire string', () {
      expect(SessionErrorCode.permissionDenied.value, 'permission_denied');
      expect(SessionErrorCode.sensorUnavailable.value, 'sensor_unavailable');
      expect(SessionErrorCode.lowBattery.value, 'low_battery');
      expect(SessionErrorCode.osTerminated.value, 'os_terminated');
      expect(SessionErrorCode.invalidState.value, 'invalid_state');
    });

    test('fromString roundtrips', () {
      for (final code in SessionErrorCode.values) {
        expect(SessionErrorCode.fromString(code.value), code);
      }
    });

    test('fromString throws on unknown', () {
      expect(() => SessionErrorCode.fromString('unknown'), throwsArgumentError);
    });
  });

  group('PayloadEncoding', () {
    test('value returns wire string', () {
      expect(PayloadEncoding.jsonUtf8.value, 'json_utf8');
    });

    test('fromString roundtrips', () {
      for (final enc in PayloadEncoding.values) {
        expect(PayloadEncoding.fromString(enc.value), enc);
      }
    });

    test('fromString throws on unknown', () {
      expect(() => PayloadEncoding.fromString('unknown'), throwsArgumentError);
    });
  });

  group('ComputeProfile', () {
    test('defaults', () {
      const profile = ComputeProfile();
      expect(profile.windowSec, 60);
      expect(profile.emitIntervalSec, 5);
    });

    test('JSON roundtrip', () {
      const profile = ComputeProfile(windowSec: 30, emitIntervalSec: 10);
      final json = profile.toJson();
      final decoded = ComputeProfile.fromJson(json);
      expect(decoded, profile);
    });

    test('fromJson uses defaults for missing fields', () {
      final profile = ComputeProfile.fromJson(const <String, dynamic>{});
      expect(profile.windowSec, 60);
      expect(profile.emitIntervalSec, 5);
    });

    test('copyWith', () {
      const profile = ComputeProfile();
      final updated = profile.copyWith(windowSec: 120);
      expect(updated.windowSec, 120);
      expect(updated.emitIntervalSec, 5);
    });
  });

  group('SessionConfig', () {
    test('auto-generates sessionId if not provided', () {
      final config = SessionConfig(mode: SessionMode.focus, durationSec: 300);
      expect(config.sessionId, isNotEmpty);
      // UUID v4 format
      expect(
        config.sessionId,
        matches(
          RegExp(
            '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-'
            r'[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
    });

    test('uses provided sessionId', () {
      final config = SessionConfig(
        sessionId: 'my-session',
        mode: SessionMode.breathing,
        durationSec: 60,
      );
      expect(config.sessionId, 'my-session');
    });

    test('JSON roundtrip', () {
      final config = SessionConfig(
        sessionId: 'test-id',
        mode: SessionMode.focus,
        durationSec: 300,
        profile: const ComputeProfile(windowSec: 30),
        windowLabel: 'test-label',
      );
      final json = config.toJson();
      final decoded = SessionConfig.fromJson(json);
      expect(decoded, config);
    });

    test('JSON roundtrip without windowLabel', () {
      final config = SessionConfig(
        sessionId: 'test-id',
        mode: SessionMode.focus,
        durationSec: 300,
      );
      final json = config.toJson();
      expect(json.containsKey('window_label'), isFalse);
      final decoded = SessionConfig.fromJson(json);
      expect(decoded.windowLabel, isNull);
    });
  });

  group('SessionEvent', () {
    test('fromJson dispatches SessionStarted', () {
      final event = SessionEvent.fromJson({
        'type': 'session_started',
        'session_id': 'abc',
        'started_at_ms': 1000,
      });
      expect(event, isA<SessionStarted>());
      final started = event as SessionStarted;
      expect(started.sessionId, 'abc');
      expect(started.startedAtMs, 1000);
    });

    test('fromJson dispatches HsiFrame', () {
      final event = SessionEvent.fromJson({
        'type': 'hsi_frame',
        'session_id': 'abc',
        'seq': 1,
        'emitted_at_ms': 2000,
        'encoding': 'json_utf8',
        'hsi_json': <String, dynamic>{'hsi_version': '1.0'},
      });
      expect(event, isA<HsiFrame>());
      final frame = event as HsiFrame;
      expect(frame.seq, 1);
      expect(frame.hsiJson['hsi_version'], '1.0');
    });

    test('fromJson dispatches SessionSummary', () {
      final event = SessionEvent.fromJson({
        'type': 'session_summary',
        'session_id': 'abc',
        'duration_actual_sec': 300,
        'encoding': 'json_utf8',
        'hsi_json': <String, dynamic>{'hsi_version': '1.0'},
      });
      expect(event, isA<SessionSummary>());
      expect((event as SessionSummary).durationActualSec, 300);
    });

    test('fromJson dispatches SessionError', () {
      final event = SessionEvent.fromJson({
        'type': 'session_error',
        'session_id': 'abc',
        'code': 'permission_denied',
        'message': 'No access',
      });
      expect(event, isA<SessionError>());
      final error = event as SessionError;
      expect(error.code, SessionErrorCode.permissionDenied);
      expect(error.message, 'No access');
    });

    test('fromJson throws on unknown type', () {
      expect(
        () => SessionEvent.fromJson({
          'type': 'unknown_event',
          'session_id': 'abc',
        }),
        throwsArgumentError,
      );
    });

    test('SessionStarted toJson roundtrip', () {
      const event = SessionStarted(sessionId: 'x', startedAtMs: 100);
      final decoded = SessionEvent.fromJson(event.toJson());
      expect(decoded, isA<SessionStarted>());
      expect((decoded as SessionStarted).startedAtMs, 100);
    });

    test('HsiFrame toJson roundtrip', () {
      const event = HsiFrame(
        sessionId: 'x',
        seq: 5,
        emittedAtMs: 500,
        hsiJson: {'key': 'value'},
      );
      final decoded = SessionEvent.fromJson(event.toJson());
      expect(decoded, isA<HsiFrame>());
      expect((decoded as HsiFrame).seq, 5);
    });
  });

  group('SessionStatus', () {
    test('JSON roundtrip', () {
      const status = SessionStatus(sessionId: 'abc', active: true, lastSeq: 10);
      final json = status.toJson();
      final decoded = SessionStatus.fromJson(json);
      expect(decoded, status);
    });
  });
}

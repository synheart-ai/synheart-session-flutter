// ignore_for_file: avoid_print
import 'package:synheart_session/synheart_session.dart';

/// Standalone example demonstrating synheart_session usage.
///
/// Uses the mock engine — no wearable device required.
Future<void> main() async {
  final session = SynheartSession.mock(seed: 42);

  final config = SessionConfig(
    mode: SessionMode.focus,
    durationSec: 30,
    profile: const ComputeProfile(windowSec: 10),
  );

  print('Starting session ${config.sessionId}...');

  final stream = session.startSession(config);

  await for (final event in stream) {
    switch (event) {
      case SessionStarted():
        print('Session started at ${event.startedAtMs}');
      case HsiFrame():
        final hsi = event.hsiJson;
        final axes = hsi['axes'] as Map<String, dynamic>;
        final physio = axes['physiological'] as Map<String, dynamic>;
        print(
          'HSI #${event.seq}: '
          'hr=${physio['hr_mean_bpm']} bpm, '
          'sdnn=${physio['hr_sdnn_ms']} ms',
        );
      case BiosignalFrame():
        final latest = event.samples.last;
        print('BIO #${event.seq}: bpm=${latest.bpm.toStringAsFixed(1)}');
      case SessionSummary():
        print('Session complete: ${event.durationActualSec}s');
      case SessionError():
        print('Error [${event.code.value}]: ${event.message}');
    }
  }

  session.dispose();
  print('Done.');
}

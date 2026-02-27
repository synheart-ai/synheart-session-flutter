import 'dart:async';

import 'package:synheart_session/src/channel/session_channel.dart';
import 'package:synheart_session/src/types/biosignal_provider.dart';
import 'package:synheart_session/src/types/biosignal_sample.dart';
import 'package:synheart_session/src/types/session_event.dart';

/// Biosignal provider that bridges HR data from the iOS/Android watch relay
/// (via [SessionChannel]) into the standard [BiosignalProvider] interface.
///
/// Usage:
/// ```dart
/// final session = SynheartSession(
///   biosignalProvider: WatchBiosignalProvider(),
/// );
/// session.startSession(config); // standard path — watch is just a provider
/// ```
class WatchBiosignalProvider implements BiosignalProvider {
  WatchBiosignalProvider({SessionChannel? channel})
    : _channel = channel ?? SessionChannel();

  final SessionChannel _channel;
  StreamController<BiosignalSample>? _controller;
  StreamSubscription<SessionEvent>? _subscription;

  @override
  bool get isAvailable => true; // optimistic; watch may not be connected

  @override
  String get name => 'watch';

  /// Exposes the underlying channel for session commands and status queries.
  SessionChannel get channel => _channel;

  @override
  Stream<BiosignalSample> startStreaming() {
    _controller = StreamController<BiosignalSample>.broadcast(
      onCancel: stopStreaming,
    );

    _subscription = _channel.events.listen(
      _handleEvent,
      onError: (Object e) {
        // Channel errors are non-fatal for the HR stream — the watch may
        // disconnect and reconnect without invalidating the session.
      },
    );

    return _controller!.stream;
  }

  @override
  void stopStreaming() {
    _subscription?.cancel();
    _subscription = null;
    _controller?.close();
    _controller = null;
  }

  void _handleEvent(SessionEvent event) {
    final ctrl = _controller;
    if (ctrl == null || ctrl.isClosed) return;

    if (event is BiosignalFrame) {
      // Preferred: raw samples from watch
      for (final sample in event.samples) {
        ctrl.add(sample);
      }
    } else if (event is SessionFrame) {
      // Fallback: synthesize sample from computed metrics
      final bpm = (event.metrics['hr_mean_bpm'] as num?)?.toDouble();
      if (bpm != null && bpm > 0) {
        ctrl.add(
          BiosignalSample(
            timestampMs: event.emittedAtMs,
            bpm: bpm,
            rrIntervalMs: 60000.0 / bpm,
          ),
        );
      }
    }
    // Ignore SessionStarted, SessionSummary, SessionError — those are
    // session lifecycle events, not biosignal data.
  }
}

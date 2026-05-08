import 'package:synheart_session/src/types/biosignal_sample.dart';

/// Abstraction over any biosignal source (mock, BLE HRM, Apple Watch, etc.).
/// Stream-based — consumers call [startStreaming] and listen for samples.
abstract class BiosignalProvider {
  bool get isAvailable;
  String get name;
  Stream<BiosignalSample> startStreaming();
  void stopStreaming();
}

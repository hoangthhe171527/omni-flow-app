import 'dart:async';

import 'package:omni_app/modules/inbox/application/voice_recorder.dart';

/// Máy ghi giả cho test composer/ThreadPage: nhịp `elapsed` do test phát
/// bằng [tick], không chạm kênh nền tảng.
class FakeVoiceRecorder implements VoiceRecorder {
  bool permission = true;
  final starts = <String>[];
  int stops = 0;
  int cancels = 0;
  int disposes = 0;
  final _ticks = StreamController<Duration>.broadcast();

  void tick(Duration d) => _ticks.add(d);

  @override
  Future<bool> ensurePermission() async => permission;

  @override
  Future<String> newRecordingPath() async =>
      '/tmp/${voiceRecordingName(DateTime(2026, 10, 10, 9, 5, 7))}';

  @override
  Future<void> start(String path) async => starts.add(path);

  @override
  Future<String?> stop() async {
    stops++;
    return starts.last;
  }

  @override
  Future<void> cancel() async => cancels++;

  @override
  Stream<Duration> get elapsed => _ticks.stream;

  @override
  Future<void> dispose() async => disposes++;
}
